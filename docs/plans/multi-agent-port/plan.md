# Plan: multi-agent-port

- Status: draft (gaps filled after plan-review-1, -2 and -3; awaiting plan-review-4)
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
- **Generator** (`scripts/gen-agents/`): reads sources, writes per-agent output into a gitignored build dir (`build/agents/<target>/`) that `install.sh` links. `install.sh` and `ai-update` run the generator into a temp dir and swap it in atomically (never `rm -rf` the live dir); `install.sh` warns when the installed build is stale or a link dangles. `make check` generates into a temp dir and compares with committed golden fixtures, so CI and a fresh checkout need no build dir.
  - Scope: every skill and agent that is linked into the targets goes through the generator (no raw links). A reference to something not generated for a target becomes "(Claude Code only)", never a dangling name.
  - Names: one map, `flow:x` → `flow-x` and `toolkit:x` → `toolkit-x`, applied to dir names, `name:` frontmatter, commands and references; golden-tested.
  - Skills and rules (`AGENTS.md` too): copies with `${CLAUDE_PLUGIN_ROOT}`, relative plugin paths (`../`, `skills/...`) and "this skill's base directory" resolved to absolute, quoted repo paths (the repo path has a space); agent and skill names rewritten through the name map; slash commands rewritten `/flow:x` → `/flow-x`; tool wording rewritten (Agent tool → Task tool / `invoke_subagent`, `mcp__engram__mem_*` → target tool names); "in parallel" → "sequentially" where the target cannot run subagents in parallel; `general-purpose` → OpenCode `general` / agy default agent. Golden tests fail on any leftover Claude-only form.
  - Commands: every generated command follows the name map in both targets (`/flow-pair 08`, `/toolkit-judgment-day`). `disable-model-invocation: true` maps to command-only in OpenCode; in agy the `/flow-pair` skill command is checked in the spike.
  - Agents: frontmatter mapped. `model` comes from one role map (`scripts/gen-agents/models.json`): roles `reviewer` (plan-reviewer, verifier, jd judges) and `worker` (jd-fix-agent), one entry per target, default `inherit`. Claude keeps its current frontmatter (`opus`; Claude Code subagents run Anthropic models only, local work stays with `toolkit:delegate-local`). OpenCode accepts any `provider/id`, including `ollama/<model>`, so the local-AI work can point a role at a local model by editing one line. agy accepts `inherit`, `pro` or `flash` only (no local models). OpenCode: `mode: subagent`, `permission` from `tools`. Antigravity: without a map entry, opus/sonnet → `pro`, haiku → `flash`; tools mapped through an explicit table built from the item 1 spike, unknown tool = generator error.
  - Hooks: the current hook files stay the Claude entry points and every existing hook test passes unchanged. Neutral contract: input `cwd`, event, `source` (agy and OpenCode default to `startup`), tool name and args, prompt, reentry; output `context` (for the model), `message` (for the user) or `block(reason)`; each target decides whether a user-only message is dropped or injected. Cores stay fail-open, as pinned today; only the agy and OpenCode PreToolUse adapters fail closed on a malformed payload. A Stop adapter never answers `continue` on missing input. agy adapter: `cwd` from `workspacePaths[0]`; Stop runs the core only when `terminationReason == NO_TOOL_CALL`; `executionNum > 1` maps to `stop_hook_active` (allow). Per-hook timeouts are copied into the agy `toolkit` key and the OpenCode plugin (`require-check` ≥ 330 s). Pair's red marker (`flow-pair-red`): `require-check` never blocks or continues; in agy the message is dropped (Stop has no carrier when not continuing).
