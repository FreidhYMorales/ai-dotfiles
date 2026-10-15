---
description: Initialize SDD context — detect stack, testing capabilities and Strict TDD, bootstrap persistence
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
TASK:
Launch `sdd:sdd-init` (Agent tool, model per the orchestrator table) to initialize Spec-Driven Development in this project: detect the tech stack, conventions, architecture, test runner, test layers and quality tools; resolve Strict TDD (enabled by default when a test runner exists); bootstrap the resolved artifact store; and persist `sdd-init/{project}` and `sdd/{project}/testing-capabilities` (topic_key upserts, `capture_prompt: false`).

Report the result envelope to the user: stack, persistence mode, Strict TDD status, testing capabilities, artifacts, and next step (`/sdd:explore` or `/sdd:new`).
