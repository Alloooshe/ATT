# The agent team — roles, the machine, sessions

Every agent reads this first. It holds what all roles share. Each role's
procedure lives in its skill, and that skill is the only copy:

| role | skill | does | never |
|---|---|---|---|
| **Coding agent** (any number) | [`team-coding-agent`](../.claude/skills/team-coding-agent/SKILL.md) | claims `ready` rows, fixes each on `agent/<NN>-<slug>`, opens a PR | merges, writes rows, runs live runs |
| **IDE coding agent** (optional, any number) | the same skill, loaded by the IDE's agent | **L1 rows only**, worktree `<wt-root>/ide-<N>` | as above; L2/L3 |
| **Tech lead** (one or more) | [`team-tech-lead`](../.claude/skills/team-tech-lead/SKILL.md) | reviews PRs against the row's *done when* using the diff, tests and CI; merges; keeps CI green | runs the product to judge output, numbers rows |
| **Agent manager** (the owner's own session) | [`team-agent-manager`](../.claude/skills/team-agent-manager/SKILL.md) | starts, stops and reports on the team, relays the owner's decisions, fixes the supervisor | the agents' own work |
| **PM** | [`team-pm`](../.claude/skills/team-pm/SKILL.md) | runs live runs, judges the output, writes the backlog; in *goal mode* researches a goal and turns it into a brief and rows | reviews or merges PRs |

When the owner says "add the lessons to the prompt", edit the skill or its
`references/lessons.md`.

Every path, branch and name below comes from `.agent-team.env` at the repo root
(see `agent-team.env.example`). In this doc `<base>` is `TEAM_BASE`,
`<wt-root>` is `TEAM_WT_ROOT`, `<state-root>` is `TEAM_STATE_ROOT`, and
`<main>` is `TEAM_MAIN_CHECKOUT`.

## Who writes what in `docs/BACKLOG.md`

| part | PM | tech lead | coding agent |
|---|---|---|---|
| new rows, numbers, levels, *done when*, order of *Open* | ✔ | — | — |
| a row's state: `ready` → `claimed agent/…` | — | — | ✔ (claim commit only) |
| a row's state while its PR is open (`pr #N …`), *Merged* additions | — | ✔ | — |
| releasing a claim silent for 24 h | — | ✔ | its own (`release #NN`) |
| *Merged* → *Closed* or back to `ready` | ✔ | — | — |
| *Inbox* | reads and empties | writes | — |
| `docs/briefs/` | ✔ (goal mode) | — | — |
| `docs/owner-notes.md` | ✔ | — | — |

Everything goes through `<base>`. It is the base of every agent branch, the
target of every PR, and the branch every live run uses.

## The machine

One owner machine and many sessions. Each rule below protects a resource that
the sessions share.

- **Your own worktree, never `<main>`.** If one process switches branches in a
  shared checkout, another process's commits land on the wrong branch. Path:
  `<wt-root>/<name>`, where `<name>` is the agent's name (`c1`, `tech-lead`,
  `pm`). The supervisor creates it. By hand:
  ```bash
  git -C <main> fetch origin
  git -C <main> worktree add --detach <wt-root>/<name> origin/<base>
  for p in $TEAM_LINKS; do ln -sfn <main>/$p <wt-root>/<name>/$p; done
  ```
  The linked paths are the untracked things nothing runs without: secrets,
  virtualenvs, `node_modules`. In a cloud container, the checkout you were
  given is already yours.
- **Sign your worktree.** Then `git log --format=%ae` shows which session did
  what. Every session commits as the owner, and a session can misread another
  session's merges as its own:
  ```bash
  git config extensions.worktreeConfig true
  git config --worktree user.name  "<Owner Name> (<name>)"
  git config --worktree user.email "<owner>+<name>@<domain>"
  ```
  `--worktree` matters: a plain `git config` renames every session at once.
- **Detached on the base.** The named `<base>` branch is checked out in
  `<main>`, so git refuses it in any other worktree. Agents' worktrees sit
  **detached** on `origin/<base>`. `scripts/agents/base.sh sync` fetches and
  rebases your commits onto it, and `scripts/agents/base.sh push` pushes
  `HEAD:<base>`. Never commit in the owner's checkout.
- **Base lock.** Every sync, commit or push to `<base>` from a lead or the PM
  holds the base lock (`TEAM_BASE_LOCK`). `base.sh` and `automerge.sh` take it
  for you; never wrap them in another `flock` on the same file, or they
  deadlock. Check `git status -sb` before committing. Coding agents' claim
  pushes race the lock; a rejected push means someone else pushed first.
- **Heavy lock.** A live export, a render or a heavy test runs under
  `flock $TEAM_HEAVY_LOCK`, inside a memory scope
  (`systemd-run --user --scope --unit <slug>-server-<name> -p MemoryMax=$TEAM_SERVER_MEM -p MemorySwapMax=0`).
- **The memory is the PM's.** Coders only code. On this machine they run no
  test suite, server, renderer, build or typecheck; CI is their test run. The
  one exception is `scripts/agents/quick_test.sh` on their own new test file
  (capped memory and time). The tech lead may run a PR's test file, one at a
  time, after `free -m`. Everything heavy (the app server, exports, runs on
  real data) belongs to the PM, inside its server scope. Several agents each
  running "just one" test suite beside a live run is how a shared machine
  freezes.
- **One app server at a time.** Two PMs may run, one in run mode and one in
  goal mode, but only one server. Start it through the server lock so that a
  second start fails instead of running:
  ```bash
  systemd-run --user --scope --unit <slug>-server-$AGENT_NAME -p MemoryMax=$TEAM_SERVER_MEM -p MemorySwapMax=0 \
    flock -w 0 $TEAM_SERVER_LOCK env TMPDIR=<wt-root>/tmp <your app's start command>
  ```
  If it is refused, another PM's server is up. Do the steps that need no
  server, or end the session `IDLE server busy`. `team.sh kill <name>` stops
  the scope along with the agent.
