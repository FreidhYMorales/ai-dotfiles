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
