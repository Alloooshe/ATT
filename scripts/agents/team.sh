#!/usr/bin/env bash
# See and control the supervised agents (scripts/agents/supervise.sh).
#
#   team.sh status              every agent: running?, phase, last session result
#   team.sh stop <name>|all     finish the current session, then stop
#   team.sh kill <name>|all     stop now (the session is cut; its claims stay)
#   team.sh attach <name>       open a Remote Control agent's session in this terminal
#   team.sh log <name>          follow the supervisor log
#   team.sh notices             what needs the owner (BLOCKED, repeated errors)
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"
ROOT="$TEAM_STATE_ROOT"

names() { [[ "${1:-}" == all ]] && ls "$ROOT" 2>/dev/null || echo "$1"; }

case "${1:-status}" in
  status)
    printf '%-14s %-8s %-48s %s\n' AGENT UNIT PHASE "LAST SESSION"
    for d in "$ROOT"/*/; do
      [[ -d "$d" ]] || continue
      n=$(basename "$d")
      u=$(systemctl --user is-active "$TEAM_AGENT_UNIT_PREFIX$n" 2>/dev/null || true)
      printf '%-14s %-8s %-48.48s %s\n' "$n" "${u:-?}" "$(cat "$d/phase" 2>/dev/null)" \
        "$(tail -1 "$d/history" 2>/dev/null | cut -c1-90)"
    done ;;
  stop)
    for n in $(names "${2:?name or all}"); do touch "$ROOT/$n/STOP"; echo "$n: stops after its current session"; done ;;
  kill)
    for n in $(names "${2:?name or all}"); do
      systemctl --user stop "$TEAM_AGENT_UNIT_PREFIX$n" 2>/dev/null
      # A Remote Control agent's session lives in Claude's background service,
      # not in the unit, so it is stopped by id.
      [[ -s "$ROOT/$n/bgid" ]] && claude stop "$(cat "$ROOT/$n/bgid")" >/dev/null 2>&1
      # A live-run server can outlive its session and starve the machine.
      systemctl --user stop "$TEAM_SERVER_UNIT_PREFIX$n.scope" 2>/dev/null
      echo "$n: stopped"
    done ;;
  attach)
    exec claude attach "$(cat "$ROOT/${2:?name}/bgid")" ;;
  log)
    tail -f "$ROOT/${2:?name}/supervisor.log" ;;
  notices)
    for f in "$ROOT"/*/notices; do [[ -f "$f" ]] && { echo "== $(basename "$(dirname "$f")")"; tail -5 "$f"; }; done ;;
  *)
    sed -n '2,10p' "$0" ;;
esac
