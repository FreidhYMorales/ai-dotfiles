# Plan: tiered-checks

- Status: reviewed, reviews 1 to 5 resolved; ready for handoff
- Deadline: none; lands before clean-install stage 2, which runs the most checks
- Mode: solo
- Supersedes: idea 27 (its question becomes the slow-test report below); idea 28 is this plan

Each check runs where it pays. Between turns the Stop hook runs a fast tier within about 10 s. The full suite runs once at the end of a `/flow:pair` story, at `toolkit:ship`, in CI, or on demand. Nothing runs in the background.

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| The user's Arch machine, Claude Code with the `toolkit` and `flow` plugins | yes | Current versions | This repo's `install.sh` |
| OpenCode and Antigravity, through the generated skills and rules | yes, generated output only | Current generator (`scripts/gen-agents`) | Same |
| Local workers (pi + ollama, `toolkit:delegate-local`) | SHOULD, prompt and verification only | Parked since 2026-10-19 (`docs/local-workers.md:3`) | Same |
| `QUICKSHELL NOTCH` | yes, last story | When no notch story is in progress | That repo |

- Out of scope: `SYS` itself (its minimal gate in clean-install stage 2 is born with a `check-fast` target; the docs story updates that plan's rows), CI changes.

## Research

engram `research/check-tiers` (2026-11-09) and `plan/tiered-checks-research` (2026-11-12).

- v1: the hook runs the whole 8-step `make check` at every stop with a changed tree, under `timeout 300` (`plugins/toolkit/hooks/require-check.sh:87`); no test covers the timeout path. It exits when the Makefile has no `check` target (`:49-54`).
- v1: step times on 2026-11-12 at load 1.4: `shell` 23 s over every script; `json` 0.46 s, `structure` 0.05 s, `settings` 0.12 s, `skills` 0.36 s, `workflows` 0.1 s; `tests` about 162 s and `bench` variable (idea 27).
- v1: no check script takes file arguments; each lists files with `repo_files` (`scripts/lib.sh:23`).
- v1: `scripts/run-tests.sh` already runs all 58 test files in parallel (`:40-47`) and has `TEST_SHARD=K/N`; no per-file selection by argument.
- v1: `/flow:pair` runs the full `Test command:` at every green iteration (`plugins/flow/skills/pair/SKILL.md:58`); `toolkit:ship` runs `make check` at `:16`, `:28` and `:35`.
- v1: `delegate-local` runs pi once (`-p`, `--no-session`), names the exact command the worker must pass and reruns the original tests itself, because workers delete or weaken tests (`SKILL.md:47,51,53,55-56`).
- v1: `pair`, `ship` and `delegate-local` are generated for OpenCode and Antigravity and compared byte for byte with goldens (`scripts/tests/gen-agents.test.sh:36`); OpenCode's rule says to run `make check` before done (`scripts/gen-agents/gen.sh:236`) (the allow list at `:114-134` belongs to the read-only `flow-verifier` subagent, not the main agent). `scripts/tests/no-sdd.test.sh:35-37` pins `flow` at exactly 0.10.1; the toolkit pin was relaxed to `at_least` (`:43-47`).
- v1: `NOTCH` is not opted in to `require-check`, so the hook never runs `make` there today. Its `check` = fmt-check, lint, test, qml-test, smoke; `fmt-check` and `lint` are the fast-tier candidates, unmeasured. Notch story 33 is merged; story 44 is in progress.
- v1: the hook is documented in `README.md:17,22,80`, `docs/multi-agent.md:17`, `install.sh:428` and its header; new repos get their gate from `plugins/flow/skills/bootstrap/templates/check.md` and `foundation/templates/development.md`. There is no `docs/development.md` in this repo.
- info: upstream gentle-ai runs a quick check once, sends long suites to a fresh worker or CI, ships no git hooks, never loops until clean.

## Product vision

- **v1:** between messages the hook answers in under 10 s in `AI` and `NOTCH`; TDD in `pair` loops on the focused test only; the full suite still gates every story end, every ship and CI.
- **v2:** background or remote suite runs, if the gap between turns ever hurts; per-change test selection.

## Core model

```
tier        when                         what                                    budget
fast        Stop hook, every turn        make check-fast (static, changed files)  ~10 s
focused     pair red/green steps         Single test                               seconds
full        pair final check, ship, CI   make check                                none
on demand   the user                     make check / make test                    none
```

- Hook rule: a `check-fast` target present -> run it (timeout 60 s), whether or not `check` exists; otherwise a `check` target -> run it as today (timeout 300 s); neither -> exit. Trust, cache and red-marker rules unchanged; the cache is keyed per target. The fallback path keeps today's message wording, which the agy adapter test pins (`agy-require-check.test.sh:49`).
- Changed files: uncommitted work (tracked changes vs `HEAD` plus untracked, not ignored) plus the branch's commits not on `origin/main` (merge-base, as `scripts/check-bench.sh:8-12` does); `HEAD` alone when `origin/main` is missing; all files when there is no `HEAD`. The list goes through the existing `-f` filter, so deleted and renamed paths drop out. A changed file counts as a sourced lib when any script has a `# shellcheck source=<that path>` directive for it, and then every script is linted. The mode is set by an environment variable that only the `check-fast` recipe sets, since `scripts/lib.sh:12` reads `$1` as ROOT.
- When the tree is dirty, a green hook means the fast tier passed on the branch's changes; a clean tree runs nothing. The docs say so.
- A `check-fast` timeout is reported, not blocked; a real failure blocks.
- Agent rule, in every instruction file: "A story, a ship and CI are done when `make check` passes. Between turns the hook runs `check-fast`."
- Long runs: the full suite may take minutes, so instructions say "allow up to 10 minutes (Claude: Bash `timeout` 600000)", or run it in the background and read the result; the wording stays neutral because it is generated for OpenCode and Antigravity too.

## Foundation

n/a: existing repo conventions (`AGENTS.md`, Strict TDD).

## Screens

n/a: no UI. Hook messages name the target that ran.

## Data captured / data inventory

n/a.

## Scope

| Item | Priority (MUST/SHOULD/LATER) | Est. dev-days | Demo value |
|---|---|---|---|
| Hook prefers `check-fast` (60 s), falls back to `check` (300 s) with today's wording, runs `check-fast` alone when there is no `check`; cache keyed by target; tests for both paths and the timeout path, using a stub `timeout` on `PATH` that records its arguments and exits 124, with no environment override; one agy adapter test for `check-fast`. A `check-fast` timeout (exit 124) ends the turn with a systemMessage that shows the elapsed time and does not block; on agy, whose adapter drops that message, this is documented in `docs/multi-agent.md` and covered by one adapter test; a real `check-fast` failure blocks; the `check` fallback keeps today's blocking timeout. The hook header and its trust and red-marker messages are updated here, with their tests. Evidence includes one `make mutate HOOKS=require-check` run, logged, not a gate. Risk: items 3 and 5, verifier | MUST | 0.8 | A turn ends in seconds |
| `AI` `check-fast` target: `check-shell.sh` gains the changed-files mode per the core model (environment variable, merge-base list, sourced-lib rule), plus json, structure, settings, skills and workflows over the repo; no tests or bench; shellcheck runs in parallel (`xargs -P"$(nproc)"`); the recipe sets the mode variable inline on the `check-shell.sh` call only and calls the other steps directly; `check.sh` unsets it on the full path so `make check` always lints every script; tests for a deleted file, a repo with no `HEAD`, no `origin/main`, a changed `lib.sh`, and `make check` with the variable exported; measured under 10 s for a small change, and the full-lint case measured well under 60 s, each at idle and under load. Risk: item 5, verifier | MUST | 0.8 | Docs-only and small edits skip the suite |
| `/flow:pair`: red and green steps loop on `Single test:`, or on `Test command:` when the backlog has no `Single test:` or it is `none`; the `Test command:` runs on the final tree, with the long-run wording: again after any step-6 fix, before the verifier's recheck and before the merge offer. A red final suite starts a regression round: for each regression, show the existing failing test's output (no `test:` commit, no red marker), commit a `fix:`, rerun that test file; if the old test must change, stop rule 3 applies; if the `Test command:` is still red after the round, stop rule 4 applies. A refactor reruns the focused test; "do N" keeps the same rule. A full run is repeated only when something changed since the last green full run: record that run's `HEAD`, and rerun when the tree is dirty or `git diff --name-only <sha>` lists anything besides the story file and the backlog; the verifier's own run counts only when its report shows the command and its pass line, and the `docs:` close commit does not invalidate it. `plugins/flow/agents/verifier.md` gets the long-run wording as a new line under its checks, not inside its pinned Hard Rules (`scripts/tests/flow-verifier.test.sh:52-61`), and one line in check 3: a regression-round `fix:`, logged in the story `## Log` and naming the existing test it turns green, needs no new `test:` commit. Goldens regenerated, with `bash scripts/tests/gen-agents.test.sh` as the focused test; evals updated and budgeted, with `pair-empty-verifier-report` re-graded; bumps `flow` and reruns `./install.sh`. The generator matches `pair` text (`scripts/gen-agents/gen.sh:63,80-81`; pinned by `gen-agents.test.sh:184-185,347-349`): the step numbers stay, with the regression round inside step 6, and the step 6 verifier sentence stays word for word; if either must change, the `gen.sh` patterns change in the same story, and a renumbering pre-approves the change to `gen-agents.test.sh:185`. Risk: item 6, verifier | MUST | 1.0 | TDD without the full suite per iteration |
| `toolkit:ship`: `make check` once before the commit, with the long-run wording; again only when a rebase changed the tree; goldens regenerated, `gen-agents.test.sh` as the focused test; bumps `toolkit` and reruns `./install.sh`. Risk: item 6, verifier | MUST | 0.25 | One full run per ship |
| Docs: `README.md` (`:17,22,80`), `docs/multi-agent.md`, `install.sh:428`, the `.github/workflows/check.yml` header comment, and idea 28 in `docs/ideas.md` (58 test files) describe the tiers, the `check-fast` contract and what a green hook means. New repos: `bootstrap/templates/check.md`, `bootstrap/SKILL.md:19`, `foundation/SKILL.md:27`, `foundation/templates/development.md`, `agents.md:26` and `architecture.md:67-72` teach both targets and the agent rule, and `foundation/templates/permissions.md` adds an explicit `Bash(make check-fast:*)`; goldens regenerated where a `SKILL.md` changes. The docs say "when the tree is dirty, a green hook means the fast tier passed on the branch's changes"; a clean tree runs nothing. Done also means clean-install's `SYS` gate row names `check-fast` = `bash -n`, shellcheck and `shfmt -d`, with the flag test and the dry-run staying in `check`, and its stage 3 row and gap 8 no longer cite idea 27 as a manual step, committed in whichever repo holds that plan at the time; skill bumps follow the release rule. Risk: item 6, verifier | MUST | 0.45 | Other repos can opt in |
| `NOTCH`: `check-fast` = `fmt-check` + `lint`, measured under 10 s (only changed files if not); `AGENTS.md:35`, `docs/development.md:3,62,118` and `docs/architecture.md:99,109` get the agent rule and the two targets, and `AGENTS.md` says the hook checks formatting and `make fmt` is the fix; the backlog's `Single test:` becomes `node --test <test file>` so QML probes have a focused command. Acceptance: `require-check.trusted` is set only after `make fmt-check lint` is green on `NOTCH` `main` (checked first, before any change), `check-fast` is on `main`, and every unmerged local branch has `main` merged in or is gone; the local copies of `feat/27-wallpaper-foundation` (72 own commits) and `feat/34-quick-wallpaper` (149) are deleted after `git branch -vv` shows each matches its `origin/` branch; the remote branches stay. Run when no notch story is in progress. Risk: item 5, verifier | MUST | 0.35 | The notch gets a gate that does not block |
| Release: once the hook and `AI` `check-fast` are on `main`, bump the `toolkit` plugin version for the hook and run `./install.sh`; demo 1 is checked on the installed plugin in a new Claude Code session, since hooks load at session start. agy runs the hook from the working copy (`install.sh:430-436`), so no agy session runs in `AI` while the hook story is open. Pre-approved test change: `scripts/tests/no-sdd.test.sh:35-37` relaxed to `at_least 0.10.1`, as `:43-47` did for toolkit, so later `flow` bumps pass. Each later skill story bumps its own plugin and reruns `./install.sh`. Risk: item 5, verifier | MUST | 0.15 | The change reaches the running agent |
| `delegate-local`: the worker's prompt names the `Single test:` command; no retry, since pi runs once; after applying the diff Claude reruns the full `Test command:`; goldens regenerated. Risk: item 6, verifier | SHOULD | 0.25 | Local workers start on the focused test |
| `make test` prints the five slowest test files with their times; shows where the tests step spends its time; idea 27's bench question stays open | SHOULD | 0.25 | Shows where the suite's time goes |
| OpenCode's generated rule follows the agent rule and runs `make check-fast` before done; `docs/multi-agent.md:22` updated; goldens regenerated; the changed `gen-agents.test.sh:125-126` assertion is pre-approved in the story. Until it lands, generated OpenCode rules keep their current line | SHOULD | 0.15 | OpenCode stops paying the full suite per turn |
| Background or remote suite runs | LATER | 0.5–1 | Earlier red without waiting |

Running MUST total: about 3.8 dev-days (4.05 if the `NOTCH` fast tier needs a changed-files mode), against no deadline; SHOULD 0.65. Order: hook, `AI` `check-fast`, release, `pair`, `ship`, docs, `NOTCH`, then the SHOULD items. Every MUST story names its high-risk item and gets a fresh verifier.

## Demo data

n/a: the existing test fixtures cover hooks and skills.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| 1. When the full suite runs | Only at the pair final check, ship, CI and on demand; never in the background (option A) | user | yes |
| 2. `NOTCH` in v1 | Yes, as the last MUST story, when no notch story is in progress; trusted only after `check-fast` is on its `main` and merged into every open story branch | user | yes |
| 3. Hook budget | About 10 s; `check-fast` timeout 60 s as a safety net | user, planner | yes |
| 4. A repo with no `check-fast` | Keeps today's behaviour: `make check`, 300 s | planner | yes |
| 5. Whether `NOTCH` `fmt-check` + `lint` fit 10 s | Measured in that story; if not, only changed files are formatted and linted | planner | no |
| 6. A red suite noticed late | Accepted: it surfaces at the story's final check, ship or CI | user | yes |
| 7. A red final suite in `pair` | A regression round: one `fix:` per existing failing test; stop rule 3 if an old test must change; stop rule 4 if the suite is still red after the round | user, planner | yes |
| 8. What "changed files" covers | Uncommitted work plus the branch's commits not on `origin/main` | user | yes |
| 9. Agent instructions | "A story, a ship and CI are done when `make check` passes. Between turns the hook runs `check-fast`." | user | yes |
| 10. A `check-fast` timeout | Reported as a systemMessage, never blocking; a real failure blocks | user | yes |
| 11. `NOTCH` stale branches | Local copies of `feat/27` and `feat/34` deleted; both stay on `origin` | user | yes |

## Deferred to v2

- Background or remote suite runs: competes with local models for CPU and NPU; option A chosen.
- Per-change test selection: needs a map from files to tests; the focused test covers the TDD loop.
- A worker retry with the failure tail in `delegate-local`: no loop exists and the feature is parked.

## Demo priorities

1. A docs-only change ends the turn in seconds with no tests run.
2. A `pair` story loops on its focused test and runs the suite once at the end, plus the verifier's own run in a high-risk story.
3. `ship` runs `make check` once and CI stays green.

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: the `check-fast` Makefile target as the hook's fast tier
- Work packages: n/a

## Plan-review resolutions

Findings refer to `plan-review-1.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | No rule for a red final suite in `pair` | One red-to-green step per regression on the same branch; a second failure triggers stop rule 4; no per-cycle suite in Mode B | user |
| 2 | `delegate-local` has no retry loop and narrowing verification drops a safeguard | SHOULD; no retry; the worker gets the `Single test:` command and Claude reruns the full `Test command:` after applying | user |
| 3 | `NOTCH` is not trusted, so its `check-fast` has no effect | Trusted in the same story that adds `check-fast`, which stays the last MUST | user |
| 4 | Templates and the clean-install `SYS` row describe one gate | `bootstrap` and `foundation` templates join the docs row; clean-install row 105 is updated at that plan's next `/flow:fill-gaps` | planner |
| 5 | `docs/development.md` does not exist | Docs row retargeted to `README.md`, `docs/multi-agent.md`, `install.sh:428` and the hook header | planner |
| 6 | Generated goldens and OpenCode's rule | Each skill story regenerates its goldens; OpenCode's rule moves to `check-fast` and allows it (SHOULD, question 4) | user, planner |
| 7 | A real timeout test would be slow | Stub `timeout` on `PATH` that records its arguments and exits 124; no environment override | planner |
| 8 | Story 33 is already merged | Condition is now "no notch story in progress" | planner |
| 9 | Idea 27 wording differs from the plan | `docs/ideas.md` updated: idea 27 becomes the SHOULD slow-test report | planner |
| 10 | No `Single test:` fallback | `pair` uses `Test command:` when `Single test:` is missing or `none` | planner |
| 11 | Changed-files edge cases | Reuse the `-f` filter; all files with no `HEAD`; tests for a deleted file and a repo with no `HEAD` | planner |
| 12 | Verifier only for hook and `pair` | `Makefile`, `ship` and `delegate-local` stories name their high-risk item and get a verifier | planner |
| 13 | `check-fast` without `check` | The hook runs `check-fast` alone | planner |
| Risks | Bash tool timeout, unlinted commits, eval cost, agy parser, parallel sessions | 600 s Bash timeout in `pair` and `ship`; docs state what a green hook means; eval runs budgeted in the `pair` story; fallback wording kept and one agy test; `ship` always runs `make check` | planner |

Findings below refer to `plan-review-2.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | Trusting `NOTCH` runs its full suite on branches without `check-fast` | Trust only after `check-fast` is on `NOTCH` `main` and merged into every open story branch; an acceptance criterion of that story | user |
| 2 | Agent instructions still demand `make check` every turn | New agent rule in `NOTCH` `AGENTS.md` and `development.md` and in the foundation and bootstrap skills and templates; goldens regenerated | user, planner |
| 3 | Regression rule clashes with Strict TDD and stop rule 3 | Regression round defined: failing test output, a `fix:` commit, rerun that file; stop rule 3 if the old test must change; stop rule 4 if the suite is still red after the round | planner |
| 4 | No full rerun after step-6 fixes | The `Test command:` runs on the final tree: again after any step-6 fix, before the verifier recheck and the merge offer | planner |
| 5 | Verifier runs the suite with no timeout guidance | `verifier.md` gets the long-run wording; its golden regenerated; counted in the `pair` row | planner |
| 6 | `lib.sh` re-lint dropped; `$1` read as ROOT | Mode set by an environment variable only the `check-fast` recipe sets; every script linted when a sourced lib changes | planner |
| 7 | Committed work never reaches the fast tier | Changed files include the branch's commits not on `origin/main`, falling back to `HEAD` | user |
| 8 | Stale messages, CI comment, README, idea 28 | Added to the docs row | planner |
| 9 | Claude-only timeout wording in generated skills | Neutral wording: "allow up to 10 minutes (Claude: Bash `timeout` 600000)", or run in the background | planner |
| 10 | `NOTCH` `Single test:` misses QML probes | The backlog line becomes `node --test <test file>` in the `NOTCH` story | planner |
| 11 | Clean-install rows have no owner | The docs story's done criterion includes them | planner |
| Risks | Untrusted branches, agents running the suite, budget under load, Bash ceiling, golden drift | Findings 1 and 2; `check-fast` measured under load; background run allowed; `gen-agents.test.sh` as the focused test of every skill story | planner |

Findings below refer to `plan-review-3.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | No release step | New MUST row: bump `toolkit` and `flow` and run `./install.sh` once the hook and `AI` `check-fast` are on `main`; demo 1 checked on the installed plugin | planner |
| 2 | Full lint near the 60 s timeout; a timeout blocks as a false red | Parallel shellcheck; full-lint case measured idle and under load; a `check-fast` timeout reports without blocking (question 1) | user, planner |
| 3 | Mode variable can leak into `make check` | `check.sh` unsets it, with a test | planner |
| 4 | No detection method for sourced libs | `# shellcheck source=<path>` directives decide | planner |
| 5 | Verifier check 3 rejects regression `fix:` commits | One line in check 3; golden regenerated | planner |
| 6 | Full runs not deduplicated | Rerun only when code or tests changed since the last green full run; the verifier's run counts; a `docs:` close does not invalidate it (question 3, decided by the planner since an unchanged tree proves nothing new) | planner |
| 7 | `NOTCH` unmerged non-story branches | `feat/27` and `feat/34` deleted when `git log main..<branch>` is empty; the user is asked otherwise (question 2) | user |
| 8 | `Risk:` labels not on the high-risk list | Item numbers: hook 3 and 5, `Makefile` 5, prompts 6 | planner |
| 9 | Permissions template and a changed assertion | `Bash(make check-fast:*)` added to the template; `gen-agents.test.sh:125-126` pre-approved in the OpenCode story | planner |
| 10 | "Green hook" wrong on a clean tree; OpenCode line false before the SHOULD | Docs say "when the tree is dirty"; OpenCode keeps its line until the SHOULD lands | planner |
| Risks | Old plugin installed, false red, `fmt-check` mid-edit, verifier vs regression round, suite cost at story ends | Release row; non-blocking timeout; `NOTCH` `AGENTS.md` names `make fmt`; verifier line; deduplicated runs | planner |

Findings below refer to `plan-review-4.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | A `flow` bump breaks the exact pin in `no-sdd.test.sh` | The release story pre-approves relaxing `:35-37` to `at_least 0.10.1` | planner |
| 2 | `NOTCH` stale branches hold real work | Local copies deleted after `git branch -vv` shows they match `origin`; the remote branches stay | user |
| 3 | Two owners for the clean-install rows | The docs story owns them, committed where that plan lives; its gap 8 included; the fill-gaps clause removed | planner |
| 4 | OpenCode auto-allow list is the verifier's | Auto-allow dropped from the OpenCode row; Research corrected | planner |
| 5 | `unset` in `check.sh` could cancel the fast mode | The recipe sets the variable inline on `check-shell.sh` only and calls the other steps directly; `unset` only on the full path | planner |
| 6 | Docs, `NOTCH` and Release rows name no high-risk item | Docs item 6, `NOTCH` item 5, Release item 5; every MUST story gets a verifier | planner |
| 7 | Release order versus the plugins it bumps | Release bumps `toolkit` for the hook only; each skill story bumps its own plugin and reruns `./install.sh` | planner |
| 8 | `NOTCH` `docs/architecture.md:99` left out | Added to the `NOTCH` row | planner |
| 9 | agy hides the timeout message | Documented in `docs/multi-agent.md`, with one adapter test | planner |
| 10 | Verifier Hard Rules pinned line by line; eval interaction | Long-run wording as a new line under its checks; `pair-empty-verifier-report` re-graded | planner |
| 11 | Gap table order | Reordered | planner |
| Risks | Stage 3 `git init`, uncached timeouts, stalled trust, self-reported verifier run | Full-lint measurement and the relaxed pin; elapsed time in the timeout message; branch decision taken now; the verifier's run counts only with the command and its pass line shown | planner |

Findings below refer to `plan-review-5.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | The generator matches `pair`'s step numbers and verifier sentence | Step numbers and the sentence stay; otherwise `gen.sh` patterns change in the same story and `gen-agents.test.sh:185` is pre-approved | planner |
| 2 | Hook messages edited in the docs story | Moved into the hook story, before the release | planner |
| 3 | Slow report does not answer idea 27 | Reworded; the bench question stays open | planner |
| 4 | Demo 2 says one full run | Both runs kept (question 1); demo 2 names the verifier's run | user |
| 5 | "Changed since the last green run" undefined | Recorded `HEAD` plus a dirty-tree check; the story file and backlog do not count | planner |
| 6 | `NOTCH` `docs/architecture.md:109` | Added to the `NOTCH` row | planner |
| 7 | `SYS` fast tier contents undefined | `bash -n`, shellcheck, `shfmt -d`; the flag test and dry-run stay in `check` | planner |
| 8 | "agy adapter parses" | Reworded: its test pins the prefix | planner |
| 9 | No mutation evidence for the hook | One logged `make mutate HOOKS=require-check` run | planner |
| Risks | New session, agy working copy, `NOTCH` already red, untested merge, uncommitted plans | Demo 1 in a new session; no agy in `AI` during the hook story; `fmt-check lint` green on `NOTCH` `main` first; merge gap accepted (gap 6); both plan folders committed before handoff | planner |
