# Tech lead — lessons

Each lesson cost a CI round, a merge or a run. Add new ones here, numbered,
with the date and the PR or run that taught it. `SKILL.md` repeats only the
most expensive. These are seeded from earlier use of this setup; the numbers
are kept stable so that the skill can cite them.

## Reviewing PRs

1. **The output of a live run is the PM's to measure, not yours.** You review
   the diff, the PR's own tests and CI. What a change does to a real run comes
   to you as the PM's numbers. Do not run the product end to end, replay a
   run, or render to settle a review.
   - For a done-when that only a live run can settle, say so in the PR and put
     one Inbox line to the PM naming the artifact or number you need. The PR
     waits.
   - What you can still check is everything that is not a live run: the diff,
     a unit test, a constant against the asset it describes, a stored input
     run through the PR's function.
   - Cloud agents may lack the real fixtures or toolchains, so some tests
     skip there. Closing that gap is the **agent's** job (require the test and
     the numbers in the PR), or the PM's job to answer.
2. **Check the done-when against stored artifacts.** Specs, logs, stored
   outputs and configs on disk are yours to read. Run a refused input through
   the PR's validator, re-run a check on a run's stored output rather than a
   fresh measurement, and read the stored logs to say what the PR would change.
3. **Check the path, not the function.** A fix to a function that only the UI
   calls does nothing for the path the agent or the job actually takes. The
   run's logs show which path ran.
4. **Never let a fix tune itself to one input.** Ask for a structural method,
   plus one test on a different input (another language, another size,
   another provider).
5. **When a fix has no clean outcome, check what it falls back to.** A
   correct prediction with a bad fallback (leave it as is, silently) is still
   a bug.
6. **Overlapping PRs.** Check the order with
   `git merge-tree --write-tree --name-only origin/<a> origin/<b>`. After a
   rebase, grep that the lines merged earlier survived.

15. **Green CI does not mean the tests ran.** A CI job that never installed a
    toolchain skips every test that needs it, and reads green. Make CI
    **fail** a test whose toolchain is missing (under `CI=true`). Check the
    run's skip list (`-rs`) and the durations for the test you rely on.

20. **A free review lock does not mean an undecided PR.** Another lead may
    have approved it, queued its automerge and released the lock. Before
    taking a PR, look for an `automerge-pr<N>` unit
    (`systemctl --user list-units 'automerge*'`) and an `approved` row cell.
    If either exists, the PR is decided; a finding after that goes to the
    deciding lead by message. Never stop their job yourself.
