---
description: Archive a verified SDD change — syncs delta specs and closes the cycle
argument-hint: "[change-name]"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Change name: $ARGUMENTS

STATUS GATE:
Build structured status first. If the change is missing or ambiguous, ask and STOP. Continue only when every task is checked and the latest `verify-report` is PASS or PASS WITH WARNINGS with zero CRITICAL issues (no override for CRITICAL). Unchecked tasks go back to `/sdd:apply` unless apply-progress/verify-report prove they are stale checkboxes and the user explicitly asks for reconciliation. `workspace-planning` context: STOP.

TASK:
Launch `sdd:sdd-archive` with change name, artifact store mode, structured status, and explicit final-state facts for anything completed after apply-progress/verify-report were written. It syncs delta specs into `openspec/specs/` (openspec/hybrid), moves the change to `openspec/changes/archive/YYYY-MM-DD-<change>/` with shell-only copies verified by `diff -r`, and persists `sdd/{change-name}/archive-report` with all observation IDs.

Present the archive summary.
