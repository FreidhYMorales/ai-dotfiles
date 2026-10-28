# Story 01: Antigravity loads my rules

## Story

01. As a developer, I want Antigravity to load my rules from the paths it really reads so that it follows the same rules as Claude when my quota runs out.

## Acceptance criteria

- [ ] Given a sentinel rule at each candidate path (`~/.gemini/config/AGENTS.md`, `~/.gemini/antigravity-cli/AGENTS.md`, `~/.gemini/AGENTS.md`, `~/.gemini/GEMINI.md`), when I run `agy -p` in a project outside this repo, then I get a recorded table of which paths agy 1.4.7 loads (manual check).
- [ ] Given `./install.sh --target antigravity`, when it runs, then `AGENTS.md` is linked only at the paths the check proved, this repo's own link at an unread path is removed, and the output names the rules path.
- [ ] Given an existing `~/.gemini/GEMINI.md`, when I install, then it is left untouched if the check showed agy ignores it; if agy loads it, it is moved to a backup and the output says how to restore it.

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
