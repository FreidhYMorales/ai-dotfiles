# Story 03: Harden the require-check Stop gate

## Story

03. As the dotfiles owner, I want the require-check gate to warn when I stop with a red check, to ignore a stale red marker and to run only in trusted repos, so that the gate cannot be skipped or abused. (idea 06)

## Acceptance criteria

- [ ] Given a trusted repo whose `make check` fails, when Claude stops again right after being blocked (`stop_hook_active`), then it is not blocked a second time but gets a message saying `make check` is still red, with the failure tail.
- [ ] Given a `/flow:pair` red marker whose red commit is no longer HEAD (a commit was made on top of it), when Claude stops with `make check` red, then it is blocked as if there were no marker; while HEAD is the red commit, the red state is still reported instead of blocked.
- [ ] Given a repo with uncommitted changes and a root Makefile but without the local opt-in (`git config require-check.trusted true`), when Claude stops, then no `make` command runs (not even target detection) and a one-line message says the repo is not trusted and how to opt in; with the opt-in, the gate behaves as today.

## Plan

- Read the opt-in from the repo's local git config only (never from a committed file), before any `make` call; without it, report one line and exit.
- On `stop_hook_active`, run the check instead of exiting early; on failure, turn the block into a message with the tail.
- Honour the red marker only when HEAD equals its recorded commit.
- Pin each behaviour with hook tests (fixtures opt in where they expect the gate to run); the agy wrapper inherits the changes.
- Document the opt-in where the hook is described, and opt this repo in.

## Out of scope

- A trusted-roots list or any global allowlist (decided: per-repo opt-in).
- Changing how `/flow:pair` writes or deletes the marker.
- Opting in repos automatically from `install.sh`.
- The cache, the timeout and `SKIP_REQUIRE_CHECK`.
- OpenCode or agy specifics beyond what the shared script gives them.

## Suggestions (your call)

- Assumption to confirm: the "not trusted" note shows only when the repo has a dirty tree and a root Makefile (a file check, no `make`), so repos without a Makefile stay silent.
- Assumption to confirm: the opt-in is read from the local config scope only (`git config --local`), so a global `require-check.trusted` cannot trust every repo at once.
- The second-stop rerun costs one more `make check` on a red tree (failures are never cached); acceptable, or skip the rerun and just say "still red from the last run"?

## Size

normal
Risk: item 2 (an untrusted clone's Makefile runs code on the host), item 5 (installed Stop hook every session depends on)

## Log

- L1 request: /flow:story 03
- L2 decision (user): trust rule = per-repo opt-in in the local git config (option a), not a trusted-roots list.
- L3 approved (user): story and the three assumptions as written (note only with a dirty tree and a root Makefile; local scope only; rerun the check on the second stop).
- L4 test list approved (user), including two changes to existing tests: the fixtures in `require-check.test.sh` (`new_repo`) and `agy-require-check.test.sh` (`repo`) opt in, and the old `stop_hook_active true skips` case is replaced by the second-stop test (criterion 1 changes that behaviour).
- L5 verifier pass 1: FAIL. A clone can ship a subdirectory that looks like a git dir (`HEAD`, `objects/`, `refs/`, `config` with `core.worktree=.` and `require-check.trusted=true`); with the session cwd inside it, discovery picked it and its Makefile ran. Fixed red→green: 58ec8d5 → daad54d (`safe.bareRepository=explicit` on discovery; also stops a planted `core.fsmonitor` from running through the hook's `git status`).
