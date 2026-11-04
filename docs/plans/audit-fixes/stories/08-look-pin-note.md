# Story 08: Startup note for a stale look pin

## Story

08. As the dotfiles owner, I want a startup note when my Claude Code differs from look's pinned version, so that I bump the pin before the band breaks silently. (idea 09)

## Acceptance criteria

- [ ] Given look is installed and the installed Claude Code differs from look's pinned version, when a session starts, then the startup update note names both versions and points to the bump procedure in `docs/look.md`.
- [ ] Given the note was already shown today, or Claude Code matches the pin, or look is not installed, when a session starts, then no look-pin line appears.
- [ ] Given `SKIP_UPDATE_CHECK=1`, or the pin or the Claude Code version cannot be read, when a session starts, then the session starts with no look-pin line and no error.

## Plan

- Extend the existing startup update check with one more note, beside the plugin, engram and upstream notes.
- Read the pin from the installed look plugin (its install path in the plugin registry), not from the repo, so it reflects what is running.
- Compare it to the installed Claude Code version; any difference (older or newer) counts.
- Rate-limit the note to once a day with a small cache file, as the engram lookup already does.
- Cover each criterion with a case in the existing update-check test, using a stub `claude`.

## Out of scope

- Bumping the pin or changing `look.test.sh` / CI behaviour.
- The same check for agy (`install.sh:468`).
- Caching offline failures of the engram lookup (story 11).

## Suggestions (your call)

- A plain string inequality is enough for "differs"; the `newer` helper is not needed.
- Assumption: "differs" means any mismatch, not only installed newer than the pin (idea 09 wording).
- Assumption: once a day per machine, via a cache file next to the engram cache (idea 09: "rate-limit to once a day via the existing cache").
- Assumption: `claude --version` costs ~15 ms here (measured), so calling it at startup is fine.

## Size

small
Risk: none

## Log

- L1 request: /flow:story 08
- L2 approved (user, 2026-11-03); test list approved, mode B.
- L3 commits: a8ae413 refine; 3a69882 test (newer Claude Code reported, red: 2 FAIL) → 3fb3977 feat; 9ff53bf test (older Claude Code, match, no look, SKIP, missing pin, failing `claude`: green on arrival, proven non-trivial by a mutant that drops the guards → 3 FAIL); ded2ef0 test (once a day, red: second startup still showed the note) → 9064644 feat; e88d178 refactor (header comment).
- L4 evidence: `update-check.test.sh` "All cases passed"; `make check` "All checks passed (7 steps)"; real host run prints `look pin 2.1.305 != Claude Code 2.1.318 (bump it: docs/look.md, "Bump the pin")`. Tamper checks empty before both feat commits.
- L5 Risk: none (no verifier).
