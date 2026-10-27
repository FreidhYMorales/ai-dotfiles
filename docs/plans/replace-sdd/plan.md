# Plan: replace-sdd

- Status: approved (reviews 1 and 2 resolved)
- Deadline: none
- Mode: solo
- Supersedes: the `sdd` plugin and `/sdd:*` commands; `flow:handoff`'s SDD output and `tasks.md`; item 5 of `docs/plans/multi-agent-port/plan.md` (port SDD agents). Idea: `docs/ideas.md` #01.

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| Claude Code on Linux (Arch) | yes | current pinned version | this marketplace (`flow`, `toolkit`, `look`) |
| OpenCode, Antigravity | later | n/a | `multi-agent-port` (resumes after this plan) |

- Out of scope: porting the new skills to other agents (that is `multi-agent-port`).

## Research

Engram `research/sdd-alternatives-2026-10` and `plan/replace-sdd-research`. Sources in `docs/ideas.md` #01.

- hola-ai (github.com/nschurmann/hola-ai, MIT): `backlog`, `story`, `pair` skills, manual invocation only. Backlog: 10-15 one-line vertical stories, no estimates, #1 is the walking skeleton, sections `## Context` + `## Backlog`. Story: 2-3 Given/When/Then criteria (more → split), ≤5-bullet plan without file names, `## Out of scope`, `## Suggestions`. Pair: approved test list, one red→green step, stop rules, never commits. (v1)
- gentle-ai ODD (MIT): task size rule (understood within one bounded read, contained risk, resumable from request + `git diff`; file counts never decide); six high-risk items; `Risk:` line at close; independent read-only verifier only when a high-risk item is named; one correction batch then "needs your decision". Task file: header, `S#` specs quoted verbatim, one-line tasks with RED→GREEN and sha, `## Log`. (v1)
- From `plugins/sdd`, keep condensed: `skills/sdd-apply/strict-tdd.md` (assertion-quality rules), `skills/sdd-verify/strict-tdd-verify.md` + `references/report-format.md` (verifier checklist), `skills/sdd-design/references/threat-matrix.md` (security item), `references/init-details.md` (test-runner detection). Drop the rest. Move `plugins/sdd/upstream/` to `docs/upstream/` (also the toolkit reference). (v1)
- Local models (`plugins/toolkit/skills/delegate-local/SKILL.md:36-47`): good at one-function steps with a check, weak at long instructions, and they weaken tests: pair steps fit them; stories stay on a strong model. (v1)

## Product vision

- **v1:** a daily loop `flow:backlog` → `flow:story` → `flow:pair` that plans just in time, works in small Strict TDD steps with the test committed before the code, and sizes verification by risk. `sdd` is gone; the full `/flow:plan` path stays for new projects and large ideas and ends in a backlog.
- **v2 (later):** port the loop to OpenCode and Antigravity (`multi-agent-port`); phase indicator (exploring/implementing/reviewing) in the `look` band; local-model pair steps through `delegate-local` by default.

## Core model

