---
name: plan
description: "Trigger: plan a feature, new feature, scope, UX, screens, wireframes, /flow:plan. Plan scope and UX as two parallel tracks with ASCII wireframe variants and write plan.md."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.1"
---

## Activation Contract

Load when the user starts a new feature or project, asks to plan, or runs `/flow:plan`. Not for implementation: code comes after `/flow:handoff`.

## Hard Rules

- Talk to the user in their language; write the plan file and engram entries in English.
- Ask ONE question at a time, then stop and wait.
- Run scope (what we cover) and UX (how it looks) as two parallel tracks; every UX choice feeds scope and vice versa.
- Design for recognition, not recall: never ask the user to describe a screen in words. Show variants and let them pick.
- For every screen show exactly 3 ASCII wireframe variants side by side, labeled A/B/C, at the target width (phone ~32 cols, desktop ~70 cols). Always invite mixing ("B with A's list"); expect a mix.
- After every variant set, show the table "What this UI demands from the backend". New demands go into scope.
- Before stating facts about the user's source material (docs, data, network, rules), delegate a read-only research subagent and cite its findings.
- Admit corrections explicitly ("I was wrong about X; it is Y because Z").
- Persist every decision to engram as it is made (`mcp__engram__mem_save`, type `decision` or `discovery`). The MCP save is bound to the session project; to save into another project use `engram save "<title>" "<content>" --type decision --project <name>`.

## Decision Gates

| Situation | Action |
|---|---|
| A UI question reveals the product vision | Split v1 (deliverable now) vs v2 (later); check v1 against the deadline |
| An addition is accepted | Add it to the running scope list and state its cost vs the deadline (scope-creep check) |
| User has screenshots, photos of sketches, or visual artifacts in the project | Read the images first; they beat text |
| Variants are not enough to decide | Escalate fidelity: ASCII -> HTML mockup file -> implementation |
| Purely technical gap | Decide yourself and state the decision; do not ask |
| Real fork with tradeoffs | Ask with a recommendation and a tradeoff table |
| New project or no established conventions | Run `/flow:foundation` before consolidating |
| A new idea surfaces that is outside current scope | Park it with `/flow:idea` |

## Execution Steps

1. Resolve the plan path: `openspec/changes/<change>/plan.md` if that dir exists, else `docs/plans/<feature>/plan.md`. If a plan exists, continue it instead of restarting.
2. Read existing proposal, specs, source docs and visual artifacts. Delegate broad reading (4+ files) to one research subagent.
3. Ask: is this project solo or collaborative? Record the answer (details come later in `/flow:split`).
4. Ask for the deadline and what the demo/evaluation will prioritize; use it to rank SHOULD items by demo value.
5. **Target platforms**: where the product runs (web/PWA, Android, iOS, Windows, macOS, Linux and which distros) and how it reaches users (URL, app stores, installer, AUR/Flatpak/package). Show the options as a checklist with a recommendation; state the cost of each extra platform vs the deadline (scope decision, not a stack decision). Never infer targets from the machine you run on. Record minimum versions and form factors (phone width ~32 cols, desktop ~70 cols) that drive the wireframes.
6. Agree the core model (entities, relations, key events) in a short block.
7. For each screen, in priority order:
   - Show 3 variants + mixing invitation using `templates/screen-variants.md`.
   - After the pick, show the backend-demands table and the data inventory (shown data, actions, states: empty/loading/error/offline).
   - Cross-check the inventory against scope; add missing demands; save the decision to engram.
8. Keep a running list: v1 scope, v2 deferred, open data gaps with assumptions.
9. Consolidate into the plan file using `templates/plan.md`. Fill every section; write "n/a" rather than delete.
10. Save the plan path and a summary to engram (type `decision`, topic `plan/<feature>`).
11. Recommend `/flow:plan-review` next (blind review by a fresh agent).

## Output Contract

- Plan file at the resolved path, following `templates/plan.md`.
- Engram entries for each decision plus one plan summary.
- Final message: plan path, v1 scope in 3-6 bullets, deferred count, open gaps count, next step `/flow:plan-review`.

## References

- `templates/plan.md` — plan file template.
- `templates/screen-variants.md` — variant set and backend-demands format.
