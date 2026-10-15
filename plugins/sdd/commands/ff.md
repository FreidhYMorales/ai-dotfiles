---
description: Fast-forward SDD planning — proposal, spec, design, tasks
argument-hint: "<change-name> [plan path]"
---

Load the `sdd:orchestrator` skill with the Skill tool FIRST and follow it as the authoritative SDD coordinator rules for this command (session preflight, init guard, model assignments, launch protocol). You coordinate; phase work runs in the named sub-agent.

CONTEXT:
- Working directory: detect with the Bash tool (`git rev-parse --show-toplevel`, fallback `pwd`).
- Project: `mem_current_project` when available, else the working directory basename.
- Change name and seed: $ARGUMENTS

WORKFLOW (honor the cached execution mode):
1. `sdd:sdd-propose` — proposal
2. `sdd:sdd-spec` and `sdd:sdd-design` — both depend only on the proposal; launch them in parallel
3. `sdd:sdd-tasks` — needs spec + design; pass `delivery_strategy` (and `chain_strategy` if known)

- `interactive`: run only the next phase, present its summary and artifact references, ask to adjust or continue, then STOP.
- `auto`: run all phases back-to-back with the gatekeeper between them, then present one combined summary including the Review Workload Forecast.

If the arguments name a plan file, pass it to every phase as the source of truth; it supersedes earlier proposal items it contradicts.
