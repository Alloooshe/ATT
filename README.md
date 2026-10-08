# ATT — agent team template

A ready-to-adopt setup for running a team of Claude Code agents on one
repository: a **PM**, one or more **tech leads**, several **coding agents**, and
an **agent manager** that the owner talks to. They coordinate through a single
backlog file, GitHub PRs and labels, and git locks, and each one runs as a
chain of short, fresh sessions under a supervisor that survives usage limits.

```
owner ──▶ agent manager ──▶ PM ──writes rows──▶ docs/BACKLOG.md ◀──claims── coding agents
                              ▲                                                   │
                              └──── Inbox ◀── tech leads ◀──────── PRs ◀──────────┘
                                               (review, guarded merge, CI)
```

## What's inside

| path | what it is |
|---|---|
| `.claude/skills/team-coding-agent/` | claim a `ready` row → failing test → fix on `agent/NN-slug` → PR in the house template; at most 2 rows per session |
| `.claude/skills/team-tech-lead/` | review PRs against the row's *done when*, guarded merge, trains, keep CI green; `references/lessons.md` |
| `.claude/skills/team-pm/` | live runs, judging output, writing provable rows; goal mode (research → brief → rows); `references/` |
| `.claude/skills/team-agent-manager/` | start/stop/report the team, relay the owner's decisions, fix bottlenecks |
| `docs/agent-team.md` | what every role shares: worktrees, identity, locks, sessions, handoff |
| `docs/BACKLOG.md` | the single backlog: Levels, States, Areas, Open, Inbox, Merged, Closed (template) |
| `docs/owner-notes.md`, `docs/evidence.md`, `docs/live-run-protocol.md`, `docs/briefs/` | templates the PM fills in |
| `scripts/agents/` | `supervise.sh` (the supervisor), `start_team.sh`, `team.sh`, `status.sh`, `base.sh`, `pr_lock.sh`, `quick_test.sh`, `rc_setup.sh`, `config.sh` |
| `scripts/lead/` | `automerge.sh` (guarded merge + *Merged* row), `train_merge.sh`, `watch_agents.sh` |
| `examples/ci.yml` | a CI workflow shaped for the team (skips drafts, changed-tests on PRs, full on the base) |
| `agent-team.env.example` | every project-specific value, in one file |

## Adopting it in a project

1. **Copy** `.claude/skills/`, `docs/` (merge with yours), `scripts/agents/`,
   `scripts/lead/` and `agent-team.env.example` into the repository root. In
   `.gitignore`, make sure `.claude/skills/` is tracked (agents in worktrees
   and in the cloud must see the skills).
2. **Configure:** `cp agent-team.env.example .agent-team.env` and set the
   project name, slug, base branch, main checkout path, linked paths, git
   identity, the quick-test command and the team. Commit it if every machine
   shares the values; otherwise ignore it.
3. **Create the base branch** (`TEAM_BASE`, e.g. `dev`), push it, and keep it
   checked out in the main checkout. Agents work detached in their own
   worktrees and push `HEAD:<base>`.
4. **Fill in the templates:** the *Areas* in `docs/BACKLOG.md` (which files
   each area covers), `docs/live-run-protocol.md` (how the PM runs the product
   end to end and what it judges), and the first owner notes. A `CLAUDE.md`
   with your architecture and invariants helps every role.
5. **CI:** adapt `examples/ci.yml`. The guarded merge needs a PR's checks to
   include at least one real `SUCCESS` (checks named in
   `TEAM_CI_IGNORE_CHECKS` do not count).
6. **Once per machine:** `scripts/agents/rc_setup.sh` (accept folder trust and
   the bypass-permissions prompt for the background sessions), then
   `scripts/agents/start_team.sh` (add `--live` when the PM may run the
   product).
7. **Talk to it:** open an interactive Claude Code session and say "manage the
   agents" (the agent manager skill), or open the PM's or a lead's Remote
   Control session from claude.ai/code.

## Requirements

Linux with a systemd user session (`systemd-run --user`), `git` (worktrees),
the GitHub CLI `gh` (authenticated, with label and merge rights), `jq`,
`flock`, and the `claude` CLI. The supervisor's resource gate reads
`/proc/meminfo`. Coding agents can also run without the supervisor: one
interactive prompt per agent ("You are a coding agent… use the
team-coding-agent skill, level L2").

## The ideas it rests on

- **One backlog, one writer per part.** The PM writes rows and their *done
  when*, coders change only a claimed row's state, and leads set PR states and
  *Merged*. A claim is a one-line commit on the base branch, so a race is a
  rejected push.
- **Provable rows.** Every *done when* names a real artifact and a number, so
  the reviewer and the PM can check it without having seen the run.
- **Short sessions, state on disk.** One unit of work per session. The
  handoff file, the backlog and the PRs carry state between sessions.
  `DONE`/`IDLE`/`BLOCKED` status lines drive the supervisor.
- **Guarded merges.** A PR is merged only when CI is green on the exact head
  that was reviewed, and cleanup happens only after the PR reads MERGED.
- **The shared machine is the PM's.** Coders run only a capped quick test; CI
  is their test run. Heavy work goes through locks and memory scopes.
- **Lessons are kept.** Each role has a `references/lessons.md`. When
  something costs a run, the lesson is added there, numbered and dated.
