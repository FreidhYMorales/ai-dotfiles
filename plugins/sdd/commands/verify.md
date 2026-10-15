---
description: Validate implementation against specs, design, and tasks with real test runs
argument-hint: "[change-name]"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Change name: $ARGUMENTS

STATUS GATE:
Build structured status first. If the change is missing or ambiguous, ask and STOP. Continue only when every task is complete.

TASK:
Launch `sdd:sdd-verify` with change name, artifact store mode, structured status, and the Strict TDD line. It runs tests and build, builds the spec compliance matrix, and persists `sdd/{change-name}/verify-report` (persisted even when the verdict is FAIL).

Present the verdict. PASS / PASS WITH WARNINGS → suggest `/sdd:archive`. FAIL → list CRITICAL issues and suggest `/sdd:apply` to fix them, then `/sdd:verify` again. Verification never launches reviews or fix loops by itself.
