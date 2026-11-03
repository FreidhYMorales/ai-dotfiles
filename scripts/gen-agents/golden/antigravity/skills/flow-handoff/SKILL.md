---
name: flow-handoff
description: "Trigger: handoff, start implementing, plan approved, turn plan into tasks, /flow-handoff. Turn the approved plan into a backlog (solo, via /flow-backlog) or the user's own tasks from split's tasks.md."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load when `/flow-plan-review` passes (and `/flow-split` is done for collaborative projects), or when the user asks to start implementing an approved plan.

## Hard Rules

- Do not re-ask decisions settled in the plan, its `Plan-review resolutions`, or engram. Read them first.
- The plan supersedes earlier proposal items it contradicts; carry that explicitly into the implementation input.
- In collaborative mode, hand off only the CLI user's own work; teammates' work lives in `docs/work-packages/`.
- Do not start coding in this skill.
- Talk to the user in their language; generated artifacts stay in English.

## Decision Gates

| Project | Output |
|---|---|
| Solo plan | `backlog.md` next to the plan, through `/flow-backlog` |
| Collaborative plan (after `/flow-split`) | your own tasks from `tasks.md`, then `/flow-next` |
| Plan status is not reviewed/approved | Stop; recommend `/flow-plan-review` |

## Execution Steps

1. Plan lookup: `docs/plans/<feature>/plan.md`. Read it and the latest review file.
2. Check the verdict is PASS (or PASS WITH CHANGES with every finding resolved in `Plan-review resolutions`).
3. List superseded items: earlier proposal/spec items the plan changes or drops.
4. Solo plan: run `/flow-backlog` on the plan so it writes `backlog.md` next to it; pass the superseded items so no story carries them. Next step: `/flow-story 01`.
5. Collaborative plan: read the `tasks.md` that `/flow-split` wrote; never rewrite it (split owns owners, files and statuses). Hand off only the CLI user's own tasks, in dependency order, each with its acceptance check. No `tasks.md` yet: stop and recommend `/flow-split`. Next step: `/flow-next`.
6. Mark the plan status `approved` and save the handoff to engram (type `decision`, topic `handoff/<feature>`).

## Output Contract

- Solo: `<plan-dir>/backlog.md`, the superseded-items list, next step `/flow-story 01`.
- Collaborative: the user's own tasks from `<plan-dir>/tasks.md` (unchanged), next step `/flow-next`.
- Final message: path or command, MUST task count and dev-days, first task to start.
