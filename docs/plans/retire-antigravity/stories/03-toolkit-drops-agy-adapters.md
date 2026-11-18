# Story 03: the toolkit plugin drops its Antigravity hook adapters

## Story

03. As a developer, I want the toolkit plugin to drop its Antigravity hook adapters so that its hooks serve only Claude Code and OpenCode. Requires: #01

## Acceptance criteria

- [ ] Given the toolkit plugin, when I look at its hooks, then there is no Antigravity adapter directory and no Antigravity adapter test, while every Claude Code hook and its test is unchanged.
- [ ] Given the release, when I read the plugin manifest and the marketplace, then both list toolkit at version 0.22.0 or newer, with the same version.
- [ ] (manual) Given the change merged, when I rerun `./install.sh`, then Claude Code loads toolkit 0.22.0 and its hooks still run (a legacy command is still blocked).

## Plan

- The three Antigravity adapters and their three tests are deleted; no Claude hook calls them, so nothing else changes in the plugin.
- The toolkit version goes 0.21.0 → 0.22.0 in the plugin manifest and the marketplace in one bump, like earlier releases.
- The retirement test pins the new state the repo's way: the adapter directory is absent and the version is `at_least 0.22.0`; the existing manifest-equality check keeps both files equal.
- Deleting the adapter tests is pre-approved by the plan and is not a RED step.
- Closing scan `rg -n -i 'agy|antigravity|\.gemini'` over the toolkit plugin shows nothing; the new retirement assertion in the retirement test is the only regression RED this story adds.

## Out of scope

- The installer, `ai-update` (story 01) and the generator (story 02).
- README, `docs/multi-agent.md` (its `hooks/agy/` mention) and the `no-agy` test (story 04).
- Any change to the Claude Code hooks, the OpenCode plugin or the `flow` and `look` plugins.
- Cleaning `~/.gemini/config/hooks.json` on this machine.

## Suggestions (your call)

- Assumption: nothing outside `docs/` points at the adapters after story 01 (a scan of the repo finds `hooks/agy` only in `docs/multi-agent.md` and `docs/ideas.md`), so deleting them breaks no install.

## Size

normal
Risk: item 5 (plugin release)

## Log

- L1 request: /flow:story 03
- L2 user: approved the test list (mode C).
- Commits: c10d1b5 test + 206499c feat (hooks/agy absent; 3 adapters and 3 agy-*.test.sh deleted, pre-approved); 8cdb68c test + 6f662e4 feat (toolkit at_least 0.22.0 in plugin.json and marketplace.json; bumped 0.21.0 -> 0.22.0).
- Closing scan `rg -n -i 'agy|antigravity|\.gemini' plugins/toolkit`: no hits.
- Evidence: `make check </dev/null` on 6f662e4: "All checks passed (8 steps)".
- Verifier: PASS on criteria 1-2 (mutants in a scratch clone; commit order, tamper and assertions PASS; its own `make check` passed). Criterion 3 left manual. The pre-run ref snapshot was lost when the scratchpad was cleared on session resume; reflogs show no ref moved (main = origin/main = f2aab66, HEAD's last move is 6f662e4).
- Manual criterion 3 (user ran `./install.sh` from this branch): "Plugin "toolkit" updated from 0.21.0 to 0.22.0", "done. Active targets: claude opencode."; installed_plugins.json lists toolkit 0.22.0 with no agy dir in its cache; the installed 0.22.0 prefer-modern-cli.sh blocks `ls -la` (exit 2, "Use eza instead of ls") and lets `eza -la` through (exit 0). The running session picks up 0.22.0 at its next restart.
- Risk: item 5 (plugin release)
