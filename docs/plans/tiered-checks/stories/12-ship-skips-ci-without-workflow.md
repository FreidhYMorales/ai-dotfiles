# Story 12: ship skips the CI watch when no workflow is active

## Story

12. As a developer whose GitHub Actions are disabled, I want ship to skip the CI watch when the repo has no active workflow so that shipping ends at a green make check and a push.

## Acceptance criteria

- [ ] Given a repo whose workflows are all disabled or absent (`gh workflow list --all` shows none `active`), when ship pushes, then it looks for no run, says CI was skipped because no workflow is active, and reports done with `make check` green and the pushed SHA.
- [ ] Given a repo with an active workflow, when ship pushes, then it still finds the run for the pushed SHA and watches it until it is green, as today.
- [ ] Given the change, when I run `make check` and read the generated OpenCode copy of the skill, then it carries the rule, the `toolkit` plugin is bumped and installed with `./install.sh`, and `make check` is green.

## Plan

- The "no CI workflow" gate widens to "no active workflow", checked with `gh workflow list --all` after the push.
- The "done means CI is green" rule and the CI-watch step apply only when a workflow is active; otherwise done is `make check` green plus the push.
- The output names the skip instead of a run URL.
- Goldens regenerated, `bash scripts/tests/gen-agents.test.sh` as the focused test; `toolkit` bumped and reinstalled.

## Out of scope

- Re-enabling, deleting or editing `.github/workflows/check.yml`; the workflow stays disabled on GitHub.
- Docs that mention CI (`README.md`, `docs/multi-agent.md`, the `check.yml` header) and `/flow:pair`, which watches no CI.
- The Antigravity copy: no criterion checks it; its golden regenerates only because `gen-agents.test.sh` pins it.
- Stories 10 and 11.

## Suggestions (your call)

- none

## Size

normal
Risk: item 6 (skill prompt wording; no test would catch ship watching a run that never starts)

## Log

- L1 request: "si, que ship se salte el paso de CI, como casi todo esto esta para mi maquina o sea este mismo con las mismas configuraciones."
- Assumptions: added to the tiered-checks backlog as story 12 because ship's checks are this feature's domain. Context: on 2026-11-17 the user disabled the only workflow, `check` (`gh workflow disable 387174330`, state `disabled_manually`), for lack of Actions minutes. Today `SKILL.md:19` says done means CI green, `:29` stops only when there is no CI workflow file, and `:39` always watches a run. Skipping is decided per repo by workflow state, not by a setting, so a repo with active CI keeps today's behaviour. `toolkit` is at 0.20.0, so the bump is 0.21.0. Same verifier treatment as story 06 (plan finding 12).
- L2 approved (2026-11-17): as proposed.
- L3 test list approved: 2 blocks in `scripts/tests/toolkit-ship.test.sh` (no active workflow; active workflow), an OpenCode-only pin in `gen-agents.test.sh`, a 0.21.0 floor in `no-sdd.test.sh`; no manual criteria.
- L4 steps: 83bc64c → 7031750 (gate "No active workflow" via `gh workflow list --all`, Done rule conditional; the old row "No remote, or no CI workflow" split into "No remote" and the new gate, no test pinned it); 7004aa5 → ed4beac (step 5 watches only when a workflow is active; its `gh run watch` case was green at the test commit because it pins today's behaviour, which criterion 2 keeps); c6e98ec pin (OpenCode copy, green at once, both cases seen failing with main's `SKILL.md`); c52ecd6 → f3c3d78 (toolkit 0.21.0). Every tamper check empty; goldens for both targets regenerated in each `feat:` commit.
- L5 check: `make check` at f3c3d78 "All checks passed (8 steps)", 1 min 23 s; `./install.sh` exit 0, toolkit 0.21.0 installed.
- L6 verifier (flow:verifier): FAIL on C1: plan bullet 3 ("the output names the skip instead of a run URL") was not done; `## Output Contract` still said "CI result with run URL". Refs and HEAD unchanged.
- L7 correction batch: 54a650b → 25389b3 (`## Output Contract`: "CI result with run URL, or that CI was skipped because no workflow is active"; red "1 case(s) failed", then green). `make check` at 25389b3 exit 0, "All checks passed (8 steps)"; `./install.sh` exit 0.
- L8 verifier recheck: PASS on C1-C3, commit order, tamper and assertions. Refs and HEAD unchanged. Left as is, outside the criteria: the frontmatter description still says "watch CI until it is green" with no condition.
- Risk: item 6 (skill prompt wording; no test would catch ship watching a run that never starts)
