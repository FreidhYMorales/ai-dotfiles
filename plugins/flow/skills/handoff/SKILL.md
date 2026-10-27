---
name: handoff
description: "Trigger: handoff, start implementing, plan approved, turn plan into tasks, /flow:handoff. Turn the approved plan into a backlog (solo, via /flow:backlog) or an ordered MUST/SHOULD task list."
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
| Solo plan | `backlog.md` next to the plan, through `/flow:backlog` |
| Collaborative plan | `tasks.md` in the plan dir, for `/flow:split` |
| Plan status is not reviewed/approved | Stop; recommend `/flow:plan-review` |

## Execution Steps

1. Plan lookup: `docs/plans/<feature>/plan.md` first, then legacy `openspec/changes/<change>/plan.md` (legacy plans stay read-write). Read it and the latest review file.
2. Check the verdict is PASS (or PASS WITH CHANGES with every finding resolved in `Plan-review resolutions`).
3. List superseded items: earlier proposal/spec items the plan changes or drops.
4. Solo plan: run `/flow:backlog` on the plan so it writes `backlog.md` next to it; pass the superseded items so no story carries them. Next step: `/flow:story 01`.
5. Collaborative plan: write `<plan-dir>/tasks.md` (then `/flow:split`): tasks grouped MUST then SHOULD, ordered by dependency, each with files touched, acceptance check (state or test), and dev-day estimate. Contract/setup tasks go first; integration tasks for teammates' packages go where their dependencies are met.
6. Mark the plan status `approved` and save the handoff to engram (type `decision`, topic `handoff/<feature>`).

## Output Contract

- Solo: `<plan-dir>/backlog.md`, the superseded-items list, next step `/flow:story 01`.
- Collaborative: `<plan-dir>/tasks.md`, next step `/flow:split`.
- Final message: path or command, MUST task count and dev-days, first task to start.
