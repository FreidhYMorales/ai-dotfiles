---
description: Implement SDD tasks — writes code following specs and design
argument-hint: "[change-name] [task range]"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Change name / tasks: $ARGUMENTS

STATUS GATE:
Build structured status first. If the change is missing or ambiguous, ask and STOP. Continue only when `applyState: ready`, spec/design/tasks exist, and `actionContext` allows edits. Run the Review Workload Guard and resolve `delivery_strategy`/`chain_strategy`/`size:exception` before launching.

TASK:
Launch `sdd:sdd-apply` with: change name, assigned tasks (or "next pending batch"), artifact store mode, structured status, resolved delivery decision, the Strict TDD line from the orchestrator (enabled unless capabilities say otherwise), and the apply-progress continuity instruction when prior progress exists. The agent implements, marks tasks `[x]` in the persisted tasks artifact, and merges `sdd/{change-name}/apply-progress`.

Present files changed, TDD evidence, deviations, remaining tasks, and next step (`/sdd:apply` again or `/sdd:verify`).
