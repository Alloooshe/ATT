# Backlog — the only one

This is the single list of what is open. Everything else is evidence:
[`evidence.md`](evidence.md) holds the run-by-run findings (search it for
`#NN`).

**Who edits this file.** The **PM** (`team-pm` skill) runs live runs, numbers
findings, writes rows and their *done when*, and moves *Merged* rows to
*Closed* or back to `ready`. The **tech lead** (`team-tech-lead`) sets a row's
state while its PR is open (`pr #N …`), adds rows to *Merged* when it merges
them, and writes to the *Inbox*. A **coding agent** (`team-coding-agent`) makes
exactly one kind of edit here: it **claims** rows by changing their state from
`ready` to `claimed agent/<NN>-<slug>`, in a commit that touches nothing else.
See [`agent-team.md`](agent-team.md).

Branch: **`<base>`** (`TEAM_BASE`). It is the base of every agent branch and
the target of every PR. New rows continue from **#4**.

## Levels

Every row carries a **level**, so the owner can send different models to
different work. The PM sets it when numbering a row. A coding agent that is
told a level claims only rows at that level.

| level | what it takes | typical |
|---|---|---|
| **L1** | One file or two. The fix is named in *where to start*, and a unit test proves it. No judgement about output quality. | a prompt sentence, a missing guard, a config value, a test that should skip |
| **L2** | Logic in one area across a few files, following an existing pattern; tests on synthetic inputs. | a validation rule, a pass over the data model, a helper, an API field |
| **L3** | A new or changed **instrument** or core algorithm, or work that must be proven on the real fixtures in `tests/fixtures/real/`; the diagnosis may need revising. | a detector, a measurement, a renderer change, a cross-area refactor |

## States

| state | meaning | who sets it |
|---|---|---|
| `ready` | Diagnosed, has a "done when". Any coding agent may claim it. | PM |
| `claimed agent/<NN>-<slug>` | A coding agent is on it, on that branch. | the coding agent, on claiming |
| `pr #N` | A PR is open for it (may carry `(changes requested: …)`, `(on hold: PM — …)`, `(approved on <sha>)`). | tech lead, on seeing the PR |
| `merged` | On `<base>`, tests green, not yet checked in a live run. | tech lead, on merge |
| `closed` | Proven in a live run; moved to *Closed* with the proof. | PM |
| `parked` | Real, but not now (`parked (owner: …)` when it waits on a decision). Nobody claims it. | PM |

A claim with no push to its branch for 24 h goes back to `ready` (the tech lead releases it).

## Areas

Several coding agents may run at once. The *area* column says which files a row
touches, so two agents can avoid claiming rows that will conflict. Prefer a row
whose area no other open claim shares.

| area | files |
|---|---|
| **A — <area name>** | `src/<module>/`, … |
| **B — <area name>** | `src/<module>/`, … |
| **T — tests & CI** | `tests/` (helpers and fixtures), `.github/workflows/`, `scripts/ci/` |

## Open — in the order to take them

Owner directives that change the order go here, dated, above the table
(e.g. **Owner notes first**: rows labelled `owner note N` lead).

| # | area | level | state | gap | where to start | done when |
|---|---|---|---|---|---|---|
| **1** | A | L1 | `ready` | **Example row: what is wrong, in one bold sentence.** The evidence, with numbers, and the run that found it (`evidence.md` → run 1). | `src/<module>/<file>`: the function to change and the approach. | A named real artifact (a fixture, a stored output of run 1) and a number: e.g. `tests/fixtures/real/case1.json` → `validate()` returns 0 errors, and the negative case still reads 1. |
| **2** | B | L2 | `parked (owner: pick provider X or Y)` | **Example of a row waiting on the owner.** | … | … |
| **3** | T | L1 | `ready` | **Example test/CI row.** | … | … |

## Inbox — tech lead → PM

One line each: a PR's *Found on the way*, a done-when that the real data shows
is wrong, a row to re-level, or a question only a live run can answer. The PM
turns each into a row or answers it, then deletes the line.

- (empty)

## Merged — waiting for the PM's next live run

On `<base>`, tests green. The PM checks each in a run and moves it to *Closed*
or back to `ready` with the new evidence.

| # | what to look for in the run |
|---|---|

## Closed

Proven items and their proof. The PM adds rows here as items close.

| # | proven in | proof |
|---|---|---|
