# Story 22: Verification proves bench changes

## Story

22. As the dotfiles owner, I want a change under `bench/` proven by `bench/worker/validate.sh` during verification, so that a broken benchmark task cannot stay unnoticed. (idea 16, from #12)

## Acceptance criteria

- [ ] Given an uncommitted or unpushed change under `bench/`, when I run `make check`, then every task is validated, and a task that fails validation makes `make check` fail and names that task.
- [ ] Given no such change, as in CI, when I run `make check`, then no task is validated and the output says the validation was skipped.
- [ ] Given a change under `bench/` on a machine without a task's source repo, when I run `make check`, then that task is reported as skipped with the missing repo named, the other tasks are validated, and the missing repo alone does not fail `make check`.

## Plan

- Add one verification step that looks for changes under `bench/`, both in the working tree and in commits the remote's `main` does not have.
- With a change, the step runs the existing validation; without one, it prints that it skipped and adds no real time.
- The validation tells a task whose source repo is absent from a task that fails, and reports the first as skipped.
- Update the README rows that describe the benchmark and `make check`.

Assumptions:

- Tasks that use a private repo still count on this machine. A moved `~/Mio/Configuraciones` shows as a skip line, not a failure, because the repo may be shared to test on other machines.
- `make check` with a bench change takes about 203 s here (89 s plus 114 s), under the 300 s limit of `require-check`. Nothing is sped up in this story.
- `make check` cannot recurse: the tasks that run it build this repo at `bench/worker/BASE` and remove `bench/` first.

## Out of scope

- A CI job for the benchmark, its tools or `fetch-depth`.
- Speeding up the four tasks that run a nested `make check`.
- Moving `bench/worker/BASE` or changing any task.
- Running the model benchmark, `bench/worker/run.sh`.

## Suggestions (your call)

## Size

normal
Risk: item 5 (a new step in `make check`, the gate run at every stop and in CI)

## Log

- L1 request: /flow:story 22
- L2 decision (user): local only, no CI job; this machine is where the work happens, and the AI dotfiles might at most be shared to test on other environments. Measured on 2026-11-05: `make check` 89 s; tasks 01-04 100 s, tasks 10-20 10 s, all 20 tasks 114 s.
- L3 commits: 8241542 test → 2a16104 feat; 3967571 → 3f344c8; 362f8ef → 853d97c; 6d6a950 → 114eefd; guards 39e17b1, f0db8e0, b840a58; e561d46 docs. Manual test: real `make check`, 20/20 tasks, rc 0, 204 s.
- L4 first verifier: FAIL. (1) No test for a change outside `bench/`. (2) An exported `GIT_DIR` made `bench/worker/lib.sh` rewrite the checked repo. Fixed by guards 07d641c and f7f2343 test → 6ee9ee3 fix. `make check`: "All checks passed (8 steps)", 204 s.
- L5 recheck: FAIL, so NEEDS DECISION. Both findings are closed in production code and all criteria pass, but `the branch of the checked repo stays` and `the other branch of the checked repo survives` still pass with the fix removed: `cloned-task` uses a commit from another repo, so `checkout -B` dies before the code that switches branches and deletes refs. Non-blocking notes: only `GIT_DIR` is pinned by a test; the whole of `make check` under an exported `GIT_DIR` still rewrites the checked repo, through the tests step, as it already does on `main`. Story stays open; the user decides.
