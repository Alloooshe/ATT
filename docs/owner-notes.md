# Owner notes — the standing checklist, decisions and requests

Every note the owner has given on the product's output, in their words, with
what "fixed" looks like **in the output of a live run**. The PM judges every
run against this checklist **first**, pass or fail per note with the evidence
that proves it. Every report to the owner opens with that table, before any
other score. A note is done only when a run shows it fixed. Filing, merging or
passing a unit test is not enough (PM Lesson 16).

**Adding a note.** As soon as the owner gives one: take the next number (never
renumber), the date, the owner's words verbatim, the output test, and the rows
that fix it (file them if there are none). The state is `open`. A repeat adds
its date to the same note. Repeats are the signal that a fix did not land.
Rows that fix a note say `owner note N` and sit at the top of *Open* in
[`BACKLOG.md`](BACKLOG.md); the tech leads review those PRs first.

## Output checklist

| # | given (repeats) | the owner's words | fixed looks like, in the output | rows | state |
|---|---|---|---|---|---|
| **1** | YYYY-MM-DD (run N) | "…verbatim…" | A check someone else can run on a run's output, with a number. | #NN | open — last run judged: … |

## Decisions

Dated owner decisions that every agent must respect: what is in or out of
scope, which inputs may or may not be used (privacy), which providers and
models, spending limits.

- YYYY-MM-DD — …

## Requests

Open requests from the owner that are not output notes: tooling, process,
reports.

- YYYY-MM-DD — …
