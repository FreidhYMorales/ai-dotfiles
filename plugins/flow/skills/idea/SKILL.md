---
name: idea
description: "Trigger: new idea, should we do this, is it worth it, feature request, add this later, park this, /flow:idea. Triage an idea before committing: score feasibility, effort, value, fit, and give a GO/DEFER/DROP/SPIKE verdict."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load when the user brings a new idea or feature and the question is "should we do it, and when?", at any point in the workflow. Also load when an idea surfaces mid-planning (e.g. during `/flow:plan`) that is outside current scope: park it here instead of derailing the plan. Not for "how to implement" inside existing code (that is SDD explore).

## Hard Rules

- Talk to the user in their language; `docs/ideas.md` and engram entries are in English.
- Ask ONE question at a time, then stop and wait. At most 2–3 clarifying questions per idea.
- Ideas may be triaged in batches, but discuss them one at a time.
- Never state facts the verdict depends on (APIs, policies, data availability, library limits) without checking: delegate one quick research subagent (context7 MCP for library docs) and cite it.
- Always end with a recommended verdict and its main tradeoff; the user decides. Never change the plan without approval.
- Check scope creep: every GO names what it displaces relative to the current cut line and deadline.
- Persist each triaged idea to engram (`mcp__engram__mem_save`, type `decision`, topic `idea/<slug>`). For another project: `engram save "<title>" "<content>" --type decision --project <name>`.

## Decision Gates

| Situation | Action |
|---|---|
| Feasibility hinges on an unknown fact | Research subagent before scoring |
| Uncertainty still too high after research | Recommend SPIKE: one concrete question, max hours, success criterion |
| GO and a plan exists | Append to the plan with a cut-line update (or run `/flow:plan` for a large idea) |
| GO and no plan exists | Recommend `/flow:plan` |
| Idea fits but not before the deadline | DEFER to v2 or backlog |
| Duplicate of an existing idea row | Update that row instead of adding one |

## Execution Steps

1. Load `docs/ideas.md` (create from `templates/ideas.md` if missing) and the current plan's scope, cut line and deadline, if any.
2. Capture the idea in one sentence plus the user's motivation; confirm it.
3. Clarify with at most 2–3 single questions (who benefits, must-have behavior, constraints).
4. Delegate research if feasibility depends on external facts.
5. Score in a table:

   | Criterion | Assessment |
   |---|---|
   | Feasibility (technical / data / policy-legal) | |
   | Complexity | |
   | Effort (dev-days, range) | |
   | Value / impact (who, how much) | |
   | Risk | |
   | Dependencies | |
   | Fit (v1 / v2 / backlog) vs plan and deadline | |
   | Displaces (cut-line check) | |

6. Recommend a verdict: **GO** / **DEFER** / **DROP** (with reason) / **SPIKE** (question + max hours). Wait for the user's decision.
7. Record it: index row + short section in `docs/ideas.md`; engram entry. On GO, update the plan only after approval.

## Output Contract

- Updated `docs/ideas.md` (index row + section per idea).
- Engram entry per idea (topic `idea/<slug>`).
- Final message: idea, score table, recommended verdict with tradeoff, user's decision, next step.

## References

- `templates/ideas.md` — ideas log template.
