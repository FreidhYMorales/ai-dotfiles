# Story 25: The bench step tells the truth about its gaps

## Story

25. As the dotfiles owner, I want the bench step's skip message, its handling of a deleted `validate.sh`, its leftovers after a timeout and the README's CI claim to be accurate, so that the step's small gaps stop misleading me. (idea 25, from #22)

## Acceptance criteria

- [ ] Given a clean checkout that cannot compare with `origin/main`, or a directory with no git, as on a pull request in CI, when I run `make check`, then the bench step says it skipped because it could not compare, not that nothing changed, and it does not fail; and the README states that CI skips only because its shallow checkout has no `origin/main` to compare with.
- [ ] Given a change under `bench/` that deletes `bench/worker/validate.sh`, when I run `make check`, then the bench step fails with a message naming the missing file, not a raw exit 127.
- [ ] Given a task's check or gate running under the bench step, when an outer timeout stops the step, then within a few seconds neither that command nor the work directory remains.

## Plan

- Tell the bench step's three outcomes apart: compared and found no change, could not compare, and found a change.
- Before validating, confirm the validator exists, and fail with a clear message when it does not.
- Make stopping the validation also stop the task command running under it, for both the check and the gate.
- Correct the README rows that describe the bench step and CI.

Assumptions:

- A deleted `validate.sh` stays a failure, as it is today: a change under `bench/` that cannot be proven must not pass. This includes removing all of `bench/` on purpose; the step is red until that commit reaches `origin/main`.
- Being unable to compare stays a skip and not a failure, so CI stays green with no benchmark tools (story 22 L2).
- Reproduced on 2026-11-05 with `timeout 4` over `validate.sh` and a gate that sleeps 12 s: the outer `timeout` returned 124 and the work directory was gone, but the nested `timeout 900` and its command ran on until the end and finished their writes. So the leftover is the process, and with a long command it is not limited to the few seconds idea 25 estimated.
- A fix under `bench/worker/` makes `make check` validate every task until it reaches `origin/main`, about 204 s against the 300 s limit of `require-check`.

## Out of scope

- A CI job for the benchmark, its tools or `fetch-depth`.
- Validating anything when the comparison is impossible.
- Chasing process groups started deeper inside a nested `make check`, such as a test's own `timeout`; those end at their own limit.
- Handling signals other than the one an outer timeout sends.
- Changing how `bench/worker/run.sh` reports or runs tasks.

## Suggestions (your call)

## Size

normal
Risk: item 5 (the bench step of `make check`, the gate run at every stop and in CI)

## Log

- L1 request: /flow:story 25
