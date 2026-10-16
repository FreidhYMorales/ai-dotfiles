---
name: foundation
description: "Trigger: new project, greenfield, choose stack, architecture, folder structure, conventions, project setup, AGENTS.md, /flow:foundation. Choose stack, architecture style and conventions proportional to the project; write architecture.md, ADRs and AGENTS.md."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.5"
---

## Activation Contract

Load during planning of a greenfield project (or one with no established conventions), after the core model is agreed in `/flow:plan` and BEFORE `/flow:split`: contracts and work packages depend on it. If the project already has a stack, run in **audit mode**: detect and document existing conventions, propose only the gaps.

## Hard Rules

- Talk to the user in their language; `docs/architecture.md`, ADRs, `AGENTS.md` and engram entries are in English.
- Ask ONE question at a time, then stop and wait. Cover one decision area at a time, in the order of the Execution Steps.
- This skill CHOOSES (unlike detection-only init): always recommend one option, but only show a tradeoff table on real forks. Decide purely technical gaps yourself and state them.
- Recognition over recall: show 2–3 concrete candidates (stacks, folder trees as ASCII) and let the user pick or mix.
- Proportionality: match architecture to size, team and lifetime. Say explicitly when something would be over-engineering (e.g. hexagonal for a 3-week CRUD demo).
- Prefer mainstream, typed stacks when teammates code with browser AI ("AI-friendliness": fewer hallucinated APIs and type errors).
- Secrets never go in git: `.env.example` is committed, real `.env` is ignored, CI/deploy secrets live in the platform's secret store.
- Commits use conventional commits with no AI attribution. The user runs Strict TDD: the testing strategy must allow tests first.
- Delegate broad reading (4+ files) or library/hosting research to one research subagent (context7 MCP for library docs); cite its findings.
- Persist each decision to engram (`mcp__engram__mem_save`, type `decision`, topic `foundation/<project>/<area>`). For another project: `engram save "<title>" "<content>" --type decision --project <name>`.
- Every project gets a `Makefile` with a `check` target (format check, lint, typecheck if the language has one, tests) and at least one passing smoke test, so `make check` is green from day one (`templates/check.md`). Not optional, whatever the stack: wrap the native tools. The toolkit Stop hook blocks agents from finishing while it fails.
- Never scaffold, move files, create remotes or install dependencies without explicit approval. Bootstrap asks for ONE approval of the full, filled-in plan, then runs it without further stops.

## Decision Gates

| Situation | Action |
|---|---|
| Existing stack/config detected (package.json, pyproject, go.mod, lint config...) | Audit mode: document what exists, ask only about gaps |
| Best-fit stack unknown to the team | Show learning cost vs deadline; never hide the better option, never force it (step 2.4) |
| Constraints already answered in `/flow:plan` | Reuse them; ask only what is missing |
| Required capability (offline, maps, realtime, auth) narrows the stack | Verify library support via research subagent before recommending |
| Candidate pattern adds layers the domain does not need | Flag it as over-engineering and recommend the simpler option |
| No UI in the project | Skip step 10 and write "n/a" |
| No `.git` or no `origin` remote | Include `git init` / `gh repo create` in the bootstrap plan (step 13) |
| Existing files do not match the chosen structure | Audit mode: propose a migration table, apply with `git mv` on a branch (step 13) |
| `.claude/settings.json` already exists | Merge: keep existing rules, propose only missing ones |
| A personal `allow` (settings.local.json) matches a proposed `ask` | Warn: `ask` wins across all settings files, so it WILL prompt. User picks: keep `ask` or drop it from the project file |

## Execution Steps

1. **Constraints intake**: deadline, team size, hosting/budget, required capabilities, target devices. Reuse plan answers. Do NOT ask about known languages yet: it anchors the choice.
2. **Stack, fit-first**:
   1. Shortlist 2–3 stacks by fit alone: for each required capability, which ecosystem is strongest (library maturity, runtime model, deploy target). Use the research subagent when unsure.
   2. Only then ask each person's skills.
   3. Table: capability fit, learning cost vs deadline (rough weeks to productive, per person), time-to-demo, hosting/cost, maintainability, AI-friendliness. Recommend one.
   4. If the best fit is unfamiliar, say so plainly and recommend it only when the deadline absorbs the learning cost AND someone can review AI-written code in it. Otherwise recommend the familiar stack and record the best fit under "Alternatives considered" in the stack ADR.
   5. Mixed stacks (e.g. a Python ML service behind a TS app) only when a capability has no viable option in the main stack; state the extra ops cost.
3. **Architecture style**: 2–3 ASCII folder-tree variants proportional to size (feature-based "screaming" for small apps; hexagonal/clean only when domain complexity or multiple adapters justify it). User picks/mixes.
4. **Conventions**: naming, formatter/linter (exact tools), conventional commits, branching/PR flow, dependency policy (allowlist: no new deps without approval).
5. **Testing**: layers and tools; MUST test domain logic, contracts, golden tests from source material; test commands. Compose the `make check` recipe from the chosen format/lint/typecheck/test commands (`templates/check.md`).
6. **Config & secrets**: `.env.example`, `.gitignore` entries, where CI/deploy secrets live.
7. **CI and deploy**: CI runs `make check` on every PR; deploy target.
8. **Agent permissions**: build the project `.claude/settings.json` from `templates/permissions.md` using the exact test/lint/format/typecheck/build commands decided above. Show the three tiers (allow/ask/deny) and confirm before writing.
9. **Observability/errors**, proportional: logging, error boundaries, surfacing sync failures.
10. **Accessibility and i18n** when there is UI (UI language may differ from code language).
11. Write `docs/architecture.md` (`templates/architecture.md`), one ADR per major decision in `docs/adr/NNNN-<slug>.md` (`templates/adr.md`), `AGENTS.md` (`templates/agents.md`) a `CLAUDE.md` containing only `@AGENTS.md`, and `.claude/settings.json` (step 8); add `.claude/settings.local.json` to `.gitignore`.
12. Update the plan's `## Foundation` section with links and a 3–5 line summary. Resolve plans exactly like `/flow:plan`: `openspec/changes/*/plan.md`, then `docs/plans/*/plan.md` (no depth limit). Several → ask which; none → say so.
13. **Bootstrap**: fill in `templates/bootstrap.md` (greenfield: git init, tree, tooling, first commit, `gh repo create`; existing project: migration table + `git mv` on a branch) and present it as one plan. On approval, run it end to end; on any failure, stop and report.
14. Tell the user next: `/flow:plan-review`, then `/flow:split` inlines these conventions into every work package.

## Output Contract

- `docs/architecture.md`, `docs/adr/NNNN-<slug>.md` per major decision, `AGENTS.md`, `CLAUDE.md` (`@AGENTS.md`), `.claude/settings.json`, `Makefile` with a green `check` target.
- Updated plan `Foundation` section; engram entry per decision.
- Repo created and pushed (greenfield) or reorganization PR (existing), when approved.
- Final message: chosen stack, style, key conventions, files written, repo URL or PR, next step.

## References

- `templates/architecture.md` — architecture doc template.
- `templates/adr.md` — ADR template.
- `templates/agents.md` — project AGENTS.md template.
- `templates/bootstrap.md` — repo creation and folder reorganization sequences.
- `templates/check.md` — `make check` recipes per stack.
- `templates/permissions.md` — project permission tiers and base `.claude/settings.json`.
