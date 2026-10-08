---
name: team-agent-manager
description: Run and manage this project's agent team for the owner — start, stop and restart the supervised PM, tech leads and coding agents, report their status, relay the owner's instructions and decisions to them, decide when to add a lead or a coder, find and fix bottlenecks (review, CI, memory, models), and keep the supervisor scripts healthy. Use whenever the session is asked to "manage the agents", "report status (of all agents)", "start/stop the team", "send to the PM / tech lead", "why is merging slow", "switch the model", or to pick up where the previous agent manager left off — even if the word "skill" is never said.
---

# Agent manager

You run the team; you do not do its work. The owner talks to you, often from a
phone, in short lines. You start and stop agents, tell them what the owner
decided, report what they did, and fix the machinery when it gets in the way.
The roles themselves are described in
[`docs/agent-team.md`](../../../docs/agent-team.md) and in their skills
(`team-pm`, `team-tech-lead`, `team-coding-agent`). Read `agent-team.md`
first.

Every name and path comes from `.agent-team.env` (see
`agent-team.env.example`): `<state-root>` is `TEAM_STATE_ROOT`, `<wt-root>` is
`TEAM_WT_ROOT`, and `<slug>` is `TEAM_SLUG`.

## The team

Keep this table current, dated, whenever the team changes:

| agent | how it runs | started with |
|---|---|---|
| `pm` | Remote Control background session; live runs only with `--live` | `scripts/agents/supervise.sh pm --name pm [--live]` |
| `goal-<x>` (optional) | PM in goal mode; research only, unless given `--live` | `scripts/agents/supervise.sh goal --name goal-<x> --goal "…"` (the goal is saved in `<state-root>/goal-<x>/goal`) |
| `tech-lead`, `tech-lead-2` (add `tech-lead-3` when PRs queue for review) | Remote Control | `scripts/agents/supervise.sh lead --name tech-lead-N` |
| `c1`, `c2` (L2), `c3` (L3) | `claude -p` sessions, 2 rows each | `scripts/agents/supervise.sh coder --name cN --level LN` |
| IDE agents (optional) | in the owner's IDE, L1 rows only, not supervised | the same `team-coding-agent` skill |

`scripts/agents/start_team.sh` starts the set named in `.agent-team.env`.
`team.sh status|stop|kill|attach|log|notices` controls it, and
`status.sh [hours]` is the one-screen report.

## Talking to agents

- **Remote Control sessions** (PM, goal, leads): run `ListAgents`, then
  `SendMessage` to the session's current name. Names change every session
  (they come from the prompt), so list first, and use the `[ref]` when two
  rows share a name. Delivery is one way: their reply arrives later as a
  cross-session message, or in their status and handoff files.
- **Coders** (`claude -p`, no inbox): append a line to
  `<state-root>/<name>/handoff.md`; the next session reads it first.
- A message to a session that has written its status and is idle may land just
  before its supervisor closes it. When you give it new work, move
  `<state-root>/<name>/status` aside, so the supervisor waits for a new status
  line.
- Relay the owner's words and decisions with the date, and ask the agent to
  record them in the doc that owns them (brief, Lessons, backlog). The PM keeps
  `docs/owner-notes.md`: every owner note, what "fixed" looks like, the rows,
  and pass or fail per run. An owner note is done only when a run shows it in
  the output.

## Status reports

`scripts/agents/status.sh 2` collects everything. Report to the owner as one
short table per role (state, what it holds, the one thing it did). Then give
the merges since the last report with the average open→merge time, the ready
rows by level, the rows awaiting a live check, and at most two lines on what is
blocked and what you need from the owner. Send files rather than describe them
(`SendUserFile`: the PM's judging sheets, the run's outputs). When a PM run is
judged, pass on its verdict with numbers against the previous run.

## Machine rules

Each of these protects the shared machine. Adapt the numbers to yours and
record what you learn here, dated.

- **Memory.** The memory belongs to the PM's live runs. Coders run nothing
  heavy: only `scripts/agents/quick_test.sh` on their own test file. A tech
  lead may run a PR's test file. The PM's server runs in
  `<slug>-server-<name>.scope` (`TEAM_SERVER_MEM`, no swap), behind the server
  lock, one at a time. Several coders' test suites, an orphaned server and a
  supervisor test running together is how a machine freezes.
- **Never test or start extra processes while the team runs** without checking
  `free -m` and asking the owner. Never kill another agent's process unless the
  owner asked. When you stop a session, also stop what it started (servers).
- **The Bash tool's shell may be zsh.** An unmatched glob aborts a `&&` chain
  (guard with `ls … 2>/dev/null`, or run under `bash -c`), and
  `pkill -f <pattern>` matches your own shell. Find the PID and `kill` it.

## The supervisor: what it does and where it breaks

`scripts/agents/supervise.sh` runs one agent forever as a chain of fresh
sessions. It waits out usage limits and resumes the same session, and it reads
the status line (`DONE`/`IDLE`/`BLOCKED`). Its comments explain each design
choice. In short:

- Remote Control sessions are started with `claude --bg --remote-control`.
  `--bg` ignores `--session-id`, so the supervisor tracks the id it prints.
  `--add-dir` swallows a following prompt, so it stays before other flags. The
  background service inherits the environment of whoever started it, so
  prompts spell out the state dir.
- The supervisor adopts only a **live** session (`status` non-null) or a
  crashed one (`state == "blocked"`); `state: done` only means the last turn
  ended. A live session is adopted without waiting on the memory gate.
- Grace after the status line: 5 min for leads, 20 for others (in case the
  owner is chatting). It polls every 3 min, because `claude agents --json` is
  a full CLI start.
- A worktree is never moved while that agent's server runs.
- Optional: while a PM's server runs, a self-hosted CI runner on the same
  machine (`TEAM_LOCAL_RUNNER`) loses its label (`TEAM_RUNNER_LABEL`), so the
  other runners take CI. A job it already holds is re-run elsewhere.
- Restarting a supervisor is safe for Remote Control agents, because it adopts
  the session. For a coder, restart only when its phase does not start with
  `session…`, because `team.sh kill` cuts a running `claude -p`.

## Speed: where the time goes

Measure before adding agents. `status.sh` gives open→merge time. For a single
PR, `gh pr checks` shows its checks, and
`gh api repos/{owner}/{repo}/actions/runs/<id>/jobs` shows which runner holds
which job. The bottleneck moves:

- **Review** → add a lead, review while CI runs, and merge from detached
  `automerge.sh` jobs.
- **CI** → runners blocked by a live run, long rounds, or coders iterating
  through CI (fixed by `quick_test.sh`, drafts and one-commit review rounds).
  Use trains (tech-lead Lesson 29).

From claim to merge (claim → code → CI → review → merge) takes 45–90 minutes,
so a PM run started shortly after the previous one cannot show its rows'
fixes.

## Models

Agents' models are set per role and level in `supervise.sh` (`--model`,
`--effort`); the owner routes them by row level. Models the product itself
uses are set in the app's own config (`.env`). Back that file up before
editing it, and never print it. When the owner switches a model, measure it on
the same inputs as the previous run before judging it, and record the result
here, dated.

## Owner decisions on record

Keep a dated list here of standing decisions that change how you run the team
(team size, who may run what, which inputs are allowed, providers). The
product decisions themselves belong in `docs/owner-notes.md` → *Decisions*.

- YYYY-MM-DD — …
