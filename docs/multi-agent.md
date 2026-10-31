# Multi-agent support (Claude Code, OpenCode, Antigravity)

Claude Code is the full target. OpenCode and Antigravity get the shared rules, the skill files and the generated ports. This page says what `install.sh` does for each one and what still works only in Claude Code.

## What the installer does

`./install.sh` detects the installed agents; `--target claude|opencode|antigravity|all` (comma-separated) picks them by hand.

| Piece | Claude Code | OpenCode | Antigravity |
|---|---|---|---|
| Global rules | `claude/CLAUDE.md` → `~/.claude/CLAUDE.md` | generated `AGENTS.md` → `~/.config/opencode/AGENTS.md` | generated `AGENTS.md` → `~/.gemini/config/AGENTS.md`, when `~/.gemini` exists |
| Skills | `flow`, `toolkit` plugins | none raw: every skill but judgment-day is generated (below) | none raw: every skill but judgment-day is generated (below) |
| Plugin agents | yes | generated `flow-plan-reviewer`, `flow-verifier` → `~/.config/opencode/agents/` | generated `flow-plan-reviewer`, `flow-verifier` → `~/.gemini/config/agents/` |
| Generated skills and commands | n/a | every `flow` and `toolkit` skill but judgment-day, as `flow-x`/`toolkit-x` → `~/.config/opencode/skills/`; `/flow-plan`, `/flow-plan-review`, `/flow-fill-gaps`, `/flow-backlog`, `/flow-story`, `/flow-pair` commands (the rest wait for backlog #14) | the same skills → `~/.gemini/antigravity-cli/skills/` |
| Hooks | yes | `prefer-modern-cli` and the session-start hooks (`host-info`, `pack-hint`, `backup-status`, run once per session and joined into one block appended to the system on each model call), and `pause` (a message starting with "pausa"/"pause" saves the engram checkpoint once and keeps the pause protocol, resuming with `opencode --continue`, in the system until the next message): plugin `toolkit.ts` → `~/.config/opencode/plugins/` | `prefer-modern-cli`, the `make check` Stop gate (`require-check`) and the session-start hooks (`host-info`, `pack-hint`, `backup-status`, joined into one injected system message): a `toolkit` key merged into `~/.gemini/config/hooks.json` |
| Engram MCP | yes (plugin) | configure by hand; the installer warns when missing | configure by hand; the installer warns when missing |
| Status line, `look` band | yes | no | no |
| `bin/*`, systemd units, git hooks | yes | yes | yes |

The repo-root `AGENTS.md` is a symlink to `claude/CLAUDE.md`. OpenCode and Antigravity read a generated copy of it with `/flow-x` names and a closing section for the rules their hooks do not cover: OpenCode runs `make check` before saying done (it has no Stop gate), Antigravity follows the pause protocol (it has no prompt hook); both read `/flow:<skill>` in raw support files as `/flow-<skill>`.

## Manual setup per machine

OpenCode's background service (`opencode serve --service`) loads plugins when it starts and `opencode run` talks to it, so after updating `toolkit.ts` restart that service; `opencode run --standalone` uses a private server with the current plugin and your environment.

The installer never writes engram's MCP config outside Claude Code (`engram setup` may rewrite the agent's config); it only checks it and prints a warning naming the manual step:

- OpenCode: an enabled `mcp.engram` entry in `~/.config/opencode/opencode.json` running `engram mcp --tools=agent`. Missing or `"enabled": false` warns `run: engram setup opencode`.
- Antigravity: `agy mcp list` must list `engram`. The installer asks `agy` instead of reading a file, because two `mcp_config.json` exist (`~/.gemini/config/` and `~/.gemini/antigravity-cli/`). Missing warns `run: engram setup antigravity-cli`; without `agy` on the PATH it says it cannot check.

