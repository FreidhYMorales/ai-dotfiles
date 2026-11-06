# Story 23: make check leaves the repo alone under git's local variables

## Story

23. As the dotfiles owner, I want `make check` to leave the checked repo alone when git's local variables such as `GIT_DIR` are exported, so that running the gate from a hook can never rewrite my refs.

## Acceptance criteria

- [x] Given `GIT_DIR` and git's other local variables exported and pointing at the checked repo, when I run `make check`, then that repo's refs, HEAD and commits are exactly as they were, even though tests build throwaway repos of their own.
- [x] Given the same variables exported, when I run `make check`, then the result is the one I get without them: it passes on a healthy tree, fails on a broken one, and no test fails because of the variables.
- [x] Given the same variables exported, when I run a single step such as `scripts/run-tests.sh` or `make test`, then the checked repo's refs, HEAD and commits are also unchanged.

## Plan

- Clear the names git itself reports through `git rev-parse --local-env-vars` before any step of the gate runs git, so the list never has to be kept by hand.
- Do it where every step passes, so a step run alone gets the same protection as the whole gate.
- Prove it on a throwaway repo with no remote, holding one fixture test that builds its own repo and commits there: export the variables, run the gate on the fixture, compare refs, HEAD and commits before and after.
- The proof never runs the real suite under the variables: that would recurse into itself, and the idea's finding is that the suite does the damage.

Assumptions, for approval:

- The third criterion goes beyond the backlog line's "`make check`" because the idea's finding came from `scripts/run-tests.sh` run directly.
- Inside a hook the gate reads the repo's real index, not the commit's temporary one. The gate uses git only for the file list and for the bench step's "did `bench/` change" test; a staged or unstaged change counts the same there. A partial commit (`git commit <file>`) can still differ for a newly added file, which is acceptable because nothing runs the gate from a hook today.

## Out of scope

- Adding any hook that runs `make check`; nothing in this repo runs it that way today.
- A test file run directly with `bash <name>.test.sh`, outside the gate: it stays unprotected.
- `bench/worker/lib.sh`'s own guard: it also runs outside the gate, so it stays.
- The `require-check` hook, and `make check` in other repos.
- The verifier's clone rules and pair's ref comparison (done in #24).

## Suggestions (your call)

- All seven `scripts/check-*.sh` and `scripts/run-tests.sh` already source `scripts/lib.sh`, so that one file is the natural single place; `bench/worker/lib.sh` already has the two lines to copy.
- `scripts/tests/checks.test.sh` already runs `check.sh` on fixtures, so the new test fits there.

## Size

normal
Risk: item 2, 5 (the gate's git commands must reach only the intended repo)

## Log

- L1 request: /flow:story 23
- L2 approved by the user, assumptions included; both suggestions accepted: clear the variables in `scripts/lib.sh`, add the test to `scripts/tests/checks.test.sh`.
- L3 commits: test e223739, fix 4929983; tests 10ab231, a74dadd, bde71c8. `make check` at bde71c8: `All checks passed (8 steps)`.
- L4 verifier: NEEDS DECISION. C1, C2, C3, tamper, assertions and security pass; refs and HEAD identical around the run. Open point: 10ab231, a74dadd and bde71c8 come after the fix, and the fix went beyond what e223739 required. The verifier reproduced their red: 8 failures with the guard removed, 5 with it narrowed to `unset GIT_DIR`.
- L5 user accepted the three commits as they are, with no history rewrite. No formal PASS.
- L6 observations left open: a hand-kept `unset` list or a guard only in `scripts/run-tests.sh` passes every test, though no criterion breaks; `scripts/tests/timer-retries.test.sh` failed once without the variables (`sleep: invalid option -- '1'`), then passed 5 of 5 reruns.
- Risk: item 2, 5 (the gate's git commands must reach only the intended repo)
