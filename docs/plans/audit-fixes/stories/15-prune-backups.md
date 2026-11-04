# Story 15: Prune the installer's old backup copies

## Story

15. As the dotfiles owner, I want `install.sh` to prune its own old `*.bak-*` copies, keeping the newest ones, so that backups stop piling up. (idea 12, from #09)

## Acceptance criteria

- [ ] Given a file the installer manages has more than 3 backups named `<target>.bak-YYYYMMDD-HHMMSS`, when I run `./install.sh`, then only the 3 newest remain and each removed copy is named in the output.
- [ ] Given the same backups, when I run `./install.sh --dry-run`, then it names each copy it would remove and removes nothing.
- [ ] Given 3 or fewer installer backups of a target, or files that do not match the installer's backup name (e.g. `opencode.json.bak-free`), sit next to a path the installer does not manage (e.g. `engram.env.bak-*`) or live in agy's `skills-backup/`, when I run `./install.sh`, then they are left untouched.

## Plan

- Prune right after the installer makes a backup, scoped to that one target, so only paths the installer manages are ever looked at.
- Match only the exact name the installer writes (`.bak-` plus a 15-character timestamp); newest is decided by that timestamp, which sorts as text.
- Go through the existing dry-run wrapper so `--dry-run` reports instead of deleting.
- Cover keep-3, dry-run and the leave-alone cases in the existing install tests with a throwaway HOME.

## Out of scope

- agy's `skills-backup/` and the move of `*.bak-*` skill dirs into it (that step promises "never deletes").
- A flag or setting for how many copies to keep.
- Pruning backups of targets the installer does not touch on this run.
- `install.sh --uninstall` (story 16).

## Suggestions (your call)

- Assumption: a backup can be a directory (the link step renames a clashing dir), so a pruned directory copy is removed whole.
- Assumption: the moved-aside `GEMINI.md.bak-*` counts as an installer backup (same name format, same managed path) and is pruned the same way.
- Assumption: pruning only when a new backup is made means an existing pile shrinks on the next run that backs that target up, not on every run. If you want the pile cleaned on every run, the scope becomes "every target the installer manages" instead.

## Size

normal
Risk: item 1, 5 (deletes backup files; install script)

## Log

- L1 request: /flow:story 15
- L2 user chose to keep the 3 newest copies per target (2026-11-04).
- L3 approved (user, 2026-11-04), pruning only when a new backup is made.
- L4 test list approved (5 cases), mode C; tests live in a new `install-backups.test.sh` (install-claude.test.sh takes over 5 minutes).
- L5 commits: 2548141 test (link_file keeps 3, red: 5 FAIL) → 6bb51f4 feat; 3decd99 test (settings.json merge, red: 3 FAIL) → e861b6e feat; b68452d test (directory backup: green on arrival, killed by an `rm -f` mutant); f894774 test (dry-run, red: 1 FAIL) → 5d53cc6 fix; fb1b775 test (leave-alone: green on arrival, killed by three mutants: any `.bak-*` name, keep 2, prune the whole dir).
- L6 evidence: `install-backups.test.sh` "All cases passed"; `make check` "All checks passed (7 steps)". Tamper checks empty before each code commit.
- L7 verifier: PASS (fb1b775), with two notes outside the criteria: `GEMINI.md.bak-*` is not pruned (the Suggestions assumed it would be), and 3+ stamped `<skill>.bak-*` dirs left in agy's skills dir at run start are now pruned before the "moved, never deleted" step.
