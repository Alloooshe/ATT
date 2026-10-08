# I ran a team of AI coding agents on my own machine for nine days. 344 merged tasks later, here's what actually made it work.

*A PM, three tech leads and up to five coders — all Claude Code agents, all local. The trick wasn't smarter agents. It was a boring protocol.*

---

Everyone has seen the demo: one AI agent, one GitHub issue, one pull request. It's impressive. It's also not how software gets built.

Real product work looks different. Someone has to *notice* what's wrong and write it down so it can be checked. Five fixes are in flight at once, all against the same branch. Someone other than the author has to review each one. And all of it runs on hardware with finite memory and a CI queue that's always longer than you'd like.

So I tried something: instead of one agent, a **team** — with roles, a backlog, code review and merge discipline — running entirely on my own machine. Over nine days on a private project it filed about **430 tasks** and merged **344** of them, with a median of **1.3 hours from "I'll take this" to "merged"**.

I've open-sourced the setup as **ATT — Agent Team Template**: https://github.com/Alloooshe/ATT

Here's what I learned.

## The team

| Role | Does | Never does |
|---|---|---|
| 📋 **PM** | runs the product end-to-end, judges the output, writes backlog rows with a "done when" | reviews or merges code |
| 👩‍💻 **Coding agents** | claim a row, write a failing test, fix it, open a PR | merge, write rows |
| 🔍 **Tech leads** | review each PR against its "done when", merge it safely, keep CI green | run the product |
| 🧑‍✈️ **Agent manager** | the one I talk to — starts/stops the team, reports, relays my decisions | the agents' work |

Every one of them is a Claude Code session. None of them share a conversation. **They coordinate only through the repository.**

## Lesson 1: coordinate through files, not chat

Multi-agent frameworks usually put agents in one big conversation. That falls apart fast: context fills up, agents talk past each other, nobody knows who owns what.

ATT's whole protocol is things a developer already has:

- **One backlog file.** Each part has exactly one writer. The PM writes rows. Coders change one cell — `ready` → `claimed`. Leads mark rows merged.
- **A claim is a git commit.** Two agents grabbing the same task is a push race. One push gets rejected; that agent picks another row. Mutual exclusion, for free, from git.
- **PR ownership is a GitHub label.** `review:tech-lead-2` means hands off. Labels expire, so a crashed agent doesn't hold a PR forever.
- **Locks are files.** One for pushing to the shared branch, one for heavy work, one for the app server.

Boring? Extremely. That's the point. Every decision is a commit, so the whole team's history is `git log`.

## Lesson 2: short sessions beat long ones

My first coding agent ran in one long session, fixing task after task. It got worse as it went — later fixes were sloppier, it forgot rules from the start.

Now every agent runs as a **chain of short, fresh sessions**. A coder finishes its open PRs, claims at most two new tasks, writes a handoff note, prints `DONE`, and exits. A supervisor script starts the next session with a clean context.

The supervisor also handles the annoying part: when the account hits its usage limit, it waits for the reset and **resumes the same session**, so half-finished work finishes with its context intact.

## Lesson 3: never trust "CI is green"

The tech leads taught me this one the hard way. Things that read as "pass" in GitHub but weren't:

- A **draft** PR's checks are all *skipped* — and an all-skipped rollup looked green.
- A CI job that **never installed** a toolchain skipped every test that needed it. Green.
- A **re-triggered** run still carried the old run's cancelled jobs. Red, falsely.

So merges are **guarded**: a background job merges only when CI is green *on the exact commit the lead reviewed*, requires at least one real success, and deletes the branch only after GitHub says `MERGED`. Out of 344 merges, the shared branch needed **two** reverts.

## Lesson 4: it's local-first, and that matters

ATT runs on your machine. Agents are `systemd` user units. Each gets its own git worktree. CI runs on your own runners. There's no hosted orchestrator, no dashboard you have to trust — you can `ls` the state directory, `tail` a log, or kill an agent with one command.

Local also means **finite**. On a 14 GB machine, three coders' test runs, a leftover app server and a test of the supervisor itself, all at once, froze it solid. The fix became a rule: *the memory belongs to the PM.* Coders run only a tiny capped test on their own new test file (512 MB, two minutes). CI is their real test run.

## Lesson 5: write the failures down

Each role has a `lessons.md`. When something costs a run, the agent adds a numbered, dated rule. After nine days: **56 lessons for the tech leads, 27 for the PM.**

They read like a field manual: *"Check the path, not the function."* *"A fix's own score is not a test."* *"Merge the base branch into the train last."* Every new session reads them. The team literally gets better without retraining anything.

## The numbers (honestly)

From the project's git history over nine days:

- **~430** backlog rows filed by the PM agent
- **365** rows claimed by coding agents, **344 merged** (94%)
- **1.3 h** median claim → merge (66% within 2 h, 91% within 8 h)
- Difficulty barely mattered: 1.2 h for the easiest tasks, 1.4 h for the hardest — the bottleneck was CI and review, not coding
- **21 merge trains** (one CI run for up to 37 PRs) carried 177 of the merges
- **2** reverts on the shared branch

Two caveats I want to be upfront about. This is **one project, one owner, nine days** — a field study, not a controlled benchmark. And "merged" means tests passed and a lead approved it; it doesn't prove every fix was right. I've written all of this up, including a proposed proper benchmark, in a paper (link in the repo).

## Try it

```bash
git clone https://github.com/Alloooshe/ATT.git
cp -r ATT/{.claude,docs,scripts,agent-team.env.example} your-project/
cd your-project && cp agent-team.env.example .agent-team.env   # edit it
scripts/agents/start_team.sh
```

Then open Claude Code and say *"manage the agents."*

If it helps you, a ⭐ on GitHub goes a long way: **https://github.com/Alloooshe/ATT**

*I'd love to hear how it breaks on your project — that's how the lessons file grows.*
