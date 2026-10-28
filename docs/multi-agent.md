# Multi-agent support (Claude Code, OpenCode, Antigravity)

Claude Code is the full target. OpenCode and Antigravity get the shared rules and the skill files, nothing more. This page says what `install.sh` does for each one and what still works only in Claude Code.

## What the installer does

`./install.sh` detects the installed agents; `--target claude|opencode|antigravity|all` (comma-separated) picks them by hand.

| Piece | Claude Code | OpenCode | Antigravity |
|---|---|---|---|
| Global rules | `claude/CLAUDE.md` → `~/.claude/CLAUDE.md` | `AGENTS.md` → `~/.config/opencode/AGENTS.md` | `AGENTS.md` → `~/.gemini/config/AGENTS.md`, when `~/.gemini` exists |
| Skills | `flow`, `toolkit`, `look` plugins | each `plugins/*/skills/*` → `~/.config/opencode/skills/` | each `plugins/*/skills/*` → `~/.gemini/antigravity-cli/skills/` |
| Plugin agents | yes | no | no |
| Hooks | yes | no | no |
| Engram MCP | yes (plugin) | no: configure by hand | no: configure by hand |
| Status line, `look` band | yes | no | no |
| `bin/*`, systemd units, git hooks | yes | yes | yes |

The repo-root `AGENTS.md` is a symlink to `claude/CLAUDE.md`, so all three agents read the same rules file.

## Manual setup per machine

Engram is not wired by the installer outside Claude Code. Add it by hand:

- OpenCode: an `mcp.engram` entry in `~/.config/opencode/opencode.json` running `engram mcp --tools=agent`.
- Antigravity: an `engram` server in `~/.gemini/antigravity-cli/mcp_config.json`.

### Which rules files Antigravity loads

Checked on 2026-10-27 with agy 1.4.7: a unique sentinel line in each candidate file, then `agy -p` from a directory outside any repo, run twice with the same result.

| File | Loaded |
|---|---|
| `~/.gemini/config/AGENTS.md` | yes |
| `~/.gemini/AGENTS.md` | yes |
| `~/.gemini/GEMINI.md` | yes |
| `~/.gemini/antigravity-cli/AGENTS.md` | no |

`install.sh` links the rules only at `~/.gemini/config/AGENTS.md` (the global root agy's own docs name) and removes the link earlier runs made under `antigravity-cli/`. Because agy loads `~/.gemini/GEMINI.md` on top of these rules (gentle-ai writes one), the installer moves it to `~/.gemini/GEMINI.md.bak-<timestamp>` and prints the `mv` command that restores it.

## What works outside Claude Code

Skills that are plain instructions work: most of `flow` (`plan`, `research`, `foundation`, `bootstrap`, `fill-gaps`, `handoff`, `idea`, `next`, `split`, `integrate`) and most of `toolkit`.

These skills depend on Claude Code and break elsewhere:

- `flow:backlog`, `flow:story` and `flow:pair`: the loop relies on Claude Code hooks and the `flow:verifier` agent, so the installer does not link these three skills outside Claude Code.
- `flow:plan-review`: needs the `flow:plan-reviewer` agent.
- `toolkit:judgment-day`: needs the `toolkit:jd-*` agents.

Porting them (agents per tool, plugin-root paths, hooks) is open work; it starts with `/flow:plan`.

## Known side effect

Inside this repo, Claude Code loads the rules twice: once as the global `~/.claude/CLAUDE.md` and once as the project `AGENTS.md`.
