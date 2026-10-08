#!/usr/bin/env bash
# Guarded merge of one reviewed PR, then its *Merged* row in docs/BACKLOG.md.
#
#   scripts/lead/automerge.sh <PR> <row> "<what to look for in the next live run>" <branch>
#
# Merges only when CI passes and the head is the one reviewed; cleans up only
# after the PR reads MERGED. It resets the checkout it runs in to the base tip
# before writing the backlog, so run it from a worktree of its own
# (<wt-root>/<lead>-merge), by its absolute path, in a detached job:
#   systemd-run --user --collect --unit automerge-pr<N> --working-directory "$PWD" \
#     "$PWD/scripts/lead/automerge.sh" <N> <row> "<text>" <branch>
source "$(dirname "$(readlink -f "$0")")/../agents/config.sh"
cd "$TEAM_REPO_ROOT" || exit 1
ignore_json=$(printf '%s\n' $TEAM_CI_IGNORE_CHECKS | jq -R . | jq -sc .)
# Only the newest workflow run counts: a re-triggered run's jobs sit beside the
# old run's, whose never-started jobs read CANCELLED. A cancelled run on what
# became the same head stays in the rollup too. A pass needs one SUCCESS
# besides the ignored checks (TEAM_CI_IGNORE_CHECKS): a draft's checks all read
# SKIPPED, and an all-SKIPPED rollup must never read "pass" — a merge with no
# test run.
q='[.statusCheckRollup[] | . + {run: ((.detailsUrl // .targetUrl // "") | [scan("/runs/([0-9]+)")] | (.[0][0] // "0") | tonumber)}] | (map(.run) | max) as $m | [.[] | select(.run == $m) | {n: (.name // .context // ""), c: (.conclusion // .state // "")}] | if length==0 then "pending" elif any(.c=="FAILURE" or .c=="ERROR" or .c=="CANCELLED" or .c=="TIMED_OUT") then "FAIL" elif any(.c=="" or .c=="PENDING" or .c=="IN_PROGRESS" or .c=="QUEUED" or .c=="WAITING") then "pending" elif any((.n | IN('"$ignore_json"'[]) | not) and .c=="SUCCESS") then "pass" else "FAIL" end'
head0=$(gh pr view "$1" --json headRefOid -q .headRefOid < /dev/null)
# CI skips drafts; a job started on one would wait on checks that never run.
[ "$(gh pr view "$1" --json isDraft -q .isDraft < /dev/null)" = false ] || { echo "#$1 is a draft (or gh failed) -- mark it ready, then start the job"; exit 0; }
# An empty answer is a failed gh call, not a verdict ("error connecting to
# api.github.com" must not end the wait), so only pass/FAIL leave the loop.
st() { gh pr view "$1" --json statusCheckRollup -q "$q" < /dev/null 2>/dev/null; }
until s=$(st "$1"); [ "$s" = pass ] || [ "$s" = FAIL ]; do sleep 30; done
h=$(gh pr view "$1" --json headRefOid -q .headRefOid < /dev/null)
echo "#$1 CI $s head_same=$([ "$h" = "$head0" ] && echo yes || echo NO)"
[ "$s" = pass ] && [ "$h" = "$head0" ] || exit 0
# Batched merges start together, and GitHub refuses the second of two
# simultaneous merges with "Base branch was modified". That is a race, not a
# verdict: retry it, on the same head.
for try in 1 2 3 4 5 6; do
  out=$(gh pr merge "$1" --merge --match-head-commit "$head0" < /dev/null 2>&1)
  echo "$out" | grep -v '^$'
  echo "$out" | grep -q 'Base branch was modified' || break
  echo "#$1 merge raced another merge (try $try); retrying"
  sleep $((try * 15))
done
# Only clean up after a confirmed merge: a refused merge (conflict) must keep
# the branch -- deleting it closes the PR unmerged.
[ "$(gh pr view "$1" --json state -q .state < /dev/null)" = MERGED ] || { echo "#$1 NOT merged -- left as is"; exit 0; }
git push -q origin --delete "$4" < /dev/null 2>/dev/null
exec 9>"$TEAM_BASE_LOCK"; flock 9
# Not one `pull && edit && commit && push` chain: a concurrent fetch fails the
# pull, `&&` skips the edit, and the merged row is silently never written.
# Retry until the push lands, and say so loudly if it never does.
msg="Merge #$2 (PR #$1)"
[ -n "${TEAM_COMMIT_TRAILER:-}" ] && msg="$msg

$TEAM_COMMIT_TRAILER"
for attempt in 1 2 3 4 5; do
  git fetch -q origin "$TEAM_BASE" 2>/dev/null
  git reset -q --hard "origin/$TEAM_BASE" || continue
  ROW="$2" TXT="$3" "$TEAM_PYTHON" -c "
import os,pathlib
B=pathlib.Path('docs/BACKLOG.md'); t=B.read_text(); L=t.split('\n')
i=next((i for i,l in enumerate(L) if l.startswith('| **'+os.environ['ROW']+'**')),None)
if i is not None: L.pop(i)
t='\n'.join(L); a='| # | what to look for in the run |\n|---|---|\n'
if a not in t: raise SystemExit('Merged table header not found')
t=t.replace(a, a+'| '+os.environ['ROW']+' | '+os.environ['TXT']+' |\n'); B.write_text(t)" || continue
  git diff --quiet docs/BACKLOG.md && { echo "#$1 backlog already records row $2"; break; }
  git add docs/BACKLOG.md
  git commit -q -m "$msg" || continue
  # HEAD, not the branch name: lead worktrees are detached on the base branch,
  # because the named branch is checked out in the owner's checkout.
  if git push -q origin "HEAD:$TEAM_BASE" < /dev/null; then
    git log --oneline -1
    break
  fi
  echo "#$1 backlog push lost a race (attempt $attempt); retrying"
  sleep $((attempt * 3))
  [ "$attempt" = 5 ] && echo "#$1 MERGED but the backlog row for $2 was NOT written -- add it by hand"
done
gh pr view "$1" --json state -q .state < /dev/null
