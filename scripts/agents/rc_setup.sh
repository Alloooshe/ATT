#!/usr/bin/env bash
# One-time setup so the PM and tech lead can run as background Remote Control
# sessions (scripts/agents/supervise.sh, the default for lead / pm / goal).
#
# A background session cannot show a prompt, and Claude Code asks two things
# once, in a terminal, that only the owner should answer:
#   1. "Do you trust the files in this folder?"   (per folder)
#   2. the bypass-permissions warning               (once per config)
# This opens claude in each folder in turn. Accept both, then type /exit.
#
#   rc_setup.sh                 $TEAM_WT_ROOT itself, then the leads and the PM
#   rc_setup.sh goal-1 pm-2     other agent names
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"

dirs=()
if (( $# == 0 )); then
  dirs+=("$TEAM_WT_ROOT")   # trusting the parent may cover future agents' worktrees
  # shellcheck disable=SC2086
  set -- $TEAM_LEADS "$TEAM_PM"
fi
for n in "$@"; do dirs+=("$TEAM_WT_ROOT/$n"); done

mkdir -p "$TEAM_WT_ROOT"
for d in "${dirs[@]}"; do
  if [[ "$d" != "$TEAM_WT_ROOT" && ! -e "$d/.git" ]]; then
    git -C "$TEAM_MAIN_CHECKOUT" fetch -q origin
    git -C "$TEAM_MAIN_CHECKOUT" worktree add -q --detach "$d" "origin/$TEAM_BASE"
  fi
  echo
  echo "== $d"
  echo "   Accept 'trust this folder' and the bypass-permissions warning, then type /exit."
  (cd "$d" && claude --dangerously-skip-permissions --model haiku)
done
echo
echo "Done. Start the team: scripts/agents/start_team.sh"
