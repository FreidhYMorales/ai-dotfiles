# Multi-agent support (Claude Code, OpenCode, Antigravity)

Claude Code is the full target. OpenCode and Antigravity get the shared rules and the skill files, nothing more. This page says what `install.sh` does for each one and what still works only in Claude Code.

## What the installer does

`./install.sh` detects the installed agents; `--target claude|opencode|antigravity|all` (comma-separated) picks them by hand.

| Piece | Claude Code | OpenCode | Antigravity |
|---|---|---|---|
| Global rules | `claude/CLAUDE.md` → `~/.claude/CLAUDE.md` | `AGENTS.md` → `~/.config/opencode/AGENTS.md` | `AGENTS.md` → `~/.gemini/config/AGENTS.md`, when `~/.gemini` exists |
| Skills | `flow`, `toolkit`, `look` plugins | each `plugins/*/skills/*` → `~/.config/opencode/skills/` | each `plugins/*/skills/*` → `~/.gemini/antigravity-cli/skills/` |
| Plugin agents | yes | no | no |
| Hooks | yes | `prefer-modern-cli` only: plugin `toolkit.ts` → `~/.config/opencode/plugins/` | `prefer-modern-cli` only: a `toolkit` key merged into `~/.gemini/config/hooks.json` |
| Engram MCP | yes (plugin) | configure by hand; the installer warns when missing | configure by hand; the installer warns when missing |
| Status line, `look` band | yes | no | no |
| `bin/*`, systemd units, git hooks | yes | yes | yes |

The repo-root `AGENTS.md` is a symlink to `claude/CLAUDE.md`, so all three agents read the same rules file.

## Manual setup per machine

The installer never writes engram's MCP config outside Claude Code (`engram setup` may rewrite the agent's config); it only checks it and prints a warning naming the manual step:

- OpenCode: an enabled `mcp.engram` entry in `~/.config/opencode/opencode.json` running `engram mcp --tools=agent`. Missing or `"enabled": false` warns `run: engram setup opencode`.
- Antigravity: `agy mcp list` must list `engram`. The installer asks `agy` instead of reading a file, because two `mcp_config.json` exist (`~/.gemini/config/` and `~/.gemini/antigravity-cli/`). Missing warns `run: engram setup antigravity-cli`; without `agy` on the PATH it says it cannot check.

### Which rules files Antigravity loads

Checked on 2026-10-27 with agy 1.4.7: a unique sentinel line in each candidate file, then `agy -p` from a directory outside any repo, run twice with the same result.

| File | Loaded |
|---|---|
| `~/.gemini/config/AGENTS.md` | yes |
| `~/.gemini/AGENTS.md` | yes |
| `~/.gemini/GEMINI.md` | yes |
| `~/.gemini/antigravity-cli/AGENTS.md` | no |

`install.sh` links the rules only at `~/.gemini/config/AGENTS.md` (the global root agy's own docs name) and removes the link earlier runs made under `antigravity-cli/`. Because agy loads `~/.gemini/GEMINI.md` on top of these rules (gentle-ai writes one), the installer moves it to `~/.gemini/GEMINI.md.bak-<timestamp>` and prints the `mv` command that restores it.

### Which skills dirs Antigravity discovers

Checked on 2026-10-28 with agy 1.4.7, the same way: sentinel skills in each candidate dir, two `agy -p` runs plus a control run.

| Dir or case | Result |
|---|---|
| `~/.gemini/config/skills/` | discovered |
| `~/.gemini/antigravity-cli/skills/` | discovered |
| `~/.gemini/skills/` | discovered |
| a `<name>.bak-<timestamp>` dir in a skills dir | discovered, by its `name:` frontmatter |
| two skills with the same `name:` | the copy in `~/.gemini/antigravity-cli/skills/` wins |
| `~/.gemini/antigravity-cli/skills-backup/` | not discovered |

The repo skills already live in the winning dir. `install.sh` moves every `*.bak-*` entry out of `~/.gemini/antigravity-cli/skills/` into `skills-backup/` (an earlier installer left gentle-ai's originals there under that name), adding a numeric suffix when the name is taken; nothing is deleted.

## What works outside Claude Code

Skills that are plain instructions work: most of `flow` (`plan`, `research`, `foundation`, `bootstrap`, `fill-gaps`, `handoff`, `idea`, `next`, `split`, `integrate`) and most of `toolkit`.

These skills depend on Claude Code and break elsewhere:

- `flow:backlog`, `flow:story` and `flow:pair`: the loop relies on Claude Code hooks and the `flow:verifier` agent, so the installer does not link these three skills outside Claude Code.
- `flow:plan-review`: needs the `flow:plan-reviewer` agent.
- `toolkit:judgment-day`: needs the `toolkit:jd-*` agents.

Porting them (agents per tool, plugin-root paths, hooks) is open work; it starts with `/flow:plan`.

## Known side effect

Inside this repo, Claude Code loads the rules twice: once as the global `~/.claude/CLAUDE.md` and once as the project `AGENTS.md`.
