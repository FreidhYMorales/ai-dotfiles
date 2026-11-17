# Story 01: install.sh and ai-update stop installing Antigravity

## Story

01. As a developer, I want install.sh and ai-update to stop installing Antigravity so that an install sets up only Claude Code and OpenCode.

## Acceptance criteria

- [ ] Given the installer, when I run it with `--target antigravity`, then it fails with `unknown target: antigravity` and installs nothing; with `--target all` it ends with `done. Active targets: claude opencode.`
- [ ] Given `agy` on `PATH` and `~/.gemini/antigravity-cli` present, when I run the installer with no `--target` (install or `--uninstall`), then its `done.` line never names `antigravity` and nothing under `~/.gemini` is created, changed or removed.
- [ ] Given an Antigravity dir, when `ai-update` regenerates agents, then it passes `--target opencode` when OpenCode is also present, and runs no install when only Antigravity is.

## Plan

- The target resolver accepts only `claude`, `opencode` and `all`; auto-detection and the usage text drop agy.
- The installer loses the Antigravity install and uninstall paths, its hooks merge and unmerge, the agy backup moves, the version pin, its variables and every agy comment; shared helpers stay.
- `ai-update` stops detecting an Antigravity dir and stops adding it to `--target`.
- Test triage per the plan's shared-file rule: agy-only test files and the fake `agy` go; in shared test files only agy lines, arguments and entries go; OpenCode, Claude and user-data cases stay; `port-docs`/`tiered-docs` lose only the assertions that pin installer agy text.
- The stub removal and the installer change land in the same green step; tests that need the generated build pass `--target` explicitly; closing scan over the files this story owns shows only the named regression REDs.

## Out of scope

- The generator, goldens and `models.json` (story 02); the hook adapters and toolkit bump (story 03); README, `docs/multi-agent.md` and the `port-docs`/`tiered-docs` assertions owned by Docs (story 04).
- Cleaning `~/.gemini` on this machine.
- Any change to the Claude or OpenCode install behaviour.

## Suggestions (your call)

- Assumption: `install.sh` keeps building `build/agents/opencode` exactly as today; `install_antigravity`'s `link_generated antigravity` calls go with it, so story 02 can delete the antigravity build without breaking installs.

## Size

normal
Risk: item 1, 3, 5 (backup prune guard and uninstall, `--target` contract, installer)

## Log

- L1 request: /flow:story 01
