# ai-dotfiles

Personal configuration for AI coding tools. Claude Code first; OpenCode and Gemini later.

## Layout

| Path | What | How it is installed |
|---|---|---|
| `claude/CLAUDE.md` | Minimal always-on rules | Symlinked to `~/.claude/CLAUDE.md` |
| `claude/settings.json` | Settings fragment | Merged into `~/.claude/settings.json` with `jq` |
| `.claude-plugin/marketplace.json` | Makes this repo a plugin marketplace | `claude plugin marketplace add` |
| `plugins/flow/` | Workflow plugin | `claude plugin install flow@ai-dotfiles` |
| `plugins/flow/skills/` | `research`, `idea`, `plan`, `foundation`, `bootstrap`, `plan-review`, `fill-gaps`, `split`, `handoff`, `next`, `integrate` (templates in `<skill>/templates/`) | via plugin |
| `plugins/flow/agents/` | `plan-reviewer`: blind read-only reviewer used by `/flow:plan-review` | via plugin |
| `plugins/sdd/` | Spec-Driven Development: `/sdd:*` commands, lazy `sdd:orchestrator` skill, phase agents `sdd:sdd-*` (engram/openspec persistence, Strict TDD) | `claude plugin install sdd@ai-dotfiles` |
| `plugins/sdd/upstream/` | Upstream origin of `sdd`/`toolkit` (vendored from gentle-ai, adapted); reference only, see its `README.md` | - |
| `plugins/toolkit/` | Skills: `judgment-day` (agents `toolkit:jd-*`), `work-unit-commits`, `chained-pr`, `comment-writer`, `cognitive-doc-design`, `skill-creator`, `skill-improver`, `go-testing`, `cli-tools`, `ship` (make check -> work-unit commits -> push -> watch CI until green). Hook: `prefer-modern-cli` (PreToolUse on Bash; blocks `grep`/`find`/`ls`/`sed`/`cat` in favor of `rg`/`fd`/`eza`/`sd`/`bat`), `require-check` (Stop; runs `make check` from the git root when the tree is dirty and blocks finishing on failure; skipped when the tree is identical to the last green run; `SKIP_REQUIRE_CHECK=1` opts out), `engram-resume-fallback` (SessionStart on resume; while engram <= 3.4.0 blocks MCP writes after `--continue`, tells Claude to save via the `engram save` CLI; silent on fixed versions), `update-check` (SessionStart on startup; notify-only: installed plugins older than their marketplace, engram older than its latest release, checked once a day; `SKIP_UPDATE_CHECK=1` opts out), `host-info` (SessionStart on startup/clear/compact; one line with the dev machine OS/distro, package managers, shell and a curated list of installed tools (docker, gh, ffmpeg, yt-dlp...) so commands fit the host; `SKIP_HOST_INFO=1` opts out), `pause` (UserPromptSubmit; a prompt starting with "pausa"/"pause" saves an engram checkpoint in ~0.5 s and makes Claude stop and report in a few lines; `SKIP_PAUSE_HOOK=1` opts out), `backup-status` (SessionStart on startup; warns only when the last engram backup or verify failed, the backup is older than 2 days, the verify older than 8, or none was recorded; `SKIP_BACKUP_STATUS=1` opts out), `pack-hint` (SessionStart on startup; suggests `ai-pack add web` when the project root has `index.html` or a web framework in `package.json`; once per project and pack, then every 30 days; costs no tokens; `AI_HOOKS_OFF=pack-hint` opts out, `PACK_HINT_TIMEOUT` sets the wait, default 1.5 s) | `claude plugin install toolkit@ai-dotfiles` |
| `claude/output-styles/` | Output styles (e.g. `gentleman`) | Symlinked into `~/.claude/output-styles/` |
| `claude/statusline.sh` | Status line: model, project and git branch, context use (colored bar), 5-hour plan quota with reset time, zellij session | Symlinked into `~/.claude/`; `statusLine` merged into settings |
| `bench/worker/` | Local-worker benchmark: `run.sh [MODEL...]` has pi solve 20 tasks inside `pi-box` (bash, Lua, QML, Python, TypeScript, Go, Rust, C; levels L1 option, L2 feature, L3 bug) taken from this repo, the system dotfiles or small fixture projects; a hidden check, the task's gate and a file scope decide pass/fail, summarized per language x level. `validate.sh` proves every task without a model (check fails on base, passes with `reference.patch`). Resumable; results in `~/.local/state/worker-bench` | Run manually |
| `Makefile`, `scripts/` | `make check`: shellcheck, JSON/structure/settings validation, skill lint, workflow lint (actionlint), hook tests | Run manually; enforced by `require-check` |
| `systemd/` | User units: `engram-backup.timer` (daily), `engram-backup-verify.timer` (weekly), `upstream-watch.timer` (daily), all `Persistent=true` | Symlinked into `~/.config/systemd/user`; enabled once `engram-backup` is configured |
| `bin/` | `upstream-watch [--mark REPO|all]`: reports what changed in the repos listed in `upstreams.json` (gentle-ai, engram, gentle-shell, pi, ECC...) since the last review; a daily timer refreshes it and `update-check` mentions news at startup. `claude-perms-audit [--fix] [ROOT]`: flags risky allow rules in project `.claude/settings*.json` (`Bash(*)`, interpreter wildcards like `python3 *`, unrestricted Write/Edit, dead session paths); `--fix` removes them with a backup. `pi-box`: runs pi (or `pi-box -- CMD`) in a bubblewrap sandbox: only the project is writable, the rest of HOME is invisible, `~/.pi/agent` is a throwaway overlay; no network except ollama bridged in as `127.0.0.1:11434` (needs `socat`; `PI_BOX_NETWORK=host` for full network); refuses HOME or `/` as the project. `cz`: runs Claude inside a per-project zellij session, so closing the terminal only detaches (reattach with `cz`; `cz --continue` after a reboot). `engram-backup`: restic backup of `~/.engram` to every repo in `~/.config/restic/engram.env` (consistent `sqlite3 .backup`, content-based skip, 7d/4w/12m retention; `--init`, `--verify`, `--restore [--force]`, see [docs/recovery.md](docs/recovery.md)). `ai-update`: updates plugins and the engram binary (checksum, DB + binary backup, rollback, confirm on major; `--check` reports only). `ai-pack`: opt-in packs per project (`list`, `add`, `remove [--purge]`, `ignore`, `unignore`): `web` (playwright-cli, web-design-guidelines, taste) and `diagrams` (archify), pinned in `packs/packs.json` with vendored sources in `packs/vendor/`; the base install adds nothing, see [docs/packs.md](docs/packs.md) | Symlinked into `~/.local/bin` |
| `docs/` | Workflow design notes | - |

