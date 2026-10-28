# Story 01: Antigravity loads my rules

## Story

01. As a developer, I want Antigravity to load my rules from the paths it really reads so that it follows the same rules as Claude when my quota runs out.

## Acceptance criteria

- [x] Given a sentinel rule at each candidate path (`~/.gemini/config/AGENTS.md`, `~/.gemini/antigravity-cli/AGENTS.md`, `~/.gemini/AGENTS.md`, `~/.gemini/GEMINI.md`), when I run `agy -p` in a project outside this repo, then I get a recorded table of which paths agy 1.4.7 loads (manual check).
- [x] Given `./install.sh --target antigravity`, when it runs, then `AGENTS.md` is linked only at the paths the check proved, this repo's own link at an unread path is removed, and the output names the rules path.
- [x] Given an existing `~/.gemini/GEMINI.md`, when I install, then it is left untouched if the check showed agy ignores it; if agy loads it, it is moved to a backup and the output says how to restore it.

## Plan

- Run the sentinel check by hand with `agy -p` (print mode), restore every sentinel afterwards, and record the result table in `docs/multi-agent.md`.
- Pin the proven layout in the antigravity sandbox install test first (red), then change the installer to match.
- The installer removes only symlinks that point into this repo; anything else at those paths is the user's.
- `GEMINI.md` handling follows the check result: one branch, no option flag.
- Fix the Antigravity rows of `docs/multi-agent.md` (rules path and the `GEMINI.md` note) to match the check.

## Out of scope

- Skills paths and the `.bak-*` dirs (story 02).
- engram MCP config and the two agy `mcp_config.json` files (stories 03 and 04).
- The generator and any rewrite of `AGENTS.md` (`/flow:x` → `/flow-x`, stories 08 and later).
- Gemini CLI support; OpenCode rules.

## Suggestions (your call)

- `~/.gemini/config/AGENTS.md` is already linked by today's installer and is the global root the bundled docs name, so the likely outcome is "keep that link, drop `~/.gemini/antigravity-cli/AGENTS.md`"; the check decides.

## Size

normal
Risk: item 1 (moves `~/.gemini/GEMINI.md` if agy loads it), item 5 (install script), item 6 (what agy loads is only checkable by hand)

## Log

- L1 request: "/flow:story 01"
- L2 assumptions for approval: the sentinel check is a one-time manual run recorded in `docs/multi-agent.md`, not a committed probe script (it needs agy auth and spends quota); `AGENTS.md` (well under agy's 24 KB cap) is linked as it is today, with no rewrite.
- L3 approved by the user ("si").
- L4 test list approved, including flipping the pinned assertion 'AGENTS.md is linked for antigravity cli' (stop rule 3 cleared up front).
- L5 manual sentinel check (C1), two `agy -p` runs from a non-git dir, same result: `~/.gemini/config/AGENTS.md` yes, `~/.gemini/AGENTS.md` yes, `~/.gemini/GEMINI.md` yes, `~/.gemini/antigravity-cli/AGENTS.md` no. All files restored from a backup (GEMINI.md sha256 unchanged). Recorded in `docs/multi-agent.md` (`b59dd8e`). Decided: link only `~/.gemini/config/AGENTS.md` (documented global root, already installed).
- L6 cycles (mode C): 52c066b→d4b8c2f rules not linked under antigravity-cli; ecf0aa3→ec730a0 own unread link removed, user file kept; a1580de output names only the read path (passed on arrival, fails against main's installer); a0e297a→e56a79d GEMINI.md moved to a backup with a restore hint. `bash scripts/tests/install.test.sh` → All cases passed; `make check` → All checks passed (7 steps).
- L7 verifier (`flow:verifier`): Verdict: PASS. Notes: dry-run still prints the "moved"/"removed" lines; same-second reruns would reuse a backup name.
- L8 Risk: item 1 (moves `~/.gemini/GEMINI.md`), item 5 (install script), item 6 (manual-only check).
