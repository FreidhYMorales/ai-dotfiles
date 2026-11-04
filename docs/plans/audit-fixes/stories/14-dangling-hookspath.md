# Story 14: Warn on and repair a dangling global hooksPath

## Story

14. As the dotfiles owner, I want a startup warning when the global git hooksPath points to a missing directory, and `install.sh` to repair it, so that moving the repo never turns off gitleaks unnoticed. (idea 12, from #09)

## Acceptance criteria

- [ ] Given the global `core.hooksPath` points to a directory that does not exist, when a session starts, then a warning names the path, says gitleaks is not running on commits, and tells me to re-run `./install.sh` from the repo.
- [ ] Given the global `core.hooksPath` is unset or points to an existing directory, when a session starts, then no hooksPath line appears and the session starts with no error.
- [ ] Given the global `core.hooksPath` points to a missing directory, when I run `./install.sh` (also with `--dry-run`), then it points the hooksPath at this repo's `git-hooks` and says it replaced the dangling value; a hooksPath set to another existing directory is still left alone.

## Plan

- Add the check to the startup hooks, next to the other startup warnings; it reads only the global git config and the filesystem, no network.
- Warn on every startup while the path is dangling (no rate limit): it is a lost security barrier, not an update note.
- In the installer's git-hooks step, treat a value pointing to a missing directory like an unset one; dry-run reports what it would set.
- Cover the hook with a test using a throwaway global git config, and the installer case in the existing install tests.

## Out of scope

- Pruning `*.bak-*` copies (story 15) and `install.sh --uninstall` (story 16).
- Checking that the directory holds a working `pre-commit` or that gitleaks is installed (the installer already warns on a missing gitleaks).
- Repo-local `core.hooksPath` values (pi-box handles those).

## Suggestions (your call)

- The hook can share the `hook_off` / `lib.sh` pattern the other startup hooks use; `backup-status.sh` is the closest shape (a safety warning, not an update note).
- Assumption: "points nowhere" means the directory does not exist; an existing but empty directory is not flagged.
- Assumption: the installer fix is in scope because today `install_git_hooks` prints `skip: global core.hooksPath already set to <old path>` after a move, so the warning's advice would not work without it.

## Size

normal
Risk: item 2, 5 (gitleaks barrier; install script changes the global git config)

## Log

- L1 request: /flow:story 09
- L2 split: #09 needed more than 3 criteria → #14 (this story), #15, #16.
- L3 approved (user, 2026-11-03).
- L4 test list approved (7 cases), mode C; user approved changing the existing `/elsewhere` case to an existing dir (case 7).
- L5 commits: 6aa1112 refine; ff8645b test (dangling warns, red: 4 FAIL) → 2855504 feat; b4b622c, c2b7bc3 test (unset, existing dir: green on arrival, each killed by a mutant dropping its guard); 4536df5 test (relative path, red) → f312159 fix; fc89f30 test (installer repoints, red: 2 FAIL) → 871f074 test (case 7) → aeed71c fix; ba4a77a test (dry-run: green on arrival, killed by a mutant skipping `run`); 78a3886 test (`~` value, red; from the verifier note, user approved) → 4ff0dba fix; fd3eaad test (shellcheck SC2088 directive, comment only, user approved).
- L6 evidence: `hooks-path.test.sh` and `install-claude.test.sh` "All cases passed"; `make check` "All checks passed (7 steps)". Tamper checks empty before each code commit. 4ff0dba was committed while `make check` was red on shellcheck only (behaviour tests green); fixed in fd3eaad.
- L7 verifier: PASS (ba4a77a); recheck PASS (fd3eaad).
- L8 Risk: item 2, 5 (gitleaks barrier; install script changes the global git config).
