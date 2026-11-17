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
