# Story 03: flow:pair

## Story

03. As a developer, I want `flow:pair` to build a story in red→green steps that commit the test before the code and stop on the stop rules so that I review small diffs and catch test tampering.

## Acceptance criteria

- [x] Given an approved story, when I run `/flow:pair 02`, then it proposes a test list mapped to the criteria on branch `story/02-<slug>` and waits for approval before any test or code (eval `pair-proposes-test-list`).
- [x] Given a criterion that contradicts an existing test, when I ask pair to build it, then it stops and asks instead of changing the test (eval `pair-stops-on-test-change`).
- [x] Given a red test committed by pair, when the Stop hook runs on the same branch with that commit in HEAD, then `require-check` reports through `systemMessage` instead of blocking; a stale or other-branch marker still blocks (`plugins/toolkit/hooks/tests/require-check.test.sh`).
- [x] The loop skills are not linked into OpenCode/Antigravity, and only repo-owned leftover links are removed (`scripts/tests/install.test.sh`).

## Plan

Built without the loop (stories 01-03 build the loop itself).

## Out of scope

`flow:verifier` (story 04), `claude/CLAUDE.md` rules (story 06).

## Suggestions (your call)

None.

## Size

normal · Risk: item 5 (Stop hook and installer), item 3 (pair contract), item 6 (skill behaviour graded by paid evals)

## Log

- L1 request: build `flow:pair`, the red marker in `require-check`, the `link_skills` exclusion and the `work-unit-commits` exception per `docs/plans/replace-sdd/plan.md`.
- L2 cycle 1 red: `d72b457`, `0703804` tests alone; hook test 3 failures (honoured cases still exit 2), install test 8 failures. Green: `5ed01d9` (hook), `2d19032` (installer). Diff reviewed by hand (verifier not built yet): marker honoured only with the same branch and the red sha in HEAD; installer removes only symlinks pointing into the repo.
- L3 cycle 2 red: `c3aeffe`, `flow-pair.test.sh` 28 failures. Green: `7b7ce1e` (skill, strict-tdd reference, evals, flow 0.8.0), `eadc71b` (work-unit-commits exception, toolkit 0.13.0). `make check` all 7 steps passed.
- L4 finding: a slash prompt (`/flow:pair 02`) expands a `disable-model-invocation` skill inside evals (with vs without arms differ).
- L5 eval `pair-stops-on-test-change`: with 1.00, without 0.00 (Δ +1.00, $0.87).
- L6 eval `pair-proposes-test-list` first run with 0.50: the llm branch grader failed although the answer named `story/02-tip-percentage` (judges read "cannot create it" as failure). Grader changed to regex `story/02-[a-z0-9-]+` (user approved the test change). Re-run: with 1.00, without 0.00 (Δ +1.00, $0.77). Story eval spend ≈ $2.41.
