# Plan: multi-agent-port

- Status: draft
- Deadline: none
- Mode: solo
- Supersedes: the "Port the Claude-only parts" roadmap item in `README.md`; corrects the Antigravity rules path in `docs/multi-agent.md` (commit 498f131)

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| Claude Code | yes (unchanged baseline) | current pinned version | plugins from this marketplace |
| OpenCode | yes | v2.1.4 (local) | `install.sh --target opencode` |
| Antigravity CLI (`agy`) | yes | 1.4.7 (local) | `install.sh --target antigravity` |
| Linux (Arch) | yes | this machine | git clone + `install.sh` |

- Out of scope: macOS, other distros, Antigravity IDE/app (CLI only), Gemini CLI.

## Research

Read-only research run on 2026-10-26 (engram #701). Key findings:

- Antigravity CLI reads global rules from `~/.gemini/AGENTS.md`, `~/.gemini/GEMINI.md` and `~/.gemini/antigravity-cli/rules/*.md` (antigravity.google/docs/rules). `install.sh` links `~/.gemini/antigravity-cli/AGENTS.md`, which is not read. Per-file cap 24 KB, rules budget ~20k tokens. (v1)
- `~/.gemini/GEMINI.md` (gentle-ai, 85 KB) is over the cap and is truncated. (v1)
- OpenCode agents: `~/.config/opencode/agents/<name>.md`, frontmatter `description`, `mode: subagent`, `model: provider/id`, `permission` (`tools` deprecated). Delegation via the Task tool. MCP tools are named `engram_*`. (v1)
- OpenCode plugins: `~/.config/opencode/plugins/*.ts`; `tool.execute.before` blocks by throwing; no hook can block finishing (no `require-check`). Plugin API v2 migration in progress. (v1, risk)
- Antigravity subagents: `~/.gemini/config/agents/<name>.md`, frontmatter `name`, `description`, `tools` (agy names: `view_file`, `grep_search`, `run_command`…), `model: inherit|flash|pro`; invoked with `invoke_subagent`. A wrong tool name can hang the subagent. (v1, risk)
- Antigravity hooks: `~/.gemini/config/hooks.json`; events SessionStart, PreToolUse, PostToolUse, PreInvocation, PostInvocation, Stop; camelCase stdin (`toolCall.name`, `toolCall.args.CommandLine`); stdout `{"decision": "allow|deny|ask"}`, Stop `{"decision": "continue"}`. (v1)
- Antigravity has `agy plugin import claude` / `agy plugin install` for Claude Code plugins; untested. (v1 spike)
- Engram MCP is already configured by hand: `~/.config/opencode/opencode.json` and `~/.gemini/config/mcp_config.json`, command `engram mcp --tools=agent`. `engram setup <agent>` exists for opencode and antigravity-cli; untested. (v1)
- 7 toolkit hooks read Claude snake_case JSON and answer with Claude keys (`hookSpecificOutput.additionalContext`, `systemMessage`, exit 2). (v1)
- `${CLAUDE_PLUGIN_ROOT}` appears in skill and agent markdown only in `plugins/flow/agents/verifier.md` (1×, fallback path to the pair references); `plugins/toolkit/hooks/hooks.json` uses it for every hook command. "Agent tool"/"Skill tool" wording in judgment-day and the `jd-*` agents; `flow:plan-reviewer`, `flow:verifier` and `toolkit:jd-*` names in plan-review, story, pair and judgment-day. Flat skill symlinks break relative paths (`../../agents/...` in plan-review, `../pair/references/...` in story). (v1, refreshed 2026-10-27)

## Product vision

- **v1:** when Claude quota runs out, open OpenCode or Antigravity in any project and keep the same workflow: same rules, engram memory, safety hooks, `/flow:plan` + `plan-review`, and the story loop (`flow:backlog` → `flow:story` → `flow:pair`) with its `flow:verifier` sub-agent.
- **v2 (later):** status line / band equivalents, `look` features, other OSes, Gemini CLI.

## Core model

- **Source of truth:** Claude plugin files in `plugins/*` (skills, agents, hooks) and `AGENTS.md` → `claude/CLAUDE.md`. Never hand-edited per agent.
- **Generator** (`scripts/gen-agents/` or similar, decided in foundation of the change): reads sources, writes per-agent output into a build dir that `install.sh` links.
  - Skills: copies with `${CLAUDE_PLUGIN_ROOT}` and relative plugin paths resolved to absolute repo paths; agent names rewritten (`flow:plan-reviewer` → target agent name); tool wording rewritten (Agent tool → Task tool / `invoke_subagent`, `mcp__engram__mem_*` → target tool names).
  - Agents: frontmatter mapped. OpenCode: `mode: subagent`, no `model` (inherits session), `permission` from `tools`. Antigravity: `model` opus/sonnet → `pro`, haiku → `flash`; tools mapped through an explicit table, unknown tool = generator error.
  - Hooks: one core script per hook (agent-neutral input/output) plus a thin adapter per agent (Claude JSON, agy camelCase/decision JSON, OpenCode TS plugin calling the script).
- **Installer:** links generated output per target; sets Antigravity rules at `~/.gemini/AGENTS.md`; backs up and removes `~/.gemini/GEMINI.md`, warns if it reappears; checks engram MCP is registered per target.
- **Tests:** generator golden tests per agent; installer sandbox tests per target; `make check` runs both.

## Foundation

n/a: existing project with established conventions (`docs/development.md`, `make check`, Strict TDD, conventional commits).

## Screens

n/a: no UI. User-facing surface is `install.sh` output and agent behavior.

## Data captured / data inventory

| Screen | Data shown | Actions (events) | Source |
|---|---|---|---|
| n/a | | | |

## Scope

Order fixed by priority C → B → A.

| Item | Priority | Est. dev-days | Demo value |
|---|---|---|---|
| 0. Antigravity rules fix: link `~/.gemini/AGENTS.md`, back up/remove `GEMINI.md`, warn if it reappears; fix `docs/multi-agent.md` | MUST | 0.5 | high: today agy likely has no rules |
| 1. Spike: `agy plugin import claude` on `flow` (≤1 h); outcome decides whether item 4's Antigravity side is generated or imported | MUST | 0.25 | medium |
| 2. (C) Engram MCP: installer verifies/registers engram per target (`engram setup` if it writes the expected config, else jq merge) | MUST | 0.5 | high |
| 3. (C) Hooks: split the 7 toolkit hooks into core + adapters; Antigravity `hooks.json`, OpenCode TS plugin; `require-check` Claude + agy only | MUST | 2 | high |
| 4. (B) Generator skeleton + `plan-reviewer` agent and `plan-review` skill for both targets | MUST | 1.5 | high: proves the agent format |
| 5. (A) Loop: `flow:backlog`, `flow:story` and `flow:pair` skills (with pair's references) and the `flow:verifier` agent through the generator | MUST | 1 | high |
| 6. (A) judgment-day: `jd-judge-a/b`, `jd-fix-agent` through the generator | SHOULD | 0.5 | medium |
| 7. Slash-command equivalents: OpenCode `commands/*.md` for `/flow:*` (agy exposes skills as `/name`) | SHOULD | 0.5 | medium |
| 8. Manual smoke per target: run `/flow:plan`-review and one `flow:backlog` → `flow:story` → `flow:pair` story on a toy repo in OpenCode and agy; record in `docs/multi-agent.md` | MUST | 1 | high |

Total ≈ 7.75 dev-days.

## Demo data

A throwaway toy repo (e.g. a tiny CLI with one function) used for the manual smoke of item 8 in each agent. Lives in the scratchpad, not in the repo.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| Does `agy` read `~/.gemini/config/AGENTS.md`? | No; link `~/.gemini/AGENTS.md` only | me | no (verify in item 0) |
| Which `mcp_config.json` agy uses | `~/.gemini/config/mcp_config.json` (listed by `agy mcp list`) | me | no (item 2) |
| OpenCode skills reading sibling files by relative path | Not supported; generator writes absolute paths | me | no |
| OpenCode command names with a colon (`flow:story`) | Not allowed; use `flow-story` | me | no (item 7) |
| What `engram setup opencode|antigravity-cli` writes | May overwrite hand config; test in a sandbox HOME first | me | no |
| OpenCode plugin API v2 migration | Target the API of v2.1.4; pin in docs | me | no |
| Exact agy tool names for each Claude tool | Build the table from `builtin/skills/agy-customizations/docs`; generator fails on unknown | me | no |

## Deferred to v2

- Status line and `look` band equivalents — Claude UI only.
- `require-check` (Stop gate) for OpenCode — no blocking hook exists.
- `update-check.sh` for other agents — reads `~/.claude/plugins`.
- macOS / other distros — user only uses Linux.

## Demo priorities

1. agy and OpenCode load the same rules (ask "what are your communication rules?").
2. Engram memory saved in OpenCode is found from agy and Claude.
3. `prefer-modern-cli` blocks `ls` in all three.
4. `plan-review` runs its blind sub-agent in both targets.
5. One `flow:backlog` → `flow:story` → `flow:pair` story on the toy repo in both targets.

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: n/a
- Work packages: n/a

## Plan-review resolutions

| # | Finding | Resolution | Decided by |
|---|---|---|---|
