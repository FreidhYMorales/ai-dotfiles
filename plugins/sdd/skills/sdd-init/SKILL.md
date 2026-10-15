---
name: sdd-init
description: "Trigger: sdd init, iniciar sdd, openspec init. Initialize SDD context, testing capabilities, Strict TDD, and persistence."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "3.0"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-init` sub-agent (plugin agent `sdd:sdd-init`) that Read this file by path.

- As the `sdd-init` sub-agent, continue with the phase work below. Do not delegate. Do not load SDD skills through the Skill tool.
- If you are the main conversation (orchestrator), stop here: load the `sdd:orchestrator` skill and delegate to the `sdd:sdd-init` agent with the Agent tool.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If technical artifacts are explicitly requested in another language, use a neutral/professional register unless the user explicitly requests a different tone or regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; otherwise use a neutral/professional register unless the target context clearly calls for another tone or regional variant.

## Activation Contract

Run this phase when the orchestrator/user asks to initialize SDD in a project. You are the phase executor: do the work yourself, do not delegate, and do not behave like the orchestrator.

## Hard Rules

- Detect the real stack, conventions, architecture, testing tools, and persistence mode; never guess.
- In `engram` mode, do **not** create `openspec/`.
- In `openspec` mode, follow `skills/orchestrator/references/openspec-convention.md` and write file artifacts.
- In `hybrid` mode, write both openspec files and Engram observations.
- Always persist testing capabilities separately as `sdd/{project}/testing-capabilities` or `openspec/config.yaml` `testing:`.
- Record project convention files (`AGENTS.md`, project `CLAUDE.md`, and files they reference) in the project context so later phases can read them. Do not build a skill registry; the orchestrator resolves skills from its session.
- Use `capture_prompt: false` for automated SDD/config saves when supported; omit it if the tool schema lacks it.
- If `openspec/` already exists, report what exists and ask before updating it.

## Decision Gates

| Input | Action |
|---|---|
| `mode=engram` | Save context and capabilities to Engram only. |
| `mode=openspec` | Create/update openspec bootstrap files only. |
| `mode=hybrid` | Do both Engram and openspec persistence. |
| `mode=none` | Return detected context only; write no SDD artifacts. |
| strict TDD marker/config found (`openspec/config.yaml` `strict_tdd`, or `Strict TDD: enabled/disabled` in the user's or project's `CLAUDE.md`/`AGENTS.md`) | Use that value. |
| no marker/config but test runner exists | Default `strict_tdd: true`. |
| no test runner | Set `strict_tdd: false` and explain unavailable. |

## Execution Steps

1. Inspect project files (`package.json`, `go.mod`, `pyproject.toml`, CI, lint/test config) and summarize stack/conventions.
2. Detect test runner, test layers, coverage, linter, type checker, and formatter.
3. Resolve Strict TDD from agent marker, `openspec/config.yaml`, detected runner fallback, or no-runner fallback.
4. Initialize persistence for the resolved mode.
5. Persist testing capabilities and project context (including convention files found).
6. Return the structured initialization envelope.

## Output Contract

Return `status`, `executive_summary`, `artifacts`, `next_recommended`, and `risks`. Include project, stack, persistence mode, Strict TDD status, testing capability table, saved observation IDs/paths, and next `/sdd:explore` or `/sdd:new` step.

## References

Paths below are relative to the sdd plugin root.

- `skills/sdd-init/references/init-details.md` — detection checklist, Engram payloads, config skeleton, and output templates.
- `skills/orchestrator/references/engram-convention.md` — Engram artifact naming.
- `skills/orchestrator/references/openspec-convention.md` — openspec layout and rules.