- **Backlog** `docs/plans/<feature>/backlog.md` (small projects: `docs/plans/<project>/backlog.md`). Sections `## Context` (what, stack, expensive decisions, `Test command: <cmd>`) and `## Backlog`. Line grammar: `NN. [s] As a <who>, I want <what> so that <why>.[ Requires: #N(, #N)*]` where `[s]` is `[ ]`, `[~]` (in story), `[x] <sha>`, `[-] split → #NN, #NN` or `[-] dropped`. `NN` is a stable ID, never reused: reorder moves lines, a split gets new IDs. Solo source for `handoff` and `next`; collaborative `split`/`integrate` keep `tasks.md` (owners, files, statuses), and `next` reads `tasks.md` when present, else the backlog.
- **Invocation:** `backlog` and `story` are model-invocable with narrow triggers; `pair` is slash-only (`disable-model-invocation: true`), its eval runs as a `/flow:pair` prompt case.
- **Test command:** `flow:backlog` detects it once (condensed init-details: Makefile target, package scripts, language runner) and writes it to `## Context` together with `Single test: <cmd> <file>`; pair stops with "no runnable test" when it is missing. For markdown-skill stories the test is a bash structural test in `scripts/tests/` (sections and contract strings); evals are the story's acceptance check, not the red test.
- **Story** `docs/plans/<feature>/stories/NN-<slug>.md`: `## Story`, `## Acceptance criteria` (2-3 Given/When/Then checkboxes), `## Plan` (≤5 bullets), `## Out of scope`, `## Size` (small | normal, plus `Risk: item N (reason)` or `Risk: none`), `## Log` (request verbatim, then decisions and evidence). Small stories may stay in chat with no file.
- **Pair start:** create branch `story/NN-<slug>`; propose the test list (names and level only) and wait for approval.
- **Pair step** (mode C, default): one test → run it and show the real failure → commit `test(<scope>): …` → minimal code → green → commit `feat|fix(<scope>): …` → optional `refactor(<scope>): …` while green → short status → ask. "do N" = N steps. **Mode B** for small stories: cycles until done or a stop rule, same commits, one summary with the `Risk:` line. Any high-risk item forces C; local-model steps always C. Unlike hola-ai, pair commits by itself (decision: the committed test is the tamper evidence).
- **Red state and the Stop hook:** while a red test is committed, pair writes a marker at `$(git rev-parse --git-path flow-pair-red)` holding the branch and the red test commit sha. `require-check` honours it only when the current branch matches and HEAD contains that commit, and then reports through a JSON `systemMessage` instead of blocking. pair removes it on green and deletes stale markers at start. Before any stop, pair commits bookkeeping by named paths only (never `git add -A`); uncommitted code on a stop is left as is and reported. pair never bypasses git hooks (`--no-verify`); a hook that rejects a red commit is a stop.
- **Branch and merge:** one branch per story, push only after green. pair ends by offering `git merge --no-ff story/NN-<slug>` into `main` after the user's OK; never squash or rebase-merge.
- **Chat-only stories:** allowed only for small stories with `Risk: none`; anything else gets a story file.
- **Claude-only for now:** `backlog`, `story`, `pair` are excluded from `link_skills` (OpenCode/Antigravity) until `multi-agent-port`.
- **Stop rules** (both modes): a design decision is needed; something unrequested would be added; an existing test would change; two failed attempts; a step over ~50 lines or 3 files.
- **High-risk verifier:** when the story names a high-risk item, a fresh agent (`flow:verifier`, tools Read, Grep, Glob, Bash; read-only by rule) checks the diff against the acceptance criteria, the condensed TDD rules and, for security, the threat matrix. One correction batch, one recheck, then "needs your decision". The six high-risk items are numbered once in `plugins/flow/skills/pair/references/high-risk.md` (written by story 02); `claude/CLAUDE.md` points to it. Condensed references live in the same folder.
- **Done:** backlog line gets `[x] <sha>` (sha = last code commit of the story); for skill stories, the `make eval` result is recorded in `## Log`; backlog, story and log edits go in a final `docs(<scope>):` commit; engram gets one summary per story; story file stays in git.
- **Legacy paths:** plan lookup is `docs/plans/<feature>/` first, then `openspec/changes/<change>/`. Existing legacy plans stay read-write (reviews and resolutions are still written next to them) so proyecto_san_sebastian keeps working; only new plans go to `docs/plans/`. `openspec/specs/` in this repo is frozen history (README line); behaviour changes are recorded in story files.

## Foundation

n/a: existing project (`docs/development.md`, `make check`, Strict TDD, conventional commits).

## Screens

No UI. The "screens" are the files and the terminal loop.

### Backlog location

- Chosen: A, adjusted: file per plan dir (`docs/plans/<feature>/backlog.md`), stories in `stories/`.
- Rules: one line per story; the format is fixed so skills can parse and edit it.

| UI element | Backlog demand |
|---|---|
| Now/next/done list | fixed one-line story format with status marker |
| Mark done | pair writes `[x] <sha>` |
| Detailed story | throwaway-light `stories/NN-<slug>.md`, kept in git |

### Pair step

- Chosen: C (one step, auto commits test then code, "do N"), with B for small stories.
- States: red shown → test committed → green → code committed → ask; stop → reason + "your call".

| UI element | Backlog demand |
|---|---|
| Red shown | run the test, print real failing output before writing code |
| Test-before-code commit | pair may commit; `git diff <test-commit>` on test files before each code commit |
| Stop rules | checked every step in both modes |
| "do N" | step counter, same stop rules |

### Planning front

- Chosen: C: daily work goes straight to `flow:backlog`; `/flow:plan` (+ review, fill-gaps, foundation) only for new projects or large ideas, and its handoff writes the backlog.

## Data captured / data inventory

| Screen | Data shown | Actions (events) | Source |
|---|---|---|---|
| Backlog | stories, status, requires | add, split, reorder, mark in story/done | `backlog.md` |
| Story | criteria, plan, out of scope, size, risk | approve, edit, split | `stories/NN-*.md` |
| Pair | test name, red output, diff size, commits | next step, do N, stop | git, test runner |

## Scope

Written as the first backlog in the new format: `docs/plans/replace-sdd/backlog.md`. Summary:

