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
- L2 approved (2026-11-17): as proposed, no template test added. The `install.sh` comment keeps the 330 s Stop timeout (it still covers the 300 s fallback) and adds the 60 s `check-fast` limit. `flow` bump is a minor version (0.13.0); `toolkit` is untouched. Each affected eval runs once, as in stories 04-06.
