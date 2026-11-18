# Multi-agent support (Claude Code, OpenCode)

Claude Code is the full target. OpenCode gets the shared rules, the skill files and the generated ports. This page says what `install.sh` does for each one and what still works only in Claude Code.

Status: OpenCode is the secondary agent.

## What the installer does

`./install.sh` detects the installed agents; `--target claude|opencode|all` (comma-separated) picks them by hand.

| Piece | Claude Code | OpenCode |
|---|---|---|
| Global rules | `claude/CLAUDE.md` → `~/.claude/CLAUDE.md` | generated `AGENTS.md` → `~/.config/opencode/AGENTS.md` |
| Skills | `flow`, `toolkit` plugins | none raw: every skill but judgment-day is generated (below) |
| Plugin agents | yes | generated `flow-plan-reviewer`, `flow-verifier` → `~/.config/opencode/agents/` |
| Generated skills and commands | n/a | every `flow` and `toolkit` skill but judgment-day, as `flow-x`/`toolkit-x` → `~/.config/opencode/skills/`; each with a command of the same name (`/flow-next`, `/toolkit-ship`) → `~/.config/opencode/commands/`; `make check` fails if one shares a name with an OpenCode 2.2.5 built-in (`/pair` is one) |
| Hooks | yes | `prefer-modern-cli` and the session-start hooks (`host-info`, `pack-hint`, `backup-status`, run once per session and joined into one block appended to the system on each model call), and `pause` (a message starting with "pausa"/"pause" saves the engram checkpoint once and keeps the pause protocol, resuming with `opencode --continue`, in the system until the next message): plugin `toolkit.ts` → `~/.config/opencode/plugins/` |
| Engram MCP | yes (plugin) | configure by hand; the installer warns when missing |
| Status line, `look` band | yes | no |
| `bin/*`, systemd units, git hooks | yes | yes |

The repo-root `AGENTS.md` is a symlink to `claude/CLAUDE.md`. OpenCode reads a generated copy of it with `/flow-x` names and a closing section for the rules its hooks do not cover: OpenCode runs `make check-fast` before saying done when the Makefile defines it, else `make check` (it has no Stop gate), and it reads `/flow:<skill>` in raw support files as `/flow-<skill>`.

## Manual setup per machine

OpenCode's background service (`opencode serve --service`) loads plugins when it starts and `opencode run` talks to it, so after updating `toolkit.ts` restart that service; `opencode run --standalone` uses a private server with the current plugin and your environment.

Any extra file in OpenCode's `plugins/` dir (`~/.config/opencode/plugins/`), even an empty one, made `opencode run --standalone` hang on OpenCode 2.2.2 (story #20). Keep a debug probe inside `toolkit.ts` instead of a file of its own, and remove leftovers there before blaming the hooks.

The installer never writes engram's MCP config outside Claude Code (`engram setup` may rewrite the agent's config); it only checks it and prints a warning naming the manual step:

- OpenCode: an enabled `mcp.engram` entry in `~/.config/opencode/opencode.json` running `engram mcp --tools=agent`. Missing or `"enabled": false` warns `run: engram setup opencode`.

## What works outside Claude Code

Skills that are plain instructions work: most of `flow` (`plan`, `research`, `foundation`, `bootstrap`, `fill-gaps`, `handoff`, `idea`, `next`, `split`, `integrate`) and most of `toolkit`.

The story loop (`flow:backlog`, `flow:story`, `flow:pair`, `toolkit:work-unit-commits`) and its `flow:verifier` agent are generated for OpenCode (below). In OpenCode the verifier runs `git log`, `git diff`, `git show`, `rg` and `make check` without asking, never runs `rg --pre` or git `--output`/`--ext-diff`, asks before any other shell command or a redirection and cannot start subagents.

This skill depends on Claude Code and is not linked elsewhere:

- `toolkit:judgment-day`: needs the `toolkit:jd-*` agents; generated skills mark it "(Claude Code only)".

Porting judgment-day is v2 (plan `docs/plans/multi-agent-port/`).

### Generated skills and agents

`scripts/gen-agents/gen.sh` turns ported skills and agents into OpenCode's format; that is every `flow` and `toolkit` skill but `toolkit:judgment-day`, plus the `flow:plan-reviewer` and `flow:verifier` agents. Their model comes from one role map, `scripts/gen-agents/models.json`: the `reviewer` role holds the OpenCode model. OpenCode takes any `provider/id` (for a local model, `ollama/<model>`; `inherit` runs on the session model); a missing entry stops the generator. Edit the line and rerun `./install.sh`. Names follow one map (`flow:x` → `flow-x`, `toolkit:x` → `toolkit-x`), plugin-relative paths become absolute, and Claude tool names become OpenCode's. `install.sh` generates into a new dir, points the gitignored `build/agents` symlink at it in one rename and links from there; a failed generation keeps the previous build. `make check` compares a fresh generation with `scripts/gen-agents/golden/` and fails on any Claude-only form left in it; the header of `scripts/gen-agents/verify.sh` shows how to regenerate the goldens.

## Smoke run

Run on 2026-10-31 (story #13) on a throwaway toy repo (a bash `greet.sh` with a `--log FILE` flag, four stories, all high risk), after a fresh `./install.sh`. OpenCode `/flow-plan-review` was already proven in backlog #08.

| Check | OpenCode 2.2.2 (`opencode run --standalone --auto -m opencode/big-pickle`) | Claude Code |
|---|---|---|
| `/flow-plan-review` | pass (#08) | n/a |
| `/flow-backlog`, `/flow-story` | pass: story marked `Risk: item 2` | n/a |
| `/flow-pair` on a high-risk story | pass: 3 test→code pairs, `make check` green, no red marker, `flow-verifier` subagent ran, PASS | n/a |
| `ls` blocked by `prefer-modern-cli` | pass: `ls` and `sed` blocked | pass (live) |
| engram observation saved in OpenCode found here | saved (#961-963, project `toy-greet`) | pass: found #961-963 |

Notes from the run:

- `opencode/deepseek-v4.1-flash-free` (the session default) once turned the quoted absolute path with a space into a broken relative one and recovered with `fd`; the generated file was correct.
- `opencode/nemotron-3-ultra-free` is gone from the OpenCode catalog; any agent config pointing at it fails with "Model unavailable".
- Claude Code's auto mode refuses to launch `opencode run --auto` for `/flow-pair` itself; the user runs it.

## Known side effect

Inside this repo, Claude Code loads the rules twice: once as the global `~/.claude/CLAUDE.md` and once as the project `AGENTS.md`.
