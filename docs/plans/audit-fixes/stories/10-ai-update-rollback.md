# Story 10: ai-update keeps two engram copies and rolls back binary and database together

## Story

10. As the dotfiles owner, I want `ai-update` to keep only the last two engram copies and roll back binary and database together on a failed doctor, so that an update can never strand my memory. (idea 15)

## Acceptance criteria

- [ ] Given more than two older engram copies and a new version whose doctor reports at most warnings or blocked checks, when the update finishes, then only the two newest database copies and the two newest binary copies remain, and an update that fails removes none.
- [ ] Given a new version whose doctor fails or that does not start, when I confirm the restore (asked even with `--yes`), then the binary and the database are back as they were before the update, the old memories can be found, and `ai-update` says what it restored and exits non-zero.
- [ ] Given the same failure, when I decline or there is no answer, then the database is untouched and `ai-update` exits non-zero; a binary that does not start goes back to the previous one, and after a failed doctor the new binary stays and the exact restore commands are printed.

## Plan

- Health check: read the doctor's JSON report after the swap. It failed on a non-zero exit or `summary.errors > 0`; warnings and blocked checks pass, because engram 3.6.1 exits 0 with `status: blocked` on the real database for old sync issues. The failure signal is inferred from that format; no real doctor failure has been observed.
- Failure path: one confirmation, never skipped by `--yes`, warning that memories saved since the pre-update copy are lost. A binary reporting the wrong version counts as not starting.
- Restore: stop a running `engram serve`, put the previous binary and the pre-update database copy back, discard the stale write-ahead files so they cannot replay over the copy, then restart the server. Say that open Claude Code sessions must restart, since their `engram mcp` still holds the replaced file.
- Decline path: leave the database alone and apply the third criterion.
- Pruning: only after a healthy update, only the exact names of the copies `ai-update` makes, so `engram-backup` and the installed binary can never match.

## Out of scope

- Repairing the doctor's existing warning and blocked checks.
- Rolling back plugins or the OpenCode and Antigravity build.
- Pruning without an update, or cleaning copies held by restic.
- A configurable number of copies.

## Suggestions (your call)

- `prune_backups` in `install.sh` already keeps the newest 2 of its own copies; follow its shape, without sharing code between the two scripts.

## Size

normal
Risk: item 1, 4, 5 (restores over the live memory database and deletes old copies; `engram serve` and `engram mcp` hold it open; replaces the installed binary)

## Log

- L1 request: /flow:story 10
- Declining the restore: confirmed by the user (database never touched without a yes; a non-starting binary goes back; after a failed doctor the new binary stays and restore commands are printed).
