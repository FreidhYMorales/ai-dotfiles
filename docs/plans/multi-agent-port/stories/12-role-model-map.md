# Story 12: one role model map for the generated agents

## Story

12. As a developer, I want one role model map for the generated agents so that I can point the reviewers at a strong or local model without editing each agent. Requires: #08

## Acceptance criteria

- [ ] Given the map's `reviewer` role set to `ollama/qwen3` for OpenCode, when the agents are generated, then `flow-plan-reviewer` and `flow-verifier` for OpenCode both carry `model: ollama/qwen3` and nothing else in them changes.
- [ ] Given the `reviewer` role set to `flash` for Antigravity, when the agents are generated, then both agy agents carry `model: flash`; a value other than `inherit`, `pro` or `flash` for Antigravity, or a missing role or target entry, stops the generator with an error that names it.
- [ ] Given the map as shipped, when I run `make check`, then the generated agents equal today's goldens (OpenCode without a `model:` line, which inherits the session model; agy `model: pro`).

## Plan

- One small map file next to the generator holds, per role, one model per target; the shipped values reproduce today's output (OpenCode `inherit`, agy `pro`).
- The generator gives each generated agent its role (both are reviewers today) and writes the target's value; OpenCode `inherit` means no `model:` line.
- The agy values are checked against the three it accepts; a bad or missing entry fails generation before anything is installed.
- `docs/multi-agent.md` says where the map is and how to point the reviewers at a strong or local model.

## Out of scope

- The `worker` role (only `jd-fix-agent` uses it, and judgment-day stays Claude-only until v2).
- Claude's agent frontmatter (`model: opus` stays; Claude subagents run Anthropic models only).
- Checking that an OpenCode `provider/id` exists, or running a local model.
- The smoke run on a strong model (#13).

## Suggestions (your call)

- `agy_agent` hard-codes `model: pro` (`gen.sh:176`) and `opencode_agent` writes no model line; one lookup helper both call keeps the map read in one place.

## Size

normal
Risk: item 3 (the generated agent frontmatter both agents parse, and the map format the user edits), item 5 (generator and runtime model config)

## Log

- L1 request: "/flow:story 12"
- L2 assumptions for approval: only the `reviewer` role ships (the plan's `worker` role has no generated agent until the judgment-day port in v2); the plan's "default `inherit`" is the shipped OpenCode value, while agy ships `pro` so today's output does not change; a missing entry is an error rather than a silent default, so a typo in the map never goes unnoticed; OpenCode values are passed through unchecked (any `provider/id`, including `ollama/<model>`).
- L3 approved by the user ("si").
- L4 test list approved ("si"): gen-agents 1 OpenCode reviewer model from the map (golden plus one `model:` line), 2 agy `flash` from the map, 3 a bad agy value and a missing entry fail naming them; C3 by the existing goldens. The map lives at `scripts/gen-agents/models.json`; tests point `GEN_MODELS` at another map (approved).
