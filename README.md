# ai-dotfiles

Personal configuration for AI coding tools. Claude Code first; OpenCode and Gemini later.

## Layout

| Path | What | How it is installed |
|---|---|---|
| `claude/CLAUDE.md` | Minimal always-on rules | Symlinked to `~/.claude/CLAUDE.md` |
| `claude/settings.json` | Settings fragment | Merged into `~/.claude/settings.json` with `jq` |
| `.claude-plugin/marketplace.json` | Makes this repo a plugin marketplace | `claude plugin marketplace add` |
| `plugins/flow/` | Workflow plugin: skills, agents, hooks | `claude plugin install flow@ai-dotfiles` |
| `bin/` | Maintenance scripts (e.g. `ai-update`) | Run manually |
| `docs/` | Workflow design notes | - |

## Workflow

```
research (optional) -> plan (scope + UX in parallel) -> plan-review -> fill-gaps -> plan-review -> handoff -> implement
```

Memory: [engram](https://github.com/Gentleman-Programming/engram) is the only memory system. It is installed with `engram setup claude-code` and is not managed by this repo.

## Install

```bash
./install.sh --dry-run   # preview
./install.sh
```

Requires `jq`, `rg` and `claude`.

## Roadmap

- [ ] `flow` skills content
- [ ] `bin/ai-update`: safe engram/tool updates (backup, checksum, confirm on major)
- [ ] Session-start hook: notify-only update check
- [ ] Permissions allow/deny list
- [ ] Fix SDD agents' engram tool names (`mcp__engram__*`)
- [ ] OpenCode and Gemini support
