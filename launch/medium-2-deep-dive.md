# The boring protocol that stops AI coding agents from stepping on each other

*Claim commits, label leases, guarded merges and merge trains: a technical tour of how ATT runs a team of Claude Code agents on one repo, on one machine.*

---

When you run more than one coding agent against the same repository, the interesting failures aren't about intelligence. They're about **concurrency**: two agents fix the same bug, one agent's commits land on another's branch, a merge goes in on a commit nobody reviewed, the machine runs out of memory.

[ATT](https://github.com/Alloooshe/ATT) is the setup I use to run a PM agent, several tech-lead agents and several coding agents locally. In a nine-day deployment on a private project it merged 344 tasks at a median of 1.3 hours from claim to merge. This post is about the mechanisms — every one of which exists because something broke without it.

## 1. A claim is a commit

The backlog is one Markdown table. To take a task, a coding agent changes exactly one cell and pushes straight to the integration branch:

```bash
# state cell: `ready` → `claimed agent/142-retry-upload`
git commit -m "Claim #142 (L2) for agent/142-retry-upload" -- docs/BACKLOG.md
git push origin HEAD:dev
```

If another agent claimed it first, the push is rejected. The agent rebases, looks again, and either still owns the row or resets and picks the next one. No database, no queue, no coordinator process — git's compare-and-swap on the branch tip *is* the lock.

Each backlog part has one writer: the PM writes rows and their "done when", coders only flip `ready → claimed`, leads own the state while a PR is open. Conflicts in the backlog file are therefore rare and trivially resolvable.

## 2. Worktrees, detached, and signed

Every agent gets its own `git worktree`, **detached** on the integration branch. (The named branch is checked out in the owner's checkout, so git refuses it anywhere else — which turns out to be a feature: no agent can accidentally commit on it except by an explicit `push HEAD:dev`.)

Each worktree is also **signed**:

```bash
git config --worktree user.name  "Owner (tech-lead-2)"
git config --worktree user.email "owner+tech-lead-2@example.com"
```

Every agent pushes as the same GitHub user, so without this, a lead once read four merges by another session as its own. Now `git log --format=%ae` tells you exactly who did what.

## 3. Leases as GitHub labels

Two leads must never review the same PR. A lead takes a PR by adding the label `review:<name>`, waits three seconds, and checks: if two labels landed at once, the lexically smaller name keeps it. Leases go stale after 3 hours (a lead that died mid-review); coder ownership labels after 24 hours, like claims. Visible to every session, local or cloud, with zero infrastructure.

## 4. The guarded merge

Leads never click merge. They start a detached job:

```bash
systemd-run --user --collect --unit automerge-pr$N \
  "$PWD/scripts/lead/automerge.sh" $N $ROW "what the PM should check" $BRANCH
```

It waits for CI and merges **only if**:

- CI is green on the **newest workflow run** (re-triggered runs keep the old run's cancelled jobs around),
- at least one check is a real `SUCCESS` (a draft's rollup is all `SKIPPED`, which must never read as "pass"),
- the head is **the one the lead reviewed** (`gh pr merge --match-head-commit`),

then retries the "Base branch was modified" race, deletes the branch **only after** GitHub reports `MERGED` (deleting after a refused merge closes the PR unmerged), and writes the backlog's *Merged* row under the push lock.

## 5. Merge trains when CI is the bottleneck

Once review got fast, CI became the queue. The fix: approved PRs stay drafts (CI skips drafts), a lead merges several approved heads into `train/NN`, runs everyone's tests together once, merges the base branch in **last** so the backlog file is current, and opens one PR. One CI run for up to 37 PRs. If it goes red, drop the culprit and ship the rest. In the deployment, 21 trains carried 177 merges.

## 6. Short sessions and a supervisor

Each agent is a chain of fresh sessions, run by a ~450-line Bash supervisor under `systemd --user`:

- one unit of work per session (a coder: finish its PRs, then ≤ 2 claims), then a status line — `DONE`, `IDLE` or `BLOCKED`;
- a **handoff file** carries state to the next session; the backlog and PRs carry the rest;
- a memory/load gate before every new session;
- on a usage limit, sleep until the reset and **resume the same session**;
- `BLOCKED` stops the agent and notifies the owner.

The PM and leads run as background sessions with Remote Control on, so I can open any of them from my phone and talk to it mid-task.

## 7. The machine is a shared resource

Three file locks: pushes to the base branch, heavy work, the single app server. The server runs in a named `systemd` scope with a memory cap, so `team.sh kill pm` stops it too. Coders never run test suites locally — only `quick_test.sh` on their own new test file, capped at 512 MB and two minutes. That rule exists because the alternative froze the machine.

## 8. Lessons as durable memory

Every role has a numbered `lessons.md`, read at the start of every session. When something costs a run, a rule is added with the date and the incident. Several of the mechanisms above *are* lessons that got promoted into scripts.

## Results, briefly

344 claimed tasks merged in nine days; median 1.3 h claim → merge; 91% within 8 h; 2 reverts on the shared branch. One project, one owner — a field study, not a benchmark. Details and limitations are in the paper in the repo.

**Code:** https://github.com/Alloooshe/ATT — everything project-specific is one `.agent-team.env` file. Stars, issues and new lessons are very welcome.
