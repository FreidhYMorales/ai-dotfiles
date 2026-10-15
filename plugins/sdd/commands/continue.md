---
description: Continue the next SDD phase in the dependency chain
argument-hint: "[change-name]"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Change name: $ARGUMENTS

WORKFLOW:
1. Build structured status per the orchestrator's status contract (manual, from the active artifact store). If no change name is given and more than one change is active, ask the user to choose and STOP.
2. Determine the next phase from the dependency graph: proposal → [spec ∥ design] → tasks → apply → verify → archive.
3. Launch the matching `sdd:sdd-<phase>` agent(s) only when status says that dependency is ready. Planning tokens (`propose`, `spec`, `design`, `tasks`) launch that phase. If `blockedReasons` is non-empty, report them and STOP. Before apply, run the Review Workload Guard.
4. Carry `actionContext` and allowed edit roots into the launch, present the result, and ask whether to proceed (interactive) or continue (auto).
