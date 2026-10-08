#!/usr/bin/env bash
# Run one agent forever as a chain of short, fresh Claude Code sessions.
#
# Why a supervisor and not one long session:
#   * Context. A coding agent that fixes row after row in one conversation gets
#     worse as it grows. Each session here does one unit of work (a coder: two
#     rows; a lead: a batch of PRs) and ends; state lives in the backlog, the PRs
#     and a handoff file, never in a conversation.
#   * Usage limits. When the account's limit is hit the session ends; this
#     waits for the reset and resumes the *same* session, so a half-done unit
#     finishes with its context.
#   * Nothing here needs a human. A session that says BLOCKED stops the agent
#     and notifies; everything else loops.
#   * Remote Control for the PM and the tech leads: their sessions are
#     interactive background sessions (`claude --bg --remote-control`), so the
#     owner can open one from claude.ai/code or the phone and talk to it
#     mid-unit. `claude -p` ignores --remote-control, which is why coders (no
#     Remote Control) stay on -p. A Remote Control session is stopped only
#     after it wrote its status and sat idle RC_GRACE minutes, so a conversation
#     with the owner is not cut. One-time setup: scripts/agents/rc_setup.sh.
#
#   supervise.sh coder --name c1 --level L2 [--model sonnet]
#   supervise.sh lead  --name tech-lead
#   supervise.sh pm    --name pm [--live]
#   supervise.sh goal  --name goal-1 --goal "…" [--once]
#   common: --model M --effort E --once --foreground --delay SECONDS
#           --rc / --no-rc  Remote Control on/off (default: on for lead, pm, goal)
#           --prompt "…"  replaces the role prompt (smoke tests)
#
# Runs itself under `systemd-run --user` unless --foreground, so it survives the
# terminal. Control it with scripts/agents/team.sh. Requires Linux with a
# systemd user session, git, gh, jq, flock and the claude CLI.
set -uo pipefail

SELF="$(readlink -f "$0")"
source "$(dirname "$SELF")/config.sh"
REPO="$TEAM_MAIN_CHECKOUT"
BASE="$TEAM_BASE"
ROOT="$TEAM_STATE_ROOT"
WT_ROOT="$TEAM_WT_ROOT"

role="${1:-}"; shift || true
name="" level="" model="" effort="" goal="" prompt="" live=0 once=0 fg=0 delay=0 rcmode=""
while (( $# )); do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --level) level="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --effort) effort="$2"; shift 2 ;;
    --goal) goal="$2"; shift 2 ;;
    --prompt) prompt="$2"; shift 2 ;;
    --delay) delay="$2"; shift 2 ;;
    --rc) rcmode=1; shift ;;
    --no-rc) rcmode=0; shift ;;
    --live) live=1; shift ;;
    --once) once=1; shift ;;
    --foreground) fg=1; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
[[ "$role" =~ ^(coder|lead|pm|goal)$ && -n "$name" ]] || { grep -E '^#   (supervise|common:|        --)' "$SELF"; exit 2; }
# A goal agent's goal is kept in its state dir, so a restart needs only --name.
if [[ "$role" == goal ]]; then
  gfile="$ROOT/$name/goal"
  if [[ -n "$goal" ]]; then mkdir -p "$(dirname "$gfile")"; printf '%s\n' "$goal" > "$gfile"
  elif [[ -s "$gfile" ]]; then goal=$(cat "$gfile")
  else echo "goal needs --goal" >&2; exit 2; fi
fi
[[ "$name" =~ ^[a-z0-9-]+$ ]] || { echo "--name: lowercase letters, digits, dashes" >&2; exit 2; }

# Per-role defaults: model, effort, free memory needed to start a session
# (MIN_MB), session timeout, and the waits after a DONE and after an IDLE.
#
# Memory belongs to the PM's live runs. Coders only code — no test suites,
# renders or servers; CI is their test run — and a Claude session is
# 0.3–0.6 GB, so they need no cap and no slots. A tech lead may run a PR's test
# file. The PM's app server and exports are the only heavy work, and they run
# in their own scope.
case "$role" in
  coder) : "${model:=$([[ "$level" == L1 ]] && echo sonnet || echo opus)}"; : "${effort:=high}"
         MIN_MB=800; TIMEOUT=3h; WAIT_DONE=60;  WAIT_IDLE=1800 ;;
  lead)  : "${model:=opus}"; : "${effort:=high}"
         MIN_MB=1500; TIMEOUT=2h; WAIT_DONE=30; WAIT_IDLE=300 ;;
  pm)    : "${model:=opus}"; : "${effort:=high}"
         MIN_MB=$(( live ? 5000 : 1000 )); TIMEOUT=5h; WAIT_DONE=300; WAIT_IDLE=1800 ;;
  goal)  : "${model:=opus}"; : "${effort:=max}"
         MIN_MB=800; TIMEOUT=4h; WAIT_DONE=300; WAIT_IDLE=3600 ;;