21. **A scratch worktree's tests may import the main checkout.** A linked
    virtualenv's editable install resolves the package to the main checkout,
    so the tests run the **wrong code**. Run with `PYTHONPATH=<scratch dir>`
    (or the language's equivalent), and confirm which file was imported.
56. **A rule that moves or rewrites something moves both ways.** Before
    approving, read one stored case from the run that motivated it, and test
    the side the PR's tests skip.

23. **Run the PR's new test against the base's code, not only its own.** A
    done-when test that passes on `<base>` proves nothing. In the scratch
    worktree, run the file on the head, then
    `git checkout origin/<base> -- <src dir>` and run it again: the done-when
    test must fail there. Then `git reset --hard HEAD`.
26. **Test a PR on top of the approved PRs queued ahead of it.** When an
    approved PR changes an operation's semantics, `git merge` it into the
    scratch worktree and run the file again.
27. **A linked `.env` hides env-dependent regressions.** When a PR changes
    how an environment variable is read, test with no `.env` link and set
    exactly the variables the row names.
31. **One scratch worktree per running test.** Checking out another commit
    under a running test makes its results worthless. And never stop your own
    run with `pkill -f '<pattern>'`: the pattern is also in your shell's
    command line, so it kills the shell. Find the PID and `kill` it.
32. **A signal or parsing rule tested on synthetic data: run it on the row's
    own real input** before approving. Synthetic data is cleaner than the real
    thing.
35. **A model-settings change: probe the endpoint once.** When a PR changes
    what reaches a model (parameters, reasoning, caps, provider), make one
    cheap real call with the PR's settings, and require a test that the caller
    actually passes them.
36. **A PR that removes or renames a helper: grep for its callers on the
    head** (`git grep <name> <head>`), and run the test files of every caller.
43. **A lockfile PR: diff the package versions, not just the names the row
    names.** Re-resolving from scratch can move dozens of pins (including the
    agent runtime itself). Compare `{name: version}` maps and prefer a minimal
    re-lock.
44. **A new refusal breaks other tests' setups.** When a PR adds an error for
    a state, grep `tests/` for code that builds that state and run those
    files. Fix an old test by writing the state directly, not by dropping
    the rule.
46. **A rule about what the agent may do goes on the agent's path.** Placed
    in the shared write path, it also refuses the human using the UI.
52. **A fallback promoted to the default inherits the defects it was allowed.**
    When a PR turns a fallback into the normal path, read what the fallback
    gave up, and require a test that the normal path no longer gives it up.

## Merging

7. **Guarded merge only.** CI passes **and** the head is the one you reviewed
   (`--match-head-commit <full sha>`); `scripts/lead/automerge.sh` does both.
   Delete the branch and update the backlog **only after the PR reads
   MERGED**. A refused merge followed by a branch delete closes the PR
   unmerged.
8. **One writer per checkout.** Check `git status -sb` before any commit.
   Never edit a script that a background job is running: bash reads it as it
   goes. Copy it, or restart the job.
9. **Do not run the test suite locally.** PR CI runs what the change reaches,
   and a push to `<base>` runs everything. Locally, run one failing file. If
   the base run is red, revert the merge first, then diagnose on the PR's
   branch alone.
18. **The guarded merge pins the head it sees when it starts.** Coders may
    force-push the same code again. Before merging a new head, compare its
    diff with the reviewed commit's (`git diff --quiet <reviewed> <new>`),
    and restart the job only if they are equal.
22. **`automerge.sh` resets the checkout it runs in.** Give the jobs their
    own worktree (`<wt-root>/<name>-merge`, detached on the base, signed,
    linked) and start them there by absolute path. Never wrap `base.sh` in
    another `flock` on the base lock, or it deadlocks.
28. **Merge in batches; CI time is the team's bottleneck.**
    - Batch: start several approved, green PRs' automerge jobs together.
      Pushes to the base should not cancel each other's runs in progress, so
      the newest waiting run covers the batch.
    - No catch-up runs: ask for a rebase only on a real conflict
      (`git merge-tree`).
    - Review while CI runs, and queue the automerge at once.
    - One push per review round, with the PR kept a draft while iterating.
    - Batched merges race ("Base branch was modified"); `automerge.sh` retries.
      Re-run a dropped run with `gh run rerun <id> --failed` rather than an
      empty commit.
29. **Merge in trains: one CI run for many PRs.** Approved PRs stay drafts,
    with "approved on <sha>" recorded. The lead who proposes the train owns
    it; the other answers "ok". If CI goes red, drop the culprit and merge
    the rest. When cancelling runs, filter by PR, not by status. After each
    train, tell the agent manager what merged and how many CI rounds it used.
34. **Merge the base into the train last, so its backlog is the newest.**
    Otherwise the train's `docs/BACKLOG.md` reads as a revert of every row
    written since. Confirm `git merge-tree --write-tree --name-only
    origin/<base> HEAD` lists no file.
37. **When the PM offers a pre-flight replay of a train on a real run's
    inputs, hold the merge until it reports.** A unit test on synthetic data
    proves the function, not the path.
42. **Re-run an approved PR's neighbours after each train merges ahead of
    it.** Run the tests that newer merges added for the same files.
45. **A cancelled run on the same head is not a failure, and neither are a
    re-triggered run's leftovers.** `automerge.sh` reads only
    the newest workflow run. A job that ends `CI FAIL` within a minute of its
    start is the rollup, not the PR: read the rollup first.
49. **A draft's checks read SKIPPED.** A merge job started on a draft could
    merge with no test run. `automerge.sh` refuses drafts and requires one
    real `SUCCESS`; mark the PR ready first and wait until the test job shows
    as queued.
50. **Run the PR's own test file on its head merged with the base.** CI tests
    the merge commit, not the head.
51. **With several merge bases, GitHub may see a conflict that `merge-tree`
    does not.** When `git merge-base --all` prints more than one commit,
    check each one. If only `docs/BACKLOG.md` conflicts, merge the base in
    yourself and take its file.
53. **A PR run keeps the workflow of its merge commit; re-trigger it, don't
    re-run it.** To pick up a CI fix on the base, run
    `gh pr ready <N> --undo && gh pr ready <N>`, which builds a new merge
    commit.
55. **A CONFLICTING PR starts no CI run.** Read `mergeable` before a
    re-trigger.

## Running the product (the PM's job, not yours)

10. **You do not render or run to review.** If you are about to run the
    product to settle a PR, write the Inbox line instead.
11. **If the owner asks you directly for a run**, use the heavy lock and a
    memory scope, as `agent-team.md` describes, so it never collides with the
    PM's live run.
12. **Spend only to prove a done-when.** One small paid call is fine;
    anything larger goes to the owner first.
24. **Do not queue a review test behind the PM's live run.** If `lsof` on the
    heavy lock names a live run, decide what the diff alone settles, write the
    rest into the PR comment and the handoff, and move on.
39. **No local heavy tests while the PM's server is up**
    (`systemctl --user is-active <slug>-server-<pm>.scope`). Let CI test,
    review on the diff, and wait. Afterwards, look for orphaned processes.

## Team

13. **Sign your worktree** (see `agent-team.md`). With every session
    committing as the owner, a lead can read other sessions' merges as its
    own.
14. **One lead per PR.** With more than one lead, take
    `scripts/agents/pr_lock.sh` before reading a PR.
40. **One lead under usage limits.** When the team is cut down, the remaining
    lead owns every train, including one another lead built. Watch its guarded
    merge job; never restart it.

## CI and runners

17. **A runner that drops mid-job may be a PR, not the host.** Look for a PR
    whose run stalled (no test output for minutes) and run its test file under
    a memory cap: exit 137 is the answer. Scan new loops for an index that
    never advances.
19. **A failure on one platform is the host until the same test fails on
    another.** Run the failing file on the PR's branch locally first. If it
    passes, fix the test or the CI environment, never the PR.
25. **Every runner dropping in the same second is the host.** Check the
    runners (`gh api repos/{owner}/{repo}/actions/runners`), re-run the failed
    jobs, restart each automerge on the unchanged head, and tell the owner.
41. **A runner that gets its label back may not take jobs already queued.**
    When a job sits `queued` while a matching runner is idle, restart that
    runner (never while it is busy).
47. **A new runner pool: read the base's own run before calling a PR red.**
    Test names that fail on the base too are the host's problem, not the PR's.
48. **A parallel test run can hang on one test.** Wrap long runs in a stall
    check (no new output for a few minutes), then run the in-flight test
    alone before blaming the PR.

## Reporting

16. The owner often reads on a phone. Send files rather than describe them,
    keep reports to a table, and give one coding-agent prompt per level when
    asked.
