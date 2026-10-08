# PM — lessons

Each lesson cost a run. Add new ones here, numbered, with the date and the run
that taught it. `SKILL.md` repeats only the most expensive. These are seeded
from earlier use of this setup; the numbers are kept stable so that the skill
can cite them. Project-specific facts (where inputs live, which are excluded,
house settings) go in `docs/live-run-protocol.md` and `docs/owner-notes.md`,
not here.

## Running

1. **Run with the product's real settings.** Never turn off a feature just to
   make a run cheaper or easier, and never override the house configuration
   for one run. A run that differs from what a user gets proves nothing about
   what a user gets. If you compare against a reference, say which one and
   why, and record any owner decision about references in `owner-notes.md`.
2. **Vary the inputs, not the reference.** Change one variable per run, so
   that a difference has one cause. Keep a list of the inputs on disk, with
   what each one stresses, in `live-run-protocol.md`. Prefer real inputs over
   synthetic ones, and inputs the product has not been tuned on. Name each
   input's source.
3. **Know your judging material.** Keep human-made examples of good output
   (to judge against, not to copy) listed in `live-run-protocol.md`, with what
   each shows. Inputs the owner has excluded are never used, not even as a
   probe.
4. **Mind memory.** Run the server in its named scope
   (`<slug>-server-$AGENT_NAME`, `MemoryMax=$TEAM_SERVER_MEM`). The named
   scope is how `team.sh kill` finds and stops it. Check `free` and `uptime`
   first, stop the server after the run, and restart it after merges, because
   it keeps the code it started with. A server that outlives its session keeps
   working beside everyone else, and can freeze the machine.
5. **Temp on the home disk.** A shared `/tmp` tmpfs fills up and breaks
   renders and streams at once. Run the server with `TMPDIR=<wt-root>/tmp`.
6. **Script the run in bash**: each stage, then a check that its output
   exists, then the next stage, in the background. If the product refuses an
   input, read the refusal, repair only from measured values, call it a hand
   repair, and file the cause as a row.

## Judging

7. **The product's own score is not the truth.** Scores and automated
   comparisons vary between runs and cannot see everything. The owner may
   prefer a run with a lower score. A direct look at the output decides: a
   sheet of the output at the same scale as the reference, plus close-ups
   where it matters.
8. **"Works in a test" ≠ "works live."** A merged fix that does not show in
   the output is filed against the path it missed, not against the function.
9. **Judge the content, not only the form.** Ask whether the output is right,
   not only well-shaped: is this the right moment and the right form for what
   is meant, and is anything said twice?
10. **Keep a list of what the owner keeps asking for**, in `owner-notes.md`,
    and look for each item in every run.

## Writing rows

11. **A row is ready when someone else can prove it.** Its *done when* names a
    real artifact (a fixture, a stored output of a run, a replayable input)
    and a number. Its level follows *Levels*, and nothing in it is tuned to a
    single input: say what must hold on other inputs. The tech lead holds PRs
    to exactly this text.

## Answering the tech lead

12. **The output is yours to measure.** A done-when that only a live run can
    settle reaches you as an Inbox line, and its PR waits. Measure it once the
    PR's code-level defects are fixed, on the PR's branch in a worktree of
    your own or in your next live run, and answer on the Inbox line with
    numbers.

## Reporting

13. **Run log.** Every run gets one record in a run log (a table in
    `evidence.md`, or a shared page) with these fields: order, run, inputs,
    date, commit, cost, verdict (running | pass | fail | warn), score, and
    findings. Write `running` at the start, then the verdict. Keep every field
    brief.
14. The owner often reads on a phone. Send the output and the judging sheet as
    files, and keep the report a table with numbers.

## Judging (2)

15. **Read what the evaluation measured on the reference before reading its
    verdict.** An instrument that half-reads the reference gives the product
    wrong targets. A gap the instrument cannot measure on the reference is an
    instrument row, not a product gap.

## Owner notes

16. **An owner note is done only when a run shows it fixed in the output.**
    Filing a row, merging it, or a green score is not the fix. Every note
    lives in `docs/owner-notes.md` with its output test. Judge every run
    against that checklist first, and open every report with it. Rows that fix
    a note carry `owner note N` and lead *Open*. A note given twice means the
    first fix did not land; say so in the report.
17. **A thinner reference makes a thinner output.** If the product follows
    what was measured on a reference, a reference the instrument half-reads
    asks for less. Compare the reference's measurements with the last good
    run's before blaming the model or the code, and keep the house floor under
    them.

## Running (2)

18. **Never sync the worktree a server runs from.** A server that imports
    lazily mixes two commits in one run. Push docs from a second worktree
    while a run is live, and record the server's commit in the run's files.
19. **Fail-open stages fail silently: check that each wrote its output before
    the next stage.** After each stage, check that its files exist, that its
    logs have no `ok: false` rows, and which provider actually served it.

## Pre-flight

20. **A pre-flight is green only on the input the run's own model will
    produce.** Replaying another run's intermediate output proves the fix for
    that output, not for this one. Replay on the newest output from the
    configuration that will actually run, and keep a hold between stages.
21. **Replay a run's own recorded steps before spending a run on a fix.** If
    the product logs its operations, replaying them through the real handlers
    on a PR's head (no server, no spend) shows in minutes what a full run
    shows in an hour. A replay proves the logic, not the output: the first
    real output of a new feature still needs a look.
22. **The product's self-correction obeys its own evaluation, and the
    evaluation does not know the house rules.** If an automated pass "fixes"
    output against a score, it can undo a house rule. Until the evaluation
    knows the rule, a run that rests on it says so explicitly in its
    instructions, and you read the final state, not only the first.
23. **At the hold between stages, read the intermediate lists as well as the
    numbers.** A wrong plan is cheaper to fix before the expensive stage than
    after it.
24. **Rows merged together are proven on each other's output.** Before a go,
    replay each new consumer on what its new producer writes, not on an older
    producer's output.
25. **A fix's own score is not an output test.** A fix that reports success by
    its own measure can still fail when looked at directly. A quality fix, and
    any stopgap built on it, is green only when its real output has been
    measured independently and looked at.

## The gate

26. **Know which clock or baseline an instrument reads before reopening a
    row.** Name the reference point in every number, and ask the lead for the
    stored value before calling a merged fix dead. Measure what the consumer
    actually receives, not the source file.
27. **An unattended run finds what a hand-held run hid.** Anything shipped
    from a past run's files (a default, a sample, a fixture) is checked for
    that run's private or one-off settings before it ships.
