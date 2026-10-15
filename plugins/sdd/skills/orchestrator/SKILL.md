---
name: orchestrator
description: "Trigger: /sdd:* commands, SDD routing, 'use SDD', continue/apply/verify/archive an SDD change. Coordinator rules for Spec-Driven Development: delegate each phase to its sub-agent."
license: MIT
metadata:
  author: FreidhYMorales
  version: "0.1.0"
---

## Activation Contract

Load before handling any `/sdd:*` command, SDD meta-command, natural-language SDD request ("do it with SDD"), or SDD continuation/apply/verify/archive routing. While this skill is active you are the SDD **coordinator**: keep one thin thread, delegate every phase to its sub-agent, and synthesize results. Never execute phase work inline when the phase agent is available.

Plugin root: `${CLAUDE_PLUGIN_ROOT}`. Reference docs live in `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/`. Inside phase skills, paths written as `skills/...` are relative to that plugin root.

## Hard Rules

- Delegate each phase to its plugin agent with the Agent tool: `subagent_type: "sdd:sdd-<phase>"` (for example `sdd:sdd-apply`). Judgment Day agents are `toolkit:jd-judge-a`, `toolkit:jd-judge-b`, `toolkit:jd-fix-agent`.
- Every SDD phase Agent call MUST pass `model` from the Model Assignments table. Generic (non-SDD) delegation omits `model` unless the user asked for one.
- Never launch `sdd-apply` just because the user asked to implement something; follow Entry Routing.
- Route only from structured status (manual status contract) and the dependency graph, never from free text.
- If a phase returns `blocked`, stop and report the blocker. Do not advance dependent phases.
- Generated technical artifacts (specs, designs, tasks, code, comments, tests) default to English regardless of the conversation language. Direct conversation with the user follows the user's language. Forward this rule to every phase prompt.
- Ask at most one decision at a time outside the grouped preflight; when a choice blocks progress, present every option faithfully and STOP until the user answers. Never answer on the user's behalf.

## Commands

| Command | Does |
|---|---|
| `/sdd:init` | Detect stack, testing capabilities and Strict TDD; bootstrap persistence |
| `/sdd:explore <topic>` | Investigate an idea; no implementation |
| `/sdd:new <change>` | Explore, then propose |
| `/sdd:ff <change>` | Fast-forward planning: propose → spec ∥ design → tasks |
| `/sdd:continue [change]` | Run the next dependency-ready phase |
| `/sdd:status [change]` | Read-only structured status |
| `/sdd:apply [change]` | Implement pending tasks in batches |
| `/sdd:verify [change]` | Validate implementation against specs/tasks with real test runs |
| `/sdd:archive [change]` | Sync delta specs and close the change |
| `/sdd:onboard` | Guided end-to-end walkthrough on the real codebase |

## Dependency Graph

```text
explore (optional) -> proposal -> specs --> tasks -> apply -> verify -> archive
                                   ^
                                   |
                                 design
```

`spec` and `design` both depend only on `proposal` and may run in parallel. `tasks` needs both.

## SDD Session Preflight (hard gate)

Before any SDD command or natural-language SDD request, the session needs an explicit `SDD Session Preflight` block with four choices:

1. **Pace**: Interactive → `interactive`; Automatic → `auto`.
2. **Artifacts**: OpenSpec → `openspec`; Engram → `engram`; Both → `hybrid`. If Engram is not callable, offer only OpenSpec or inline (`none`).
3. **PRs**: Ask me → `ask-on-risk`; Single PR → `single-pr`; Auto → `auto-chain`. (`exception-ok` only when the user explicitly accepts `size:exception`.)
4. **Review budget**: 400 lines → `review_budget_lines: 400`; 800 lines → `800`; Other → one follow-up for the number.

- Ask all four in ONE `AskUserQuestion` call (four groups, in this order), localized to the user's language, without showing canonical values. If that tool is unavailable or the runtime is non-interactive, print the four groups with every option as plain text and STOP.
- Existing `openspec/config.yaml`, prior artifacts or prior `sdd-init` results do NOT satisfy preflight. If the user already stated all four choices in this conversation, summarize them as the block and continue.
- Cache the block for the session and include it in every phase prompt. Do not run init, delegate, edit files or apply tasks before it exists.

## SDD Init Guard

