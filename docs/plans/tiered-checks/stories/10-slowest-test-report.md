# Story 10: make test reports its slowest test files

## Story

10. As a developer, I want make test to print its five slowest test files so that I can see where the suite's time goes.

## Acceptance criteria

- [ ] Given a test run with more than five test files, when `make test` finishes, then it prints the five slowest test files, slowest first, each with its time in seconds.
- [ ] Given a test run with five or fewer files, or one with a failing file, when `make test` finishes, then the report still appears, lists every file it ran up to five, and the exit status is unchanged.

## Plan

- The runner records each file's wall time as it runs in parallel, next to its status.
- After the per-file results, it prints one short "slowest" block: up to five files, sorted by time, descending.
- Under `TEST_SHARD` the report covers only that shard's files.
- Tests pin the order and count with stub test files that sleep different, clearly separated amounts.

## Out of scope

- Idea 27's bench question (stays open).
- Timing the other `make check` steps, thresholds, failing on slow tests, history or trends.
- Changing parallelism, sharding or the pass/fail output.

## Suggestions (your call)

- Assumption: times are wall-clock per file while files run in parallel, so they show the slowest files, not their isolated cost.
- Assumption: one decimal of seconds is enough precision.

## Size

small
Risk: none

## Log

- L1 request: /flow:story 10
- Stopped in test 1: the code prints the report correctly, but the committed test's parser (`report`, `5b3b291`) reads every line after the header, including `finish`'s `tests: ok`, so it cannot go green without editing the committed test.
