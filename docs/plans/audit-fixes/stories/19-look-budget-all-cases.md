# Story 19: A 30 s budget for every look harness test

## Story

19. As the dotfiles owner, I want every look harness test to have the 30 s budget, and `make check` to fail when one lacks it, so that a slow CI runner stops turning `main` red one case at a time. (idea 21, from #18)

## Acceptance criteria

- [ ] Given the look tests that run in the harness (their callback takes `$`), including the ones declared inside a loop, when they run on a slow runner, then each has the 30 s budget instead of the 5 s default.
- [ ] Given a look harness test without that budget, when I run `make check`, then it fails and names that test.
- [ ] Given a look test that does not run in the harness, when I run `make check`, then it is not required to have the budget.

## Plan

- Widen the existing budget check from one named case to every harness case in the look test files, red first, naming each case that lacks it.
- Give the 24 declarations that lack it the budget the other 14 already have; change nothing else in those tests.
- Keep the check's story 18 assertion as it is; the new one goes beside it.
- Run the look suite and `make check`; the real proof is the next CI runs on `main`.

## Out of scope

- The two cases that do not use the harness ("prune splits live sources...", "a throwing render falls back...") and the plain `*.test.ts` files.
- Changing the harness's 5 s default, the CI workflow or the pinned Claude Code version.
- Any change to look's production code or to what a test asserts.

## Suggestions (your call)

- Assumption: "harness test" means a callback that takes `$`. That gives 24 declarations without the budget: 23 at the top level plus one inside a loop in `ci-poll.test.tsx`, which runs 4 times. Idea 21's first count of 25 was wrong, and the correction is in the same commit as this story.
- Assumption: a real hang now takes up to 30 s to fail per case instead of 5. Assertion failures stay fast (story 18's mutant failed in 245 ms).
- The mechanical edit touches 6 test files, above pair's "~50 lines or 3 files" step size. Approving this story accepts it as one step, since splitting it per file would leave `make check` red in between.

## Size

small
Risk: none

## Log

- L1 request: /flow:story 19
- L2 approved (user, 2026-11-04) as written: harness means a callback taking `$`; the 6-file mechanical edit is accepted as one step.
