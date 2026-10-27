# Story 05: handoff ends in the backlog

## Story

05. As a developer, I want `/flow:plan`'s handoff to write `backlog.md` and `next`/`split` to read it so that large projects end in the same loop. Requires: #01

## Acceptance criteria

- [ ] Given an approved solo plan, when I run `/flow:handoff`, then it ends in a `backlog.md` next to the plan (through `/flow:backlog`) and names `/flow:story 01` as the next step, never an `/sdd:*` command; a collaborative plan still gets `tasks.md` and `/flow:split`.
- [ ] Given a plan folder, when I run `/flow:next`, then it lists from `tasks.md` when one exists (proyecto_san_sebastian keeps working), else the open backlog stories whose `Requires:` are all `[x]`.
- [ ] Given a plan in `docs/plans/<feature>/` or only in legacy `openspec/changes/<change>/`, when any flow planning skill looks for it, then it finds `docs/plans/` first and the legacy folder second, and reviews and resolutions are still written next to a legacy plan.

## Plan

- handoff drops its SDD branch: solo plans go to the backlog skill, collaborative plans keep the task list and point to split.
- next reads the task list when present and otherwise derives what is startable from the backlog statuses and `Requires:`.
- The plan lookup in plan, plan-review, fill-gaps, research, foundation and handoff states one order: `docs/plans/` first, then the legacy folder, which stays read-write.
- idea's "that is SDD explore" pointer goes to the new loop.
- A structural test pins the lookup order and the handoff/next contracts; evals cover a solo handoff and a backlog-driven next.

## Out of scope

- split and integrate formats (they keep `tasks.md`).
- Removing the `sdd` plugin, its references in toolkit, README or CLAUDE.md (story 07).
- Migrating proyecto_san_sebastian's plan to `docs/plans/`.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 3 (the plan lookup and `tasks.md` are contracts live projects rely on: proyecto_san_sebastian, deadline 2026-10-29), item 6 (skill behaviour graded by paid evals)

## Log

- L1 request: `/flow:story 05` (after the user approved merging story 04: "si").
- L2 assumptions for approval: handoff's SDD recommendation is removed now (the open quickshell SDD change does not go through handoff; `CLAUDE.md` keeps its SDD sentence until story 07); collaborative handoff keeps writing `tasks.md` as today.
- L3 approved by the user ("si").
