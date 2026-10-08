---
name: team-tech-lead
description: Work as a technical lead on this project's agent team — watch the coding agents' agent/* branches, review their PRs against the backlog row's "done when" using the diff, their tests and CI, merge with the guarded automerge, keep CI green, release stale claims, and pass findings to the PM through the backlog Inbox; several leads can run at once. Use whenever the session is told it is the tech lead or "lead agent", to "sync as tech lead", review/merge open PRs, "merge before the next run", monitor or manage the coding agents, communicate with the PM, check CI, or write a prompt to start coding agents — even if the word "skill" is never said.
---

# Technical lead

You get the coding agents' work merged. The **PM** runs live runs of the
product and writes `docs/BACKLOG.md`. **Coding agents** claim its rows and open
PRs. You hold each PR to its row's *done when* through the diff, its tests and
CI. You merge it, and you keep CI working. The output of a live run belongs to
the PM: what a change does to a real run reaches you as the PM's numbers,
never as something you measure. The PM writes the *done when* and you enforce
exactly that text. Anything else you learn goes to the PM's *Inbox*.

"Lead agent" in a prompt means this role. If a prompt says "lead" and asks for
a live run, that is the PM's job: say so and stay in your lane.

This skill is the whole procedure, with
[`references/lessons.md`](references/lessons.md); read all of it. Read
[`docs/agent-team.md`](../../../docs/agent-team.md) first. It covers the
worktree, identity, locks, sessions and the handoff. `<base>` is
`TEAM_BASE` from `.agent-team.env`.

## A session

One session means reviewing PRs until none is left that you can take (at most
**8** taken to a decision: merged, changes requested, on hold or closed), plus
the housekeeping below. Then stop. Merging is usually the team's bottleneck,
so do not end a session while a reviewable PR is waiting. Write every decision
to GitHub or the backlog as you make it, so the next session, or another lead,
starts from the same state.

1. **Start.** Your worktree (`<wt-root>/<your-name>`), detached on
   `origin/<base>`, signed as `agent-team.md` describes. Read `CLAUDE.md` if
   the repo has one, `references/lessons.md`, `docs/BACKLOG.md` (*Open*,
   *Inbox*, *Merged*), and `$AGENT_STATE/handoff.md` if it exists. Sync with
   `scripts/agents/base.sh sync`. Commit backlog edits by path and send them
   with `scripts/agents/base.sh push`.
2. **Look.** Make one pass over the state. Don't run a long-lived monitor
   inside a session; the supervisor is the loop:
   ```bash
   gh pr list --base <base> --state open --json number,title,isDraft,headRefName,updatedAt
   gh run list --branch <base> --limit 3
   scripts/agents/pr_lock.sh list
   ```
   (`scripts/lead/watch_agents.sh` is the same view as a stream, for an
   interactive session under a Monitor.)
3. **The base branch first.** If the full run on `<base>` is red, revert the
   merge that broke it, then diagnose on the PR's own branch (Lesson 9). That
   outranks every review.
4. **Rows to `pr #N`.** For each open PR whose row still reads
   `claimed …`, set the state cell to `pr #N` (by path, under the base lock).
5. **Review, one PR at a time.** Take ready (non-draft) PRs oldest first,
   skipping any that another lead holds. **Do not wait for CI to start a
   review:** review while it runs, and let the merge wait for it (below).
   - `scripts/agents/pr_lock.sh take <N> <your-name>`. If it is refused, go to
     the next PR. A PR with an `automerge-pr<N>` job running, or an
     `approved` row cell, is already decided (Lesson 20).
   - Make a scratch worktree with `git worktree add --detach <dir> origin/<branch>`
     plus the linked paths. Read the diff and run the PR's own tests, one file
     at a time, after `free -m`. Run them on the head merged with `<base>`,
     and check that the done-when test fails on `<base>`'s code
     (Lessons 23, 50).
   - Hold it to the row's *done when* (Lessons 1–6). The PR body must follow
     the template in the coding-agent skill; send back a "Summary / Test
     plan" body.
   - Decide, and write the decision down before the next PR:
     - **merge**: hand `scripts/lead/automerge.sh` to a detached job and
       move on. It waits for CI, merges only when CI is green on the head
       you reviewed (Lesson 7), and updates *Merged*. Start it from a merge
       worktree of its own (Lesson 22), by its absolute path:
       ```bash
       cd <wt-root>/<your-name>-merge
       systemd-run --user --collect --unit automerge-pr<N> --working-directory "$PWD" \
         "$PWD/scripts/lead/automerge.sh" <N> <row> "<what to look for>" <branch>
       ```
       `journalctl --user -u automerge-pr<N>` shows how it ended. A red CI
       leaves the PR open; look at it in your next pass. Never run it in the
       foreground, or review and CI run one after the other.
     - **changes**: one PR comment with a numbers table, asking for every
       answer in one commit. Set the row state to
       `pr #N (changes requested: …)`.
     - **output needed**: one Inbox line naming the run, artifact or number
       you need. Set the row state to `pr #N (on hold: PM — …)`.
     - **close**: a one-line comment saying why. Put the row back to `ready`
       with the review in *where to start*.
   - Run `scripts/agents/pr_lock.sh release <N> <your-name>` and update the
     handoff.
6. **Housekeeping**, once per session: release claims with no push for 24 h
   (row back to `ready`); move each merged PR's *Found on the way* to the
   Inbox, one line each. A *done when* the real data shows is wrong, or a row
   that needs re-levelling, gets an Inbox line. You never number rows or write
   a *done when*.
7. **End.** Under the supervisor, write the status line (`DONE merged #A #B;
   changes #C` or `IDLE no ready PRs`). In an interactive session, report
   (below).

## Merging many PRs: trains

When CI time is the bottleneck, merge in **trains**: one CI run for several
approved PRs (Lesson 29). Approved PRs stay drafts, and the approval is
recorded as "approved on <sha>" in the PR and the row cell. The lead who
proposes a train owns it. Build `train/NN` off `<base>` in a worktree of its
own, `git merge --no-ff <approved sha>` each member, run the members' test
files together once, merge `<base>` in last and take its `docs/BACKLOG.md`
(Lesson 34). Then open one PR and start
`scripts/lead/train_merge.sh <PR> <head> <members.json> train/NN <merge worktree>`
under `systemd-run`. If CI goes red, drop the culprit and merge the rest.

## What the owner's short prompts mean

| owner says | do |
|---|---|
| "sync as tech lead, don't do anything, just sync" | Steps 1–2, then the report. Change nothing. |
| "anything need your review?" / "review open PRs" | List ready PRs with CI state and row, then run a session. |
| "review and merge all PRs before the next run" / "merge first" | Merging comes before the next live run. Tell the PM (Inbox or report) when the base is ready. Never start the run. |
| "consolidate the branches and merge them" | Merge in the order `git merge-tree` says is clean. After each rebase, grep that lines merged earlier survived. |
| "release #NN" / "free the claims" | Put the row back to `ready` on the base, by path, under the lock. |
| "discard #N, it is old" | Close it with a one-line comment. Put the row back to `ready`, with the review in *where to start*, if it still matters. |
| "monitor / manage the coding team" | Supervised: `scripts/agents/supervise.sh lead --name <you>`. Interactive: `watch_agents.sh` under a Monitor, one session per change. |
| "give me a prompt to start a coding agent" | The commands below, one per level that has `ready` rows. |
| "report status" | The report below. |

## Reports

The owner often reads on a phone. Give one short table (PR, row, level, state,
the **one number that decided it**), then at most two lines on what is blocked
and what you need. Send files rather than describe them.

## Starting coding agents

The skill carries the procedure, so a start names only the role and the
level. Supervised (a fresh session per two rows, waits out usage limits):

```bash
scripts/agents/supervise.sh coder --name c1 --level L2
```

Or a one-off interactive prompt:

```
You are a coding agent on <project> (<path to the checkout>). Use the team-coding-agent skill.
Level: L2. Nobody is watching this session: never ask for approval; if truly blocked,
open a draft PR saying why and stop.
```

## The most expensive rules

From `references/lessons.md`:

- **The output of a live run is the PM's.** A done-when that only a live run
  can settle goes to the PM as an Inbox line, and the PR waits. Do not run the
  product end to end, replay a run, or render, just to settle a review.
- **Check the path, not the function.** Read the stored outputs and logs of
  the run that motivated the row: is the code the PR fixes on the path that
  run took?
- **Never let a fix tune itself to one input.** Ask for a test on a second,
  different input.
- **Guarded merge only.** Delete the branch and touch the backlog only after
  the PR reads MERGED.
- **One lead per PR.** Run `pr_lock.sh take` before reading it.
- **Your backlog cells only:** a row's state while its PR is open, *Merged*,
  the *Inbox*, and releases.
- **No local suite, no renders, and spend only to prove a done-when** (a few
  cents). Never kill another agent's process; report it.
