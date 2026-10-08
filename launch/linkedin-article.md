# What running a team of AI agents taught me about managing a team

For nine days, my "engineering team" was a set of AI agents running on my own computer: a product manager, three tech leads and up to five developers. Together they filed about 430 tasks on a real, private project and merged 344 of them, at a median of 1.3 hours from "I'll take this" to "merged".

I expected the hard part to be the AI. It wasn't. The hard part was the same thing that's hard with human teams: **coordination**. And the fixes looked a lot like good management.

## 1. Clear ownership beats clever collaboration

My first instinct was to let agents "talk to each other". It was chaos. What worked was the opposite: each role owns one thing, and owns it completely. The PM writes the tasks and defines "done". Developers only claim and fix. Leads only review and merge. Nobody edits anybody else's part.

*Management takeaway:* ambiguity about who decides costs more than any skill gap.

## 2. "Done" has to be checkable by someone who wasn't there

Every task carries a "done when" that names something concrete and a number. A reviewer who never saw the original problem can still say yes or no. Tasks without that came back again and again.

*Management takeaway:* if two people can disagree about whether it's done, it isn't specified.

## 3. Short, focused work with good handoffs

Agents that worked for hours in one session got sloppier. Agents that did one unit of work, wrote a handoff note, and stopped stayed sharp — the next session picked up the note with a fresh head.

*Management takeaway:* handoff notes are cheap; context overload is expensive.

## 4. Trust, but verify the thing that actually shipped

The leads learned that "tests are green" can lie — a skipped test reads as green, too. So nothing merges unless the exact version that was reviewed is the version that passed. Out of 344 merges, only 2 had to be reverted.

*Management takeaway:* review the thing that ships, not the description of it.

## 5. Turn mistakes into rules

Every time something went wrong, the agent responsible added a numbered "lesson" to a shared file, which every future session reads. After nine days there were 83 of them.

*Management takeaway:* a blameless post-mortem only helps if someone reads it next time.

---

I've open-sourced the whole setup as **ATT (Agent Team Template)**, so anyone using Claude Code can run the same team locally on their own project: https://github.com/Alloooshe/ATT

A note on honesty: this is one project and one person's experience, not a controlled study, and the write-up says so. But if you're thinking about where AI agents fit in your engineering org, the lesson I'd take away is this: **the agents are ready for structure. Give them some.**
