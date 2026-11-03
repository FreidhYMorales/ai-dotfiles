# Story 01: Trustworthy CI check job

## Story

01. As the dotfiles owner, I want the CI `check` job to fail only when something is really broken, with margin under its timeout, so that a red run means something again. (idea 08)

## Acceptance criteria

- [ ] Given the three timing-sensitive tests (look, pack-hint "two parallel sessions: one hint", OpenCode pack-hint 2 s cut-off), when they run under the same parallel load as the 2-core CI runner, then they pass every time, and each still fails when the behaviour it checks is really broken.
- [ ] Given a push to main, when the `check` job runs, then it finishes in at most 7 minutes against its 10-minute timeout.
- [ ] Given five consecutive pushes to main with no real breakage, when CI runs, then all five `check` runs are green.

## Plan

- Reproduce each flaky failure locally under CI-like load (2 CPUs, parallel test files) and find its root cause before changing anything.
- Make each test tolerant of load by waiting on the event it checks, not on wall-clock sleeps; never inflate a timeout unless a test proves the timeout itself is the behaviour.
- Cut job time where it goes: measure per-file durations, then reduce parallel contention or move the slow look tests to their own job, whichever the measurement points to.
- Prove the margin and the stability with real runs on main.

## Out of scope

- The recovery job, the other audit findings and new tests for untested behaviour.
- Changing what any hook or plugin does; only tests and CI layout change.
- Raising `timeout-minutes` to hide slowness.

## Suggestions (your call)

- `scripts/run-tests.sh` runs every test file in parallel with no cap; a cap at `nproc` is a cheap first experiment before splitting jobs.
- Assumptions to confirm: "margin" = at most 7 min; "trustworthy" = five consecutive green runs on main.

## Size

normal
Risk: item 5 (CI workflow and test runner layout)

## Log

- L1 request: /flow:story 01
