---
description: Explore an idea or feature — reads the codebase and compares approaches
argument-hint: "<topic>"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Topic: $ARGUMENTS

TASK:
Launch `sdd:sdd-explore` to investigate "$ARGUMENTS": current state, affected areas, approaches with tradeoffs, and a recommendation. Exploration only: no code changes. The agent persists `sdd/{change-name}/explore` (or `sdd/explore/{topic-slug}` when standalone) per the artifact store.

Present the executive summary and recommendation, then suggest `/sdd:new <change>` when the idea should become a change.
