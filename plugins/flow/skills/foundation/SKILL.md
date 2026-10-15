---
name: foundation
description: "Trigger: new project, greenfield, choose stack, architecture, folder structure, conventions, project setup, AGENTS.md, /flow:foundation. Choose stack, architecture style and conventions proportional to the project; write architecture.md, ADRs and AGENTS.md."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
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
- Never scaffold files or install dependencies without explicit approval.

## Decision Gates

| Situation | Action |
|---|---|
| Existing stack/config detected (package.json, pyproject, go.mod, lint config...) | Audit mode: document what exists, ask only about gaps |
| Constraints already answered in `/flow:plan` | Reuse them; ask only what is missing |
| Required capability (offline, maps, realtime, auth) narrows the stack | Verify library support via research subagent before recommending |
| Candidate pattern adds layers the domain does not need | Flag it as over-engineering and recommend the simpler option |
| No UI in the project | Skip step 9 and write "n/a" |

## Execution Steps

1. **Constraints intake**: deadline, team size and each person's skills, hosting/budget, required capabilities, target devices. Reuse plan answers.
2. **Stack**: 2–3 candidates in a table (team familiarity, capability/library fit, time-to-demo, hosting/cost, maintainability, AI-friendliness). Recommend one.
3. **Architecture style**: 2–3 ASCII folder-tree variants proportional to size (feature-based "screaming" for small apps; hexagonal/clean only when domain complexity or multiple adapters justify it). User picks/mixes.
4. **Conventions**: naming, formatter/linter (exact tools), conventional commits, branching/PR flow, dependency policy (allowlist: no new deps without approval).
5. **Testing**: layers and tools; MUST test domain logic, contracts, golden tests from source material; test commands.
6. **Config & secrets**: `.env.example`, `.gitignore` entries, where CI/deploy secrets live.
7. **CI and deploy**: tests, lint, typecheck on every PR; deploy target.
8. **Observability/errors**, proportional: logging, error boundaries, surfacing sync failures.
9. **Accessibility and i18n** when there is UI (UI language may differ from code language).
10. Write `docs/architecture.md` (`templates/architecture.md`), one ADR per major decision in `docs/adr/NNNN-<slug>.md` (`templates/adr.md`), `AGENTS.md` (`templates/agents.md`) and a `CLAUDE.md` containing only `@AGENTS.md`.
11. Update the plan's `## Foundation` section with links and a 3–5 line summary.
12. Offer (do not do) scaffolding of the folder tree and tooling config; proceed only on approval.
13. Tell the user next: `/flow:plan-review`, then `/flow:split` inlines these conventions into every work package.

## Output Contract

- `docs/architecture.md`, `docs/adr/NNNN-<slug>.md` per major decision, `AGENTS.md`, `CLAUDE.md` (`@AGENTS.md`).
- Updated plan `Foundation` section; engram entry per decision.
- Final message: chosen stack, style, key conventions, files written, scaffolding offer, next step.

## References

- `templates/architecture.md` — architecture doc template.
- `templates/adr.md` — ADR template.
- `templates/agents.md` — project AGENTS.md template.