Before any SDD command, check `mem_search(query: "sdd-init/{project}", project: "{project}")` (or `openspec/config.yaml` for file-based stores). If absent, launch `sdd:sdd-init` first, then continue with the requested command. Resolve `{project}` with `mem_current_project` when available, else the git root basename.

## Entry Routing

New change request via SDD → preflight → init guard → explore/propose (`/sdd:new` equivalent). Launch `sdd:sdd-apply` only when all are true:

1. Preflight is complete.
2. The change has spec, design, and tasks artifacts.
3. The user explicitly asked to apply/continue, or planning just completed and the Review Workload Guard passed.

If a dependency is missing, STOP and propose `/sdd:new` or `/sdd:ff`.

## Execution Mode

- `auto`: phases run back-to-back; the gatekeeper validates after each phase. Expect zero prompts on the happy path and at most one per recoverable failure.
- `interactive`: after each phase show a concise summary and ask whether to adjust or continue. "continue"/"dale"/"go on" approves only the next phase.
- Before `sdd-propose` in interactive mode, offer one proposal question round about business problem, rules, outcomes, edge cases, scope boundaries, non-goals and constraints. Do not ask about test commands, PR shape or line budgets unless the user asks.

## Automatic Mode Gatekeeper

After every phase, before launching the next:

- **Contract**: result has `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`, `skill_resolution`; status is not `partial`/`blocked`.
- **Artifact exists** in the active backend.
- **No hallucination**: claimed files, symbols, commands and artifacts exist.
- **No drift** from the phase's inputs.
- **Routing coherence**: `next_recommended` follows the dependency graph; no unaddressed CRITICAL risk.

Validate inline for explore/spec/tasks/archive. For design and apply, launch one fresh `general-purpose` sub-agent that validates only the phase artifact against its inputs (not a code review). On failure, re-run the same phase once with specific corrective feedback; if it fails again, STOP the chain and report.

## Artifact Store

`engram` (default when Engram is callable), `openspec`, `hybrid`, or `none` (inline only; recommend enabling persistence). Pass `Artifact store mode: <mode>` to every phase agent. Details: `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/persistence-contract.md`.

## Delivery and Chain Strategy

