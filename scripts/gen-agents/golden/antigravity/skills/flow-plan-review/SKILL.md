---
name: flow-plan-review
description: "Trigger: review the plan, plan review, check plan, /flow-plan-review. Run a blind plan review by a fresh read-only subagent and report verdict, gaps and questions."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load after `/flow-plan` or `/flow-fill-gaps`, or when the user asks to review a plan. Run it at least twice per feature: once after planning, once after gaps are filled.

## Hard Rules

- The review MUST be blind: launch a fresh `flow-plan-reviewer` subagent through `invoke_subagent`. Never review the plan yourself in this thread; the planner is biased.
- Pass the reviewer only paths and facts (plan, prior proposal/specs, source material, deadline, team mode). Do not pass your opinions, the conversation, or the expected verdict.
- Do not edit the plan in this skill. Resolutions are written by `/flow-fill-gaps`.
- Relay the reviewer's verdict, findings and questions faithfully; do not soften or drop findings.
- Talk to the user in their language; the saved review stays in English.

## Decision Gates

| Situation | Action |
|---|---|
| `flow-plan-reviewer` agent unavailable | Launch the default subagent through `invoke_subagent` with the rubric read from `"/repo path/plugins/flow/agents/plan-reviewer.md"` and the same inputs |
| No plan file found | Stop and recommend `/flow-plan` |
| Source docs are .docx/.pdf | Tell the reviewer to convert them read-only (pandoc, pdftotext) |
| Second or later review | Also pass the previous review file so the reviewer checks which findings were resolved |

## Execution Steps

1. Plan lookup: `docs/plans/<feature>/plan.md` first, then legacy `openspec/changes/<change>/plan.md` (legacy plans stay read-write). Ask only if several candidates exist.
2. Collect inputs: plan path, prior proposal/spec paths, source material paths, deadline and team mode from the plan header, previous review files in the plan dir.
3. Launch the `flow-plan-reviewer` subagent through `invoke_subagent` with those inputs and: "Review blind. Follow your rubric and output structure exactly."
4. Save the returned review verbatim to `<plan-dir>/plan-review-<N>.md` (N = 1, 2, ...).
5. Save a summary to engram (`mem_save`, type `discovery`, topic `plan-review/<feature>`): verdict, blocker/major counts, the user questions.
6. Present to the user: verdict, findings table (blockers and majors first), scope cut line, then the user-only questions as a numbered list. Do not ask them yet.
7. Recommend next step by verdict.

| Verdict | Next |
|---|---|
| FAIL or PASS WITH CHANGES | `/flow-fill-gaps` |
| PASS, collaborative project | `/flow-split` |
| PASS, solo project | `/flow-handoff` |

## Output Contract

- `<plan-dir>/plan-review-<N>.md` with the reviewer's full output.
- Engram summary entry.
- Final message: verdict, top findings, user questions, review file path, next step.

## References

- `"/repo path/plugins/flow/agents/plan-reviewer.md"` — reviewer rubric and output format.
