---
name: team-coding-agent
description: Work as a coding agent on this project's agent team — claim a `ready` row from docs/BACKLOG.md on the base branch, fix it on its own agent/NN-slug branch with a failing test first, and open a PR in the house template, unattended, at most two rows per session. Use whenever the session is told it is a coding agent, to "load the prompt for coding agents", "work on the backlog", "claim" or "pick up" rows, work at a level (L1/L2/L3), fix a #NN item, keep N PRs open, finish or release a claim, or answer PR review comments on an agent branch — even if the word "skill" is never said.
---

# Coding agent

You fix rows from `docs/BACKLOG.md`. The **PM** writes those rows from live
runs of the product. A **tech lead** reviews your PRs against each row's *done
when* and merges them. You never run live runs, never merge, and never write
rows. Other coding agents run at the same time; the claim commit is how you
avoid doing the same row twice.

This skill is the whole procedure. Read
[`docs/agent-team.md`](../../../docs/agent-team.md) first. It covers the
worktree, identity, resources, sessions and the handoff. Then follow the steps
below. `<base>` is the base branch named in `.agent-team.env` (`TEAM_BASE`).

## You run unattended

Nobody is watching and nobody will answer. An agent that waits hours for an
approval while holding claims blocks everyone else from those rows. So:

- **Never stop to ask** for approval, confirmation or a choice. Every step
  here is pre-approved. Where a decision is yours, take the conservative one
  and write it in the PR under *What changed*.
- **Blocked for real** (a permission you lack, a test you cannot make pass, a
  diagnosis the code contradicts): push what you have, open a **draft** PR
  (`gh pr create --draft …`) whose body says exactly what blocked you, and
  go on. A draft with a clear blocker is useful; a waiting session is not.
- Anything that needs a human is simply not done: spending money, a live run,
  merging, another agent's branch.

## A session

One session means finishing your open PRs, then **at most two** new claims,
then stopping. Context that grows across many features makes later fixes
worse; the supervisor starts a fresh session for the next two.

1. **Start.** Set up your worktree and identity as `agent-team.md` describes.
   Read `CLAUDE.md` if the repo has one (otherwise the README and any
   architecture or contributing docs). Read the *Levels*, *States* and
   *Areas* sections of `docs/BACKLOG.md`, and
   `$AGENT_STATE/handoff.md` if it exists.
2. **Sync.** Run `git fetch origin`, then work detached on the base tip:
   `git switch --detach origin/<base>`. A named `<base>` branch cannot be
   checked out here because the owner's checkout holds it.
3. **Finish before starting.** Your PRs are the ones labelled
   `coder:<your-name>`: `scripts/agents/pr_lock.sh mine <your-name> coder`.
   Don't use `gh pr list --author @me`: every agent pushes as the same GitHub
   user, so it lists everyone's PRs. Then, if you hold fewer than two PRs,
   adopt **one** orphan: an open PR with no `coder:` label whose CI is red
   or whose review asks for changes (`scripts/agents/pr_lock.sh list`).
   Take it with `scripts/agents/pr_lock.sh take <N> <your-name> coder`; if
   that is refused, leave it. For each PR you hold:
   - failing CI or review comments → fix on the same branch, answer **all**
     comments in **one** commit, push, reply. While you iterate, keep the PR a
     draft, because CI skips drafts;
   - conflicts → rebase on `origin/<base>`, `git push --force-with-lease`;
   - merged → delete your local branch, `pr_lock.sh release <N> <your-name> coder`;
   - closed by the lead → the row went back to `ready` with the review in its
     *where to start*. Delete your branch, release the label, and do not
     reopen it.
   Never push to a PR labelled for another coder. Never push an empty commit
   to re-trigger CI.
   With **two** of your PRs open and waiting on review, claim nothing: write
   the handoff and end the session (`IDLE waiting on review of #A #B`).
4. **Pick, at your level.** In *Open*, take the first `ready` row at your
   level, preferring an area that no current `claimed …` row shares. A level
   in your prompt means **only** that level, never above or below. No level
   named means any level. You may take two or three rows together only if
   they are one change in the same files. If nothing is `ready`, stop
   (`IDLE no ready row at L<n>`); never invent work.
5. **Claim it on the base branch.** Change only those rows' state cell from
   `ready` to `` `claimed agent/<NN>-<slug>` ``, then
   ```bash
   git commit -m "Claim #NN (L<n>) for agent/<NN>-<slug>" -- docs/BACKLOG.md
   git push origin HEAD:<base>
   ```
   If the push is rejected, someone pushed first: run
   `git fetch && git rebase origin/<base>` and look at your rows again. If they
   are still yours, push. If someone took them, run
   `git reset --hard origin/<base>` and go back to step 4.
   Write the claim into the handoff now.
6. **Branch** from the claim: `git switch -c agent/<NN>-<slug>`, and push it
   early (`git push -u origin agent/<NN>-<slug>`) so the lead sees you. A
   claim with no push for 24 h is released.
7. **Read the evidence** before touching code: search `docs/evidence.md`
   (and the brief linked in *where to start*) for `#NN`. The diagnosis is
   done; do not re-derive it. If the code proves it wrong, say so in the PR
   rather than fix something else.
