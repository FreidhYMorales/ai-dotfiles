# Story 07: Recovery drill restores real engram memories

## Story

07. As the dotfiles owner, I want the CI recovery drill to restore memories a real engram binary can find, so that I know my memory survives, not just a SQLite file. (idea 17)

## Acceptance criteria

- [ ] Given the old machine saves real memories with a pinned engram release, when the drill restores from the backup drive and again from the off-site clone, then `engram search` on each new machine finds every saved memory.
- [ ] Given a restore that brings back data engram cannot find (a memory missing from the restored store), when the drill runs, then it fails and names the memory it could not find.
- [ ] Given the downloaded engram archive does not match the release's published checksum, when the drill runs, then it stops before running that binary and says why.

## Plan

- Fetch one pinned engram release (version plus its `checksums.txt` check, the same way `ai-update` verifies an upgrade) before the old machine step.
- Old machine: replace the hand-made one-table database with a few `engram save` calls into the machine's own data dir.
- After each restore: `engram search` each saved title against the restored data dir; any miss fails the drill.
- Keep the existing legs (drive restore, off-site clone restore, `--verify`) unchanged; drop the `count(*)`/`integrity_check` checks that the search replaces, or keep `integrity_check` as a cheap extra.
- RED first: a test that runs the drill's check against a store missing one memory and against a bad checksum.

## Out of scope

- Tracking the engram pin against new releases (a staleness warning like idea 09 / story 08).
- Merging this into story 06's clean-machine container job.
- Changes to `engram-backup` itself or to `ai-update`.
- Testing engram's MCP server or `serve`; only the CLI `save`/`search` path.

## Suggestions (your call)

- Assumption: pin the version the host runs today (`engram 3.6.1`, upgraded with `ai-update` on 2026-11-03 before this story), the release asset the drill needs is `linux_amd64`.
- Assumption: `engram save`/`search` work with no running `serve`, against the data dir given by `ENGRAM_DATA_DIR`; check that first in RED, it decides whether the drill must start a server.
- The download/checksum logic in `ai-update` (`upgrade_engram`) is the concrete signal; reuse its shape rather than inventing a second one, but do not refactor `ai-update` in this story.

## Size

normal
Risk: item 5 (CI job downloads and runs a pinned external binary)

## Log

- L1 request: /flow:story 07
- L2 approved; host engram upgraded 3.6.0 -> 3.6.1 first, so the pin is 3.6.1.
- L3 built with `/flow:pair 07`. User approved the `ENGRAM_RELEASE_URL` override (default: GitHub v3.6.1) so the tests use a local `file://` release. Confirmed first: `engram save`/`search` need no `serve`, `ENGRAM_DATA_DIR` alone works; a miss echoes the query, so the drill matches the result line `) — <title>`.
- L4 evidence: b2e8292 test + f4f3d2b feat (checksum mismatch stops the drill before engram runs); ccc8670 test + ed2e079 feat (a memory engram cannot find fails the drill, named). `make check`: "All checks passed (7 steps)". Real e2e `bash scripts/recovery-e2e.sh`: "recovery drill passed: engram 3.6.1 finds 3/3 memories restored from the drive and from the off-site clone" (29 s). CI `recovery` job: pending push.
- L5 verifier: PASS (C1-C3 pass, TDD order and tamper check pass). Non-blocking notes: checksums.txt comes from the same release as the archive (integrity, not provenance; same as `ai-update`); `curl`/`tar` rely on the Arch base image and are not in the drill's tool check.
- Risk: item 5 (CI job downloads and runs a pinned external binary)
