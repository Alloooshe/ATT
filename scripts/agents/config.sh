# Sourced by every team script. Loads `.agent-team.env` from the repository
# root (see agent-team.env.example) and fills in defaults, so no script names a
# path, a branch or a project.
#
# Scripts run from a worktree, from the main checkout, or under systemd with
# HOME as the working directory, so the repo root is found from this file.
_team_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEAM_REPO_ROOT="$(git -C "$_team_here" rev-parse --show-toplevel 2>/dev/null || echo "$_team_here/../..")"
if [[ -f "${TEAM_ENV_FILE:-$TEAM_REPO_ROOT/.agent-team.env}" ]]; then
  # shellcheck disable=SC1090
  source "${TEAM_ENV_FILE:-$TEAM_REPO_ROOT/.agent-team.env}"
fi

: "${TEAM_PROJECT:=Project}"
: "${TEAM_SLUG:=team}"
: "${TEAM_BASE:=dev}"
: "${TEAM_MAIN_CHECKOUT:=$TEAM_REPO_ROOT}"
: "${TEAM_WT_ROOT:=$HOME/$TEAM_SLUG-wt}"
: "${TEAM_STATE_ROOT:=$HOME/.$TEAM_SLUG-agents}"
: "${TEAM_LINKS:=.env .venv node_modules}"
: "${TEAM_GIT_NAME:=$(git config user.name 2>/dev/null || echo agent)}"
: "${TEAM_GIT_EMAIL:=$(git config user.email 2>/dev/null || echo agent@example.com)}"
: "${TEAM_PYTHON:=python3}"
: "${TEAM_QUICK_TEST_CMD:=python -m pytest -q -x -p no:cacheprovider}"
: "${TEAM_QUICK_TEST_MEM:=512M}"
: "${TEAM_QUICK_TEST_TIMEOUT:=120}"
: "${TEAM_SERVER_MEM:=10G}"
: "${TEAM_LOCK_DIR:=/tmp}"
: "${TEAM_LOCAL_RUNNER:=}"
: "${TEAM_RUNNER_LABEL:=}"
: "${TEAM_CI_IGNORE_CHECKS:=changes}"
: "${TEAM_LEADS:=tech-lead tech-lead-2}"
: "${TEAM_PM:=pm}"
: "${TEAM_CODERS:=c1:L2 c2:L2 c3:L3}"

# Locks shared by every session on the machine.
TEAM_BASE_LOCK="${TEAM_BASE_LOCK:-$TEAM_LOCK_DIR/$TEAM_SLUG-base-git.lock}"   # any commit/push to the base branch
TEAM_HEAVY_LOCK="${TEAM_HEAVY_LOCK:-$TEAM_LOCK_DIR/$TEAM_SLUG-heavy.lock}"    # live exports, renders, heavy tests
TEAM_SERVER_LOCK="${TEAM_SERVER_LOCK:-$TEAM_LOCK_DIR/$TEAM_SLUG-server.lock}" # one app server at a time

# systemd unit names: <slug>-agent-<name>, <slug>-server-<name>.scope, automerge-pr<N>.
TEAM_AGENT_UNIT_PREFIX="$TEAM_SLUG-agent-"
TEAM_SERVER_UNIT_PREFIX="$TEAM_SLUG-server-"

if [[ -n "${TEAM_CLAUDE_CONFIG_DIR:-}" ]]; then export CLAUDE_CONFIG_DIR="$TEAM_CLAUDE_CONFIG_DIR"; fi
unset _team_here
