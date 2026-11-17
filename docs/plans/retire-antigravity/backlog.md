# Backlog: retire-antigravity

## Context

- What: the repo supports Claude Code and OpenCode only; Antigravity (agy) stops being generated, installed, tested and documented. Plan: `docs/plans/retire-antigravity/plan.md`. Lands before `clean-install` stage 3. Superseded, carried by no story: cleaning `~/.gemini` on this machine; the Antigravity half of `multi-agent-port` beyond dropping #47; agy entries in closed plans and ideas (history stays).
- Stack: bash, Claude Code plugins (hooks), the agent generator (`scripts/gen-agents`), `install.sh`, `make`.
- Expensive decisions: `install.sh --target` accepts only `claude|opencode|all`; OpenCode generated output stays byte for byte; no `~/.gemini` cleanup.
- Test command: `make check`
- Single test: `bash scripts/tests/<name>.test.sh` (plugin hooks: `bash plugins/toolkit/hooks/tests/<name>.test.sh`)

## Backlog

01. [ ] As a developer, I want install.sh and ai-update to stop installing Antigravity so that an install sets up only Claude Code and OpenCode.
02. [ ] As a developer, I want the agent generator to produce only OpenCode output so that a skill change touches one golden set. Requires: #01
03. [ ] As a developer, I want the toolkit plugin to drop its Antigravity hook adapters so that its hooks serve only Claude Code and OpenCode. Requires: #01
04. [ ] As a developer, I want the docs and open items to describe only Claude Code and OpenCode so that nothing in the repo points at Antigravity. Requires: #01, #02, #03