## Workflow

```
research (optional) -> plan (scope + UX in parallel) -> foundation -> bootstrap (both for new projects) -> plan-review
  -> fill-gaps -> plan-review -> split (collaborative only) -> handoff -> implement -> integrate (teammates' packages)

implement (SDD): /sdd:new | /sdd:ff -> /sdd:continue -> /sdd:apply -> /sdd:verify -> /sdd:archive

idea: enters at any time to triage a new idea (GO / DEFER / DROP / SPIKE)
```

| Skill | Does |
|---|---|
| `/flow:research` | Optional pre-planning research brief (prior art, libraries, policies), tagged v1/v2 |
| `/flow:idea` | Triages an idea at any time: feasibility, effort, value, fit; GO/DEFER/DROP/SPIKE in `docs/ideas.md` |
| `/flow:plan` | Scope + UX tracks: target platforms and distribution, 3 ASCII variants per screen, backend demands, `plan.md` |
| `/flow:foundation` | New projects: chooses stack, proportional architecture, conventions; writes `docs/architecture.md` (with the `make check` recipe), `docs/development.md` (reproducible setup per supported dev OS), ADRs, `AGENTS.md`, `.claude/settings.json` |
| `/flow:bootstrap` | Executes foundation: git, folder tree, tooling, `Makefile` with a green `check` and a smoke test, first commit, GitHub repo; or a `git mv` reorganization PR. One approval for the whole plan |
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

## Turning hooks off

Every toolkit hook honors `AI_HOOKS_OFF`: a comma-separated list of hook names (file name without `.sh`) or `all`. The per-hook `SKIP_*` variables keep working.

```bash
AI_HOOKS_OFF=host-info,pause claude   # these two stay quiet this session
AI_HOOKS_OFF=all claude               # minimal session, no toolkit hooks
```

Measured cost (2026-10-19): toolkit hooks add ~160 tokens at startup (~300 on resume) and none takes more than ~110 ms; skill descriptions add ~1.5k tokens and engram's hooks ~1.3k.

## Verification

Agent output is accepted because it passes checks, not because someone read every line. Every repo (this one and projects set up by `/flow:foundation` + `/flow:bootstrap`) exposes `make check`; the toolkit `require-check` Stop hook runs it before Claude can finish. Never weaken or skip a check to make it pass.

