# ai-dotfiles

Personal configuration for AI coding tools. Claude Code first; OpenCode and Gemini later.

## Layout

| Path | What | How it is installed |
|---|---|---|
| `claude/CLAUDE.md` | Minimal always-on rules | Symlinked to `~/.claude/CLAUDE.md` |
| `claude/settings.json` | Settings fragment | Merged into `~/.claude/settings.json` with `jq` |
| `.claude-plugin/marketplace.json` | Makes this repo a plugin marketplace | `claude plugin marketplace add` |
| `plugins/flow/` | Workflow plugin | `claude plugin install flow@ai-dotfiles` |
| `plugins/flow/skills/` | `research`, `idea`, `plan`, `foundation`, `plan-review`, `fill-gaps`, `split`, `handoff`, `next`, `integrate` (templates in `<skill>/templates/`) | via plugin |
| `plugins/flow/agents/` | `plan-reviewer`: blind read-only reviewer used by `/flow:plan-review` | via plugin |
| `plugins/sdd/` | Spec-Driven Development: `/sdd:*` commands, lazy `sdd:orchestrator` skill, phase agents `sdd:sdd-*` (engram/openspec persistence, Strict TDD) | `claude plugin install sdd@ai-dotfiles` |
| `plugins/sdd/upstream/` | Upstream origin of `sdd`/`toolkit` (vendored from gentle-ai, adapted); reference only, see its `README.md` | - |
| `plugins/toolkit/` | Skills: `judgment-day` (agents `toolkit:jd-*`), `work-unit-commits`, `chained-pr`, `comment-writer`, `cognitive-doc-design`, `skill-creator`, `skill-improver`, `go-testing` | `claude plugin install toolkit@ai-dotfiles` |
| `claude/output-styles/` | Output styles (e.g. `gentleman`) | Symlinked into `~/.claude/output-styles/` |
| `bin/` | Maintenance scripts (e.g. `ai-update`) | Run manually |
| `docs/` | Workflow design notes | - |

## Workflow

```
research (optional) -> plan (scope + UX in parallel) -> foundation (new projects) -> plan-review
  -> fill-gaps -> plan-review -> split (collaborative only) -> handoff -> implement -> integrate (teammates' packages)

implement (SDD): /sdd:new | /sdd:ff -> /sdd:continue -> /sdd:apply -> /sdd:verify -> /sdd:archive

idea: enters at any time to triage a new idea (GO / DEFER / DROP / SPIKE)
```

| Skill | Does |
|---|---|
| `/flow:research` | Optional pre-planning research brief (prior art, libraries, policies), tagged v1/v2 |
| `/flow:idea` | Triages an idea at any time: feasibility, effort, value, fit; GO/DEFER/DROP/SPIKE in `docs/ideas.md` |
| `/flow:plan` | Scope + UX tracks: 3 ASCII variants per screen, backend demands, `plan.md` |
| `/flow:foundation` | New projects: chooses stack, proportional architecture, conventions; writes `docs/architecture.md`, ADRs, `AGENTS.md` |
| `/flow:plan-review` | Blind review by the `plan-reviewer` agent: verdict, gaps, MUST/SHOULD/LATER cut |
| `/flow:fill-gaps` | Resolves findings one question at a time; appends `Plan-review resolutions` |
| `/flow:split` | Freezes contracts; writes paste-able work packages for teammates using browser AI |
| `/flow:handoff` | Approved plan -> `/sdd:ff` / `/sdd:new` seeded with the plan, or ordered task list |
| `/flow:integrate` | Checks a delivered package against its contract and tests |
| `/flow:next` | Lists tasks you can start now without waiting for delegated work |

Memory: [engram](https://github.com/Gentleman-Programming/engram) is the only memory system. It is installed with `engram setup claude-code` and is not managed by this repo.

## Install

```bash
./install.sh --dry-run   # preview
./install.sh
```

Requires `jq`, `rg` and `claude`.

## Roadmap

- [x] `flow` skills content
- [ ] `bin/ai-update`: safe engram/tool updates (backup, checksum, confirm on major)
- [ ] Session-start hook: notify-only update check
- [ ] Permissions allow/deny list
- [x] Fix SDD agents' engram tool names (`mcp__engram__*`)
- [ ] OpenCode and Gemini support
