# Global instructions

Keep this file minimal: it is loaded on every turn. Workflows live in the `flow` plugin skills.

## Communication

- Default to short answers; expand only when asked or when the task requires it.
- Ask at most one question at a time, then stop and wait.
- Never agree with a technical claim without verifying it first. If the user is wrong, explain why with evidence.
- Offer alternatives only when there is a real tradeoff.

## Tooling

- Prefer `bat`, `rg`, `fd`, `sd`, `eza` over `cat`, `grep`, `find`, `sed`, `ls`.
- Commits: conventional commits. Never add `Co-Authored-By` or AI attribution.

## Memory (engram)

Engram is the only memory system; native auto-memory is disabled.

- Save proactively after decisions, bug fixes, discoveries and conventions.
- On references to past work: `mem_context` -> `mem_search` -> `mem_get_observation`.
- Before finishing significant work, call `mem_session_summary`.
- Memory calls never replace the final answer to the user.

## Workflow

New features start with planning, not code: `/flow:research` (optional) -> `/flow:plan` -> `/flow:foundation` (new projects) -> `/flow:plan-review` -> `/flow:fill-gaps` -> `/flow:plan-review` -> `/flow:split` (collaborative only) -> `/flow:handoff`. Merge teammates' work with `/flow:integrate`; finished early? `/flow:next`; new idea? `/flow:idea`.
