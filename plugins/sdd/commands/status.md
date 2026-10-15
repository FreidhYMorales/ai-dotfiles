---
description: Show structured SDD status for a change (read-only)
argument-hint: "[change-name]"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Change name: $ARGUMENTS

TASK (read-only: launch no executors, edit nothing, mark no tasks):
1. Require the session preflight (at least the artifact store). If missing, ask the preflight and STOP.
2. Resolve the change: use `$ARGUMENTS` if given; else select the single active change and say how; if ambiguous, ask and STOP.
3. Build status per `sdd-status-contract.md` from the selected store (do not hardcode Engram) and return: change selection, artifact statuses with paths/topics, task progress with unchecked tasks, dependency states, latest verify verdict, `actionContext`, `nextRecommended`, and `blockedReasons`.
4. If status cannot be resolved safely, return `status: blocked` with the missing information.
