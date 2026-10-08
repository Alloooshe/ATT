#!/usr/bin/env bash
# The only way a coding agent runs a test on the shared machine. Memory belongs
# to the PM's live runs; CI is the real test run. This catches a typo, an
# import error or a wrong assertion in a pure-logic test in seconds instead of
# a full CI round.
#
#   scripts/agents/quick_test.sh tests/test_<yours>.py [-k name]
#
# Hard limits (from .agent-team.env): TEAM_QUICK_TEST_MEM (default 512M), no
# swap, TEAM_QUICK_TEST_TIMEOUT seconds (default 120), one file, stop at the
# first failure. A test that needs a browser, a renderer or a server will be
# killed by the limit or skip — that is expected: leave it to CI.
#
# The command is TEAM_QUICK_TEST_CMD (default: python -m pytest -q -x ...),
# run from the repo root with .venv/bin first on PATH when it exists.
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"
[[ $# -ge 1 && -f "$1" ]] || { sed -n '2,15p' "$0"; exit 2; }
cd "$(git rev-parse --show-toplevel)" || exit 2
path="$PATH"; [[ -d .venv/bin ]] && path="$PWD/.venv/bin:$PATH"
# shellcheck disable=SC2086
systemd-run --user --scope --quiet --collect -p MemoryMax="$TEAM_QUICK_TEST_MEM" -p MemorySwapMax=0 -p CPUQuota=200% \
  env PATH="$path" PYTHONPATH="$PWD" timeout "$TEAM_QUICK_TEST_TIMEOUT" $TEAM_QUICK_TEST_CMD "$@"
rc=$?
case $rc in
  0) echo "quick_test: passed" ;;
  124) echo "quick_test: over ${TEAM_QUICK_TEST_TIMEOUT}s — too heavy to run here; leave it to CI" ;;
  137|143) echo "quick_test: killed at $TEAM_QUICK_TEST_MEM — too heavy to run here; leave it to CI" ;;
  *) echo "quick_test: failed (rc=$rc)" ;;
esac
exit $rc