- **Never run the full suite locally**, whatever your role. PR CI runs what
  the change reaches, and a push to `<base>` runs everything.
- **`TMPDIR=<wt-root>/tmp`** for servers and renders. A shared `/tmp` tmpfs
  that fills up breaks every render at once.
- Never kill another session's process; report it instead. Never print
  secrets. Never `git add -A`; add files by path.

## Sessions

Agents are started by the supervisor, `scripts/agents/supervise.sh` (see
*Starting the team* below), or by the owner by hand. Either way, a session is
**one unit of work in a fresh context**:

| role | one session is | then |
|---|---|---|
| coding agent | finish its open PRs, then at most **2** new claims → PRs | exit |
| tech lead | review PRs until none is left to take (at most **8** decisions), plus housekeeping | exit |
| PM (run mode) | one live run judged and filed, or one backlog pass | exit |
| PM (goal mode) | one goal researched into a brief and rows | exit |

Short sessions keep context small. There is no compaction to manage, because
the state lives on disk: the backlog, the PRs, the branches and the session's
**handoff file**.

**Handoff file.** Under the supervisor, `$AGENT_STATE` is a directory that
survives sessions (`<state-root>/<name>`). Read `$AGENT_STATE/handoff.md` at
the start; it is what the previous session of the same agent left. Rewrite it
as you go, not only at the end, because a usage limit can cut a session. It
says what you hold (claims, branches, PRs you own or are reviewing) and the
next step for each. Keep it under 40 lines.

**End of session.** Write one line to `$AGENT_STATE/status`:

| line | means | the supervisor |
|---|---|---|
| `DONE <one-line summary>` | did a unit of work | starts the next session soon |
| `IDLE <why>` | nothing to do (no `ready` row at your level, no PR to review) | waits longer before the next |
| `BLOCKED <why>` | needs the owner | stops this agent and notifies |

Then stop. Without the supervisor (`$AGENT_STATE` unset), skip both files and
report to the owner as your skill says.

**Usage limits.** When the account's limit is hit, the session ends. The
supervisor waits for the reset and resumes the *same* session ("continue where
you stopped"), so a half-done unit finishes with its context. You don't need to
do anything, but keep the handoff current, because a resume can fail.

**Remote Control.** The PM's and the tech leads' supervised sessions are
interactive background sessions with Remote Control on, so the owner can join
one from the phone. Answer the owner and follow them, but never wait for them.
The supervisor ends the session a few minutes after your status line (5 for
leads, 20 otherwise), or nudges you after an hour idle without one.

**Interactive sessions** (the owner typing). The same unit-of-work rule holds.
When a unit is done and the conversation is long, say so in one line ("unit
done; handoff written — safe to /clear") rather than starting the next unit.

## Running more than one of a role

- **Coding agents:** the claim commit keeps rows disjoint. Prefer an area that
  no other open claim shares. Each agent has its own name, worktree and state
  dir. A PR belongs to the coder whose `coder:<name>` label it carries
  (`scripts/agents/pr_lock.sh … coder`). Every agent pushes as the same
  GitHub user, so `--author @me` cannot tell them apart.
- **Tech leads:** one lead reviews a PR at a time. Take it with
  `scripts/agents/pr_lock.sh take <N> <your-name>` before reading it, skip a
  PR that another lead holds, and `release` it when you merge, ask for
  changes, or put it on hold. A lock untouched for 3 h is stale and may be
  taken. Backlog edits stay safe under the base lock.
- **PM:** one in run mode at a time, because live runs share the heavy lock
  and the server. Goal-mode PMs may run beside it; they write only
  `docs/briefs/` and new rows, under the base lock.

## Starting the team

The PM and the tech leads run as **Remote Control** sessions. Open them from
claude.ai/code or the Claude app ("<Project> tech-lead", "<Project> pm") to talk
to them mid-unit. Once per machine, in a terminal, accept the folder-trust and
bypass-permissions prompts that they cannot show in the background:

```bash
cp agent-team.env.example .agent-team.env   # then edit: project, base branch, paths, team
scripts/agents/rc_setup.sh               # opens claude per worktree: accept both, /exit
# everyone in TEAM_LEADS / TEAM_PM / TEAM_CODERS, staggered:
scripts/agents/start_team.sh             # PM without live runs
scripts/agents/start_team.sh --live      # PM may run live runs

# or one at a time:
# one coding agent at L2 (fresh session per 2 rows, waits out limits, forever)
scripts/agents/supervise.sh coder --name c1 --level L2
scripts/agents/supervise.sh coder --name c2 --level L1 --model sonnet
scripts/agents/supervise.sh lead  --name tech-lead
scripts/agents/supervise.sh lead  --name tech-lead-2
scripts/agents/supervise.sh pm    --name pm                 # backlog passes; no live run
scripts/agents/supervise.sh pm    --name pm --live          # also live runs (owner's "go")
scripts/agents/supervise.sh goal  --name goal-1 --goal "Export to PDF with the house template" --once

scripts/agents/team.sh status            # every agent: state, last status, next wake
scripts/agents/team.sh stop c1           # finish the current session, then stop
scripts/agents/team.sh stop all
```

Each agent runs in the background under `systemd-run --user`, so it survives
the terminal; logs are in `<state-root>/<name>/logs/`. The owner's short
prompts still work in an interactive session: "you are a coding agent, L2"
loads the same skill.
