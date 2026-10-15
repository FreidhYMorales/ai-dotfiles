---
name: handoff
description: "Trigger: handoff, start implementing, plan approved, turn plan into tasks, /flow:handoff. Turn the approved plan into SDD input or an ordered MUST/SHOULD task list."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load when `/flow:plan-review` passes (and `/flow:split` is done for collaborative projects), or when the user asks to start implementing an approved plan.

## Hard Rules

- Do not re-ask decisions settled in the plan, its `Plan-review resolutions`, or engram. Read them first.
- The plan supersedes earlier proposal items it contradicts; carry that explicitly into the implementation input.
- In collaborative mode, hand off only the CLI user's own work; teammates' work lives in `docs/work-packages/`.
- Do not start coding in this skill.
- Talk to the user in their language; generated artifacts stay in English.

## Decision Gates

| Project | Output |
|---|---|
| Uses gentle-ai SDD (`openspec/` exists or `sdd-*` skills available) | Recommend `/sdd-ff` (scope is clear) or `/sdd-new` (needs exploration), seeded with the plan path |
| No SDD | Ordered task list in the plan dir |
| Plan status is not reviewed/approved | Stop; recommend `/flow:plan-review` |

## Execution Steps

1. Locate the plan (`openspec/changes/<change>/plan.md`, else `docs/plans/<feature>/plan.md`) and the latest review file.
2. Check the verdict is PASS (or PASS WITH CHANGES with every finding resolved in `Plan-review resolutions`).
3. List superseded items: earlier proposal/spec items the plan changes or drops.
4. SDD path: give the exact command, e.g. `/sdd-ff <change>` with the instruction "Use <plan path> as the source of truth; it supersedes these proposal items: ...". Remind that the proposal/specs must reflect the superseded items before tasks are generated.
5. Non-SDD path: write `<plan-dir>/tasks.md`: tasks grouped MUST then SHOULD, ordered by dependency, each with files touched, acceptance check (state or test), and dev-day estimate. Contract/setup tasks go first; integration tasks for teammates' packages go where their dependencies are met.
6. Mark the plan status `approved` and save the handoff to engram (type `decision`, topic `handoff/<feature>`).

## Output Contract

- SDD: the exact command plus the superseded-items list.
- Non-SDD: `<plan-dir>/tasks.md`.
- Final message: path or command, MUST task count and dev-days, first task to start.
