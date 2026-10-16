---
name: split
description: "Trigger: split work, collaborators, teammates, assign tasks, work packages, /flow:split. Freeze contracts and split an approved plan into paste-able work packages."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.1"
---

## Activation Contract

Load after `/flow:plan-review` passes on a collaborative project, or when the user asks to divide work among teammates. Solo projects skip to `/flow:handoff`.

## Hard Rules

- Ask ONE question at a time, then stop and wait.
- Assume teammates use AI in the BROWSER (Claude.ai/ChatGPT): no CLI, no engram, no repo access through the AI, and the AI writes most of their code. Every package must be self-contained.
- Freeze contracts BEFORE writing any package: schema/collections, shared types, function and API I/O, seed/data formats. Commit them as files in the repo; packages copy them inline.
- Packages live in the repo (`docs/work-packages/NN-<slug>.md`), never only in engram (engram is local).
- Distribute equitably by estimated dev-days, adjusted for each person's strengths and availability; respect dependencies and file ownership (one owner per file).
- The CLI user is a participant and keeps integration, architecture, offline sync and backend config. Hand off isolated logic and UI pieces.
- Each package stays under a few pages. Cut context, not contracts or tests.
- Inline the relevant conventions from `docs/architecture.md` / `AGENTS.md` (stack, folder map, naming, lint/test commands, no new deps) and the setup steps for the teammate's OS from `docs/development.md` into every package; teammates' browser AI cannot read the repo.
- Talk to the user in their language; packages are always in English (user decision: English is the default standard; teammates translate if needed).

## Decision Gates

| Situation | Action |
|---|---|
| Contracts are not stable yet | Stop; resolve them with the user first (`/flow:fill-gaps`) |
| Task touches files another person owns | Split the task or move ownership; never share a file |
| Task depends on unfinished work | Give a stub/mock of the dependency's contract in the package |
| Load imbalance > ~1 dev-day | Rebalance and show the new table |

## Execution Steps

1. Load the approved plan and its latest review. Confirm MUST/SHOULD items and dev-day estimates.
2. Ask: how many collaborators (besides you)? Then, one person at a time: name, strengths, availability (days or hours until the deadline).
3. Freeze contracts: list each contract file to create (e.g. `src/contracts/types.ts`, `schema.sql`, `seed/*.json`), write or update them, and show them to the user for approval.
4. Build the dependency graph of ALL v1 tasks (delegated and the CLI user's own), then propose the split as a table and wait for approval:

   | # | Package | Owner | Dev-days | Depends on | Files owned | Status |

   Include a load-per-person summary. Order the CLI user's own queue so work that does NOT depend on delegated packages comes first, and add a **pull backlog**: unassigned SHOULD/LATER tasks that are independent of delegated work, so anyone who finishes early can keep going (see `/flow:next`). Where the CLI user's task depends on a delegated package, mark whether it can proceed against the frozen contract with a stub/mock (integrate the real code later).
   Persist the table as `<plan-dir>/tasks.md` (status: `todo` | `doing` | `delivered` | `integrated` | `blocked`); it is the single source of truth for `/flow:next`.
5. Write one package per task with `templates/work-package.md`. Skeleton files carry exact signatures with empty bodies; tests are runnable with expected outputs.
6. Recommend a CI gate on every PR (tests, lint, typecheck). Offer to add the workflow file if none exists.
7. Update the plan's `## Collaboration` section: people, frozen contract paths, package links, owners.
8. Save the split to engram (type `decision`, topic `split/<feature>`).
9. Tell the user: send each teammate their package file; tip: put it in a Claude.ai/ChatGPT Project as persistent context. Next steps: `/flow:handoff` for the CLI user's own work, `/flow:integrate` when packages come back.

## Output Contract

- Frozen contract files in the repo.
- `docs/work-packages/NN-<slug>.md` per task.
- Updated plan `Collaboration` section.
- Final message: split table, load per person, package paths, CI recommendation, next steps.

## References

- `templates/work-package.md` — work package template.
