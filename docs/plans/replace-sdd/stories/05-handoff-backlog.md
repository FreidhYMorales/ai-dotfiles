# Story 05: handoff ends in the backlog

## Story

05. As a developer, I want `/flow:plan`'s handoff to write `backlog.md` and `next`/`split` to read it so that large projects end in the same loop. Requires: #01

## Acceptance criteria

- [x] Given an approved solo plan, when I run `/flow:handoff`, then it ends in a `backlog.md` next to the plan (through `/flow:backlog`) and names `/flow:story 01` as the next step, never an `/sdd:*` command; a collaborative plan uses the `tasks.md` that `/flow:split` wrote (never rewrites it) and names `/flow:next`.
- [x] Given a plan folder, when I run `/flow:next`, then it lists from `tasks.md` when one exists (proyecto_san_sebastian keeps working), else the open backlog stories whose `Requires:` are all `[x]`.
- [x] Given a plan in `docs/plans/<feature>/` or only in legacy `openspec/changes/<change>/`, when any flow planning skill looks for it, then it finds `docs/plans/` first and the legacy folder second, and reviews and resolutions are still written next to a legacy plan.

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

- `next` with neither `tasks.md` nor `backlog.md` offers `/flow:backlog`, even for a collaborative plan (should be `/flow:split`); not covered by a criterion, proyecto_san_sebastian has a `tasks.md` (verifier note).
- `next-from-backlog` shows no lift (without the plugin the model also reads the backlog grammar correctly): the format is self-explanatory, so this eval checks behaviour, not added value.

## Size

normal
Risk: item 3 (the plan lookup and `tasks.md` are contracts live projects rely on: proyecto_san_sebastian, deadline 2026-10-29), item 6 (skill behaviour graded by paid evals)

## Log

- L1 request: `/flow:story 05` (after the user approved merging story 04: "si").
- L2 assumptions for approval: handoff's SDD recommendation is removed now (the open quickshell SDD change does not go through handoff; `CLAUDE.md` keeps its SDD sentence until story 07); collaborative handoff keeps writing `tasks.md` as today.
- L3 approved by the user ("si").
- L4 test list approved (6 structural tests, 2 acceptance evals); lookup order split in two steps (stop rule 5: 3 files per step).
- L5 cycles (mode C): 671ca24→7a52ec9 solo handoff to backlog; 581192c→1ae5a61 collaborative tasks.md; 79d0b1c→f3b5695 next falls back to backlog; b186e1b→dc0d760 and 64d2393→251b849 lookup order in 6 skills (new plans always in docs/plans); ee851f0→e33db0c idea points to the loop; c2e4d52 acceptance evals.
- L6 verifier (general-purpose following verifier.md): NEEDS DECISION. Collaborative handoff wrote tasks.md and pointed back to /flow:split (loop with split, which runs first and owns tasks.md); next step 1 wording garbled ("Otherwise (solo), else read"), forced by a test literal.
- L7 user approved changing the affected assertions. ba7a8e6 (+ beebbc4, comment-only shellcheck fix: ba7a8e6 was committed with shellcheck red) → 61d4c11 handoff reads split's tasks.md, hands off own tasks, next step /flow:next; 76ef6d4 → 2d383b1 next wording; bbf2e39 refactor (tasks.md written only by split). Every code commit gated on `make check`.
- L8 verifier recheck (`flow:verifier` agent, now loaded): Verdict: PASS; both issues resolved, no regressions.
- L9 evals: `handoff-solo-to-backlog` with 1.00, without 0.00 (Δ +1.00, $0.85); `next-from-backlog` with 1.00, without 1.00 (Δ 0.00, $0.47). Story eval spend ≈ $1.32.
- L10 Risk: item 3, item 6.
