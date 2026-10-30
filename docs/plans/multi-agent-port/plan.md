# Plan: multi-agent-port

- Status: approved (gaps filled after plan-review-1 to -6; ready to build: next story #23)
- Deadline: none
- Mode: solo
- Supersedes: the "Port the Claude-only parts" roadmap item in `README.md`; corrects the Antigravity rules path in `docs/multi-agent.md` (commit 498f131)

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| Claude Code | yes (unchanged baseline) | current pinned version | plugins from this marketplace |
| OpenCode | yes | 2.2.2 (local, verified 2026-10-29) | `install.sh --target opencode` |
| Antigravity CLI (`agy`) | yes | 1.4.9 (local; rules and skills tables measured on 1.4.7, re-run on 1.4.9 in #17 and after every agy upgrade) | `install.sh --target antigravity` |
| Linux (Arch) | yes | this machine | git clone + `install.sh` |

- Out of scope: macOS, other distros, Antigravity IDE/app (CLI only), Gemini CLI.

## Research

Read-only research run on 2026-10-26 (engram #701). Key findings:

- Antigravity CLI reads global rules from `~/.gemini/AGENTS.md`, `~/.gemini/GEMINI.md` and `~/.gemini/antigravity-cli/rules/*.md` (antigravity.google/docs/rules). Story 01's sentinel test (agy 1.4.7) proved `~/.gemini/config/AGENTS.md`, `~/.gemini/AGENTS.md` and `~/.gemini/GEMINI.md` load and `~/.gemini/antigravity-cli/AGENTS.md` does not; `install.sh` links only `~/.gemini/config/AGENTS.md` (`docs/multi-agent.md`). Per-file cap 24 KB, rules budget ~20k tokens. (v1)
- `~/.gemini/GEMINI.md` (gentle-ai, 85 KB) is over the cap and is truncated. (v1)
- OpenCode agents: `~/.config/opencode/agents/<name>.md`, frontmatter `description`, `mode: subagent`, `model: provider/id`, `permission` (`tools` deprecated). Delegation via the `subagent` tool (2.2.2, story 08 L6). MCP tools are named `engram_*`. (v1)
- OpenCode plugins: `~/.config/opencode/plugins/*.ts`; the V1 factory never fires in 2.x; the working shape is `export default { id, setup }` with `ctx.tool.hook("execute.before")`, and throwing there blocks the tool (story 05); no hook can block finishing (no `require-check`). (v1)
- Antigravity subagents: `~/.gemini/config/agents/<name>.md`, frontmatter `name`, `description`, `tools` (agy names: `view_file`, `grep_search`, `run_command`…), `model: inherit|flash|pro`; invoked with `invoke_subagent`. A tool name missing from agy's registry never hangs: the subagent is never built, the error is only in the log and agy exits 0 (silent failure, story 03 L6). Registry names proven on 1.4.9: `read_file`, `view_file`, `grep_search`; engram needs `mcpServers:` (story 16). (v1, risk)
- Antigravity hooks: `~/.gemini/config/hooks.json`; events SessionStart, PreToolUse, PostToolUse, PreInvocation, PostInvocation, Stop; camelCase stdin (`toolCall.name`, `toolCall.args.CommandLine`); stdout `{"decision": "allow|deny|ask"}`, Stop `{"decision": "continue"}`. (v1)
- Antigravity has `agy plugin import claude` / `agy plugin install` for Claude Code plugins; untested (spike moved to LATER, R5-7).
- Engram MCP is already configured by hand: `~/.config/opencode/opencode.json` and `~/.gemini/config/mcp_config.json`, command `engram mcp --tools=agent`. `engram setup <agent>` exists for opencode and antigravity-cli; untested. (v1)
- 7 toolkit hooks read Claude snake_case JSON and answer with Claude keys (`hookSpecificOutput.additionalContext`, `systemMessage`, exit 2). (v1)
- `${CLAUDE_PLUGIN_ROOT}` appears in skill and agent markdown only in `plugins/flow/agents/verifier.md` (1×, fallback path to the pair references); `plugins/toolkit/hooks/hooks.json` uses it for every hook command. "Agent tool"/"Skill tool" wording in judgment-day and the `jd-*` agents; `flow:plan-reviewer`, `flow:verifier` and `toolkit:jd-*` names in plan-review, story, pair and judgment-day. Flat skill symlinks break relative paths (`../../agents/...` in plan-review, `../pair/references/...` in story). (v1, refreshed 2026-10-27)

## Product vision

- **v1:** when Claude quota runs out, open OpenCode or Antigravity in any project and keep the same workflow: same rules, engram memory, safety hooks, `/flow:plan` + `plan-review`, and the story loop (`flow:backlog` → `flow:story` → `flow:pair`) with its `flow:verifier` sub-agent.
- **v2 (later):** status line / band equivalents, `look` features, other OSes, Gemini CLI.

## Core model

- **Source of truth:** Claude plugin files in `plugins/*` (skills, agents, hooks) and `AGENTS.md` → `claude/CLAUDE.md`. Never hand-edited per agent.
- **Generator** (`scripts/gen-agents/`): reads sources, writes per-agent output into a gitignored build dir (`build/agents/<target>/`) that `install.sh` links. `install.sh` and `ai-update` run the generator into a new dir and swap it in atomically (the `build/agents` symlink is replaced in one rename; never `rm -rf` the live dir; a failed generation keeps the previous build). The build is regenerated on every install, so it cannot go stale; dangling links into the repo are pruned. `make check` generates into a temp dir and compares with committed golden fixtures, so CI and a fresh checkout need no build dir.
  - Scope: every skill and agent that is linked into the targets goes through the generator (no raw links). A reference to something not generated for a target becomes "(Claude Code only)", never a dangling name.
  - Names: one map, `flow:x` → `flow-x` and `toolkit:x` → `toolkit-x`, applied to dir names, `name:` frontmatter, commands and references; golden-tested.
  - Skills and rules (`AGENTS.md` too, generated per target instead of a raw link): copies with `${CLAUDE_PLUGIN_ROOT}`, relative plugin paths (`../`, `skills/...`), bare support-file references (`references/`, `templates/`, `cheatsheets/`, `assets/`) and "this skill's base directory" resolved to absolute, quoted repo paths (the repo path has a space); agent and skill names rewritten through the name map; slash commands rewritten `/flow:x` → `/flow-x`; tool wording rewritten (subagent launches become neutral "launch the `X` subagent" wording in OpenCode, which uses its `subagent` tool, and "through `invoke_subagent`" in agy; `mcp__engram__mem_*` → target tool names); "in parallel" → "sequentially" where the target cannot run subagents in parallel; `general-purpose` → OpenCode `general` / agy default agent. Golden tests fail on any leftover Claude-only form.
  - Commands: every generated command follows the name map in both targets (`/flow-pair 08`, `/toolkit-work-unit-commits`). `disable-model-invocation: true` keeps the skill (a command loads it) with its "explicit use only" description; OpenCode has no command-only skill; in agy whether the `/flow-pair` skill runs as a command is checked in #09.
  - Agents: frontmatter mapped. `model` comes from one role map (`scripts/gen-agents/models.json`): roles `reviewer` (plan-reviewer, verifier, jd judges) and `worker` (jd-fix-agent), one entry per target, default `inherit`. Claude keeps its current frontmatter (`opus`; Claude Code subagents run Anthropic models only, local work stays with `toolkit:delegate-local`). OpenCode accepts any `provider/id`, including `ollama/<model>`, so the local-AI work can point a role at a local model by editing one line. agy accepts `inherit`, `pro` or `flash` only (no local models). OpenCode: `mode: subagent`, `permission` from `tools`. Antigravity: without a map entry, opus/sonnet → `pro`, haiku → `flash`; tools mapped through an explicit table built from #16, unknown tool = generator error (the goldens catch it in `make check` before any install); an agent that uses engram declares it under `mcpServers:`; `commandExecutionPolicy` is set per agent (`off` while the agent has no shell tool). Until #17 proves a shell tool, the agy verifier cannot run the `Test command:`, so a high-risk agy story ends in NEEDS DECISION; pair treats an empty verifier report as NEEDS DECISION, never PASS.
  - Hooks: the current hook files stay the Claude entry points and every existing hook test passes unchanged. Contract as shipped: the cores read and answer Claude JSON (`hookSpecificOutput.additionalContext`, `systemMessage`, exit 2); each target's adapter translates its payload into that shape and the answer back (`source` defaults to `startup` in agy and OpenCode); each target decides whether a user-only message is dropped or injected. Cores stay fail-open, as pinned today; only the agy and OpenCode PreToolUse adapters fail closed on a malformed payload. A Stop adapter never answers `continue` on missing input. agy adapter: `cwd` from `workspacePaths[0]`; Stop runs the core only when `terminationReason == NO_TOOL_CALL`, `executionNum` is a number ≥ 1 and `workspacePaths[0]` is absolute, otherwise it lets agy stop (jq's `null > 1` is false, so a missing `executionNum` must never read as a first run); `executionNum > 1` maps to `stop_hook_active` (allow). Per-hook timeouts are copied into the agy `toolkit` key and into each `spawnSync` of the OpenCode plugin (the per-hook values of `plugins/toolkit/hooks/hooks.json`; `require-check` ≥ 330 s). Pair's red marker (`flow-pair-red`): `require-check` never blocks or continues; in agy the message is dropped (Stop has no carrier when not continuing).
- **Installer:** links generated output per target, only at paths the item 0 sentinel test proves the target reads. `~/.gemini/GEMINI.md` is backed up and removed only if that test shows agy loads it (Gemini CLI is not used). Merges a named `toolkit` key into agy `~/.gemini/config/hooks.json` with jq (written through `mktemp` beside the file, so two installs never share a temp file; herdr rewrites the same file and may drop the key, which the next install re-asserts, noted in `docs/multi-agent.md`) and links a separate OpenCode `toolkit.ts`; never touches herdr hooks, `engram.ts` or other keys. Repo skills shadow gentle-ai copies by precedence. The installer removes only its own symlinks into this repo; `.bak-*` dirs (gentle-ai originals moved aside by `link_file`) are moved out of all three agy skills discovery dirs (`~/.gemini/antigravity-cli/skills/`, `~/.gemini/config/skills/`, `~/.gemini/skills/`; today only the first is swept) into a backup dir (`~/.gemini/antigravity-cli/skills-backup/`), never deleted by the installer; whether agy discovers a `.bak-*` file in `~/.gemini/config/agents/` is probed in #17. Only verifies that engram MCP is registered per target (never runs `engram setup`).
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

| Item | Priority | Status | Est. dev-days left | Demo value |
|---|---|---|---|---|
| 0. agy discovery test first (sentinel files for rules and skills at every candidate path, `.bak-*` dirs and gentle-ai duplicates), then the installer fix at the proven paths; `GEMINI.md` handled as in Core model; fix `docs/multi-agent.md` | MUST | done (#01, #02); the 1.4.9 re-run lives in #17 | 0 | high: today agy may have no rules |
| 1. Spike (before item 4): `agy plugin import claude` on `flow`, plus an agy subagent that calls engram MCP; record the real agent dir, tool names and whether `/flow-pair` runs as a command | LATER (R5-Q2) | partial: format done (#16); `/flow-pair` as an agy command checked in #09; the plugin-import spike is LATER | 0 | medium |
| 2. (C) Engram MCP: installer verifies engram is registered per target (OpenCode with jq, agy with `agy mcp list` only, since two agy `mcp_config.json` files exist); `engram setup` stays a documented manual step | MUST | done (#04) | 0 | high |
| 3. (C) Hooks: contract as shipped (Core model), 6 cores (`update-check` deferred), agy jq-merge adapter, OpenCode `toolkit.ts`, adapter golden tests incl. one SessionStart hook, cancel and reentry; `pause` in OpenCode only; `require-check` Claude + agy only | MUST | done (#05, #06, #18, #19, #20); #21 open | 0.1 | high |
| 3b. OpenCode hook timeouts: each `spawnSync` gets the per-hook timeout of `plugins/toolkit/hooks/hooks.json`, a 10 s default for a hook without one (`prefer-modern-cli`), a timed-out PreToolUse allows (fail open, like the cores); one plugin test that a hanging hook is cut off and pins that direction (R4-7, R6-7) | MUST | open (#22) | 0.1 | medium |
| 4a. Generator skeleton, name map, `plan-reviewer` agent and `plan-review` skill for both targets, golden fixtures in `make check`, gitignored build dir with atomic swap, `install.sh` wiring | MUST | done (#08) | 0 | high: proves the agent format |
| 4b. `ai-update` regenerates and relinks, with `scripts/tests/ai-update.test.sh` | MUST | open (#11) | 0.25 | medium |
| 4c. Role model map `scripts/gen-agents/models.json` (today agy `model: pro` is fixed in the generator) | MUST | open (#12) | 0.25 | medium |
| 4d. Generator: bare support-file references (`references/`, `templates/`, `cheatsheets/`, `assets/`) become absolute quoted repo paths only when the path exists in that skill's dir (directory-only prose, as in `skill-creator`, stays; golden for it) and `verify.sh` flags leftovers; lands before #09 and #10 (R4-4, R6-3, R6-4) | MUST | open (#23) | 0.3 | high: otherwise generated skills point at missing files |
| 4e. agy agent mapping: `mcpServers:` for engram, `commandExecutionPolicy` per agent, the agy verifier ends in NEEDS DECISION without a shell tool (a generated line in the agy `flow-pair`, never hand-edited); one rule in the source `pair` skill for all targets: an empty or missing verifier report is NEEDS DECISION, never PASS, checked with `make eval` (R4-5, R4-8, R5-4) | MUST | open (#23) | 0.45 | high |
| 5. (A) Loop: `flow:backlog`, `flow:story` and `flow:pair` skills (with pair's references), `toolkit:work-unit-commits` and the `flow:verifier` agent through the generator; `/flow-backlog`, `/flow-story`, `/flow-pair` commands; `disable-model-invocation` mapping; red tests first, then replace `CLAUDE_ONLY_SKILLS` with a Claude-only list (judgment-day) whose raw links leave OpenCode and agy, and rewrite references to non-generated parts as "(Claude Code only)" with a golden (pair's judgment-day fallback) (R6-2); the OpenCode verifier gets `bash: ask` with allow patterns (`git log/diff/show*`, `rg *`, `make check`) and the permission key that 2.2.2 honours for its `subagent` tool, checked here (R5-8, R6-6); a generated line in the target `pair` lets a skill story close with "make eval pending (needs Claude)" in its log, and `/flow:next` lists pending evals (R6-Q3) | MUST | open (#09) | 2.0 | high |
| 5b. Every other linked skill (plan, research, fill-gaps, handoff, next, idea, split, integrate, ship...) and `AGENTS.md` through the generator (R4-3), with per-target rule lines and a golden each: OpenCode runs `make check` before saying done only when a root Makefile has `check` and the tree is dirty, and skips it while the `flow-pair-red` marker names the current branch (as `require-check` does), agy follows the pause protocol; the generated `AGENTS.md` says `/flow:x` means `/flow-x` for raw support files (R5-3, R6-5, R6-8); gentle-ai's same-named and retired spec-workflow skills move out of the three agy discovery dirs into `skills-backup/`, never deleted, with an install test (R6-1); `/flow-plan`, `/flow-fill-gaps` commands (`/flow-plan-review` done in #08) | MUST | open (#10) | 1.25 | high |
| 6. (A) judgment-day: `jd-judge-a/b`, `jd-fix-agent` through the generator | v2 (R4-Q3) | deferred | 0 | medium |
| 7. Remaining commands in OpenCode (`/flow-next`, `/flow-handoff`, `/toolkit-*`, ...); collision test against built-ins | SHOULD | open (#14) | 0.25 | medium |
| 8. Manual smoke per target: run `/flow-plan-review` and one high-risk `/flow-backlog` → `/flow-story` → `/flow-pair` story on a toy repo in OpenCode and agy (the verifier must run, or in agy stop with NEEDS DECISION); first step restarts the OpenCode service; also checks demo priorities 1-3 (same rules, engram saved in OpenCode found from agy and Claude, `ls` blocked in all three, R5-10); record in `docs/multi-agent.md` | MUST | partial: OpenCode `/flow-plan-review` done (#08 L6); rest open (#13); agy half may close as "format-verified, run pending" (R4-Q2) | 1.5 | high |
| 9. Migration: remove own symlinks; move `.bak-*` dirs out of discovery dirs; migrate `scripts/tests/install.test.sh` to the generated layout; residual: sweep all three agy skills dirs, `hooks.json` through `mktemp`, a prune test with `AI_BUILD_DIR` outside the repo, a warning when `agy --version` differs from the pinned 1.4.9 (R4-10, R4-13, R5-8, R5 risks) | MUST | partial (#02, #08); residual in #22 | 0.25 | medium |
| 17. Real agy checks (story #17): subagent returns a real engram observation, hook payloads, Stop gate, session-start context, rules/skills sentinels on 1.4.9, `.bak-*` in the agents dir, `find_by_name`/`run_command` in the registry; first a PreToolUse `deny` probe under the user-run `--dangerously-skip-permissions`: if the flag bypasses it, the hook checks are recorded "unproven" and do not block v1 (R5-Q3) | MUST | open, waits on agy quota | 0.55 | high |
| 8b. Support files (`references/`, `templates/`) generated through the same rewrite instead of pointing at the raw sources (R6-8) | SHOULD | open | 0.25 | low |
| 10. Docs: README roadmap, `install.sh` header, `docs/multi-agent.md` (incl. the agy `mcp_config.json` line, herdr dropping the toolkit key, the extra-plugin-file hang in OpenCode 2.2.2); one neutral line in source `AGENTS.md` for the raw project copy agents load inside this repo (R3-11) | SHOULD | open (#15) | 0.25 | low |

Total MUST left ≈ 7.0 dev-days; with SHOULD ≈ 7.75. No deadline: fits. (Review 3 billed 12.25 MUST before stories 01-08 landed.)

## Demo data

A throwaway toy repo (e.g. a tiny CLI with one function) used for the manual smoke of item 8 in each agent. Lives in the scratchpad, not in the repo.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| Which rules and skills paths `agy` reads (`~/.gemini/AGENTS.md` per web docs vs `~/.gemini/config/` per bundled 1.4.7 docs) | Proven by the sentinel tests (#01, #02; `docs/multi-agent.md`); the installer links only proven paths; re-run on 1.4.9 in #17 | me | yes (#01, #02) |
| agy subagent format and tool names (`flow:verifier` depends on them) | Proven in #16 (agents dir, frontmatter, registry names, `mcpServers:`); `Glob`/`Bash` wait for #17. If unworkable, high-risk stories in agy stop with NEEDS DECISION (never an inline verifier) | user | yes (fallback; format #16) |
| Which `mcp_config.json` agy uses | `~/.gemini/config/mcp_config.json` (listed by `agy mcp list`); the installer asks `agy mcp list` instead of reading a file | me | yes (#04) |
| OpenCode skills reading sibling files by relative path | Not supported; generator writes absolute paths (#08); bare support-file references in item 4d | me | yes (#08), residual #23 |
| OpenCode command names with a colon (`flow:story`) | Not allowed; every command is `flow-` prefixed in both targets (`/flow-story`) | user | yes |
| What `engram setup opencode|antigravity-cli` writes | Not run by the installer; verify only, `engram setup` is a documented manual step | me | yes |
| OpenCode plugin API | The 2.x `{ id, setup }` shape proven in story 05; versions pinned in Platforms | me | yes |
| Exact agy tool names for each Claude tool | `read_file`, `view_file`, `grep_search` proven (story 16); `Glob`/`Bash` omitted until #17 proves `find_by_name`/`run_command`; generator fails on any other unmapped tool | me | partly (#17) |
| agy tool approvals | `-p` mode soft-denies subagent tools that need approval; `--mode auto` unavailable on the account; manual agy runs use `--dangerously-skip-permissions`, run by the user; `commandExecutionPolicy` set per generated agent | user, me | no (#17) |

## Deferred to v2

- Status line and `look` band equivalents — Claude UI only.
- `require-check` (Stop gate) for OpenCode — no blocking hook exists; v1 uses a generated rule line to run `make check` before saying done.
- `pause` for agy — no prompt-submit event; v1 uses a rule line.
- `update-check.sh` for other agents — reads `~/.claude/plugins`.
- macOS / other distros — user only uses Linux.
- judgment-day in OpenCode and agy (scope item 6) — its `jd-*` agents need `Skill`, `Edit`/`Write` and engram tools that resolve in agy only through an unproven `mcpServers:` map; judgment-day stays Claude-only (R4-Q3).

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
| R4-1 | Platform pins stale (OpenCode 2.1.4, agy 1.4.7 vs installed 2.2.2, 1.4.9) | Platforms pin 2.2.2 / 1.4.9; agy rules and skills sentinels re-run on 1.4.9 in #17 and after every agy upgrade (`plan-review-4.md`) | planner |
| R4-2 | Four Research lines falsified by stories 01, 03, 05 | Rewritten: agy silent failure (no hang), OpenCode 2.x `{ id, setup }` plugin shape, proven agy rules path, API pin resolved | planner |
| R4-3 | `AGENTS.md` raw-linked although Core model generates it | Generated per target with the same rewrite, part of item 5b (+0.25 d MUST) | user |
| R4-4 | Bare support-file references not rewritten; skills ship broken yet pass `make check` | Item 4d: absolute quoted paths for `references/`, `templates/`, `cheatsheets/`, `assets/`, leftover scan extended; lands first in #09 | planner |
| R4-5 | agy agent mapping cannot express engram or the verifier's needs | Item 4e: `mcpServers:` and `commandExecutionPolicy`; agy verifier without a shell tool ends in NEEDS DECISION; unmapped tool stays a generator error (story 08 L4: the goldens catch it before any install) | planner, user (unmapped = error) |
| R4-6 | Neutral hook contract and agy Stop rule differ from the code | Core model describes the contract as shipped and the extra Stop guards (numeric `executionNum` ≥ 1, absolute `workspacePaths[0]`, the `null > 1` trap) | planner |
| R4-7 | OpenCode `spawnSync` calls have no timeout | Item 3b: per-hook timeouts from `plugins/toolkit/hooks/hooks.json`, one hang test (+0.1 d MUST) | planner |
| R4-8 | agy tool-approval posture unaddressed | `commandExecutionPolicy` per agent; manual agy runs use `--dangerously-skip-permissions` run by the user; Data gaps row; checked in #17 | planner |
| R4-9 | Scope table bills done work as open | Status column; item 4 split into 4a-4e; MUST left ≈ 6.4 d | planner |
| R4-10 | `.bak-*` sweep covers one of three agy skills dirs | Item 9 residual sweeps all three; agents-dir `.bak-*` discovery probed in #17 | planner |
| R4-11 | "warns when the build is stale" not what ships | Replaced: regenerated on every install, dangling links pruned | planner |
| R4-12 | "command-only" mapping not implementable | `disable-model-invocation` keeps the skill with an explicit-use description; a command loads it | planner |
| R4-13 | agy `hooks.json` fixed temp file; herdr may drop the key | `mktemp` beside the file (item 9 residual); next install re-asserts the key; note in `docs/multi-agent.md` (item 10) | planner |
| R4-Q1 | Generate `AGENTS.md`? | Yes (R4-3) | user |
| R4-Q2 | May the agy half close as "format-verified, run pending"? | Yes: already settled in story 03 L10 ("do not stop only because of agy"); item 8 agy half and #17 may stay open while v1 ships on a verified OpenCode | user (story 03 L10) |
| R4-Q3 | judgment-day in agy worth SHOULD? | No: item 6 moves to v2; judgment-day stays Claude-only | user |
| R4-Q4 | Which versions to pin; upgrade guard? | Pin 2.2.2 / 1.4.9; re-run agy sentinels on every agy upgrade (R4-1) | planner |
| R4-Q5 | All skills through the generator, or loop first? | Keep 5b; item 4d lands first so broken references never reach a target | planner |
| R4 risks | agy quota gates every agy check; silent agy subagent failure; live install drift; herdr rewrites `hooks.json`; OpenCode extra-plugin-file hang; stale OpenCode service; one unmapped tool aborts generation | agy half may stay "run pending" (R4-Q2); pair treats an empty verifier report as NEEDS DECISION (Core model); re-run `install.sh` before item 8; re-assert the toolkit key on every install; item 10 documents the hang; item 8 restarts the service first; unmapped tools are caught by the goldens in `make check` | planner |
| Estimates (R4) | Scope table counted done items | MUST left ≈ 6.4 dev-days, with SHOULD ≈ 6.9 (recounted from the Status column; `plan-review-4.md` estimated 6.2) | planner |
| R5-1 | Backlog #14 still promised judgment-day | #14 reworded to remaining commands + collision test (item 7); judgment-day stays v2 (`plan-review-5.md`) | planner |
| R5-2 | MUST work without a story or hidden in another story's line | New #22 (3b + item 9 residual); new #23 (4d + 4e) lands before #09; #17 line lists the plan checklist | planner |
| R5-3 | OpenCode Stop gate and agy `pause` "rule line" had no scope item | Item 5b generates per-target rule lines into `AGENTS.md`, a golden each (+0.15 d) | planner |
| R5-4 | Empty-report rule needs the source `pair` skill | One rule in the source `pair` skill for all targets, checked with `make eval`; agy's "no shell tool" line is generated (item 4e, +0.1 d) | user (Q1), planner |
| R5-5 | OpenCode delegates through `subagent`, not the Task tool | Research and Core model corrected; rewrite targets neutral "launch the `X` subagent" wording | planner |
| R5-6 | Data gaps rows stale | Rules paths, `mcp_config.json` and OpenCode relative paths marked resolved (#01, #02, #04, #08; residual #23) | planner |
| R5-7 | `agy plugin import claude` spike no longer decides anything | Moved to LATER; `/flow-pair` as an agy command stays a #09 check (−0.25 d) | user (Q2) |
| R5-8 | Story 08 verifier notes missing from the plan | Item 5 limits the OpenCode verifier's `bash`; item 9 residual adds a prune test with an external `AI_BUILD_DIR` | planner |
| R5-9 | #15 blocked by #13's open agy half | #15 requires #10 only; smoke results recorded inside #13 | planner |
| R5-10 | Demo priorities 1-3 not checked anywhere | Added to item 8's checklist | planner |
| R5-11 | #21 billed 0 | Item 3 bills 0.1 d | planner |
| R5-Q1 | Empty-report rule in Claude's `pair` too? | Yes, source skill for all targets (R5-4) | user |
| R5-Q2 | Keep the plugin-import spike? | No, LATER (R5-7) | user |
| R5-Q3 | Accept `--dangerously-skip-permissions` for #17? | Yes, after a `deny` probe; if the flag bypasses hooks, those checks are recorded "unproven" and do not block v1 (+0.05 d) | user |
| R5 risks | Flag may defeat hook checks; agy auto-upgrades unnoticed; #09 too big; pair change touches Claude; agy NEEDS DECISION as the normal path | `deny` probe first (R5-Q3); version-mismatch warning in #22; 4d/4e split into #23; `make eval` and a one-line rule; stated in `docs/multi-agent.md` (item 10) | planner |
| Estimates (R5) | Review 5 additions | MUST left ≈ 6.6 dev-days, with SHOULD ≈ 7.1 (no deadline: fits) | planner |
| R6-1 | Prefixed names stop shadowing gentle-ai copies in `~/.gemini/skills/` | gentle-ai's same-named and retired spec-workflow skills move into `skills-backup/`, never deleted, install test (item 5b, +0.1 d) (`plan-review-6.md`) | user (Q2) |
| R6-2 | judgment-day's fate in the targets undefined | Settled by R4-Q3 (Claude-only): a Claude-only list replaces `CLAUDE_ONLY_SKILLS`, its raw links leave the targets, "(Claude Code only)" rewrite with a golden; Core model example fixed (item 5, +0.15 d) | user (R4-Q3), planner |
| R6-3 | #10 could ship skills before #23 | #10 requires #23 | planner |
| R6-4 | 4d would corrupt `skill-creator`/`skill-improver` | Rewrite only paths that exist in the skill's dir; golden for `skill-creator` (+0.05 d) | planner |
| R6-5 | OpenCode `make check` rule line ignores the red marker | Rule line mirrors `require-check` (root `check` target, dirty tree, `flow-pair-red` marker), golden (item 5b) | planner |
| R6-6 | Static verifier `bash` limit; `task: deny` vs the `subagent` tool | `bash: ask` with allow patterns; #09 checks which 2.2.2 permission key blocks `subagent` | planner |
| R6-7 | Timeout default and direction undefined | 10 s default; a timed-out PreToolUse allows; pinned by the hang test (item 3b) | planner |
| R6-8 | Support files keep Claude names | SHOULD item 8b generates them; meanwhile the generated `AGENTS.md` says `/flow:x` means `/flow-x` | planner |
| R6-9 | Stale item-1 spike references | Pointed at #16 and #09; Data gaps row resolved (#16); `toolkit.ts` header version fixed in #22 | planner |
| R6-10 | #13 lacks #12; mitigation notes sit in SHOULD docs | #13 requires #12 and records the herdr, extra-plugin-file and agy NEEDS DECISION notes in `docs/multi-agent.md` | planner |
| R6-Q1 | Unlink judgment-day from the targets? | Yes, already settled by R4-Q3 (R6-2) | user (R4-Q3) |
| R6-Q2 | Move gentle-ai same-named and retired spec-workflow copies aside? | Yes (R6-1) | user |
| R6-Q3 | Close skill stories with "make eval pending" in the fallback? | Yes: a generated `pair` line records it in the story log, `/flow:next` lists pending evals (item 5, +0.1 d) | user |
| R6 risks | `make eval` needs Claude; retired spec-workflow skills in agy; repo path baked in; OpenCode restart after `ai-update`; version-warning noise | R6-Q3; R6-1; one line in the `install.sh` header (item 10); `ai-update` prints "restart OpenCode" when the build changed (#11); the agy warning names the re-run command (#22) | planner |
| Estimates (R6) | Review 6 additions | MUST left ≈ 7.0 dev-days, with SHOULD ≈ 7.75 (no deadline: fits) | planner |