8. **Write the test first, and only quick-run it.** You run nothing heavy
   locally: no app server, renderer, build, typecheck or test suite. The
   machine's memory belongs to the PM, and CI is your test run. The one
   exception is your own new test file, through
   `scripts/agents/quick_test.sh tests/<your_test_file>`, which runs one file
   with capped memory and time. Use it before every push to catch typos,
   imports and wrong assertions; it saves a whole CI round. If it says "too
   heavy", leave that test to CI. Never run the test runner any other way.
   - Write a test that would fail on `<base>` and pass with your fix, and say
     in *Proof* why it fails without the fix.
   - Where the fix changes what the user sees, assert on the output itself,
     not on an internal flag.
   - Its docstring names the row and the run that found it.
   - **Instruments are proven on real data.** For a row that measures
     something, test it against the labelled real fixtures in
     `tests/fixtures/real/`, with a **negative case** that must read null. An
     instrument that passes synthetic tests can still read the wrong thing on
     every real input. Readings on full real inputs are the PM's to take; ask
     for them under *For the lead's next run*.
9. **Fix** with the smallest change that meets the *done when*, inside the
   row's area. Anything outside the area stays small and is named in the PR.
   - **Do not undo another pass.** If the code runs passes in a fixed order,
     with a hard rule last, a new pass must not run after the rule and break
     it.
   - **Stay inside the scope.** Change only the cases your row is about.
   - **Never remove a bound without adding a new one.** Use a larger ceiling
     for the case, not none.
   - **Never tune to one input.** A constant copied from the one example
     passes that example and breaks the others.
   - **Normalise, never derive.** When you accept a looser input shape, rename
     or relocate what the producer wrote; do not compute values it did not
     write.
   - **Harder than its level?** Push what you have, open a draft PR saying
     so, and stop; the lead re-levels it.
   - **Partial is fine; say so.** Title it `#NN (partial): …` and list what is
     left under *Found on the way*.
   - **Not a bug** is a real outcome. Open a PR (only a test, if that is all)
     saying why.
10. **Check by reading, plus the quick run.** `quick_test.sh` on your new
    test file must pass (or say "too heavy") before you push. Re-read the
    diff against the *done when*, the repo's import or layering rules, and
    the tests of the modules you touched (`git grep -l <module> tests/`)
    for anything your change breaks. Then let CI run them. When you remove
    or rename a function, `git grep` for its callers.
11. **Commit by path** (`git add <files>`; never `-A` or `.`; never
    `docs/BACKLOG.md` on an agent branch). The message is a plain sentence
    saying what now works ("Retry the upload when the token expires (#76)"),
    ending with the `Co-Authored-By` line the session gives you.
12. **Open the PR** with
    `gh pr create --base <base> --title "#NN: <what changed, plainly>"`
    and the body below, then label it yours:
    `scripts/agents/pr_lock.sh take <N> <your-name> coder`. Update the
    handoff. CI is your test run: before ending the session, look at
    `gh pr checks <N>`. If it is red, read the log (`gh run view --log-failed`),
    fix it and push. If it is still running, the next session's step 3 picks
    it up. For a second claim, go back to step 4. After two, end the session
    (`DONE #NN pr #A, #MM pr #B`).

## PR body: exactly this, every heading, in order

The lead reads the `Backlog:` line to set the row's state. Tool-generated
"Summary / Test plan" bodies are sent back unread.

```
Backlog: #NN (L<n>, claimed on agent/<NN>-<slug>)

## What was wrong
One or two sentences, with the number from the evidence.

## What changed
Files and the reason for each.

## Proof
The test(s), what they assert, before → after numbers.
Quick-run locally: <passed | too heavy>. CI runs the rest. Why the new test fails without the fix: …

## For the lead's next run
What to look for in a live run to close it.

## Found on the way
New problems, with evidence — the PM numbers them. "None" if none.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## What the owner's short prompts mean

| owner says | do |
|---|---|
| "you are a coding agent, load the prompt and start" | A session, as above. |
| a level ("L2", "work on L1 only") | Only rows at exactly that level. |
| "claim whatever you want" | No level restriction this session. |
| "keep 2 PRs" | The default: at most two open PRs per agent. |
| "spawn subagents" | Each subagent takes its own claim, branch and worktree; claims still go one at a time through the base push. Prefer separate supervised agents (`agent-team.md`), because subagents share your session's limit and context. |
| "continue" / "monitor and claim as you go" | Another session: sync, finish open PRs, then claim. |
| "report status" | A table: row, level, branch, PR, state (CI / review / merged), next step. No prose. |
| "don't start anything new, finish what you claimed" | Finish open PRs and claims only; claim nothing. |
| "release #NN" | A commit on the base branch setting only that row's state back to `ready` ("Release #NN …"); push it and stop work on its branch. |
| "everything merged?" | `scripts/agents/pr_lock.sh mine <you> coder` plus your merged PRs, answered with the table. |

## Rules

- In `docs/BACKLOG.md` you change **only the state cells of rows you claim**.
  Never edit `docs/evidence.md`. You update other docs (README, docstrings,
  runbooks) as your fix requires.
- **Number nothing**; new problems go under *Found on the way*.
- **No money, no live runs:** never call paid generation or production APIs
  for real, and never turn off an approval gate. Tests mock providers.
- Never push anything but a claim (or a release) to the base branch, never
  push to another agent's branch, and never merge.
- Secrets (`.env` and the like) hold live keys: never print, copy or commit
  them. Use the project's own environment (its virtualenv or package
  manager), not system interpreters.
- Docstrings explain **why**, and cite the run that found the problem.
