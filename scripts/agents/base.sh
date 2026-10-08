#!/usr/bin/env bash
# Sync with and push to the base branch ($TEAM_BASE) from a *detached* worktree.
#
# The named branch belongs to the owner's checkout ($TEAM_MAIN_CHECKOUT), so
# git refuses to check it out in a second worktree. Agents' worktrees sit
# detached on origin/$TEAM_BASE and push with HEAD:$TEAM_BASE.
# Both steps hold the base lock, because PMs, leads, automerge and coding
# agents' claims all push to the same branch.
#
#   base.sh sync    fetch, then rebase local commits onto origin/$TEAM_BASE
#   base.sh push    sync, then push HEAD to $TEAM_BASE (retries a lost race)
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"

sync() {
  git fetch -q origin "$TEAM_BASE"
  if [[ -n "$(git branch --show-current)" && "$(git branch --show-current)" != "$TEAM_BASE" ]]; then
    echo "on branch $(git branch --show-current), not $TEAM_BASE — refusing" >&2; exit 1
  fi
  git rebase -q "origin/$TEAM_BASE"
}

exec 9>"$TEAM_BASE_LOCK"; flock 9
case "${1:-}" in
  sync) sync; git log --oneline -1 ;;
  push)
    for attempt in 1 2 3 4 5; do
      sync
      if git push -q origin "HEAD:$TEAM_BASE"; then git log --oneline -1; exit 0; fi
      echo "push lost a race (attempt $attempt); retrying" >&2; sleep $(( attempt * 3 ))
    done
    echo "push to $TEAM_BASE failed 5 times" >&2; exit 1 ;;
  *) sed -n '2,11p' "$0"; exit 2 ;;
esac
