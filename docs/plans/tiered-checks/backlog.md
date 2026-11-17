# Backlog: tiered-checks

## Context

- What: each check runs where it pays. Between turns the Stop hook runs `check-fast` within about 10 s; the full suite runs at `/flow:pair`'s final check, at ship and in CI. Story 08 is committed in the `QUICKSHELL NOTCH` repo. Plan: `docs/plans/tiered-checks/plan.md`. Superseded, carried by no story: idea 27 as a standalone spike (only the slow-test report remains; its bench question stays open), a parallel test runner (`run-tests.sh` is already parallel), a `delegate-local` worker retry, pair's "until green" loop on the full `Test command:`, background or remote suite runs.
- Stack: bash, Claude Code plugins (hooks, skills), the agent generator (`scripts/gen-agents`), `make`.
- Expensive decisions: the `check-fast` Makefile target is the hook's contract for any repo; the full suite no longer runs between turns; `NOTCH` becomes trusted for `require-check`.
- Test command: `make check` (story 08: the `NOTCH` repo's `make check`)
- Single test: `bash scripts/tests/<name>.test.sh` (plugin hooks: `bash plugins/toolkit/hooks/tests/<name>.test.sh`)

## Backlog

01. [x] a59fb55 As a developer, I want the Stop hook to run a check-fast tier instead of the full make check in this repo so that a turn ends in seconds.
02. [x] 793f8e9 As a developer, I want check-fast to lint only the scripts my branch changed so that a small edit stays under 10 s even on a loaded machine. Requires: #01
03. [x] cd47f8a As a developer, I want a check-fast timeout reported without blocking the turn so that a slow machine never makes the agent fix healthy code. Requires: #01
04. [x] da51db6 As a developer, I want /flow:pair to loop on the focused test and run the full suite once on the final tree so that TDD does not wait on the suite at every step.
05. [x] 94ae6eb As a developer, I want a red final suite in /flow:pair to become a regression round so that late regressions get fixed without breaking Strict TDD. Requires: #04
06. [x] c37f844 As a developer, I want ship to run make check once so that shipping does not repeat the full suite.
07. [x] a32a85c As a developer, I want the docs, agent rules and new-repo templates to teach the two tiers so that agents stop running the full suite every turn. Requires: #01
08. [x] ffce544 As a developer of the notch, I want a check-fast tier there and the hook trusted so that the notch gets a gate between turns without grabbing the keyboard. Requires: #01, #07
09. [x] c48651f As a developer using local workers, I want delegate-local to hand the worker the focused test and rerun the full suite after applying so that workers start fast without weakening the safeguard.
10. [x] a358069 As a developer, I want make test to print its five slowest test files so that I can see where the suite's time goes.
11. [~] As a developer using OpenCode, I want its generated rule to run make check-fast before done so that OpenCode stops paying the full suite every turn. Requires: #01
12. [x] 25389b3 As a developer whose GitHub Actions are disabled, I want ship to skip the CI watch when the repo has no active workflow so that shipping ends at a green make check and a push.
