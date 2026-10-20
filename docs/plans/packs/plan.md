# Plan: opt-in packs

- Status: approved (reviews 1-4 resolved; remaining detail goes to TDD in implementation)
- Deadline: none
- Mode: solo
- Supersedes: README roadmap idea "install.sh --profile minimal" (packs replace profiles: the base install stays as it is, extras are per project)

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| Arch Linux (the maintainer's machines) | yes | bash 5, Claude Code with project skills, terminal ~70 cols | this repo, `./install.sh` links `bin/ai-pack` |
| Other distros / macOS | no | - | - |

- Out of scope: Windows, macOS, non-Claude agents (OpenCode/Gemini stay on the roadmap).

## Research

Findings from a read-only research pass on 2026-10-19 (engram: "packs research: per-project activation + tool supply chain"), plus facts checked by the reviewers:

- v1: project skills live in `.claude/skills/<name>/SKILL.md`; a personal skill with the same name wins.
- v1: Playwright CLI `@playwright/cli` v0.1.22 (npm, no install scripts) ships a skill; on Arch `install-deps` uses apt, so use the system Chromium. `PLAYWRIGHT_MCP_EXECUTABLE_PATH` is documented for the MCP server, not the CLI; the CLI reads `.playwright/cli.config.json`.
- v1: on this machine `npm config get prefix` is `/usr`, so `npm install -g` needs root.
- v1: Vercel `web-design-guidelines` fetches its rules from `main` on every run (unpinned); no LICENSE file (README says MIT).
- v1: `taste-skill` v2.1.2 (MIT; frontmatter name `design-taste-frontend`; Node 22+, Chromium, network for images).
- v1: Archify v3.2.0 is a skill only (MIT), runs Node, checks for updates daily unless `ARCHIFY_UPDATE_CHECK_DISABLED=1`.
- v1: toolkit hooks run from the plugin cache (`~/.claude/plugins/cache/ai-dotfiles/toolkit/<version>`), not from the repo; new hooks need a toolkit version bump.
- v1: `scripts/check-shell.sh` lints every tracked shell file, so vendored third-party scripts must be excluded; `scripts/check-skills.sh` only scans `plugins/*/skills`, so it needs no change.
- v1: Claude Code creates and rewrites `.claude/settings.local.json` itself (permission approvals), so ai-pack does not write it.
- v1: `info/exclude` is shared by every worktree of a repo (`$GIT_COMMON_DIR/info`), so ai-pack does not use it.
- v2: `.claude/settings.local.json` `enabledPlugins` overrides user scope (kind `plugin`); MCP `claude mcp add --scope local` lives in `~/.claude.json` (kind `mcp`).
- v2: `awesome-design-md` is 84 brand `DESIGN.md` files (MIT, no code).
- v2: `codebase-memory-mcp` v0.12.1 is a static binary with checksums and cosign, no network or LLM; one build per account (shared daemon); default installer adds global hooks.
- v2: Ponytail v5.3.2 injects a ruleset plus a codebase map at SessionStart/SubagentStart, writes a statusline into `~/.claude`, logs a CSV per turn; third-party runs report ~44% less code but weaker bad-input handling on 5/24 tasks.
- The dotfiles repo is PRIVATE (`gh repo view`, 2026-10-19).

## Product vision

- **v1:** the base dotfiles stay lean for every session; per project, `ai-pack add <pack|tool>` turns on pinned, reviewed extras: `web` (Playwright CLI verification + design skills) and `diagrams` (Archify). A startup hint suggests a pack when the project looks like it needs one, at no token cost.
- **v2:** `bigcode` (codebase-memory-mcp) when a real repo passes the threshold; brand `DESIGN.md` on demand; Ponytail only if the eval shows a gain; more packs (data/notebooks, mobile, infra); kind `plugin`; `ai-pack doctor`/`prune`.

## Core model

```
tool  name, kind: skill | npm            (v2: binary, mcp, plugin)
      source: vendored (MIT, in packs/vendor/, tag + tree hash; may carry a small reviewed patch)
            | fetched (pinned commit URL + sha256; unlicensed files, never committed;
                       may be templated into a vendored SKILL.md after verification)
            | npm (exact version + sha512 integrity of the `npm pack` tarball)
      layer:  machine (npm, installed once into ~/.local/share/ai-pack/npm, bins linked
              into ~/.local/bin) and/or project (activated per project)
      requires: [{cmd, min?, hint}]   project_dirs: {dir: contents}   leftovers: [runtime paths]
pack  name, tools: [tool], detect: {files_any: [...], package_deps_any: [...]}

Project-side writes are whole directories only (no edits to existing files):
  <project>/.claude/skills/<tool>/   and   <project>/.playwright/ (outputDir .playwright/output)
  each created dir contains a `.gitignore` with `*` (self-ignoring; worktree-safe)
  each dir is built in <project>/.claude/.ai-pack-stage-<id>/ (outside skills/, same fs),
  then moved with `mv -T` (new) or `mv --exchange` (replace; coreutils >= 9.5) ; stale
  stages are deleted under the lock at the start of every add/remove

npm installs: each version into ~/.local/share/ai-pack/npm/<tool>@<ver>.staging with
  --ignore-scripts, then `mv -T` to <tool>@<ver>, then the bin link is switched atomically
  (temp link + `mv -T`); recorded in machine.json only after that; old prefixes kept until --purge

pinned hash = sha256 over (type, exec bit, relative path, sha256) lines, NUL-sorted, of the
  final dir contents minus `.gitignore`; modes set with chmod after the copy; templating is
  deterministic (same input, same hash)

state (~/.local/state/ai-pack/, schema_version 1, flock on ./lock, temp file + mv;
       a newer schema_version -> refuse writes, `hint` silent; older -> defaults for missing keys):
  machine.json   tool -> installed versions, bin links created, projects using it (refcount)
  projects.json  project key -> journal per tool: version, dirs created, files written (path + sha256)
  ignored.json   project key -> ignored packs
  hints.json     project key + pack -> last shown (timestamp)

project key = git root realpath of the cwd, else realpath of the cwd (one function, in ai-pack)

events: install, activate, deactivate, purge, ignore, unignore, hint-shown
```

## Foundation

n/a: existing repo conventions apply (bash + shellcheck/shfmt, `make check`, TDD with `scripts/tests/*.test.sh` style tests, conventional commits, upstream-watch for pinned sources).

## Screens

### Startup hint (SessionStart, toolkit hook `pack-hint.sh`)

```
┌ pack hint ──────────────────────────────────────┐
│ package.json + vite detected                    │
│ suggested: ai-pack add web  (ai-pack ignore web)│
└─────────────────────────────────────────────────┘
```

- Chosen: B (hint) with A (CLI applies it).
- Hook: a thin wrapper. On `startup` it runs `timeout 1.5 ai-pack hint --cwd <hook input cwd>` (from PATH, falling back to `${XDG_BIN_HOME:-$HOME/.local/bin}/ai-pack`; the `hint` output carries a version, part of the frozen contract) and prints its one line as `systemMessage` (never `additionalContext`, so 0 tokens). If `ai-pack` is not on PATH, times out or fails, it stays silent. Respects `AI_HOOKS_OFF=pack-hint`. hooks.json `"timeout": 2`.
- `ai-pack hint`: reads `packs.json` from its own repo (resolved through the realpath of `bin/ai-pack`); in the project it reads only the root `package.json` and `index.html`; shown once per project and pack, again after 30 days; never when any tool of the pack is active, or the pack is ignored; writes only `hints.json`, with `flock -n` (skip if busy) and temp file + `mv`; any parse error means silence.
- Detection (v1): `web` = `package_deps_any` vite/react/vue/svelte/next/astro, or `files_any` root `index.html`; `diagrams` = no rules (manual).
- States: nothing detected -> silent; shown < 30 days ago -> silent; pack active -> silent; pack ignored -> silent; two sessions starting at once -> at most one hint.

| UI element | Backend demand |
|---|---|
| "vite detected" | detect rules in `packs.json` |
| once per 30 days | `hints.json` timestamps |
| silent when active/ignored | `projects.json` / `ignored.json` |

### `ai-pack` CLI

```
$ ai-pack list
 web       ✔  playwright, web-design-guidelines, taste
 diagrams  ·  archify
 ── tools ──
 playwright            ✔ (via web) 0.1.22 (machine 0.1.23)
 archify               ✔ 3.2.0 -> 3.3.0 available (ai-pack add archify)
 taste                 ⚠ shadowed by ~/.claude/skills/design-taste-frontend
$ ai-pack add archify
 + archify v3.2.0  (skill copied to .claude/skills/archify, tree hash ok)
 ok: active in /home/me/proj/cli-go — run /reload-plugins
$ ai-pack add web
 error: chromium not found; install it with: sudo pacman -S chromium
 nothing was written
$ ai-pack remove --purge playwright
 error: still used by /home/me/proj/shop, /home/me/proj/blog; nothing removed
```

- Chosen: C (packs + standalone tools).
- Commands: `list`, `add <pack|tool>` (on an active tool: re-sync to the manifest version), `remove <pack|tool> [--purge]`, `ignore <pack>`, `unignore <pack>`, and the internal `hint --cwd <dir>` used by the hook.
- Rules:
  - Preflight for the whole pack before any write: requirements (with min versions), downloads, checksums and integrity.
  - Each project dir is built in a stage dir and moved into place (`mv -T` new, `mv --exchange` replace); the journal entry is written after the move, under the lock. A failure after preflight rolls back the dirs moved and npm prefixes staged in this run. An interrupted run leaves at most whole dirs plus stale stages (cleaned next run): a dir with no journal entry whose pinned hash matches is shown as "adoptable" by `list` (read-only) and adopted by the next `add` (this also covers moved projects); any other existing target is refused and nothing is written.
  - `remove` deletes the files ai-pack wrote if their sha256 still matches, then the dir if it is empty apart from `.gitignore` and declared leftovers (which are printed). If a written file was edited by hand, it warns, keeps the dir, drops the journal entry (refcount drops) and prints "delete <path> to re-add". `add` re-sync over a hand-edited copy warns and does not overwrite.
  - Shared tools deactivate only when no active pack in that project needs them. Machine-wide installs stay after the last project removes them. `--purge` uninstalls only when no existing project uses the tool: entries whose project root no longer exists are shown and dropped under the lock; if any existing project still uses it, it refuses and lists those projects (no override).
  - Bin links: refuse if `~/.local/bin/<bin>` exists and is not a link ai-pack created (journaled in `machine.json`).
  - A manifest bump of a machine-wide tool applied from one project upgrades it for every project; `list` shows it everywhere (from `machine.json`) and `add` prints "restart your Claude sessions".
  - Warn on `add`/`list` when a personal or plugin skill shadows the project copy, by directory name or frontmatter `name` (recursive scan, maxdepth 4, of `~/.claude/skills` and the plugin cache; personal skills can be nested, e.g. `skills/synced/<id>/<skill>`).
  - ai-pack checks its own dependencies (`jq`, `flock`, `curl`, `sha256sum`) at startup and prints the exact pacman line; kind `npm` requires `npm` (`sudo pacman -S npm`).
  - `list` lines fit in 70 columns.
  - `list`/`remove` check real presence and tolerate dirs removed by hand; `list` skips projects whose root no longer exists (no state write).
  - `remove` prints runtime leftovers (e.g. `.playwright/output/`, Archify HTML output) without deleting them.
  - After changes print "run /reload-plugins" (skills only) or "restart Claude in this project" (Playwright config).
- Run from a subdirectory: resolves to the project key; document "start claude at the repo root".
- States: missing requirement -> exact `pacman` command, nothing written; checksum/integrity mismatch -> abort, nothing written; network error -> nothing written; failure after preflight -> rollback of this run; foreign target -> refuse, nothing written; not in a git repo -> cwd is the project.

| UI element | Backend demand |
|---|---|
| ✔ / · per pack and tool | `projects.json` + real presence check |
| "(via web)" | per-project refcount across active packs |
| "3.2.0 -> 3.3.0" | journal version vs manifest version |
| "installed by another project" | `machine.json` version vs project journal |
| "shadowed by" | scan of `~/.claude/skills` and installed plugin skills (dir + frontmatter name) |
| purge refusal | `machine.json` refcount, existing roots only |
| tree hash ok | pinned hashes in `packs.json` |

## Data captured / data inventory

| Screen | Data shown | Actions (events) | Source |
|---|---|---|---|
| Startup hint | detected signal, suggested pack | hint-shown | `packs.json`, state files, project `package.json`/`index.html` |
| ai-pack | packs, tools, active state, versions, drift, shadowing, unused installs | install, activate, deactivate, purge, ignore, unignore | `packs.json`, state files, project dirs, `~/.claude/skills` |

## Scope

| Item | Priority (MUST/SHOULD/LATER) | Est. dev-days | Demo value |
|---|---|---|---|
| `packs/packs.json` schema + manifest (schema_version, kinds, layers, sources, requires with min and hint, project_dirs, leftovers, detect `files_any`/`package_deps_any`) | MUST | 0.5 | high |
| `bin/ai-pack` core: project key, state + flock + atomic writes + schema_version rules, per-file journal, stage dirs + `mv -T`/`--exchange` + stale-stage cleanup, adoption by hash, refcounts, pack preflight + rollback, read-only list/add/remove/ignore/unignore/hint, `--purge` rules, drift and shadow warnings, own dependency check | MUST | 2.6 | high |
| Kind `skill` (copy, chmod, pinned hash minus `.gitignore`, self-ignoring `.gitignore`, vendored + fetched sources, deterministic templated SKILL.md) | MUST | 0.5 | high |
| Kind `npm` (per-version staging prefix under `~/.local/share/ai-pack/npm`, `npm pack` + sha512 integrity, `--ignore-scripts`, atomic bin link switch with collision check, refcounted, machine-wide upgrade notice) | MUST | 1.0 | high |
| Vendored pins in `packs/vendor/`: taste-skill v2.1.2, Archify v3.2.0 (patched to disable the update check); in-house `web-design-guidelines` SKILL.md template + fetched pin of the rules; Playwright `.playwright/cli.config.json` with `executablePath: /usr/bin/chromium` and `outputDir: .playwright/output`; requires `chromium`, `node >= 22`, `npm` | MUST | 0.6 | medium |
| Exclude `packs/vendor/` from `check-shell.sh` + test that `make check` passes with vendored files; run `gitleaks` on `packs/vendor/` before the vendoring commit | MUST | 0.1 | medium |
| Packs v1: `web` (playwright-cli, web-design-guidelines, taste-skill), `diagrams` (archify) | MUST | (in manifest) | high |
| Tests `scripts/tests/ai-pack.test.sh` (stub claude/npm/curl, fake HOME and projects incl. two worktrees and a subdirectory/symlink fixture; journal, staging, re-sync without nesting, adoption, killed run + stale stage, refcount, purge with dead and live roots, rollback, network error before and during npm install, idempotency, collision, bin-link collision, drift, hand-edit on remove and re-sync, runtime output on remove, nested shadow, newer schema_version, deterministic template, hint silent with a partly active pack) | MUST | 2.0 | high |
| toolkit hook `pack-hint.sh` (thin wrapper) + `ai-pack hint` 30-day logic with `flock -n` + concurrency test + `systemMessage` assertion + hooks.json + hooks-off test + Makefile `HOOKS` mutate list + toolkit version bump | MUST | 0.7 | high |
| Early manual check: project skills pickup (incl. running the vendored taste-skill copy from `.claude/skills`), where `playwright-cli install --skills` writes, a real `playwright-cli open` + snapshot with system Chromium (record the working Chromium/node/playwright-cli versions), then `git status` and `ai-pack remove web`, Archify patch works, how the hint renders next to the other startup messages, hook from a launcher without `~/.local/bin` on PATH, `claude` started from a subdirectory | MUST | 0.5 | medium |
| upstreams.json entries for every pinned source (incl. the web-interface-guidelines rules repo) | MUST | 0.1 | medium |
| docs/packs.md (taste-skill's run-time image search, unpinned npm transitive deps, moved-project behaviour, "start claude at the repo root") + README rows (bin, toolkit hook opt-out) + roadmap (replace `--profile` line) | MUST | 0.25 | medium |
| Ponytail eval: 3 over-build-tempting cases, with vs without, verdict recorded | SHOULD | 0.5 | high |
| Brand `DESIGN.md`: `design-md <brand>` tool fetched at a pinned commit | LATER | 0.5 | low |
| `bigcode` pack: kinds `binary` + `mcp`, codebase-memory-mcp (daemon stop before swap, `claude mcp add --scope local`), file-count cache | LATER (v2) | 1.5 | medium |
| Kind `plugin` (local-scope enable in `settings.local.json`) | LATER | 0.5 | low |
| `ai-pack doctor` / `prune` | LATER | 0.5 | low |

Total MUST: ~8.85 dev-days; no deadline, solo -> fits.

## Demo data

The test suite builds throwaway projects (`package.json` with vite, a fake Go CLI, two worktrees of one repo, a symlinked path) under a temp HOME; all fixtures under mktemp; no real installs (stubs for claude, npm, curl). A manual demo on a real web project runs `ai-pack add web`, then restarts Claude.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| Does `playwright-cli install --skills` write into the project or HOME? | Checked first in implementation; ai-pack copies the skill into the project either way | Claude | no |
| Does the vendored taste-skill run from `.claude/skills` alone? | Checked in the manual check; if not, vendor the extra files it needs | Claude | no |
| Can the Archify update check be disabled by a small patch to the vendored copy? | Yes (it reads one env var); if not, document `ARCHIFY_UPDATE_CHECK_DISABLED=1` for the user's shell | Claude | no |
| Working system Chromium + playwright-cli pair | Recorded in docs/packs.md after the manual check | Claude | no |
| Behaviour when `claude` starts in a subdirectory | Verified in the manual check; documented either way | Claude | no |
| npm transitive dependencies | Not pinned (no lockfile in a published package unless it ships `npm-shrinkwrap.json`); documented | Claude | yes |
| `web` detection | `package.json` with vite/react/vue/svelte/next/astro, or a root `index.html` | Claude | yes |
| `diagrams` detection | none: manual only | Claude | yes |
| Unlicensed rules | fetched at add time from a pinned commit + sha256, never committed | Claude | yes |

## Deferred to v2

- `bigcode` pack (codebase-memory-mcp, kinds `binary` + `mcp`) — no current repo passes the threshold; adds a daemon and a machine-wide version lock.
- Brand `DESIGN.md` — taste-skill and web-design-guidelines cover v1; fetch one brand on demand later.
- Ponytail adoption — only if the eval shows less code without losing input handling.
- Kind `plugin` — no v1 tool needs it after vendoring taste-skill.
- More packs (data, mobile, infra) — when a real project needs one.
- `ai-pack doctor` / `prune` — `list` shows drift; `--purge` already drops dead roots.

## Demo priorities

1. `ai-pack add web` in a web project turns on Playwright and the design skills only there; another project and the other worktree's `git status` show nothing new.
2. The startup hint appears in a vite project once (and again after 30 days), never in this repo.
3. `ai-pack remove web` removes every dir ai-pack created, leaves hand-edited copies alone with a warning, and lists runtime leftovers.

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: `packs/packs.json` schema (incl. detect rules) and state file schemas (schema_version 1)
- Work packages: n/a

## Plan-review resolutions

Source: `plan-review-1.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | No machine-wide layer | Tools have `layer` machine/project; `machine.json` refcounts projects; global installs stay unless `--purge` | planner + user (purge policy) |
| 2 | No `binary` kind | Designed (url + sha256 to `~/.local/bin`, `mcp` requires it); moved to v2 with `bigcode` | planner + user (scope B) |
| 3 | plugin/npm not checksum-pinnable | taste-skill vendored as a skill at v2.1.2; `plugin` kind LATER; npm: see review 2 #1-2 | planner |
| 4 | Nothing records what add did | Per-project journal; superseded by review 3: project writes are whole dirs only, journaled with tree hashes | planner |
| 5 | Symlink drift | Skills copied, version journaled, `list` flags drift, `add` re-syncs | user |
| 6 | No locking | `flock` + temp file and `mv`; hook writes see review 2 #4 | planner |
| 7 | Hint once vs every startup | Once per project and pack, again after 30 days (`hints.json`) | user |
| 8 | No drift reconciliation | Project key = git root realpath; list/remove check real presence; list skips missing roots; adoption by hash | planner |
| 9 | Hint cache/timeout undefined; line count too slow | Hook timeout 2, 1.5 inside; file-count rule only in v2 `bigcode` | planner |
| 10 | Token cost depends on output field | `systemMessage` only, asserted in test | planner |
| 11 | Git edge cases | Superseded by review 3 #1: self-ignoring dirs, no `info/exclude`; refuse on foreign targets | planner |
| 12 | Runtime side effects | Playwright config dir (self-ignoring); "as before" = every dir ai-pack created; remove prints leftovers | planner |
| 13 | Activation timing not told | Print restart / `/reload-plugins` | planner |
| 14 | No unignore; project root undefined | `unignore` added; one project-key function in ai-pack; subdirectory checked early | planner |
| 15 | Licensing of vendored files | Repo is private; still, unlicensed rules are fetched at add time (pinned + sha256), never committed; MIT tools vendored; brand files LATER | planner + user |
| 16 | Hook wiring missing from scope | hooks-off test, Makefile `HOOKS`, README rows, toolkit version bump in scope | planner |
| 17 | Node 22+ not checkable | `requires` entries accept `min` | planner |

Source: `plan-review-2.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | `npm -g` needs root (prefix `/usr`) | Own prefix `~/.local/share/ai-pack/npm`, bins linked into `~/.local/bin` | planner |
| 2 | Transitive npm deps float | `npm pack` + sha512 integrity check, install the tarball; transitive deps documented as unpinned | planner |
| 3 | Hook cannot read `packs/packs.json` from the plugin cache | Superseded by review 3: the hook runs `ai-pack hint`, which reads `packs.json` from its own repo | planner |
| 4 | Hook "read-only" but writes hints | `ai-pack hint` writes only `hints.json` with `flock -n` (skip if busy) + temp/mv; concurrency test | planner |
| 5 | `make check` would lint vendored scripts | `packs/vendor/` excluded from `check-shell.sh`; test that `make check` passes | planner |
| 6 | remove can overwrite later user edits | No file edits at all (review 3 #4); dirs deleted only on tree-hash match, else warn | planner |
| 7 | Pack half-active on failure | Pack-level preflight before any write; rollback of this run; network error state | planner |
| 8 | CBM binary swap while daemon runs | Designed (daemon stop, temp + mv, restart notice); moved to v2 with `bigcode` | planner + user (scope B) |
| 9 | `--purge` while other projects use the tool; silent machine-wide upgrade | `--purge` refuses for existing projects, no override; upgrade applies to all, `list` flags it, `add` prints restart notice | user |
| 10 | Exclude lines not journaled | Superseded by review 3 #1: no exclude lines | planner |
| 11 | Archify update check not handled | Patched in the vendored copy; taste image search kept and documented | planner |
| 12 | Playwright env is for the MCP server | `.playwright/cli.config.json` with `executablePath` (self-ignoring dir) | planner |
| 13 | Fetch-and-inline and tree hash undefined | Fetched file verified by sha256, then templated into SKILL.md; tree hash defined (review 3 #12); rules repo in upstreams.json | planner |
| 14 | Personal skill shadows project copy | Shadow warning on `add`/`list` (dir and frontmatter name) | planner |
| 15 | Toolkit version bump missing | Added to the hook row | planner |
| v1 scope | MUST grew to ~10.15 days | Split: v1 = skills + npm (`web`, `diagrams`); `bigcode` to v2 | user |

Source: `plan-review-3.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | `info/exclude` shared across worktrees | Simplified: every created dir carries a `.gitignore` with `*`; `info/exclude` is not used; two-worktree test | planner |
| 2 | Interrupted add leaves unjournaled files | Staging dir + `mv` per target, journal after the move; adoption of unjournaled dirs whose tree hash equals the pinned hash; killed-run test | planner |
| 3 | Dead projects block `--purge` forever | `--purge` shows and drops entries whose root is gone; still refuses for existing projects | user |
| 4 | Collision rule vs existing `settings.local.json` | Simplified: ai-pack never writes `settings.local.json` (or any existing file); Archify update check patched in the vendored copy | planner |
| 5 | Moved project keeps old state | Adoption by tree hash at the new path; documented | planner |
| 6 | Hook "never reads the repo" vs project files | Reworded: `ai-pack hint` reads `packs.json` from the dotfiles repo and only root `package.json`/`index.html` in the project | planner |
| 7 | Project key computed twice | Simplified: the hook delegates to `ai-pack hint --cwd`; one key function; shared fixture test | planner |
| 8 | `detect.json` format undefined | Simplified: no `detect.json`; detect schema (`files_any`, `package_deps_any`) is part of the frozen `packs.json` contract | planner |
| 9 | `DESIGN.md` owned by no tool | Moved to LATER (`design-md <brand>`) | user |
| 10 | Chromium not in `requires` | `requires` has `chromium` (hint `sudo pacman -S chromium`) and `node >= 22` | planner |
| 11 | Shadow check by dir name only | Also by frontmatter `name` | planner |
| 12 | Tree hash path- and mode-dependent | Relative NUL-sorted paths with mode, computed inside the dir; copy with `cp -a` | planner |
| 13 | No machine-layer collision rule | Refuse foreign `~/.local/bin` entries; bin links journaled in `machine.json` | planner |
| 14 | Re-sync over hand edits | Warn and do not overwrite when the tree hash differs | planner |
| 15 | `install.sh` export not in scope | Simplified: nothing to export; `install.sh` already links `bin/*` | planner |

Source: `plan-review-4.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | `mv` onto an existing dir nests | `mv -T` for new dirs, `mv --exchange` for replacement (coreutils 9.12 here); re-sync test asserts no nesting | planner |
| 2 | Runtime output vs whole-dir hash | Per-file journal (path + sha256); dir removed only if empty apart from `.gitignore` and leftovers; Playwright `outputDir: .playwright/output` (self-ignoring), listed as leftover; manual check runs a real snapshot then `git status` and remove | user (output dir) + planner |
| 3 | npm install fetches deps after preflight | Per-version staging prefix with `--ignore-scripts`, `mv -T`, atomic bin link switch, `machine.json` after success, old prefixes kept until `--purge`; network-failure-during-install test | planner |
| 4 | Full mode in hash depends on umask | Hash uses file type + exec bit only; chmod after copy | planner |
| 5 | Staging inside `skills/`; stale stages | Stage under `<project>/.claude/.ai-pack-stage-*`; stale stages deleted under the lock at the start of add/remove | planner |
| 6 | `list` adopts but is "read-only" | `list` is read-only and shows "adoptable"; `add` adopts | planner |
| 7 | Hand-edited copy on remove | Drop the journal entry, keep the dir, print "delete <path> to re-add"; refcount drops | planner (no real fork: the other option blocks `--purge` forever) |
| 8 | Missing requires (npm, ai-pack deps) | `npm` required by kind npm; ai-pack checks `jq`, `flock`, `curl`, `sha256sum` at startup | planner |
| 9 | Shadow scan misses nested skills | Recursive scan (maxdepth 4) of `~/.claude/skills` and the plugin cache; nested fixture | planner |
| 10 | Unknown schema_version | Newer -> refuse writes, `hint` silent; older -> defaults; test | planner |
| 11 | `list` line too wide | Shortened to fit 70 columns | planner |
| 12 | web-design-guidelines SKILL.md origin | Written in-house; only the rules are fetched (pinned + sha256) | planner |
| 13 | Pinned hash scope undefined | Final dir contents minus `.gitignore`; deterministic-template test | planner |
| 14 | Hint with a partly active pack | Silent if any tool of the pack is active; test | planner |
| risks | PATH from launchers; hook/CLI skew; npm swap mid-session; node upgrades | Hook falls back to `~/.local/bin/ai-pack`; `hint` output versioned; old npm prefixes kept; tested versions recorded in docs/packs.md | planner |

## Post-implementation changes

Dated 2026-10-19, after verify. The sections above keep the original decisions; where they differ, this section wins.

| Item | Was | Now | Why |
|---|---|---|---|
| web-design-guidelines rules (Research, Core model source kinds, Scope row, Data gaps, resolutions review-1 #15 and review-2 #12) | Rules fetched at add time from a pinned commit + sha256, never committed | Vendored as `packs/vendor/web-design-guidelines/rules.md` (upstream `command.md`, commit 4ecfb9f) with the upstream LICENSE; SKILL.md stays in-house | Upstream added an MIT LICENSE in 2025-09; the fetch path is gone, so `add` needs no network for this tool |
| archify vendored tree | Verbatim v3.2.0 plus the update-check patch | Also without `examples/*.html` (11.9 MB, unused) | Size; documented in `packs/vendor/README.md` |
| taste project dir | `.claude/skills/taste` | `.claude/skills/design-taste-frontend` | Claude lists project skills by dir name; the frontmatter name is `design-taste-frontend` |
| `pack-hint` timeout | Fixed cut | `PACK_HINT_TIMEOUT` widens the cut (hook `timeout` stays 2) | Slow CI runners made the hint test flaky |
| CI image | Check job on `ubuntu-24.04` | `archlinux:latest` container (commit 321eee7) | Matches the target platform; Ubuntu 24.04 ships coreutils 9.4 without `mv --exchange` |
| Post-change notice | "reload" or "restart" in the plan | `add` prints "restart Claude in this project" when a tool writes outside `.claude/skills`, else "run /reload-plugins" | Found by verify; implemented in the corrective batch |