The installer pins agy 1.4.9 (the two tables below were checked on 1.4.7; their 1.4.9 re-run is story #17). When `agy --version` prints anything else, it warns and points here: re-run both sentinel checks on the new version before trusting the linked paths.

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

The repo skills already live in the winning dir. `install.sh` moves every `*.bak-*` entry out of the three discovery dirs into `skills-backup/` (an earlier installer left gentle-ai's originals there under that name), adding a numeric suffix when the name is taken; nothing is deleted. It also moves there every real dir in the three discovery dirs (`~/.gemini/skills/`, `~/.gemini/config/skills/`, `~/.gemini/antigravity-cli/skills/`) named like a repo skill (gentle-ai copies such as `work-unit-commits` or `judgment-day`, which the prefixed repo names no longer shadow) or like a retired plugin's skills (`<plugin>-*`); other gentle-ai skills, `_shared` and links stay. Each move is printed as source -> destination, so a restore is one `mv`.

## What works outside Claude Code

Skills that are plain instructions work: most of `flow` (`plan`, `research`, `foundation`, `bootstrap`, `fill-gaps`, `handoff`, `idea`, `next`, `split`, `integrate`) and most of `toolkit`.

The story loop (`flow:backlog`, `flow:story`, `flow:pair`, `toolkit:work-unit-commits`) and its `flow:verifier` agent are generated for both targets (below). In OpenCode the verifier runs `git log`, `git diff`, `git show`, `rg` and `make check` without asking, never runs `rg --pre` or git `--output`/`--ext-diff`, asks before any other shell command or a redirection and cannot start subagents. In Antigravity the verifier has no shell tool yet, so a high-risk story ends in NEEDS DECISION and is finished in Claude or OpenCode.

This skill depends on Claude Code and is not linked elsewhere:

- `toolkit:judgment-day`: needs the `toolkit:jd-*` agents; generated skills mark it "(Claude Code only)".

Porting judgment-day is v2 (plan `docs/plans/multi-agent-port/`).

### Generated skills and agents

`scripts/gen-agents/gen.sh` turns ported skills and agents into each target's format; that is every `flow` and `toolkit` skill but `toolkit:judgment-day`, plus the `flow:plan-reviewer` and `flow:verifier` agents. Their model comes from one role map, `scripts/gen-agents/models.json`: the `reviewer` role holds one model per target. OpenCode takes any `provider/id` (for a local model, `ollama/<model>`; `inherit` runs on the session model), Antigravity takes `inherit`, `pro` or `flash`; a missing entry or another agy value stops the generator. Edit the line and rerun `./install.sh`. Names follow one map (`flow:x` → `flow-x`, `toolkit:x` → `toolkit-x`), plugin-relative paths become absolute, and Claude tool names become the target's. `install.sh` generates into a new dir, points the gitignored `build/agents` symlink at it in one rename and links from there; a failed generation keeps the previous build. `make check` compares a fresh generation with `scripts/gen-agents/golden/` and fails on any Claude-only form left in it; the header of `scripts/gen-agents/verify.sh` shows how to regenerate the goldens.

In Antigravity the reviewer gets only the tool names agy 1.4.9 proved in its registry (`read_file`, `view_file`, `grep_search`): without `Glob` and `Bash` it cannot convert .docx/.pdf sources or run `git log`. An unmapped tool stops the generator, because agy silently never builds such a subagent.

## Smoke run

Run on 2026-10-31 (story #13) on a throwaway toy repo (a bash `greet.sh` with a `--log FILE` flag, two stories, both `Risk: item 2`), after a fresh `./install.sh`. OpenCode `/flow-plan-review` was already proven in backlog #08.

| Check | OpenCode 2.2.2 (`opencode run --standalone --auto -m opencode/big-pickle`) | Antigravity 1.4.9 (interactive, Gemini 3.8 Flash) | Claude Code |
|---|---|---|---|
| `/flow-plan-review` | pass (#08) | pass: `flow-plan-reviewer` subagent returned the full structure and wrote `plan-review-1.md`; with no `plan.md` it stopped at the gate | n/a |
| `/flow-backlog`, `/flow-story` | pass: story marked `Risk: item 2` | pass (`/flow-story`): `Risk: item 2` | n/a |
| `/flow-pair` on a high-risk story | pass: 3 test→code pairs, `make check` green, no red marker, `flow-verifier` subagent ran, PASS | **fail**: the `flow-verifier` subagent called only engram (`mem_search`, `mem_context`), ran no command, yet reported `make check` passed and `Verdict: PASS`; pair accepted it instead of ending in NEEDS DECISION (backlog #37) | n/a |
| `ls` blocked by `prefer-modern-cli` | pass: `ls` and `sed` blocked | not exercised: the model picked `eza` itself, so the hook never fired (stays with #17) | pass (live) |
| engram observation saved in OpenCode found here | saved (#961-963, project `toy-greet`) | pass: found #962 | pass: found #961-963 |

Notes from the run:

- agy asked for approval on almost every command, the verifier's file reads included; a fallback session needs the user at the keyboard.
- `opencode/deepseek-v4.1-flash-free` (the session default) once turned the quoted absolute path with a space into a broken relative one and recovered with `fd`; the generated file was correct.
- `opencode/nemotron-3-ultra-free` is gone from the OpenCode catalog; any agent config pointing at it fails with "Model unavailable".
- Claude Code's auto mode refuses to launch `opencode run --auto` for `/flow-pair` itself; the user runs it.

## Known side effect

Inside this repo, Claude Code loads the rules twice: once as the global `~/.claude/CLAUDE.md` and once as the project `AGENTS.md`.
