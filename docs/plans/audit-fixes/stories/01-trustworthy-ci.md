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
- L2 decision (user): shard the CI tests into two parallel jobs instead of raising look's per-test timeouts; local `make check` unchanged.
- L3 root causes, reproduced by running two full suites at once pinned to one CPU: pack-hint "two parallel sessions" and "default ~/.local/bin fallback" bypassed `run_hook` and kept the 1.5 s default (`FAIL two parallel sessions (round 1..3): one hint`); look cases without `timeoutMs` exceeded the harness's 5 s watchdog (`Error: timed out after 5000 ms`, the failing case varies); the OpenCode "took 4s" failures predate multi-agent-port story 48. `run-tests.sh` showed only the last 40 lines of a failing file, which hid the look case on CI.
- L4 approved test list: the pack-hint change to the existing cases was approved by the user. Mutation: disabling `flock -n 9` in `packs/lib/state.sh` makes the parallel case fail (`5 case(s) failed`). Under the same load after the fix, pack-hint passes.
- L5 commits: 830b9f5 test, a367830 test (shellcheck only, before any code), 675f3c8 test (pack-hint), 48c21c1 feat (TEST_SHARD), 6fd9b03 test + c485f6c fix (TEST_SHARD leaked into checks.test.sh; found under local load before any push), 282c0d0 ci (two-shard matrix).
- L6 evidence: under half load (each shard twice at once on one CPU) all four runs pass, look included (308 s and 255 s). `make check`: "All checks passed (7 steps)", 2:51. Draft PR #31, CI run 41668933542: check (1/2) 5:27, check (2/2) 5:08, recovery 0:45, all green.
- L7 verifier: NEEDS DECISION. Branch sound (commit order, tamper check, assertions PASS). C2 is proven on the PR, not yet on main; C3 (five green runs on main) is only possible after the merge.
- Risk: item 5 (CI workflow and test runner layout)
- L8 merged to main as 58497be (`--no-ff`); PR #31 closed as merged. First main run: check (1/2) 5:17, check (2/2) 5:21, recovery 0:34, all green. C2 proven on main. C3: 1 of 5 consecutive green runs; close the story (`[x]`) at 5.
