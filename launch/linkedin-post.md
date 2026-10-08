I ran a full team of AI coding agents on my own machine for 9 days. 🧑‍💻🤖

Not one agent fixing one issue — a team:
📋 a PM agent that tests the product and writes the backlog
👩‍💻 coding agents that claim tasks, write a failing test, and open PRs
🔍 tech-lead agents that review every PR and merge it safely
🧑‍✈️ an agent manager I talk to from my phone

All Claude Code. All local — no hosted orchestrator.

The results on a real, private project:
✅ ~430 tasks filed, 344 merged
⏱️ median 1.3 hours from "claimed" to "merged"
🚂 21 merge trains (up to 37 PRs in one CI run)
↩️ only 2 reverts on the shared branch

What made it work wasn't smarter agents. It was a boring protocol:
• a claim is a git commit — two agents can't take the same task
• PR ownership is a GitHub label
• merges only happen on the exact commit that was reviewed
• short sessions with notes on disk, instead of one giant context
• every failure becomes a written "lesson" the next session reads

I've open-sourced it as ATT — Agent Team Template, with a write-up of the results (one project, so a field study, not a benchmark — the paper is upfront about that).

⭐ https://github.com/Alloooshe/ATT

Would love to hear where it breaks on your codebase.

#AI #AIAgents #ClaudeCode #SoftwareEngineering #DevTools #OpenSource #LLM
