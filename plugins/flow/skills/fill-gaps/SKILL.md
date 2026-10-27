---
name: fill-gaps
description: "Trigger: fill gaps, resolve review findings, answer review questions, /flow:fill-gaps. Close plan-review gaps one question at a time and record resolutions in the plan."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load after `/flow:plan-review` returns FAIL or PASS WITH CHANGES, or when the user wants to resolve open gaps in a plan.

## Hard Rules

- Ask ONE question at a time, then stop and wait for the answer.
- Every question carries your recommendation. When there is a real fork, add a tradeoff table (option, pros, cons, cost in dev-days, demo impact).
- Resolve purely technical gaps yourself; state the decision in one line and do not ask.
- Never re-ask a decision already settled in the plan or engram; check both first.
- Before answering a factual question about the user's source material, delegate a read-only research subagent.
- After every accepted addition, run the scope-creep check: new item, its dev-days, running MUST total vs the deadline.
- When a UI gap appears, use the variant method from `/flow:plan`: 3 ASCII variants (A/B/C), invite mixing, then the backend-demands table.
- Admit corrections explicitly.
- Persist each resolution to engram as it is made (type `decision`). For another project use `engram save "<title>" "<content>" --type decision --project <name>`.
- Talk to the user in their language; write the plan and engram entries in English.

## Decision Gates

| Gap type | Action |
|---|---|
| Technical only (naming, library choice within allowlist, data format) | Decide, state it, record it |
| Product / priority / policy | Ask the user with a recommendation |
| UI or state (empty/error/offline) | Show variants, then backend demands |
| Pushes MUST past the deadline | Propose moving something to SHOULD/LATER or v2; ask the user to choose |

## Execution Steps

1. Plan lookup: `docs/plans/<feature>/plan.md` first, then legacy `openspec/changes/<change>/plan.md` (legacy plans stay read-write). Load the latest `<plan-dir>/plan-review-<N>.md` and the plan.
2. Build the gap queue: blockers, then majors, then the reviewer's user questions, then minors. Mark which you will decide yourself.
3. Announce the technical decisions you made in one short list.
4. Ask the first user question; wait; record the answer; continue until the queue is empty or the user stops.
5. Update the plan sections each answer touches (screens, scope table, data inventory, deferred to v2, data gaps).
6. Append or extend `## Plan-review resolutions` in the plan: one row per finding with finding, resolution, decided by (user/planner). Reference the review file name.
7. Update the plan status line and save a summary to engram (topic `plan/<feature>`).
8. Recommend `/flow:plan-review` again for a fresh blind pass.

## Output Contract

- Updated plan with a `Plan-review resolutions` table covering every finding (resolved, deferred, or rejected with reason).
- Engram decision entries per resolution.
- Final message: resolved count, deferred count, new MUST total vs deadline, next step `/flow:plan-review`.
