#!/usr/bin/env bash
# Guarded merge of a train PR: one CI run for several approved PRs.
#
#   train_merge.sh <train PR> <reviewed head sha> <members.json> <train name> <checkout>
#
# members.json is [{"pr": N, "row": NN, "branch": "agent/NN-slug", "text": "what to look for"}].
# Merges only when CI is green on the head that was built and reviewed; then
# closes each member PR as merged via the train and writes their Merged rows.
# Like automerge.sh it resets <checkout> to the base tip: give it its own worktree.
source "$(dirname "$(readlink -f "$0")")/../agents/config.sh"
PR=$1 HEAD0=$2 MEMBERS=$3 TRAIN=$4 CO=$5
cd "$CO" || exit 1
q='[.statusCheckRollup[] | (.conclusion // .state // "")] | if length==0 then "pending" elif any(.=="FAILURE" or .=="ERROR" or .=="CANCELLED") then "FAIL" elif any(.=="" or .=="PENDING" or .=="IN_PROGRESS" or .=="QUEUED") then "pending" elif any(.=="SUCCESS") then "pass" else "FAIL" end'
st() { gh pr view "$PR" --json statusCheckRollup -q "$q" < /dev/null 2>/dev/null; }
until s=$(st); [ "$s" = pass ] || [ "$s" = FAIL ]; do sleep 30; done
h=$(gh pr view "$PR" --json headRefOid -q .headRefOid < /dev/null)
echo "$TRAIN #$PR CI $s head_same=$([ "$h" = "$HEAD0" ] && echo yes || echo NO)"
[ "$s" = pass ] && [ "$h" = "$HEAD0" ] || exit 0
for try in 1 2 3 4 5 6; do
  out=$(gh pr merge "$PR" --merge --match-head-commit "$HEAD0" < /dev/null 2>&1)
  echo "$out" | grep -v '^$'
  echo "$out" | grep -q 'Base branch was modified' || break
  sleep $((try * 15))
done
[ "$(gh pr view "$PR" --json state -q .state < /dev/null)" = MERGED ] || { echo "$TRAIN #$PR NOT merged -- left as is"; exit 0; }
msha=$(gh pr view "$PR" --json mergeCommit -q .mergeCommit.oid < /dev/null)
git push -q origin --delete "$TRAIN" < /dev/null 2>/dev/null
# Members: GitHub may already read them MERGED (their heads are now in the
# base); otherwise close them with the train named. Branches go only after that.
jq -r '.[] | "\(.pr) \(.branch)"' "$MEMBERS" | while read -r n br; do
  state=$(gh pr view "$n" --json state -q .state < /dev/null)
  if [ "$state" = MERGED ]; then
    gh pr comment "$n" --body "Merged via $TRAIN (PR #$PR, ${msha:0:7})." < /dev/null >/dev/null
  else
    gh pr close "$n" --comment "Merged via $TRAIN (PR #$PR, ${msha:0:7}); its head is in $TEAM_BASE." < /dev/null >/dev/null
  fi
  git push -q origin --delete "$br" < /dev/null 2>/dev/null
  echo "member #$n: was $state, now $(gh pr view "$n" --json state -q .state < /dev/null)"
done
exec 9>"$TEAM_BASE_LOCK"; flock 9
rows=$(jq -r '[.[] | "#\(.row)"] | join(" ")' "$MEMBERS")
msg="Merge $TRAIN (PR #$PR): $rows"
[ -n "${TEAM_COMMIT_TRAILER:-}" ] && msg="$msg

$TEAM_COMMIT_TRAILER"
for attempt in 1 2 3 4 5; do
  git fetch -q origin "$TEAM_BASE" 2>/dev/null
  git reset -q --hard "origin/$TEAM_BASE" || continue
  MEMBERS="$MEMBERS" TRAIN="$TRAIN" PRN="$PR" "$TEAM_PYTHON" -c "
import os,json,pathlib
B=pathlib.Path('docs/BACKLOG.md'); t=B.read_text()
a='| # | what to look for in the run |\n|---|---|\n'
if a not in t: raise SystemExit('Merged table header not found')
add=''
for m in json.load(open(os.environ['MEMBERS'])):
    L=t.split('\n')
    L=[l for l in L if not l.startswith('| **'+str(m['row'])+'**')]
    t='\n'.join(L)
    add+='| '+str(m['row'])+' | ('+os.environ['TRAIN']+', PR #'+os.environ['PRN']+') '+m['text']+' |\n'
t=t.replace(a,a+add,1); B.write_text(t)" || continue
  git diff --quiet docs/BACKLOG.md && { echo "backlog already records $TRAIN"; break; }
  git add docs/BACKLOG.md
  git commit -q -m "$msg" || continue
  if git push -q origin "HEAD:$TEAM_BASE" < /dev/null; then git log --oneline -1; break; fi
  echo "backlog push lost a race (attempt $attempt); retrying"; sleep $((attempt * 3))
  [ "$attempt" = 5 ] && echo "$TRAIN MERGED but the Merged rows were NOT written -- add them by hand"
done
gh pr view "$PR" --json state -q .state < /dev/null