```bash
make check   # all steps, summary of failures
make lint    # shell + skills
make validate
make test
```

Skill evals (`plugins/<plugin>/evals/`, run with `claude plugin eval`) check that skills fire when they should, stay quiet when they should not, and change the outcome versus a no-plugin baseline. They run real sessions, so they are not part of `make check`: run `make eval PLUGIN=flow` (or `toolkit`, `sdd`) after changing a skill.

`make check` needs `shellcheck`; `shfmt` is used when installed. CI pins shfmt (v3.14.1) and actionlint (1.7.12) to the versions Arch ships; bump the `*_VERSION` and `*_SHA256` pairs in the workflow when Arch updates it, since releases format some constructs differently. CI runs `make check` on every push to `main` and every pull request.

## Roadmap

- [x] `flow` skills content
- [x] `bin/ai-update`: safe engram/tool updates (backup, checksum, confirm on major)
- [x] `host-info` hook and target platforms / dev environments in `flow`
- [x] Session-start hook: notify-only update check
- [x] Secret protection: Read deny rules + global gitleaks pre-commit hook
- [x] Fix SDD agents' engram tool names (`mcp__engram__*`)
- [x] Verification harness: `make check` + `require-check` Stop hook
- [x] Mutation testing for hooks (`make mutate`, `scripts/mutate.sh`; remaining survivors are equivalent mutants)
- [x] `claude plugin eval` suite for `flow` (plan, idea, should-not-fire)
- [x] Eval suite for `toolkit:ship`
- [x] Eval suite for `sdd` routing (preflight gate, explore delegation with its model, no apply without tasks, should-not-fire)
- [ ] Eval suites for the other `toolkit` skills
- [x] CI running `make check` (`.github/workflows/check.yml`)
- [x] `install.sh` idempotency test (`scripts/tests/install.test.sh`)
- [x] Local encrypted engram backup (`engram-backup` + daily timer)
- [ ] Off-site engram backup: Google Drive via `rclone` repo, or a private git repo with `engram sync` (plaintext; `age` to encrypt)
- [x] Pause/resume: `cz` (zellij session survives closing the terminal), `pause` hook (instant checkpoint), atomic settings write in `install.sh`
- [ ] Lid-closed mode on Arch so work survives closing the laptop (thermal limits)
- [ ] Local workers (pi + ollama): **parked**, dotfiles stay Claude-first. Built: `pi-box`, `bench/worker`, draft `toolkit:delegate-local`. Results and how to resume: [docs/local-workers.md](docs/local-workers.md)
- [ ] Worker isolation, step 2: a dedicated system user for the worker (project access via group/ACL) on top of `pi-box`
- [x] Worker isolation, step 3: `pi-box` network limited to ollama (socat bridge; no internet, no other local services, no host DNS)
- [ ] NPU: try OpenVINO for small models on the 47 TOPS NPU
- [x] Backup observability: SessionStart notice when the last engram backup failed or is older than 2 days; weekly `engram-backup --verify`
- [x] Fresh-machine recovery: `engram-backup --restore`, CI drill on a clean Arch container (`scripts/recovery-e2e.sh`), guide in [docs/recovery.md](docs/recovery.md)
- [x] Upstream watch (`upstream-watch`, `upstreams.json`): list the repos we learn from (gentle-ai for sdd/toolkit, engram, gentle-shell (built on pi), Gentleman-Skills, gentle-agent-state, earendil-works/pi, affaan-m/ECC) with what we took and the last reviewed release; notify when they change and triage with `/flow:idea`
- [x] Status line (context %, 5-hour quota, branch, zellij session)
- [ ] Claude Code look and feel: theme, visual tweaks and TUI mods (panes, banners), keeping it functional first
- [x] Permission hygiene: `claude-perms-audit` (manual; cleaned `python3 *` and dead rules on 2026-10-17)
- [ ] Secret scan of engram memory: run gitleaks over the engram DB/export so a token saved by mistake does not live on in backups
- [ ] Ideas from affaan-m/ECC (MIT): per-language rules (reuse for local-worker cheat sheets), one variable to disable hooks plus a minimal profile, a cap on SessionStart context (off for local-model setups). Its Memory Vault overlaps engram: reference only
- [x] Opt-in packs (`ai-pack`, `web` and `diagrams`, startup hint): replaces the `install.sh --profile minimal` idea. Guide: [docs/packs.md](docs/packs.md)
- [ ] Packs v2: bigcode/codebase-memory-mcp, design-md on demand, Ponytail eval, more packs, `ai-pack doctor` / prune
- [ ] OpenCode and Gemini support
