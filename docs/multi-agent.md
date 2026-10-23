# Multi-Agent Architecture (Claude Code, OpenCode, Antigravity)

Preserve the planning-first, Spec-Driven Development (SDD), Engram memory, and verification workflow across Claude Code, OpenCode, and Google Antigravity without altering your daily development habits.

## Core Principle

**The workflow is the source of truth; the agent runtime is an interchangeable execution engine.**

Whether interacting with Claude Code, OpenCode, or Antigravity, the conventions remain strictly identical:
1. **Planning first**: Research -> Plan -> Foundation -> Bootstrap -> Plan Review -> Gap Filling -> Handoff.
2. **Spec-Driven Development**: Formal changes under `openspec/`, strict TDD, and phase gates (`new`/`ff` -> `continue` -> `apply` -> `verify` -> `archive`).
3. **Engram memory**: Proactive persistence after decisions, bug fixes, and discoveries.
4. **Verification harness**: `make check` gates acceptance before finishing work.

---

## Component Compatibility Matrix

| Component | Claude Code | OpenCode | Antigravity | Canonical Location |
|---|---|---|---|---|
| **Global Rules** | `~/.claude/CLAUDE.md` | `~/.config/opencode/AGENTS.md` & workspace `AGENTS.md` | `~/.gemini/config/AGENTS.md` & workspace `AGENTS.md` | `AGENTS.md` (root, linked to `claude/CLAUDE.md`) |
| **Workflow Skills (`flow`)** | via `flow` plugin | `~/.config/opencode/skills/` | `~/.gemini/antigravity-cli/skills/` | `plugins/flow/skills/` |
| **SDD Skills (`sdd`)** | via `sdd` plugin | `~/.config/opencode/skills/` | `~/.gemini/antigravity-cli/skills/` | `plugins/sdd/skills/` |
| **Toolkit Skills (`toolkit`)** | via `toolkit` plugin | `~/.config/opencode/skills/` | `~/.gemini/antigravity-cli/skills/` | `plugins/toolkit/skills/` |
| **Subagents** | `plugins/*/agents/*.md` | `~/.config/opencode/agents/*.md` | Dynamic runtime (`define_subagent` / `invoke_subagent`) | `plugins/*/agents/` |
| **Persistent Memory** | Engram via MCP / CLI | Engram via MCP (`opencode mcp add`) | Engram via MCP (`mcp_config.json`) | System engram binary (`~/.local/bin/engram`) |
| **Lifecycle Hooks** | Shell hooks in `plugins/*/hooks/` | JS/TS runtime plugins | `hooks.json` (`run_command` matchers) | Tool-specific adapter layer |
| **UI & Statusline** | `look` plugin & `statusline.sh` | Native OpenCode TUI | Antigravity CLI / IDE Canvas | Claude-specific (isolated) |
| **System Binaries** | `bin/*` in `~/.local/bin` | Same | Same | Agnostic OS-level tools |

---

## Target-by-Target Breakdown

### 1. Claude Code (Default / Baseline)
Claude Code remains a first-class citizen. Nothing in the Claude configuration or runtime changes:
- `claude/CLAUDE.md` is linked to `~/.claude/CLAUDE.md`.
- `claude/settings.json` is merged into `~/.claude/settings.json`.
- The marketplace `ai-dotfiles` registers and installs `flow`, `sdd`, `toolkit`, and `look`.
- Statusline and look band operate as normal.

### 2. OpenCode
OpenCode adheres to open standards for Agent Skills and markdown agents:
- **Rules:** Reads `AGENTS.md` from the project root automatically.
- **Skills:** Discovers skills placed in `~/.config/opencode/skills/` (symlinked from `plugins/*/skills/*`). Each skill retains its progressive disclosure via YAML frontmatter (`name`, `description`).
- **Agents:** Subagents like `plan-reviewer` and `jd-judge-a` map directly to `.opencode/agents/` or `~/.config/opencode/agents/`.
- **MCP:** Engram is exposed via `opencode mcp add engram`.

### 3. Google Antigravity
Antigravity supports progressive skills, hierarchical rules, and runtime subagent delegation:
- **Rules:** Hierarchically discovers `AGENTS.md` from the working directory up to git root, plus global rules in `~/.gemini/config/`.
- **Skills:** Loaded from `~/.gemini/antigravity-cli/skills/` (or project `.agents/skills/`). Frontmatter and folder structure (`SKILL.md`, `references/`, `scripts/`) are 100% compatible.
- **Subagents:** Antigravity orchestrates phase agents dynamically at runtime (`sdd-orchestrator` invokes `sdd-apply`, `sdd-verify`, etc.).
- **Hooks:** Native `hooks.json` maps events (`PreToolUse`, `PostToolUse`), with the execution matcher matching `run_command`.

---

## Switching Between Agents Without Friction

Because the rules and skills share the exact same underlying files through symlinks:
1. **Zero drift:** Edits to a skill or rule take effect immediately across all agents.
2. **Zero switching cost:** When opening a project in Claude, OpenCode, or Antigravity, the agent receives the exact same role constraints, communication tone, and progressive procedure runbooks.
3. **Safe fallbacks:** If an agent lacks a specific UI feature (like Claude's `statusline.sh` or `look` banner), core execution and verification (`make check`) are completely unaffected.

---

## Verification

Every change to rules, skills, or installer scripts must pass:
```bash
make check
```
This guarantees that cross-agent compatibility additions never break Claude Code marketplace validations, line caps, or test suites.
