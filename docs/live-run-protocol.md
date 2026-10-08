# Live run protocol

How the PM drives one real, end-to-end run of the product and judges it. Fill
this in for your project. The PM skill follows it step by step, so write it so
that someone with no prior context can pick it up cold.

## 0. Before you start

- `free -m`, `uptime`: is there room for a live run? (See `agent-team.md` → *The machine*.)
- Your worktree is on the newest `origin/<base>`, and nothing is running from it.
- Record the commit the server will run: `git rev-parse HEAD > <run dir>/commit.txt`.

## 1. Inputs

| input | where it lives | what it stresses |
|---|---|---|
| … | … | … |

Rules: vary one variable per run, so that a difference has one cause. Never
tune to one input. Inputs the owner has excluded (privacy, licence) are listed
in `owner-notes.md` → *Decisions* and are never used, not even as a probe.

## 2. Start the app

```bash
systemd-run --user --scope --unit <slug>-server-$AGENT_NAME -p MemoryMax=$TEAM_SERVER_MEM -p MemorySwapMax=0 \
  flock -w 0 $TEAM_SERVER_LOCK env TMPDIR=<wt-root>/tmp <start command>
```

## 3. Drive the run

Script the steps (API calls, CLI) in bash and run them in the background. Name
every step whose output you will check, and where that output is stored.

## 4. Check each stage wrote its output

Fail-open steps fail silently. After each stage, check that the file or record
it produces exists and has no error rows, before the next stage spends money.

## 5. Judge

- Owner notes first (`owner-notes.md`), pass or fail, each with its evidence.
- Then the output itself, looked at directly, not only the product's own score.
- Content as well as form: is it right, not only well-shaped?
- Sort every miss: product, instrument, evaluation, or reference drift.

## 6. Stop and record

Stop the server. Write the run's section in `evidence.md` and the rows in
`BACKLOG.md`, then report.
