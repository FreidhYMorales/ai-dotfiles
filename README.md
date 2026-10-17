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
| `plugins/toolkit/` | Skills: `judgment-day` (agents `toolkit:jd-*`), `work-unit-commits`, `chained-pr`, `comment-writer`, `cognitive-doc-design`, `skill-creator`, `skill-improver`, `go-testing`, `cli-tools`, `ship` (make check -> work-unit commits -> push -> watch CI until green). Hook: `prefer-modern-cli` (PreToolUse on Bash; blocks `grep`/`find`/`ls`/`sed`/`cat` in favor of `rg`/`fd`/`eza`/`sd`/`bat`), `require-check` (Stop; runs `make check` from the git root when the tree is dirty and blocks finishing on failure; `SKIP_REQUIRE_CHECK=1` opts out), `engram-resume-fallback` (SessionStart on resume; while engram <= 3.4.0 blocks MCP writes after `--continue`, tells Claude to save via the `engram save` CLI; silent on fixed versions), `update-check` (SessionStart on startup; notify-only: installed plugins older than their marketplace, engram older than its latest release, checked once a day; `SKIP_UPDATE_CHECK=1` opts out), `host-info` (SessionStart on startup/clear/compact; one line with the dev machine OS/distro, package managers, shell and a curated list of installed tools (docker, gh, ffmpeg, yt-dlp...) so commands fit the host; `SKIP_HOST_INFO=1` opts out) | `claude plugin install toolkit@ai-dotfiles` |
| `claude/output-styles/` | Output styles (e.g. `gentleman`) | Symlinked into `~/.claude/output-styles/` |
| `Makefile`, `scripts/` | `make check`: shellcheck, JSON/structure/settings validation, skill lint, workflow lint (actionlint), hook tests | Run manually; enforced by `require-check` |
| `bin/` | `ai-update`: updates plugins and the engram binary (checksum, DB + binary backup, rollback, confirm on major; `--check` reports only) | Symlinked into `~/.local/bin` |
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
| `/flow:plan` | Scope + UX tracks: target platforms and distribution, 3 ASCII variants per screen, backend demands, `plan.md` |
| `/flow:foundation` | New projects: chooses stack, proportional architecture, conventions; writes `docs/architecture.md`, `docs/development.md` (reproducible setup per supported dev OS), ADRs, `AGENTS.md`, and a `Makefile` with a `check` target plus a passing smoke test |
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

## Verification

Agent output is accepted because it passes checks, not because someone read every line. Every repo (this one and projects created by `/flow:foundation`) exposes `make check`; the toolkit `require-check` Stop hook runs it before Claude can finish. Never weaken or skip a check to make it pass.

```bash
make check   # all steps, summary of failures
make lint    # shell + skills
make validate
make test
```

Skill evals (`plugins/<plugin>/evals/`, run with `claude plugin eval`) check that skills fire when they should, stay quiet when they should not, and change the outcome versus a no-plugin baseline. They run real sessions, so they are not part of `make check`: run `make eval PLUGIN=flow` after changing a skill.

`make check` needs `shellcheck`; `shfmt` is used when installed. CI pins shfmt (v3.14.1) and actionlint (1.7.12) to the versions Arch ships; bump the `*_VERSION` and `*_SHA256` pairs in the workflow when Arch updates it, since releases format some constructs differently. CI runs `make check` on every push to `main` and every pull request.

## Roadmap

- [x] `flow` skills content
- [x] `bin/ai-update`: safe engram/tool updates (backup, checksum, confirm on major)
- [x] `host-info` hook and target platforms / dev environments in `flow`
- [x] Session-start hook: notify-only update check
- [x] Secret protection: Read deny rules + global gitleaks pre-commit hook
- [x] Fix SDD agents' engram tool names (`mcp__engram__*`)
- [x] Verification harness: `make check` + `require-check` Stop hook
- [ ] Mutation testing for hooks
- [x] `claude plugin eval` suite for `flow` (plan, idea, should-not-fire)
- [x] Eval suite for `toolkit:ship`
- [ ] Eval suites for the other `toolkit` skills and `sdd`
- [x] CI running `make check` (`.github/workflows/check.yml`)
- [x] `install.sh` idempotency test (`scripts/tests/install.test.sh`)
- [ ] OpenCode and Gemini support
