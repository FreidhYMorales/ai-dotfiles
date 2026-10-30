---
name: flow-backlog
description: "Trigger: backlog, user stories, break this idea into stories, break this plan into stories, /flow-backlog. Turn an idea or an approved plan into backlog.md: 10-15 one-line vertical stories, story 01 the walking skeleton, plus the project's test command. Not for general questions or for implementing code."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
  adapted-from: "nschurmann/hola-ai skills/backlog (MIT)"
---

## Activation Contract

Load when the user wants an idea or an approved plan (the `/flow-plan` handoff) split into user stories, or asks for a backlog. Not for answering general questions, refining one story (that is `/flow-story`) or writing code (that is `/flow-pair`).

## Hard Rules

- Talk to the user in their language; `backlog.md` and engram entries are in English.
- Ask ONE question at a time, each with your suggested answer, then stop and wait.
- Agree only the stack (new projects) and the expensive-to-change decisions; never design architecture or implementation.
- **Invent nothing.** Split only what the user or the plan said. A gap is a question, not a story.
- **Vertical slices, never by layer.** Each story delivers value on its own through every layer it needs.
- **No technical stories.** The actor is never the developer's tooling or "the system"; "set up the database" is built inside the first story that needs it.
- 10-15 stories max (fewer is fine); one line each; no acceptance criteria, estimates or priorities.
- Story 01 is the walking skeleton: the smallest slice of the product's core value usable end to end (to-do app: "a user adds a task and sees it in the list"). Supporting concerns (sign-in, accounts, settings) are never story 01 on their own; build the minimum inside the first story that needs them, or give them a later story.
- The file format below is a contract other skills parse (`story`, `pair`, `next`); never deviate from it.
- Ignore old engram topics `sdd/*` and `sdd-init/*`.

## Decision Gates

| Situation | Action |
|---|---|
| Approved plan exists (`docs/plans/<feature>/plan.md`, else legacy `openspec/changes/<change>/plan.md`) | Take What, Stack and decisions from it; ask only about gaps |
| Bare idea, no plan | Write to `docs/plans/<project>/backlog.md` (small projects) or `docs/plans/<feature>/backlog.md` |
| Plan found under legacy `openspec/changes/<change>/` | Write `backlog.md` next to it (legacy stays read-write) |
| Idea is large (new product, several actors, deadline) | Suggest `/flow-plan` first; its handoff ends here |
| `backlog.md` already exists | Edit it in place: append, reorder, split, drop; never renumber |
| No runnable test command found | Write `Test command: none`; warn that `/flow-pair` will stop with "no runnable test" |
| Collaborative mode in the plan | The backlog is the solo source; `/flow-split` keeps `tasks.md` (owners, files, statuses) |

## Execution Steps

1. Look up the plan: `docs/plans/<feature>/` first, then `openspec/changes/<change>/`. Read `backlog.md` if present.
2. Restate the idea in one or two lines; confirm it.
3. New project: agree the stack only. Then ask which expensive-to-change decisions apply: multi-tenant or multi-organization, roles and permissions, offline or sync, i18n or multi-currency, others the idea suggests. Ask, do not design.
4. Detect the test commands once (first match wins) and confirm them:
   - `Makefile` target `check` or `test` → `make check` / `make test`.
   - `package.json` script `test` → `npm test` (or the lockfile's manager: `pnpm`, `yarn`, `bun`); single test via the runner (`npx vitest run <file>`, `npx jest <file>`).
   - Language runner: `pyproject.toml`/`pytest.ini` → `pytest` / `pytest <file>`; `go.mod` → `go test ./...` / `go test <pkg> -run <Name>`; `Cargo.toml` → `cargo test` / `cargo test <name>`; `*.csproj` → `dotnet test` / `dotnet test --filter <Name>`.
   - Markdown-skill repos: the single test is a bash structural test in `scripts/tests/`.
5. Propose the backlog in chat in the exact format; the user adjusts it.
6. Write `backlog.md` from `"/repo path/plugins/flow/skills/backlog/templates/backlog.md"` at the output path.
7. Save one engram entry and name the next step: `/flow-story NN` (normally `01`).

## File format

Sections, in order: `## Context` with bullets `What:`, `Stack:`, `Expensive decisions:` (or `none`), `Test command: <cmd>` and `Single test: <cmd> <file>`; then `## Backlog`.

Line grammar (one story per line):

```
NN. [s] As a <who>, I want <what> so that <why>.[ Requires: #N(, #N)*]
```

| `[s]` | Meaning | Written by |
|---|---|---|
| `[ ]` | todo | backlog |
| `[~]` | in story (being refined or built) | story, pair |
| `[x] <sha>` | done; sha = last code commit of the story | pair |
| `[-] split → #NN, #NN` | replaced by the new stories listed | backlog, story |
| `[-] dropped` | will not be done | backlog |

- `NN` is a stable two-digit ID (`01`, `02`, ...), never reused.
- Reorder by moving lines; IDs do not change.
- Split: mark the original `[-] split → #NN, #NN` and append the new stories with the next free IDs.
- Add `Requires: #N` only when a story makes no sense without another, e.g. `03. [ ] As a member, I want to invite a teammate so that we share a board. Requires: #01, #02`.

## Output Contract

- `docs/plans/<feature>/backlog.md` (small projects without a plan: `docs/plans/<project>/backlog.md`; legacy plans: next to the plan).
- Engram: one `decision` entry (`engram_mem_save`, topic `backlog/<feature>`) with the backlog path and story count.
- Final message: path, story count, the test commands (or the `none` warning), next step `/flow-story 01`.

## References

- `"/repo path/plugins/flow/skills/backlog/templates/backlog.md"`: the file template.
- Adapted from hola-ai `backlog` (github.com/nschurmann/hola-ai, MIT).
