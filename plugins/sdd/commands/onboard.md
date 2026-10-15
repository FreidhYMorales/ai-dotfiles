---
description: Guided SDD walkthrough on the real codebase, from exploration to archive
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
TASK:
Launch `sdd:sdd-onboard` to guide the user through a complete SDD cycle on a small, real improvement in this codebase: explore, propose, spec, design, tasks, apply, verify, archive. It teaches by doing, produces real artifacts, asks before continuing past the proposal, and saves progress as `sdd-onboard/{project}` so the walkthrough is resumable.