esac

[[ -z "$rcmode" ]] && { [[ "$role" == coder ]] && rcmode=0 || rcmode=1; }
RC_NAME="$TEAM_PROJECT $name"
# Idle minutes after the status line before stopping, kept in case the owner is
# talking to the session. Short for leads: with 20 min, idle leads sat on green
# PRs that were waiting for review.
RC_GRACE="${TEAM_RC_GRACE_MIN:-$([[ "$role" == lead ]] && echo 5 || echo 20)}"
RC_STALL="${TEAM_RC_STALL_MIN:-60}"   # idle minutes without a status line before a nudge
# How often a Remote Control session is checked. `claude agents --json` is a
# full CLI start; several supervisors polling every minute cost about a core.
RC_POLL="${TEAM_RC_POLL_S:-180}"

STATE="$ROOT/$name"; WT="$WT_ROOT/$name"; LOGS="$STATE/logs"
mkdir -p "$LOGS" "$WT_ROOT/tmp"

if (( ! fg )); then
  unit="$TEAM_AGENT_UNIT_PREFIX$name"
  if systemctl --user is-active --quiet "$unit"; then
    echo "$unit is already running (scripts/agents/team.sh status)"; exit 1
  fi
  args=("$role" --name "$name" --foreground)
  [[ -n "$level" ]] && args+=(--level "$level")
  [[ -n "$goal" ]] && args+=(--goal "$goal")
  [[ -n "$prompt" ]] && args+=(--prompt "$prompt")
  args+=(--model "$model" --effort "$effort")
  (( live )) && args+=(--live)
  (( once )) && args+=(--once)
  (( delay )) && args+=(--delay "$delay")
  (( rcmode )) && args+=(--rc) || args+=(--no-rc)
  envs=(-E HOME="$HOME" -E PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin")
  [[ -n "${CLAUDE_CONFIG_DIR:-}" ]] && envs+=(-E CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR")
  [[ -n "${TEAM_ENV_FILE:-}" ]] && envs+=(-E TEAM_ENV_FILE="$TEAM_ENV_FILE")
  systemd-run --user --quiet --collect --unit "$unit" \
    -p WorkingDirectory="$HOME" "${envs[@]}" \
    "$SELF" "${args[@]}"
  echo "started $unit — logs: $LOGS  (scripts/agents/team.sh status)"
  exit 0
fi

export AGENT_STATE="$STATE" AGENT_NAME="$name" TMPDIR="$WT_ROOT/tmp"

exec 8>"$STATE/.lock"
flock -n 8 || { echo "another supervisor runs $name"; exit 1; }

log() { echo "$(date '+%F %T') $*" | tee -a "$STATE/supervisor.log"; }
phase() { echo "$*" > "$STATE/phase"; }
notify() {
  log "NOTICE $*"; echo "$(date '+%F %T') $*" >> "$STATE/notices"
  notify-send "$TEAM_PROJECT agent $name" "$*" 2>/dev/null || true
}
stopping() { [[ -e "$STATE/STOP" || -e "$ROOT/STOP" ]]; }
nap() {  # sleep $1 seconds, waking early for a STOP
  local until=$(( $(date +%s) + $1 ))
  while (( $(date +%s) < until )); do stopping && return; sleep 20; done
}

ensure_worktree() {
  if [[ ! -e "$WT/.git" ]]; then
    git -C "$REPO" fetch -q origin
    git -C "$REPO" worktree add -q --detach "$WT" "origin/$BASE" || return 1
    log "worktree $WT created"
  fi
  # Every run, not only on creation: rc_setup.sh or a human may have made it.
  local p
  for p in $TEAM_LINKS; do
    [[ -e "$REPO/$p" && ! -e "$WT/$p" ]] && ln -sfn "$REPO/$p" "$WT/$p"
  done
  # Sign the worktree, so `git log --format=%ae` says which session did what.
  git -C "$WT" config extensions.worktreeConfig true
  git -C "$WT" config --worktree user.name "$TEAM_GIT_NAME ($name)"
  git -C "$WT" config --worktree user.email "${TEAM_GIT_EMAIL%@*}+$name@${TEAM_GIT_EMAIL#*@}"
  # Skills load from the checkout at session start, so a stale worktree runs a
  # stale procedure. Move a clean worktree to the base tip; leave a dirty one to
  # its agent.
  git -C "$WT" fetch -q origin
  # Detached, never the named branch: the owner's checkout holds that. Commits
  # on a detached HEAD that never reached the base are kept for the agent to push.
  local br; br=$(git -C "$WT" branch --show-current)
  # Never under a running server: the app imports lazily, so moving the
  # worktree under it mixes two commits in one live run.
  if worktree_has_live_server "$WT" "$name"; then
    log "server is running from $WT; worktree left as is"
  elif [[ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ]] &&
     { [[ -n "$br" && "$br" != "$BASE" ]] ||
       [[ "$(git -C "$WT" rev-list --count "origin/$BASE..HEAD")" == 0 ]]; }; then
    git -C "$WT" switch -q --detach "origin/$BASE" || true
  fi
}

# True when an app server started from ``$1`` is still up.
# ``$2`` is the agent name (systemd scope ``<slug>-server-<name>.scope``).
# Works on Linux and Darwin (no /proc).
worktree_has_live_server() {
  local wt="$1" agent="${2:-}" lock="$TEAM_SERVER_LOCK"
  # Darwin /tmp paths often appear as /var vs /private/var.
  wt=$(cd "$wt" 2>/dev/null && pwd -P || echo "$wt")
  [[ -n "$agent" ]] && systemctl --user is-active --quiet "$TEAM_SERVER_UNIT_PREFIX$agent.scope" 2>/dev/null && return 0
  [[ -e "$lock" ]] || return 1
  # flock held? A non-blocking exclusive open fails while a server holds it.
  if flock -n "$lock" true 2>/dev/null; then
    return 1
  fi
  # Held — only skip when the holder was started from this worktree.
  local pids="" pid cwd cmd
  if [[ -d /proc/self ]] && command -v fuser >/dev/null 2>&1; then
    pids=$(fuser "$lock" 2>/dev/null | tr -cs '0-9' '\n' | grep -E '^[0-9]+$' || true)
  fi
  if command -v lsof >/dev/null 2>&1; then
    pids=$(printf '%s\n%s\n' "$pids" "$(lsof -t "$lock" 2>/dev/null || true)" \
      | grep -E '^[0-9]+$' | sort -u || true)
  fi
  [[ -z "$pids" ]] && return 0   # held but no holder list — be conservative
  for pid in $pids; do
    cwd=""; cmd=""
    if [[ -d "/proc/$pid" ]]; then
      cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)
      cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
    else
      cwd=$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | sed -n 's/^n//p' | head -1 || true)
      [[ -n "$cwd" ]] && cwd=$(cd "$cwd" 2>/dev/null && pwd -P || echo "$cwd")
      cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
    fi
    [[ -n "$cwd" && ( "$cwd" == "$wt" || "$cwd" == "$wt"/* ) ]] && return 0
    [[ -n "$cmd" && "$cmd" == *"$wt"* ]] && return 0
  done
  return 1
}

resources_ok() {
  local avail load cores
  avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  load=$(cut -d' ' -f1 /proc/loadavg)
  cores=$(nproc 2>/dev/null || echo 4)
  if (( avail < MIN_MB )) || awk "BEGIN{exit !($load > $cores)}"; then
    log "waiting: ${avail} MB available (need $MIN_MB), load $load"; return 1
  fi
}

prompt_for() {
  [[ -n "$prompt" ]] && { echo "$prompt"; return; }
  # Paths are spelled out: Remote Control sessions run inside Claude's background
  # service and inherit the environment of whichever supervisor started it, so
  # their AGENT_* variables can name another agent.
  local tail="This is one supervised session (agent \"$name\", worktree $WT, state dir $STATE — use these; AGENT_NAME / AGENT_STATE in your environment may belong to another agent). Follow docs/agent-team.md → Sessions: read the handoff, do one unit of work, keep the handoff current, write the status line, then stop. Nobody is watching: never ask for approval."
  (( rcmode )) && tail+=" The owner may open this session over Remote Control and talk to you: answer and follow them, but never wait for them."
  case "$role" in
    # The no-local-runs rule is in the prompt as well as the skill: Claude loads
    # the skill from the checked-out branch, and an agent branch cut before a
    # rule changed carries the old copy.
    coder) echo "You are coding agent $name on $TEAM_PROJECT (your-name for pr_lock.sh is $name). Use the team-coding-agent skill — read it from origin/$BASE (git show origin/$BASE:.claude/skills/team-coding-agent/SKILL.md), because an agent branch may carry an older copy.${level:+ Level: $level — claim only rows at exactly this level.} Run nothing heavy on this machine: no app server, renders, builds or test suite — CI is your test run. The only local test allowed is your own new test file via scripts/agents/quick_test.sh; run it before each push to avoid a CI round, and push fewer, finished commits. $tail" ;;
    lead)  echo "You are tech lead $name on $TEAM_PROJECT. Use the team-tech-lead skill. Other leads may be running: take scripts/agents/pr_lock.sh before reading any PR. $tail" ;;
    pm)    if (( live )); then
             echo "You are the $TEAM_PROJECT PM ($name). Use the team-pm skill, run mode. The owner has given go for live runs: you may run one this session if the Inbox and Merged rows call for it. $tail"
           else
             echo "You are the $TEAM_PROJECT PM ($name). Use the team-pm skill, run mode. No go for a live run: answer the Inbox, verify what can be verified without a run, keep the backlog provable. $tail"
           fi ;;
    goal)  local l=""
           (( live )) && l=" The owner has given go for live runs: run the product on the inputs the goal names to see what it does today and to prove the rows (one app server on the machine at a time — docs/agent-team.md)."
           echo "You are the $TEAM_PROJECT PM ($name) in goal mode. Use the team-pm skill and follow references/goal-mode.md. Think hard, research the internet properly, compare at least three products and two methods, then write the brief and file the rows; in later sessions keep guiding the goal (goal-mode.md step 8).$l The goal: $goal $tail" ;;
  esac
}

# Seconds until the usage limit resets, or empty if the session did not end on
# one. Reads the stream's rate_limit_event first (an epoch), then the result
# text ("… limit reached … resets 3pm"), then gives a blind 30 min.
limit_wait() {
  local f="$1" rc="$2" reset now txt
  now=$(date +%s)
  reset=$(jq -r 'select(.type=="rate_limit_event") | .rate_limit_info
                 | select(.status=="rejected") | .resetsAt // empty' "$f" 2>/dev/null | tail -1)
  if [[ -n "$reset" ]]; then
    (( reset > 100000000000 )) && reset=$(( reset / 1000 ))
    echo $(( reset - now > 0 ? reset - now + 120 : 120 )); return
  fi
  # A clean result line means the session finished on its own terms, whatever
  # the transcript says about limits.
  jq -e 'select(.type=="result" and .subtype=="success" and .is_error!=true)' "$f" >/dev/null 2>&1 && return
  txt=$(jq -r 'select(.type=="result") | .result // .subtype // empty' "$f" 2>/dev/null | tail -1)
  # No result line at all: the CLI died before one, so only its last words count.
  [[ -z "$txt" && "$rc" != 0 ]] && txt=$(grep -v '^{' "$f" | tail -c 2000)
  if grep -qiE "usage limit|limit reached|hit your .*limit|rate.?limit|out of (extra )?usage" <<<"$txt"; then
    local when epoch=""
    when=$(grep -oiE "resets? (at )?[^.·)]*" <<<"$txt" | head -1 | sed -E 's/^resets? (at )?//I; s/\(.*//')
    if [[ "$txt" =~ \|([0-9]{10}) ]]; then epoch="${BASH_REMATCH[1]}"
    elif [[ -n "$when" ]]; then epoch=$(date -d "$when" +%s 2>/dev/null || true)
      [[ -n "$epoch" ]] && (( epoch < now )) && epoch=$(( epoch + 86400 ))
    fi
    [[ -n "$epoch" ]] && { echo $(( epoch - now + 120 )); return; }
    echo 1800
  fi
}

run_claude() {  # $1 = log file, rest = claude args; returns claude's exit code
  local out="$1"; shift
  (cd "$WT" && timeout "$TIMEOUT" claude -p "$@" \
      --model "$model" --effort "$effort" \
      --permission-mode bypassPermissions \
      --output-format stream-json --verbose \
      --add-dir "$STATE" < /dev/null) > "$out" 2>&1
}

# ---------------------------------------------------- Remote Control sessions
# Three things a first version gets wrong, each of which leaves the PM and the
# tech lead with an idle duplicate or kills them outright:
#   * `--bg` assigns its own session id and ignores --session-id, so we track
#     the id it prints; passing --session-id also left a second session idle
#     without its prompt.
#   * The first `claude --bg` starts Claude's background service as a child of
#     the caller. Started from this unit, `systemctl stop` of the unit killed
#     the service and every background session with it. So it is launched in
#     its own transient scope.
#   * A supervisor that restarts must adopt the session already running in its
#     worktree, not start a second one.
rc_start() {  # claude args (prompt last) → background session; sets bgid
  local o
  o=$(cd "$WT" && systemd-run --user --scope --quiet --collect \
        timeout 90 claude --bg --add-dir "$STATE" --remote-control "$RC_NAME" \
        --model "$model" --effort "$effort" --permission-mode bypassPermissions \
        "$@" < /dev/null 2>&1)
  # --add-dir takes several directories: placed last it swallows the prompt
  # as one more, and the session sits idle "waiting for a prompt".
  echo "$(date '+%F %T') start: $o" >> "$out"
  if grep -qiE "not trusted|disclaimer|requires accepting" <<<"$o"; then
    notify "needs one-time setup: run scripts/agents/rc_setup.sh $name — $(head -1 <<<"$o")"
    phase "needs scripts/agents/rc_setup.sh"; exit 1
  fi
  bgid=$(grep -oE 'backgrounded · [0-9a-f]+' <<<"$o" | awk '{print $3}' | tail -1)
  [[ -n "$bgid" ]] || { log "background start failed: $o"; return 1; }
  echo "$bgid" > "$STATE/bgid"
}
bg_field() {  # $1 = bg id, $2 = field (status: busy|idle|null; state; sessionId)
  claude agents --json --all 2>/dev/null \
    | jq -r --arg i "$1" --arg f "$2" '.[] | select(.id==$i) | .[$f] // empty' | head -1
}
bg_resume() {  # $1 = message; resumes the tracked session (same conversation)
  local full; full=$(bg_field "$bgid" sessionId)
  [[ -n "$full" ]] || return 1
  rc_start "$1" --resume "$full"
}
# Adopt a session that is alive (it has a status: busy or idle — "state: done"
# only means its last turn ended), or one whose host died mid-work ("blocked").
# Resuming a dead finished session blocks the agent on every start, and
# skipping live "done" ones opens a duplicate beside the owner's chat.
rc_adopt() {  # the newest live background session in our worktree → bgid
  local line
  line=$(claude agents --json --all 2>/dev/null | jq -r --arg cwd "$WT" \
    '[.[] | select(.kind=="background" and .cwd==$cwd and (.status != null or .state == "blocked"))]
     | sort_by(.startedAt) | last | select(. != null) | "\(.id) \(.state // "")"')
  [[ -z "$line" ]] && return 1
  bgid=${line%% *}; local state=${line#* }
  log "adopting background session $bgid (state $state)"
  if [[ -z "$(bg_field "$bgid" status)" ]]; then   # host gone (blocked): bring it back
    bg_resume "This session was interrupted by a restart. Continue exactly where you stopped: finish the current unit of work, update the handoff, write the status line, then stop." || return 1
  fi
}
# Optional (TEAM_LOCAL_RUNNER + TEAM_RUNNER_LABEL): a self-hosted CI runner on
# this machine and a live PM share its memory and the heavy lock, so CI jobs on
# it wait behind a live run while PRs sit unmerged. Stopping the runner
# "between jobs" never fires — it always has a next job. So while this agent's
# app server is up, the runner loses its label: it takes nothing new from the
# queue, the other runners take the jobs, and the label comes back when no live
# server needs the machine. A job it already holds is cancelled and re-run.
runner_label() {  # add | remove
  local rid
  rid=$(gh api 'repos/{owner}/{repo}/actions/runners' -q ".runners[] | select(.name==\"$TEAM_LOCAL_RUNNER\") | .id" 2>/dev/null)
  [[ -n "$rid" ]] || return 1
  if [[ "$1" == remove ]]; then
    gh api -X DELETE "repos/{owner}/{repo}/actions/runners/$rid/labels/$TEAM_RUNNER_LABEL" >/dev/null 2>&1
  else
    gh api -X POST "repos/{owner}/{repo}/actions/runners/$rid/labels" -f "labels[]=$TEAM_RUNNER_LABEL" >/dev/null 2>&1
  fi
}
runner_yield() {
  [[ -n "$TEAM_LOCAL_RUNNER" && -n "$TEAM_RUNNER_LABEL" ]] || return 0
  [[ "$role" == pm || "$role" == goal ]] || return 0
  local mark="$ROOT/.runner-yielded-to-$name" run
  if systemctl --user is-active --quiet "$TEAM_SERVER_UNIT_PREFIX$name.scope"; then
    if [[ ! -e "$mark" ]]; then
      (cd "$WT" && runner_label remove) && touch "$mark" && log "CI runner $TEAM_LOCAL_RUNNER off the queue for the live server"
      for run in $(cd "$WT" && gh run list --status in_progress --limit 20 --json databaseId -q '.[].databaseId' 2>/dev/null); do
        if (cd "$WT" && gh api "repos/{owner}/{repo}/actions/runs/$run/jobs" -q ".jobs[] | select(.status==\"in_progress\" and .runner_name==\"$TEAM_LOCAL_RUNNER\") | .id" 2>/dev/null) | grep -q .; then
          (cd "$WT" && gh run cancel "$run" >/dev/null 2>&1); sleep 20
          (cd "$WT" && gh run rerun "$run" >/dev/null 2>&1) && log "moved run $run off $TEAM_LOCAL_RUNNER"
        fi
      done
    fi
  elif [[ -e "$mark" ]]; then
    rm -f "$mark"
    if ! compgen -G "$ROOT/.runner-yielded-to-*" >/dev/null; then
      (cd "$WT" && runner_label add) && log "CI runner $TEAM_LOCAL_RUNNER back on the queue"
    fi
  fi
}

run_rc_session() {  # sets rc (0 = ended with a status line)
  local st idle=0 nudged=0 resumes=0 w
  rc=1
  rc_adopt || { rm -f "$STATE/status"; rc_start "$(prompt_for)"; } || return
  phase "session $bgid since $(date '+%H:%M') — Remote Control (claude attach $bgid)"
  while :; do
    nap "$RC_POLL"
    runner_yield
    st=$(bg_field "$bgid" status)
    # A STOP waits for the unit to finish (status written) or the session to
    # sit idle; team.sh kill is the way to cut it.
    if stopping && { [[ -s "$STATE/status" ]] || [[ "$st" == idle ]]; }; then
      claude stop "$bgid" >/dev/null 2>&1; break
    fi
    [[ -z "$st" ]] && break                       # ended, crashed, or stopped by hand
    if [[ "$st" != idle ]]; then idle=0; continue; fi
    idle=$(( idle + RC_POLL / 60 ))   # minutes
    if [[ -s "$STATE/status" ]]; then
      # Done; leave it open a while in case the owner is talking to it.
      (( idle >= RC_GRACE )) && { claude stop "$bgid" >/dev/null 2>&1; break; }
      continue
    fi
    (( idle < 2 )) && continue
    claude logs "$bgid" 2>&1 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' > "$out.tail"
    w=$(limit_wait "$out.tail" 1)
    if [[ -n "$w" ]] && (( resumes < 8 )); then
      resumes=$(( resumes + 1 ))
      claude stop "$bgid" >/dev/null 2>&1
      phase "usage limit — resuming $bgid at $(date -d "@$(( $(date +%s) + w ))" '+%a %H:%M')"
      log "usage limit; sleeping ${w}s then resuming $bgid"
      nap "$w"; stopping && break
      bg_resume "The usage limit has reset. Continue exactly where you stopped: finish the current unit of work, update the handoff, write the status line, then stop." || break
      idle=0
    elif (( idle >= RC_STALL )); then
      claude stop "$bgid" >/dev/null 2>&1
      (( nudged )) && break
      nudged=1; log "idle ${idle} min with no status; nudging $bgid"
      bg_resume "Nobody is answering questions in this session. If your unit of work is done, write the status line now; otherwise continue it and then write the status line." || break
      idle=0
    fi
  done
  runner_yield
  [[ -s "$STATE/status" ]] && rc=0
  # Ended sessions otherwise pile up in claude.ai's Remote Control list (one per
  # cycle); the transcript stays in the project's history.
  [[ -z "$(bg_field "$bgid" status)" ]] && claude rm "$bgid" >/dev/null 2>&1
}

errors=0
log "start role=$role model=$model effort=$effort${level:+ level=$level} rc=$rcmode"
# Staggered starts (start_team.sh), so agents do not all claim, fetch and
# load the machine in the same minute.
if (( delay )); then phase "starting at $(date -d "+$delay sec" '+%H:%M')"; nap "$delay"; fi
while :; do
  stopping && { log "STOP file — exiting"; phase "stopped"; rm -f "$STATE/STOP"; exit 0; }
  phase "preparing"
  ensure_worktree || { notify "cannot create worktree $WT"; exit 1; }
  # The memory gate guards a new session; a live one in our worktree is adopted
  # regardless (otherwise it is left unwatched behind the gate).
  if ! { (( rcmode )) && claude agents --json 2>/dev/null | jq -e --arg cwd "$WT" \
           'any(.[]; .kind=="background" and .cwd==$cwd and .status != null)' >/dev/null; }; then
    resources_ok || { phase "waiting for memory/load"; nap 300; continue; }
  fi

  sid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid); ts=$(date +%Y%m%d-%H%M%S); out="$LOGS/$ts-$sid.jsonl"
  (( rcmode )) || rm -f "$STATE/status"
  log "session $sid"
  if (( rcmode )); then
    out="$LOGS/$ts.bg.log"
    run_rc_session
  else
    phase "session $sid since $(date '+%H:%M')"
    run_claude "$out" "$(prompt_for)" --session-id "$sid" --name "$name"; rc=$?
  fi

  resumes=0
  while (( ! rcmode )) && w=$(limit_wait "$out" "$rc") && [[ -n "$w" ]] && (( resumes < 8 )); do
    resumes=$(( resumes + 1 ))
    phase "usage limit — resuming $sid at $(date -d "@$(( $(date +%s) + w ))" '+%a %H:%M')"
    log "usage limit; sleeping ${w}s then resuming $sid"
    nap "$w"; stopping && break
    out="$LOGS/$ts-$sid.resume$resumes.jsonl"
    run_claude "$out" "The usage limit has reset. Continue exactly where you stopped: finish the current unit of work, update the handoff, write the status line, then stop." --resume "$sid"; rc=$?
  done

  status=$(head -1 "$STATE/status" 2>/dev/null || true)
  echo "$(date '+%F %T') $sid rc=$rc ${status:-<no status>}" >> "$STATE/history"
  log "session $sid ended rc=$rc: ${status:-<no status>}"
  case "$status" in
    DONE*)    errors=0; (( once )) && break; phase "done; next at $(date -d "+$WAIT_DONE sec" '+%H:%M')"; nap "$WAIT_DONE" ;;
    IDLE*)    errors=0; (( once )) && break; phase "idle; next at $(date -d "+$WAIT_IDLE sec" '+%H:%M')"; nap "$WAIT_IDLE" ;;
    BLOCKED*) notify "$status"; phase "blocked: ${status#BLOCKED }"; exit 0 ;;
    *)        # A clean exit that forgot the status line is idle, not an error:
              # an agent holding two PRs that wrote its handoff is fine.
              if (( rc == 0 )); then
                errors=0; (( once )) && break
                phase "idle (no status line); next at $(date -d "+$WAIT_IDLE sec" '+%H:%M')"; nap "$WAIT_IDLE"; continue
              fi
              errors=$(( errors + 1 ))
              if (( errors >= 3 )); then notify "3 sessions in a row ended without a status (last rc=$rc, log $out)"; phase "stopped after errors"; exit 1; fi
              w=$(( 300 * errors * errors )); phase "error $errors; retry at $(date -d "+$w sec" '+%H:%M')"; nap "$w" ;;
  esac
done
phase "finished (--once)"
log "finished"