| Item | Priority | Est. dev-days | Demo value |
|---|---|---|---|
| Story 01: `flow:backlog` (+ test and single-test detection, line grammar with `[-]`, structural test, eval, `flow` minor bump, hola-ai entry in `upstreams.json`) | MUST | 0.5-0.75 | high |
| Story 02: `flow:story` (+ `pair/references/high-risk.md`, structural test, eval) | MUST | 0.5-0.75 | high |
| Story 03: `flow:pair` modes C/B, branch, test list, stop rules, condensed strict-tdd, hardened red marker with hook tests, Claude-only `link_skills` exclusion with install test, merge offer, `work-unit-commits` exception, eval | MUST | 1.5-1.75 | high |
| Story 04: `flow:verifier` agent + condensed verify/report/threat matrix | MUST | 0.5-0.75 | high |
| Story 05: handoff writes the backlog (solo); `next` reads `tasks.md` when present, else the backlog; split/integrate keep `tasks.md`; lookup `docs/plans` then read-write `openspec/changes` in plan, plan-review, fill-gaps, research, foundation, handoff; `idea` wording | MUST | 1-1.25 | medium |
| Story 06: `claude/CLAUDE.md` sizing/risk rules pointing to `high-risk.md`, new Workflow line, keep "Strict TDD: enabled" and the SDD sentence (≤59 lines) | MUST | 0.25-0.5 | high |
| Story 07: retire `plugins/sdd`: `rg -iw sdd` clean except an allowlist (install migration block, `install.test.sh`, `docs/upstream/`, `docs/plans/`, `docs/ideas.md`, `openspec/changes/archive/`, `packs/vendor/`) asserted by a test; marketplace + description; `install.sh` uninstall + dangling-link prune with tests; `docs/upstream/`; `chained-pr`; `openspec/config.yaml`; remove the SDD sentence from `CLAUDE.md`; `docs/multi-agent.md` (loop skills Claude-only); version bumps. Gated on the quickshell change being archived | MUST | 1.25-1.75 | medium |
| Story 08: update `multi-agent-port` plan (every SDD mention; port `backlog`/`story`/`pair`/`verifier`) | SHOULD | 0.25 | low |

Total MUST ≈ 5.5-7.5 dev-days; no deadline.

## Demo data

This change itself: run `flow:story` and `flow:pair` on the stories of `backlog.md` once stories 01-03 exist (dogfooding).

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| Invocation of the loop skills | `backlog`, `story` model-invocable with narrow triggers; `pair` slash-only; `verifier` is an agent | user | yes |
| hola-ai text reuse | MIT confirmed (`gh api repos/nschurmann/hola-ai/license`); entry in `upstreams.json` in story 01 | me | yes |
| What happens to `openspec/` | `openspec/specs/` frozen history; `openspec/changes/archive/` stays; `openspec/config.yaml` removed in story 07 | me | yes |
| Other projects on SDD | `QUICKSHELL NOTCH` has `notch-workspaces-osd` open (24/27 tasks, `/sdd:*` in use); `proyecto_san_sebastian` has `ruta-recoleccion-software` as a collaborative flow plan under `openspec/changes/` (no `/sdd:*`) | user + me | yes: story 07 waits for the quickshell archive; flow keeps the legacy path |
| Old engram `sdd/*` and `sdd-init/*` topics | ignored by the new skills; noted in story 07 | me | yes |
| Generic skill names (`backlog`, `story`, `pair`) in flat OpenCode/agy dirs | excluded from `link_skills` in v1; prefixes decided in `multi-agent-port` | user + me | deferred |
| `flow` update reaching proyecto_san_sebastian before 2026-10-29 | allowed, because `next` keeps reading `tasks.md` and the legacy path stays read-write | user | yes |
| `toolkit:judgment-day` overlaps the verifier | keep it as an explicit dual review; the verifier is the default for high-risk | me | no |
| Evals for the new skills | one fires / one does-not-fire case per skill, like the existing flow evals | me | no |

## Deferred to v2

- Port to OpenCode and Antigravity — `multi-agent-port`.
- Phase indicator in the `look` band — nice to have.
- Default local-model pair steps — `delegate-local` is still a draft.

## Demo priorities

1. `flow:backlog` turns an idea into a numbered backlog with a walking skeleton.
2. `flow:story` produces criteria, a plan and a `Risk:` line.
3. `flow:pair` shows red, commits the test, then the code; stops on a test change.
4. A high-risk story triggers the verifier.

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: n/a
- Work packages: n/a

