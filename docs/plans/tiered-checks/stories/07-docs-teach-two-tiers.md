# Story 07: docs and templates teach the two tiers

## Story

07. As a developer, I want the docs, agent rules and new-repo templates to teach the two tiers so that agents stop running the full suite every turn. Requires: #01

## Acceptance criteria

- [ ] Given this repo on `main`, when I read `README.md`, `docs/multi-agent.md`, the CI workflow header, the agy Stop timeout comment in `install.sh` and idea 28, then they describe both tiers (`check-fast` between turns, `make check` at a story's end, at ship and in CI), the `check-fast` contract (a repo opts in by defining the target; without it the hook runs `make check`), and that a green hook means the fast tier passed on the branch's changes when the tree is dirty, while a clean tree runs nothing.
- [ ] Given `flow` bumped and `./install.sh` run, when a new session sets up a new repo with `/flow:foundation` and `/flow:bootstrap` (Claude, and the generated OpenCode and Antigravity copies), then the repo gets both `check-fast` and `check` targets, an `AGENTS.md` with the agent rule "A story, a ship and CI are done when `make check` passes. Between turns the hook runs `check-fast`.", and `Bash(make check-fast:*)` in its allowed permissions; the `bootstrap-one-approval`, `foundation-host-not-target` and `foundation-windows-setup` evals pass.
- [ ] Given the clean-install plan, when I read it, then its `SYS` gate row names `check-fast` = `bash -n`, shellcheck and `shfmt -d`, with the flag test and the dry-run staying in `check`, and its stage 3 row and gap 8 no longer cite idea 27 or a manual `make check` as a step.

## Plan

- This repo's docs: replace the single-gate wording with the two tiers, the `check-fast` contract and what a green hook means; idea 28's facts corrected (58 test files, already parallel runner).
- New repos: the check template, the foundation and bootstrap skills and their architecture, development, agents and permissions templates teach both targets and the agent rule; `check-fast` is static checks on changed files, no tests.
- Goldens regenerated for the changed skills, with the generator test as the focused test; the three foundation/bootstrap evals run once each, results logged.
- Clean-install rows edited on the branch that holds that plan, in a separate commit.
- Release: bump `flow`, run `./install.sh`, check criterion 2 in a new session.

## Out of scope

- The hook, its header and messages, the `check-fast` target in this repo (stories 01-03); pair and ship wording (04-06).
- `NOTCH` (story 08), `delegate-local` (09), the slow-test report (10), OpenCode's generated rule and `docs/multi-agent.md:22` (11): until 11 lands, OpenCode keeps its `make check` line.
- An agy timeout note in `docs/multi-agent.md` (dropped in story 03, L2).
- Any other clean-install change, or moving that plan to its own repo.
- This repo's `AGENTS.md`/`claude/CLAUDE.md`: neither tells agents to run `make check`, so there is nothing to replace.

## Suggestions (your call)

- No test pins the new template wording; a small assertion in an existing template test (if one reads `templates/agents.md`) would turn criterion 2's rule into a check instead of an eval. Otherwise the evals and goldens are the only guard.

## Size

normal
Risk: item 5, 6 (flow plugin release and install; docs and skill wording graded only by evals and reading)

## Log

- L1 request: /flow:story 07
- Assumptions: the plan's Docs row is the whole story, kept as one story since it fits 3 criteria. The clean-install plan lives only on the local branch `plan/clean-install` (23c656a, not on `main`; `~/Documents/MISC/clean-install-plan` does not exist yet), so "the repo that holds it" is this repo on that branch; the rows are 105 (`SYS` gate), 114 (stage 3, "`make check` by hand for that commit (idea 27)") and gap 8 in `## Data gaps & assumptions` (line 139, "Idea 27: `make check` above 300 s with a bench change"); review 3 #8 (line 227) also says "`make check` by hand" and is updated to match.
- L2 approved (2026-11-17): as proposed.
- L3 branch: `story/07-docs-teach-two-tiers` from `main` (6a4d059 story commit). Safety net green before any change: `gen-agents`, `no-sdd`, `plugins`. Test list approved (14 items; 1-5 in `tiered-docs.test.sh`, 6-10 in `flow-new-repo-tiers.test.sh`, 11 via goldens, 12 version, 13-14 manual); L2's "no template test" read corrected: Strict TDD needs tests 6-10.
- L4 user decision (2026-11-17, stop rule 2): test 1b added for `README.md:22` (the Makefile row), which the plan names and the approved list missed.
- L5 steps: 47d75b8 → 709375c (README :17, :80); 39f64fe → c71bf92 (README :22); d90e514 → 78dd269 (`docs/multi-agent.md:17`); 088c1d2 → d14641c (`install.sh:428`; its message reworded from `docs:` to `feat:` before any push); 0de78f5 → 68dec55 (`check.yml` header); 68655a4 → fa2e037 (idea 28 `Plan:` line; score kept as history); 7c1d2fc → ca51b88 (check template); 5d0c053 → a8c71ce (agents template); 02cb06a → 801b890 (permissions template); 837d70b → 6a9c9ab (architecture and development templates); 3503868 → 6ad2e81 (foundation and bootstrap `SKILL.md`, goldens regenerated: 4 files, past stop rule 5's 3 files since generated); 70ef44a (generated copies pin, green at once, 4/4 fail on the 3503868 goldens via `GOLDEN_DIR`).
- L6 release: 65af3ef (`no-sdd.test.sh` pin for flow 0.13.0) → a32a85c (flow 0.13.0). `./install.sh` run: `claude plugin list` shows flow 0.13.0 from the working copy; the installed OpenCode and Antigravity `flow-foundation` and `flow-bootstrap` copies carry the `check-fast` rule.
- L7 evals (claude plugin eval, one run of each case, $0.70): `foundation-windows-setup` with 1.00 / without 1.00; `bootstrap-one-approval` with 1.00 / without 1.00; `foundation-host-not-target` with 1.00 / without 0.00.
- L8 C3: on branch `plan/clean-install`, 24544af edits row 105 (`check-fast` = `bash -n`, shellcheck, `shfmt -d`; `check` adds the flag test and the dry-run), row 114 (`make check` at ship, not by hand, no idea 27), gap 8 (line 139, no idea 27, not a manual step) and review 3 #8 (line 227). `rg "idea 27|Idea 27"` and ``rg 'make check` by hand'`` find nothing there.
- L9 full run: `make check` "All checks passed (8 steps)" at a32a85c.
- L10 manual (C2, user, 2026-11-17): a new Claude Code session, asked which make targets `/flow:foundation` and `/flow:bootstrap` create and what each runs, answered: foundation records the recipe and bootstrap creates the Makefile (`foundation/SKILL.md:27`, `bootstrap/SKILL.md:19`); `check` = format check, lint, typecheck, tests, the gate for a story, a ship and CI; `check-fast` = format check and lint only, on changed files when the tools allow it, no tests, about 10 s, run by the Stop hook between turns, with `make check` as the fallback; `fmt` writes; bootstrap requires both green before the first commit.
- L11 verifier (flow:verifier): PASS. C1, C2, C3 PASS; each test commit red and its feat green, reproduced in a scratch clone; 70ef44a red on the 3503868 goldens; `make check` "All checks passed (8 steps)" at 6e2f328; commit order, tamper check (the L4/L5 exceptions approved) and assertions PASS. Install, evals and the new-session check rest on L6, L7 and L10. Refs and HEAD unchanged across the run.
- Risk: item 5, 6 (flow plugin release and install; docs and skill wording graded only by evals and reading) The `install.sh` comment keeps the 330 s Stop timeout (it still covers the 300 s fallback) and adds the 60 s `check-fast` limit. `flow` bump is a minor version (0.13.0); `toolkit` is untouched. Each affected eval runs once, as in stories 04-06.
