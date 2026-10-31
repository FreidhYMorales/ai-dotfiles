# Story 35: agy installer hardening

## Story

35. As a developer, I want the installer to sweep `.bak-*` out of all three agy skills dirs, write agy `hooks.json` through `mktemp`, and warn with the re-run command when agy is not the pinned 1.4.9, so that a second install or an agy upgrade never breaks a session. Requires: #08

## Acceptance criteria

- [ ] Given a `.bak-*` dir in any of the three agy skills discovery dirs (`~/.gemini/skills/`, `~/.gemini/config/skills/`, `~/.gemini/antigravity-cli/skills/`), when I run the installer, then it is moved into `skills-backup/`, never deleted, and agy no longer discovers it.
- [ ] Given an agy `hooks.json` with other keys (herdr's), when I run the installer, then the file holds the same other keys plus the `toolkit` key, is written through a fresh temp file beside it, and no `hooks.json.tmp*` is left behind.
- [ ] Given `agy --version` reports a version other than 1.4.9, when I run the installer, then it warns that the rules and skills discovery was proven on 1.4.9 and names how to re-run the checks; with 1.4.9 or no agy, no version warning.

## Plan

- The `.bak-*` sweep loops over the same three discovery dirs the gentle-ai sweep already uses, through the shared move-to-backup step.
- The agy hooks merge writes through `mktemp` beside `hooks.json` and renames it into place; dry-run and the parse-error stop stay as today.
- One version check after the engram check: reads `agy --version`, compares with the 1.4.9 pin, prints one warning line.
- One install test per criterion in the agy install tests; a stub `agy` gives the version.

## Out of scope

- Pruning links when the build dir is outside the repo (#36).
- A script that runs the agy sentinel checks; the real 1.4.9 re-run stays in #17.
- `.bak-*` files in `~/.gemini/config/agents/` (probed in #17).
- Changing what the merged `toolkit` key contains.

## Suggestions (your call)

- Merge the `.bak-*` loop into the existing three-dir loop of story 32: both already walk the same dirs and call `move_to_backup`.

## Size

normal
Risk: item 1, 5 (moves dirs in agy skills dirs; rewrites agy `hooks.json` in the installer)

## Log

- L1 request: /flow:story 35
- L2 assumptions: no sentinel script exists (the checks are the manual procedure in `docs/multi-agent.md`), so "the re-run command" points to that section; agy missing gives no version warning (the engram warning already says so); unreadable `agy --version` output counts as not 1.4.9 and the warning shows what agy printed.
- L3 approved: story, criteria and L2 assumptions approved as written.
- L4 test list approved: five integration tests in `install-agy-skills.test.sh` (`.bak-*` in the two other dirs; a stray `hooks.json.tmp` left alone; 1.5.0 warns; 1.4.9 and no agy do not), plus an agy stub `--version` (default 1.4.9) in `install-lib.sh`.
- L5 commits: 71af9b9 test → 5acbc70 feat (sweep three dirs); 6ccdab4 test → d760cb7 feat (mktemp); b9d41f7 test → 5efb6cf feat (version warning, `AGY_PINNED`); 414d4be docs (the tables still wait for their 1.4.9 re-run in #17); dc7e693 test (no-warning pins, green by design, mutation-checked: an always-on warning fails the 1.4.9 pin, dropping the agy guard fails the no-agy run).
- L6 decision: fixtures avoid `sdd-*` names, which `RETIRED_PLUGINS` already sweeps (would be trivially green).
- L7 verifier: PASS. Note 1: the `hooks.json` mode handling added in d760cb7 had no test; fixed as 2c617a1 revert → 87f84ff test (0640 kept, new file 0644; red) → 4461543 feat. Note 2: `chmod --reference` is GNU-only; the repo targets Linux, left as is.
- L8 evidence: `bash scripts/tests/install-agy-skills.test.sh` → "All cases passed"; `make check` → "All checks passed (7 steps)".
- Risk: item 1, 5 (moves dirs in agy skills dirs; rewrites agy `hooks.json` in the installer)
