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
- L2 user: approved the test list (mode C); step 3 split into 3a (RED + minimal green), 3b (dead-code refactor), 3c (agy test removal).
- Commits: 5226d36 test + 0783579 feat (--target antigravity rejected); 2307aa1 test + 5e09fca feat (--target all = claude opencode); 94fb0e7 test + 7ff67ca feat (auto-detect never picks agy; the sandbox fake agy removed in the same green); e9a50c2 refactor (dead agy install/uninstall paths, AGY_PINNED); a000267 test (agy install test files deleted, agy parts of shared install tests removed per the shared-file rule); 41dba9b test (uninstall leaves ~/.gemini alone); 7be3299 test + 527ae6a feat (ai-update passes only --target opencode); c5e83ed test (only an Antigravity dir regenerates nothing); aef0909 refactor (remaining agy variables, comments, usage text, prune_backups agy exception); bcc2ee8 test (port-docs/tiered-docs stop pinning installer agy text).
- Tests 4 (41dba9b) and 6 (c5e83ed) passed on first run: the code came with 3b and 527ae6a. Both were shown red against main's install.sh / bin/ai-update before committing (triangulation, no feat of their own).
- Closing scan over install.sh, bin/ai-update, install-*.test.sh, install-lib.sh, ai-update.test.sh: only the regression REDs (install-targets.test.sh, regen-agy, regen-both). Docs-owned lines left: port-docs.test.sh:34-35,62 and tiered-docs.test.sh:44.
- Evidence: `make check` on bcc2ee8: "All checks passed (8 steps)"; slowest test file now install-opencode 53.0s (was install-agy-skills 79.5s).
- Verifier: PASS (criteria 1-3 PASS with mutants in a scratch clone; commit order PASS; tamper PASS; assertions PASS; its own `make check` passed). Refs and HEAD unchanged across the run. Notes, no change made: aef0909 edited ai-update.test.sh labels/setup inside a refactor commit (all listed in the plan); the `--target all` check matches the done line anywhere, not as the last line.
- Risk: item 1, 3, 5 (backup prune guard and uninstall, `--target` contract, installer)
