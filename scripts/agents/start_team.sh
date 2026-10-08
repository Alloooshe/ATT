#!/usr/bin/env bash
# Start the whole team in one go: the tech leads, the PM and the coding agents
# named in .agent-team.env (TEAM_LEADS, TEAM_PM, TEAM_CODERS).
# Each is a separate supervised agent (scripts/agents/supervise.sh), started a
# minute or two apart so they do not all fetch, claim and load the machine at
# once. Agents already running are left alone, so this is safe to re-run.
#
#   start_team.sh            start everyone (PM without live runs)
#   start_team.sh --live     the PM may also run live runs (the owner's "go")
#   start_team.sh --dry-run  print the commands, start nothing
#
# Stop: scripts/agents/team.sh stop all     See: scripts/agents/team.sh status
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source ./config.sh

live="" dry=0
for a in "$@"; do
  case "$a" in
    --live) live="--live" ;;
    --dry-run) dry=1 ;;
    *) sed -n '2,12p' "$0"; exit 2 ;;
  esac
done

start() {  # name, then supervise.sh arguments
  local name="$1"; shift
  if systemctl --user is-active --quiet "$TEAM_AGENT_UNIT_PREFIX$name"; then
    echo "  $name: already running"; return
  fi
  rm -f "$TEAM_STATE_ROOT/$name/STOP"
  if (( dry )); then echo "  ./supervise.sh $*"; else echo -n "  "; ./supervise.sh "$@"; fi
}

echo "PM and tech leads use Remote Control; first time on this machine run scripts/agents/rc_setup.sh"
avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
echo "memory available: ${avail} MB (coders only code — CI runs their tests; the memory is the PM's)"

for l in $TEAM_LEADS; do start "$l" lead --name "$l"; done
# shellcheck disable=SC2086
[[ -n "$TEAM_PM" ]] && start "$TEAM_PM" pm --name "$TEAM_PM" $live --delay 60
delay=120
for c in $TEAM_CODERS; do
  start "${c%%:*}" coder --name "${c%%:*}" --level "${c##*:}" --delay "$delay"
  delay=$(( delay + 90 ))
done

(( dry )) || echo "started — scripts/agents/team.sh status"