## Plan-review resolutions

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| R1.1 | `require-check` overrides pair stop rules on a red commit | red marker honoured by the hook; bookkeeping committed before any stop; regression test in story 03 | planner |
| R1.2 | `work-unit-commits` demands test and code in one commit | add an exception: `test:` + `feat:` pair is one work unit, no squash | user (Q5) |
| R1.3 | backlog lacks split/next fields | backlog is the solo source; collaborative split/integrate keep `tasks.md` | user (Q1) |
| R1.4 | installer never uninstalls `sdd` nor prunes links | story 07: uninstall when present + prune dangling repo links, with install tests | planner |
| R1.5 | no per-project test command | `Test command:` in backlog Context, detected by `flow:backlog`; pair stops if missing; remove `openspec/config.yaml` | planner |
| R1.6 | skill stories have no real red test | bash structural test is the pair test; evals are acceptance; stories 01-03 built without the loop | user (Q4) |
| R1.7 | hola-ai test list, refactor, commit reversal | approved test list first; optional `refactor:` commit; self-commit recorded as a decision | planner |
| R1.8 | story IDs break on reorder/split | stable never-reused IDs; pinned line grammar | planner |
| R1.9 | sha vs bookkeeping commit | sha = last code commit; bookkeeping in a `docs:` commit | planner |
| R1.10 | path cleanup misses skills | story 05 lists plan, plan-review, research, foundation, handoff, idea; legacy `openspec/changes` kept as fallback (proyecto_san_sebastian uses it) | planner |
| R1.11 | story 07/08 lists incomplete | story 07 acceptance = no `rg -i sdd` hit outside archives/history; story 08 covers every SDD mention | planner |
| R1.12 | CLAUDE.md Workflow line and Strict TDD | story 06 rewrites the Workflow line, keeps "Strict TDD: enabled"; `pair`/`verifier` listed Claude-only in `docs/multi-agent.md` | planner |
| R1.13 | `openspec/specs/` drift | frozen history (README line); behaviour changes live in story files | planner |
| R1.14 | no version bumps | `flow` minor bump in story 01; marketplace and versions in story 07 | planner |
| R1.15 | verifier tools, reference paths, risk list home | verifier gets Bash, read-only by rule; references in `pair/references/`; list numbered in `CLAUDE.md` | planner |
| R1.16 | uncosted evals/references/migration tests | added to the scope estimates (4.75-6.5 MUST) | planner |
| R1.Q2 | red commits on `main` | one branch per story, no squash, push after green | user |
| R1.Q3 | other projects on SDD | quickshell `notch-workspaces-osd` (24/27) must be archived before story 07; san_sebastian needs only the legacy path | user + planner |

| R2.1 | stale red marker disables `require-check` | marker holds branch + sha, found with `git rev-parse --git-path`, honoured only when both match; stale markers cleaned at pair start; `systemMessage` report; hook tests for stale marker and wrong branch | planner |
| R2.2 | high-risk list needed before story 06 | written by story 02 in `pair/references/high-risk.md`; `CLAUDE.md` points to it | planner |
| R2.3 | explicit-use vs evals and routing | `backlog`, `story` model-invocable with narrow triggers; `pair` slash-only | user (Q1) |
| R2.4 | loop skills already linked to OpenCode/agy | excluded from `link_skills` with an install test (story 03); `docs/multi-agent.md` in story 07 | user (Q2) |
| R2.5 | story 07 `rg` check cannot pass | `rg -iw sdd` with an explicit allowlist, asserted by a test | planner |
| R2.6 | `next`, legacy path and lookup order | `next` reads `tasks.md` when present, else backlog; lookup `docs/plans` then `openspec/changes`; legacy plans read-write; `fill-gaps` added | planner + user (Q4) |
| R2.7 | single-test command | `Single test:` in backlog Context | planner |
| R2.8 | SDD sentence removed too early | story 06 keeps it; story 07 removes it | planner |
| R2.9 | split/dropped status | `[-] split → #NN, #NN` and `[-] dropped` | planner |
| R2.10 | merge owner | pair offers `git merge --no-ff` after OK; never squash/rebase | user (Q3) |
| R2.11 | chat-only stories | only small + `Risk: none` | planner |
| R2.12 | evals skippable | Done for skill stories records the `make eval` result in `## Log` | planner |
| R2.13 | hola-ai licence | MIT confirmed; `upstreams.json` entry in story 01 | planner |
| R2.risks | bookkeeping sweeps untracked files; hooks reject red commits | stage named paths only; never `--no-verify`, rejection is a stop | planner |

Review files: `plan-review-1.md`, `plan-review-2.md`. No third review: remaining risk is cheaper to catch in pair steps (user agreed).