- `delivery_strategy` domain is exactly `ask-on-risk | auto-chain | single-pr | exception-ok`. Pass it to `sdd-tasks` and `sdd-apply`. Any other value: STOP and re-collect.
- When chained PRs are selected, ask once for `chain_strategy`: `stacked-to-main` (each PR targets the previous PR branch, or main) or `feature-branch-chain` (PR #1 targets a tracker branch; children target the previous PR branch; only the tracker merges to main). Pass it to `sdd-tasks` and `sdd-apply`, and add the `toolkit:chained-pr` skill to their skills block.

## Review Workload Guard

After `sdd-tasks` and before `sdd-apply`, read the tasks artifact's `Review Workload Forecast`. If it says `Chained PRs recommended: Yes`, `400-line budget risk: High`, estimated changed lines exceed the review budget, or `Decision needed before apply: Yes`:

| `delivery_strategy` | Action |
|---|---|
| `ask-on-risk` | Stop and ask: split into chained PRs, or proceed with `size:exception` |
| `auto-chain` | Split automatically; ask for `chain_strategy` only if missing |
| `single-pr` | Stop and require an explicit `size:exception` before apply |
| `exception-ok` | Continue; tell `sdd-apply` this run uses `size:exception` |

Always include the resolved `delivery_strategy`, `chain_strategy`, and PR boundary/exception in the `sdd-apply` prompt.

## Model Assignments

| Phase agent | Model | Reason |
|---|---|---|
| sdd-explore | sonnet | Reads code, structural |
| sdd-propose | opus | Architectural decisions |
| sdd-spec | sonnet | Structured writing |
| sdd-design | opus | Architecture decisions |
| sdd-tasks | sonnet | Mechanical breakdown |
| sdd-apply | sonnet | Implementation |
| sdd-verify | sonnet | Validation against spec |
| sdd-archive | haiku | Copy and close |
| sdd-onboard | haiku | Guided walkthrough |
| jd-judge-a / jd-judge-b | sonnet | Blind adversarial review |
| jd-fix-agent | sonnet | Surgical fixes |
| default | sonnet | Fallback |

If an assigned model is unavailable, substitute `sonnet`.

## Sub-Agent Launch Protocol

1. Identify the phase and its agent (`sdd:sdd-<phase>`) and model.
2. Dedupe: keep a session log of `(phase, task-fingerprint)`; never launch the same pair twice.
3. Resolve skills per `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/skill-resolver.md` and add a `## Skills to load before work` block.
4. Prompt contents: change name, project, preflight block, `Artifact store mode`, structured status (`artifactPaths`/`contextFiles`, task progress, `actionContext`), artifact references to read (topic keys or paths, never pasted artifact bodies), and the language rule.
5. Phase agents persist their own artifacts and return the result envelope. Generic (non-SDD) sub-agents: pass relevant Engram context in the prompt, ask them to save discoveries with `mem_save`, and to close with a `## Key Learnings` list (1–5 standalone sentences).

### Context Protocol

| Phase | Reads | Writes |
|---|---|---|
| `sdd-explore` | nothing | `explore` |
| `sdd-propose` | exploration (optional) | `proposal` |
| `sdd-spec` | proposal | `spec` |
| `sdd-design` | proposal | `design` |
| `sdd-tasks` | spec + design | `tasks` |
| `sdd-apply` | tasks + spec + design + apply-progress if present | `apply-progress` |
| `sdd-verify` | spec + tasks + apply-progress | `verify-report` |
| `sdd-archive` | all artifacts | `archive-report` |

### Strict TDD Forwarding

Strict TDD is enabled by default. When launching `sdd-apply` or `sdd-verify`, read testing capabilities (`sdd/{project}/testing-capabilities` or `openspec/config.yaml`). Unless they say `strict_tdd: false` or no test runner exists, add: `STRICT TDD MODE IS ACTIVE. Test runner: {test_command}. You MUST follow strict-tdd.md. Do NOT fall back to Standard Mode.`

### Apply-Progress Continuity

When launching `sdd-apply` after prior batches, check `sdd/{change-name}/apply-progress`. If it exists, tell the agent to read it first, merge new progress into it, and never overwrite.

### Archive Final-State Handoff

When launching `sdd-archive`, forward explicit final-state facts for work done after `apply-progress`/`verify-report` were persisted (warnings fixed later, blockers resolved, updated test counts), with commit or evidence references. These outrank stale snapshot claims.

## Status

Before continue/apply/verify/archive, build structured status manually per `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/sdd-status-contract.md` (Engram: `mem_search` + `mem_get_observation` on the change topic keys; OpenSpec: `openspec/changes/<change>/`). Route only by `nextRecommended` and dependency states; if `blockedReasons` is non-empty, stop and report.

## Topic Keys

| Artifact | Topic key |
|---|---|
| Project context | `sdd-init/{project}` |
| Testing capabilities | `sdd/{project}/testing-capabilities` |
| Exploration | `sdd/{change-name}/explore` |
| Proposal | `sdd/{change-name}/proposal` |
| Spec | `sdd/{change-name}/spec` |
| Design | `sdd/{change-name}/design` |
| Tasks | `sdd/{change-name}/tasks` |
| Apply progress | `sdd/{change-name}/apply-progress` |
| Verify report | `sdd/{change-name}/verify-report` |
| Archive report | `sdd/{change-name}/archive-report` |
| DAG state | `sdd/{change-name}/state` |

Retrieval is always two steps: `mem_search(query: "{topic_key}", project: "{project}")` → `mem_get_observation(id)`. After each phase transition persist DAG state (`sdd/{change-name}/state` or `openspec/changes/{change-name}/state.yaml`).

## Recovery

- `engram`: `mem_search("sdd/{change-name}/state")` → `mem_get_observation` → resume from the recorded phase.
- `openspec`: read `openspec/changes/*/state.yaml` and artifacts.
- `hybrid`: Engram first, filesystem fallback.
- `none`: state is not persisted; explain the limitation.

## Output Contract

After each phase (or chain), report to the user: change, phase(s) run, artifact references, task progress when relevant, risks, and the next recommended command (`/sdd:*`).

## References

- `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/sdd-status-contract.md` — manual status schema and routing.
- `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/persistence-contract.md` — modes, state persistence, sub-agent prompt templates.
- `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/skill-resolver.md` — how to pick and pass skills to sub-agents.
- `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/sdd-phase-common.md` — the protocol every phase agent follows (skill loading, retrieval, persistence, envelope, workload guard).
- `${CLAUDE_PLUGIN_ROOT}/skills/orchestrator/references/engram-convention.md`, `openspec-convention.md` — artifact naming and layout.
