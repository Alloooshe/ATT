#!/usr/bin/env bash
# One screen of everything the agent manager reports: machine, runners, agents,
# their last status lines, open PRs with owners, recent merges, ready rows by
# level, the live server, and the PM's current unit. Read-only.
#
#   scripts/agents/status.sh            # recent merges = last 2 h
#   scripts/agents/status.sh 6          # last 6 h
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"
cd "$TEAM_REPO_ROOT" || exit 1
H="${1:-2}"; ROOT="$TEAM_STATE_ROOT"
since=$(date -u -d "-$H hours" +%Y-%m-%dT%H:%M)

echo "== $(date '+%a %H:%M')  $(free -m | awk '/Mem:/ {print $7" MB free"}')  load $(cut -d' ' -f1 /proc/loadavg)"
if [[ -n "$TEAM_LOCAL_RUNNER" ]]; then
  echo "runner(local) $TEAM_LOCAL_RUNNER: $(ls "$ROOT"/.runner-yielded-to-* 2>/dev/null | xargs -rn1 basename || echo "on the queue")"
fi
gh api 'repos/{owner}/{repo}/actions/runners' -q '.runners[] | "  \(.name) \(.status) busy=\(.busy) [\([.labels[].name] | join(","))]"' 2>/dev/null
echo; scripts/agents/team.sh status
echo; for d in "$ROOT"/*/; do n=$(basename "$d"); [[ -s "$d/status" ]] && echo "  $n | $(head -1 "$d/status" | cut -c1-170)"; done
for f in "$ROOT"/*/notices; do [[ -f "$f" && -n "$(find "$f" -mmin -240)" ]] && echo "  NOTICE $(basename "$(dirname "$f")"): $(tail -1 "$f" | cut -c1-140)"; done
echo; echo "== Remote Control sessions"
timeout 20 claude agents --json 2>/dev/null | jq -r '.[] | select(.kind=="background") | "  \(.id) \(.status // "-") \(.cwd|split("/")|last): \(.name[0:60])"'
systemctl --user list-units --no-legend "$TEAM_SERVER_UNIT_PREFIX*.scope" 2>/dev/null | awk '{print "  server " $1 " " $3}'
echo; echo "== PRs"; git fetch -q origin
scripts/agents/pr_lock.sh list | sed 's/^/  /'
gh pr list --base "$TEAM_BASE" --state merged --limit 60 --json number,createdAt,mergedAt \
  -q "[.[] | select(.mergedAt > \"$since\")] | \"  merged in last ${H}h (\(length)): \(map(.number)) avg open->merge \(if length>0 then (map((.mergedAt|fromdate)-(.createdAt|fromdate)) | add/length/60 | floor) else 0 end) min\""
gh run list --limit 30 --json status,headBranch -q '[.[] | select(.status!="completed")] | "  CI not done: \(length) \(map(.headBranch) | unique)"'
echo; echo "== backlog"
git show "origin/$TEAM_BASE:docs/BACKLOG.md" | grep -E '^\| \*\*[0-9]+' | awk -F'|' '$5 ~ /`ready`/ {gsub(/[* ]/,"",$2); gsub(/ /,"",$4); a[$4]=a[$4]" #"$2} END {for (k in a) print "  ready "k":"a[k]}'
echo "  merged awaiting a live check: $(git show "origin/$TEAM_BASE:docs/BACKLOG.md" | sed -n '/## Merged/,/## Closed/p' | grep -cE '^\| [0-9]+')"
echo; echo "== PM unit"; sed -n 1,4p "$ROOT/$TEAM_PM/handoff.md" 2>/dev/null | cut -c1-200
