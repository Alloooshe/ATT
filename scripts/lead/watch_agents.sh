#!/usr/bin/env bash
# Emit one line per change in the coding agents' work: backlog claims, agent
# branch pushes, PRs opened/closed/merged, PR CI results, base-branch CI.
# For an interactive lead session, under a Monitor; the supervisor needs none.
source "$(dirname "$(readlink -f "$0")")/../agents/config.sh"
cd "$TEAM_REPO_ROOT" || exit 1
export LC_ALL=C
state() {
  git fetch -q origin --prune 2>/dev/null || true
  git show "origin/$TEAM_BASE:docs/BACKLOG.md" 2>/dev/null \
    | grep -E '^\| \*\*' | grep -vE '^\| \*\*L[123]\*\*' | awk -F' \\| ' '{gsub(/\*|\| /,"",$1); print "ROW " $1 " " $3 " " $4}'
  git for-each-ref --format='BRANCH %(refname:short) %(objectname:short)' 'refs/remotes/origin/agent/*'
  gh pr list --base "$TEAM_BASE" --state all --limit 30 \
    --json number,title,state,isDraft \
    -q '.[] | "PR #\(.number) \(.state)\(if .isDraft then " draft" else "" end) \(.title)"' 2>/dev/null
  for n in $(gh pr list --base "$TEAM_BASE" --state open --json number -q '.[].number' 2>/dev/null); do
    s=$(gh pr view "$n" --json statusCheckRollup -q '[.statusCheckRollup[] | (.conclusion // .state // "")] | if length==0 then "none" elif any(.=="FAILURE" or .=="ERROR" or .=="CANCELLED") then "FAIL" elif any(.=="" or .=="PENDING" or .=="IN_PROGRESS" or .=="QUEUED") then "pending" else "pass" end' 2>/dev/null)
    echo "CI PR #$n $s"
  done
  gh run list --branch "$TEAM_BASE" --limit 1 --json headSha,status,conclusion \
    -q '.[] | "CI base \(.headSha[0:7]) \(.status) \(.conclusion)"' 2>/dev/null
}
prev=$(state | sort)
echo "watching: $(echo "$prev" | grep -c '^ROW') rows, $(echo "$prev" | grep -c '^PR ') PRs"
while true; do
  sleep 60
  cur=$(state | sort)
  [ -z "$cur" ] && continue
  comm -13 <(echo "$prev") <(echo "$cur") | sed 's/^/NEW  /'
  comm -23 <(echo "$prev") <(echo "$cur") | grep -E '^BRANCH' | sed 's/^/GONE /'
  prev=$cur
done
