# Story 05: behaviour tests for the global gitleaks hook

## Story

05. As the dotfiles owner, I want tests proving the global gitleaks hook blocks a secret, chains to the repo hook and honours `SKIP_GITLEAKS`, so that my last barrier before a push cannot regress silently. (idea 11)

## Acceptance criteria

- [ ] Given a throwaway repo using the global hook dispatcher with a fake secret staged, when I commit, then the commit is refused with the "Commit blocked" message; and when I repeat it with `SKIP_GITLEAKS=1`, then the commit goes through.
- [ ] Given a throwaway repo with its own executable pre-commit hook and clean staged changes, when I commit, then the repo's hook runs, and if that hook fails the commit is refused.
- [ ] Given gitleaks is not on `PATH`, when I commit clean changes, then the commit goes through and a warning says the secret scan was skipped.

## Plan

- One new test file drives the real dispatcher through real `git commit` calls in temporary repos that point `core.hooksPath` at the repo's `git-hooks/`, isolated from the host's global git config.
- Block and bypass use a fake secret that gitleaks detects; chaining uses a repo-local hook that leaves a trace and one that exits non-zero.
- The missing-gitleaks case runs with a `PATH` that hides gitleaks but keeps git.
- When gitleaks is missing on the machine running the tests, the cases that need it are skipped with a visible notice; CI installs gitleaks, so they always run there.
- Assumptions: the hook's behaviour stays as it is (the user chose to keep "warn" when gitleaks is missing, 2026-11-03), so this is a tests-only story; `scripts/run-tests.sh` picks up the new `*.test.sh` with no wiring.

## Out of scope

- Blocking commits when gitleaks is missing (decided: keep the warning).
- Listing gitleaks as an install dependency (#06) and warning on a dangling hooksPath (#09).
- Chaining tests for hooks other than pre-commit.
- Any change to `git-hooks/_dispatch`; if a test exposes a real bug, stop and re-size the story (it would then touch item 2).

## Suggestions (your call)

- Build the fake secret by concatenating pieces at runtime, so the test file itself does not trip gitleaks when you commit it through the same hook.

## Size

small
Risk: none

## Log

- L1 request: /flow:story 05
- L2 decision (user, 2026-11-03): missing gitleaks keeps warning, not blocking.
- L3 evidence (pair, mode B, 2026-11-03): tests-only story, no production change, so each red was shown against a sabotaged copy of the dispatcher (exit 1 removed; SKIP ignored; chaining exec removed; missing gitleaks blocking or silent), then green on the real one.
  - Commits: fc2c989 test(git-hooks): a staged secret blocks the commit; 46efb85 test(git-hooks): SKIP_GITLEAKS lets a flagged commit through; 399002b test(git-hooks): the dispatcher chains to the repo's own pre-commit; 9f5141a test(git-hooks): a missing gitleaks warns and lets the commit through.
  - `bash scripts/tests/gitleaks-hook.test.sh`: 5 PASS, "all passed"; `make check`: "All checks passed (7 steps)".
  - Mutation: `scripts/mutate.sh git-hooks/pre-commit ...` 6/6 killed (100%). `mutate.sh git-hooks/_dispatch` reports 0/6 because its `cp --parents` copy dereferences the hook symlinks, so the mutated `_dispatch` is never the hook git runs (harness limitation, not fixed here).
  - Risk: none
