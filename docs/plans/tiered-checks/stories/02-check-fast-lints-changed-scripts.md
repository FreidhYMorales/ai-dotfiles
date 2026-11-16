# Story 02: check-fast lints only the changed scripts

## Story

02. As a developer, I want check-fast to lint only the scripts my branch changed so that a small edit stays under 10 s even on a loaded machine. Requires: #01

## Acceptance criteria

- [ ] Given a branch whose changes (uncommitted work plus commits not on `origin/main`) touch one shell script, when `make check-fast` runs, then shellcheck and shfmt run on that script only, a lint error in it still fails the step, and the run takes under 10 s at idle and under load; with no changed script the step passes and says so.
- [ ] Given a changed script that another script sources (`# shellcheck source=<path>`), or a repo with no `HEAD`, when `make check-fast` runs, then every script is linted; with no `origin/main` only the uncommitted work counts, and deleted or renamed paths are not linted.
- [ ] Given `make check`, even with the changed-files variable exported, when it runs, then every script is linted as today; and the full-lint case of `check-fast` is measured well under 60 s at idle and under load.

## Plan

- `check-shell.sh` gains a changed-files mode, switched on by an environment variable; `$1` stays ROOT.
- The changed list is uncommitted work (tracked changes vs `HEAD` plus untracked, not ignored) plus the merge-base diff with `origin/main`, the way `check-bench.sh` computes it; it goes through today's script filter, so missing, symlinked and vendored paths drop out.
- A changed file named by any script's `# shellcheck source=` directive, or a repo with no `HEAD`, switches back to every script.
- Only the `check-fast` recipe sets the variable, inline on the `check-shell.sh` call; `check.sh` unsets it so `make check` always lints everything. The other five steps stay whole-repo.
- Tests in the existing checks suite with throwaway repos (deleted file, no `HEAD`, no `origin/main`, changed sourced lib, exported variable under `make check`); hyperfine numbers at idle and under load logged as evidence.

## Out of scope

- The non-blocking `check-fast` timeout (story 03); the hook itself is not touched.
- Changed-files modes for json, structure, settings, skills or workflows.
- Any change to `make check`, CI, docs (story 07), `NOTCH` (story 08) or a plugin version bump (no plugin file changes).

## Suggestions (your call)

- `check-bench.sh:9-12` already computes the uncommitted plus `origin/main...HEAD` list; a small `changed_files` helper in `lib.sh` could serve both, but moving `check-bench.sh` onto it is only a suggestion, not part of this story.

## Size

normal
Risk: item 5 (the lint step of the `check-fast` gate and the Makefile recipe)

## Log

- L1 request: /flow:story 02
- Assumptions: "no `origin/main`" falls back to uncommitted work vs `HEAD` (plan row 52, "`HEAD` alone"); shfmt follows the same file list as shellcheck; the variable name is chosen at the test list in `/flow:pair`; "under load" is the same kind of load as story 01's measurements (load about 3.5-4).
