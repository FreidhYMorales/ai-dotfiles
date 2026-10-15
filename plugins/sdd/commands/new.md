---
description: Start a new SDD change — runs exploration then creates a proposal
argument-hint: "<change-name> [description or plan path]"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Change name and seed: $ARGUMENTS

WORKFLOW:
1. Launch `sdd:sdd-explore` for this change; present the exploration summary.
2. Launch `sdd:sdd-propose` with the exploration reference (interactive mode: offer the proposal question round first).
3. Present the proposal summary and ask whether to continue with spec and design (`/sdd:continue` or `/sdd:ff`).

If the arguments name a plan file (for example from `/flow:handoff`), pass its path to both phases as the source of truth: the plan supersedes earlier proposal items it contradicts.

Each phase persists its own artifact under `sdd/{change-name}/{type}`.