- **Installer:** links generated output per target, only at paths the item 0 sentinel test proves the target reads. `~/.gemini/GEMINI.md` is backed up and removed only if that test shows agy loads it (Gemini CLI is not used). Merges a named `toolkit` key into agy `~/.gemini/config/hooks.json` with jq and links a separate OpenCode `toolkit.ts`; never touches herdr hooks, `engram.ts` or other keys. Repo skills shadow gentle-ai copies by precedence. The installer removes only its own symlinks into this repo; `.bak-*` dirs (gentle-ai originals moved aside by `link_file`) are moved out of every skills discovery dir into a backup dir (`~/.gemini/antigravity-cli/skills-backup/`), never deleted by the installer. Only verifies that engram MCP is registered per target (never runs `engram setup`).
- **Tests:** generator golden fixtures per agent (checked by `make check`); hook adapter golden tests with real payloads per target; installer sandbox tests per target, run from a path with a space; `make check` runs all of them.

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
| 0. agy discovery test first (sentinel files for rules and skills at every candidate path, `.bak-*` dirs and gentle-ai duplicates), then the installer fix at the proven paths; `GEMINI.md` handled as in Core model; fix `docs/multi-agent.md` | MUST | 0.75 | high: today agy may have no rules |
| 1. Spike (before item 4): `agy plugin import claude` on `flow`, plus an agy subagent that calls engram MCP; record the real agent dir, tool names and whether `/flow-pair` runs as a command | MUST | 0.5 | medium |
| 2. (C) Engram MCP: installer verifies engram is registered per target (OpenCode with jq, agy with `agy mcp list` only, since two agy `mcp_config.json` files exist); `engram setup` stays a documented manual step | MUST | 0.5 | high |
| 3. (C) Hooks: neutral contract (Core model: `source`, context/message split, fail-open cores, agy `terminationReason` and reentry rules, timeouts, red marker), 6 cores (`update-check` deferred), agy jq-merge adapter, OpenCode `toolkit.ts`, adapter golden tests incl. one SessionStart hook, cancel and reentry; `pause` in OpenCode only; `require-check` Claude + agy only | MUST | 3.5 | high |
| 4. (B) Generator skeleton + `plan-reviewer` agent and `plan-review` skill for both targets + golden fixtures in `make check` + gitignored build dir with atomic swap + name map + role model map + `install.sh`/`ai-update` wiring with `scripts/tests/ai-update.test.sh` | MUST | 2.5 | high: proves the agent format |
| 5. (A) Loop: `flow:backlog`, `flow:story` and `flow:pair` skills (with pair's references), `toolkit:work-unit-commits` and the `flow:verifier` agent through the generator; `/flow-backlog`, `/flow-story`, `/flow-pair` commands; `disable-model-invocation` mapping; red tests first, then drop `CLAUDE_ONLY_SKILLS` and its install tests | MUST | 1.75 | high |
| 5b. Every other linked skill (plan, research, fill-gaps, handoff, next, idea, split, integrate, ship...) through the generator; `/flow-plan`, `/flow-plan-review`, `/flow-fill-gaps` commands (v1 vision) | MUST | 0.75 | high |
| 6. (A) judgment-day: `jd-judge-a/b`, `jd-fix-agent` through the generator (sequential judges where needed) | SHOULD | 0.5 | medium |
| 7. Remaining commands in OpenCode (`/flow-next`, `/flow-handoff`, `/toolkit-*`, ...); collision test against built-ins | SHOULD | 0.25 | medium |
| 8. Manual smoke per target: run `/flow-plan-review` and one high-risk `/flow-backlog` → `/flow-story` → `/flow-pair` story on a toy repo in OpenCode and agy (the verifier must run, or in agy stop with NEEDS DECISION); record in `docs/multi-agent.md` | MUST | 1.5 | high |
| 9. Migration: remove own symlinks; move `.bak-*` dirs out of discovery dirs (install test seeds a real `.bak-*` dir and asserts it survives); migrate `scripts/tests/install.test.sh` to the generated layout | MUST | 0.5 | medium |
| 10. Docs: README roadmap, `install.sh` header, `docs/multi-agent.md` (incl. the agy `mcp_config.json` line); one neutral line in source `AGENTS.md`: "In OpenCode/agy, `/flow:x` is `/flow-x`" | SHOULD | 0.25 | low |

Total MUST ≈ 12.25 dev-days; with SHOULD ≈ 13.25. No deadline: fits.

## Demo data

A throwaway toy repo (e.g. a tiny CLI with one function) used for the manual smoke of item 8 in each agent. Lives in the scratchpad, not in the repo.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| Which rules and skills paths `agy` reads (`~/.gemini/AGENTS.md` per web docs vs `~/.gemini/config/` per bundled 1.4.7 docs) | Unknown; the item 0 sentinel test decides, the installer links only proven paths | me | no (item 0) |
| agy subagent format and tool names (`flow:verifier` depends on them) | Web docs only; the item 1 spike decides. If unworkable, high-risk stories in agy stop with NEEDS DECISION (never an inline verifier) | user | yes (fallback); no (format, item 1) |
| Which `mcp_config.json` agy uses | `~/.gemini/config/mcp_config.json` (listed by `agy mcp list`) | me | no (item 2) |
| OpenCode skills reading sibling files by relative path | Not supported; generator writes absolute paths | me | no |
| OpenCode command names with a colon (`flow:story`) | Not allowed; every command is `flow-` prefixed in both targets (`/flow-story`) | user | yes |
| What `engram setup opencode|antigravity-cli` writes | Not run by the installer; verify only, `engram setup` is a documented manual step | me | yes |
| OpenCode plugin API v2 migration | Target the API of v2.1.4; pin in docs | me | no |
| Exact agy tool names for each Claude tool | Build the table from `builtin/skills/agy-customizations/docs`; generator fails on unknown | me | no |

## Deferred to v2

- Status line and `look` band equivalents — Claude UI only.
- `require-check` (Stop gate) for OpenCode — no blocking hook exists; v1 uses a generated rule line to run `make check` before saying done.
- `pause` for agy — no prompt-submit event; v1 uses a rule line.
- `update-check.sh` for other agents — reads `~/.claude/plugins`.
- macOS / other distros — user only uses Linux.

## Demo priorities

1. agy and OpenCode load the same rules (ask "what are your communication rules?").
2. Engram memory saved in OpenCode is found from agy and Claude.
3. `prefer-modern-cli` blocks `ls` in all three.
4. `plan-review` runs its blind sub-agent in both targets.
5. One high-risk `flow:backlog` → `flow:story` → `flow:pair` story on the toy repo in both targets: red steps pass the Stop gate with a message, the verifier runs (agy: or the story stops with NEEDS DECISION).

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: n/a
- Work packages: n/a

## Plan-review resolutions

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| R1-1 | agy rules path conflicts with bundled docs | Item 0 sentinel test decides; installer links only proven paths (Data gaps) | planner |
| R1-2 | Deleting `~/.gemini/GEMINI.md` | Gemini CLI is not used; back up and remove only if the item 0 test shows agy loads it | user |
| R1-3 | Overwriting herdr hooks and `engram.ts` | jq-merge a `toolkit` key into agy `hooks.json`; separate OpenCode `toolkit.ts`; other keys untouched | planner |
| R1-4 | Adapter inputs (cwd, source, reentry) | Neutral hook contract in Core model; `cwd` from `workspacePaths[0]`, reentry from `executionNum`; fail closed; adapter golden tests | planner |
| R1-5 | `pause` mapping, "7 hooks" count | 6 hooks ported (`update-check` deferred); `pause` OpenCode only in v1, agy rule line | user |
| R1-6 | agy skills discovery and gentle-ai collisions | Repo skills shadow gentle-ai copies by precedence, never delete; item 0 test covers `.bak-*` and duplicates | user |
| R1-7 | Path rewriting, space in the repo path | Generator rewrites every relative and plugin-root form and quotes paths; golden tests fail on leftovers; sandbox tests run from a path with a space | planner |
| R1-8 | Build dir location and staleness | Gitignored `build/agents/<target>/`; `install.sh` and `ai-update` regenerate; `make check` staleness check | user (ai-update), planner |
| R1-9 | agy subagent and MCP tool names | Item 1 spike before item 4 records them; unknown tool stays a generator error | planner |
| R1-10 | Old links and install tests | New item 9 | planner |
| R1-11 | Parallel delegation, `general-purpose` fallback | "in parallel" → "sequentially" where unsupported; `general-purpose` → `general` / agy default | planner |
| R1-12 | `engram setup` may overwrite | Verify only; manual documented step | planner |
| R1-13 | Command collisions with built-ins | `flow-` prefix everywhere; collision test in item 7 | user |
| R1-14 | Docs list | New item 10 (SHOULD) | planner |
| R1-Q3 | OpenCode Stop gate rule-only | Accepted for v1 if it behaves like Claude's Stop gate; generated rule line (Deferred to v2) | user |
| R2-1 | Review 1 findings unresolved | Resolved in this table (`plan-review-2.md`) | planner |
| R2-2 | Loop needs slash commands (item 5 MUST depended on item 7 SHOULD) | `/flow-backlog`, `/flow-story`, `/flow-pair` inside item 5; `/flow:x` → `/flow-x` rewrite; `disable-model-invocation` mapping | planner |
| R2-3 | Stop gate must honour pair's red marker | Part of the neutral hook contract; agy adapter golden test (red marker → allow with message) | planner |
| R2-4 | `CLAUDE_ONLY_SKILLS` and its tests not removed | Item 5: red tests first, then drop it | planner |
| R2-5 | Loop depends on `toolkit:work-unit-commits`; shadow copies | Added to item 5; item 0 test covers shadowing; `.bak-*` handling corrected in R3-1 | planner |
| R2-6 | `AGENTS.md` names `/flow:*` verbatim | Rules go through the same generator rewrite | planner |
| R2-7 | Verifier fallback path and "base directory" | Generator rewrites both; golden test fails on leftovers | planner |
| R2-8 | Smoke never exercises the verifier | Item 8 uses a high-risk toy story | planner |
| R2-Q4 | agy verifier unworkable | Stop with NEEDS DECISION, finish the story in Claude or OpenCode; never inline. agy is a rare fallback for very complex tasks | user |
| Estimates | Plan undercounted hooks, migration and commands | MUST ≈ 10.75 dev-days (`plan-review-2.md` scope table) | planner |
| R3-1 | `.bak-*` dirs are gentle-ai originals, not clutter (R2-5 resolution was wrong) | Moved out of discovery dirs into a backup dir, never deleted by the installer; install test seeds a real `.bak-*` dir | user (move or delete both fine), planner (move: reversible) |
| R3-2 | ~20 linked skills had no stated fate; MUST skills pointed at SHOULD commands | Every linked skill goes through the generator (item 5b, MUST); `/flow-plan`, `/flow-plan-review`, `/flow-fill-gaps` in MUST; references to non-generated parts become "(Claude Code only)" | user |
| R3-3 | Staleness check on a gitignored dir breaks CI and Stop | `make check` compares a temp generation with committed golden fixtures; stale installed build is an `install.sh` warning only | planner |
| R3-4 | Hook contract lacks `source` and a context/message split | Added to the neutral contract; SessionStart adapter golden test per target | planner |
| R3-5 | "Fail closed" contradicts pinned fail-open Claude hooks | Cores stay fail-open; only non-Claude PreToolUse adapters fail closed; Stop never `continue` on missing input; current hook files stay the Claude entry points | planner |
| R3-6 | agy Stop runs on every `terminationReason` | Core runs only on `NO_TOOL_CALL`; `executionNum > 1` = `stop_hook_active`; golden tests for cancel and reentry | planner |
| R3-7 | agy 30 s default hook timeout | Per-hook timeouts copied to agy and OpenCode; golden test `require-check` ≥ 330 s | planner |
| R3-8 | Red-marker message has no carrier in agy Stop | agy golden test asserts only "not `continue`"; message dropped in agy | planner |
| R3-9 | `ai-update` wiring in no scope item | Added to item 4 with `scripts/tests/ai-update.test.sh` | planner |
| R3-10 | Skill and toolkit names undefined in targets | One name map `flow:x` → `flow-x`, `toolkit:x` → `toolkit-x` for dirs, `name:`, commands, references | planner |
| R3-11 | Raw repo `AGENTS.md` conflicts with generated rules inside this repo | One neutral line in source `AGENTS.md` (item 10) | planner |
| R3-12 | OpenCode reviewers inherit a possibly weak session model | Role model map (`reviewer`, `worker`) per target, default `inherit`; OpenCode can point a role at `ollama/<model>` for the local-AI work; Claude stays `opus` (Anthropic-only subagents; local via `toolkit:delegate-local`); agy `pro`/`flash` only; smoke runs reviewers on a strong model | user (orient to local AI), planner |
| R3 risks | Claude hook regressions, live configs in a gitignored dir, two agy `mcp_config.json`, CI cost | Hook files stay Claude entry points; atomic swap; verify agy with `agy mcp list` only; golden tests in bash/jq | planner |
| Estimates (R3) | Hooks, generator wiring, all skills | MUST ≈ 12.25 dev-days (`plan-review-3.md` 12 + 0.25 role map) | planner |
