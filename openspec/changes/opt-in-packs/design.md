# Design: Opt-in packs

Source of truth: `docs/plans/packs/plan.md` (Core model, Rules, Plan-review resolutions are settled and not reopened here).

## Technical Approach

A plain-bash CLI `bin/ai-pack` (linked by the existing `install.sh` `bin/*` loop) reads `packs/packs.json` from its own repo (`readlink -f "$0"`, like `bin/upstream-watch`), keeps state in `~/.local/state/ai-pack/` (jq, temp file + `mv -f`, like `engram-backup`), and writes only whole self-ignoring dirs into projects. The toolkit hook `pack-hint.sh` is a thin wrapper over `ai-pack hint`. Runtime tools: `jq`, `flock`, `curl`, `sha256sum`, coreutils (`mv -T`, `mv -T --exchange`, `basenc`, `base64`); none are new to an Arch base system.

## Architecture Decisions

| Decision | Option | Tradeoff | Choice |
|---|---|---|---|
| Code layout | one `bin/ai-pack` file | ~900 lines, one PR can't hold it | rejected |
| | `bin/ai-pack` dispatcher + `packs/lib/*.sh` modules | sourced via the realpath; each module lands in its own PR; linted by `check-shell.sh` | **chosen** |
| Shared helpers | source `scripts/lib.sh` | it derives `ROOT` from `$1` and owns check-step exit codes; wrong for a CLI | rejected; mirror its `err/warn/ok` names in `packs/lib/common.sh` |
| Test seams | env overrides (`AI_PACK_MANIFEST`, `AI_PACK_STATE`, `AI_PACK_DATA`, `AI_PACK_BIN`, `AI_PACK_NOW`, `CLAUDE_HOME`) | same pattern as `UPSTREAMS_FILE`/`UPSTREAM_WATCH_STATE` | **chosen**; no "kill after step" hooks in production code |
| Interrupted run test | inject a kill point | test-only code paths | rejected; tests build the post-kill state (unjournaled dir + stale stage) directly |
| Rollback | `trap ERR` | fragile with `set -u`, subshells | rejected; explicit undo stack (`undo_push`/`undo_run`) plus `trap undo_run INT TERM` |
| Lock scope | lock for `list` | blocks reads | rejected; writers take `flock -w 30` on `state/lock`; `hint` uses `flock -n`; `list` reads atomically replaced files without a lock |
| sha512 integrity | `openssl` / `xxd` | extra tools | rejected; `sha512sum` → `basenc --base16 -d` → `base64 -w0` (coreutils) |
| Templating | `envsubst` / `sed` | extra dep / escaping bugs | rejected; `awk` replaces one marker line `{{FETCHED:<name>}}` with the verified file verbatim (deterministic) |
| Hint contract | raw text | hook/CLI skew undetectable | rejected; `hint` prints `v1<TAB><message>`; the hook drops any other prefix |
| Pinning | hand-computed hashes | error-prone | internal `ai-pack hash <dir>` (same function `add` uses) |

## File Changes

| File | Action | Description |
|---|---|---|
| `bin/ai-pack` | Create | dependency check, path setup, sources modules, dispatch |
| `packs/lib/common.sh` | Create | `say/warn/die`, `version_ge` (`sort -V`), `project_key`, `require_cmd` |
| `packs/lib/state.sh` | Create | `state_read`, `state_write` (temp + `mv -f`), schema rules, `lock_wait`, `lock_try` |
| `packs/lib/tree.sh` | Create | `tree_hash`, `normalize_modes`, `render_template`, `stage_new`, `clean_stages` |
| `packs/lib/sources.sh` | Create | `fetch_verified`, `npm_pack_verified`, `npm_install_prefix`, `link_switch` |
| `packs/lib/plan.sh` | Create | target classification, preflight, apply, undo stack |
| `packs/lib/cmd.sh` | Create | `cmd_list/add/remove/ignore/unignore/hint/hash` |
| `packs/packs.json` | Create | manifest (frozen contract) |
| `packs/vendor/{taste-skill,archify,web-design-guidelines,playwright}/` | Create | vendored pins (Archify already patched, patch described in `archify/README.md`), in-house template, Playwright config |
| `plugins/toolkit/hooks/pack-hint.sh` | Create | SessionStart wrapper |
| `plugins/toolkit/hooks/hooks.json` | Modify | `startup` entry, `"timeout": 2` |
| `plugins/toolkit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | Modify | toolkit 0.10.1 → 0.11.0 |
| `scripts/check-shell.sh` | Modify | skip `packs/vendor/*` |
| `Makefile` | Modify | add `pack-hint` to `HOOKS` |
| `scripts/tests/ai-pack-*.test.sh`, `plugins/toolkit/hooks/tests/pack-hint.test.sh`, `hooks-off.test.sh`, `scripts/tests/checks.test.sh` | Create/Modify | tests |
| `upstreams.json`, `README.md`, `docs/packs.md` | Modify/Create | pins, rows, roadmap line |

## Interfaces / Contracts

`packs/packs.json` (pack and tool names share one namespace; `project_dirs` keys are relative, no `..`, under `.claude/skills/` or `.playwright`):

```json
{
  "schema_version": 1,
  "packs": {
    "web": {"tools": ["playwright", "web-design-guidelines", "taste"],
            "detect": {"files_any": ["index.html"],
                       "package_deps_any": ["vite", "react", "vue", "svelte", "next", "astro"]}},
    "diagrams": {"tools": ["archify"], "detect": {}}
  },
  "tools": {
    "playwright": {
      "kind": "npm", "layers": ["machine", "project"],
      "source": {"type": "npm", "package": "@playwright/cli", "version": "0.1.22", "integrity": "sha512-..."},
      "bins": ["playwright-cli"],
      "requires": [{"cmd": "node", "min": "22", "hint": "sudo pacman -S nodejs"},
                   {"cmd": "npm", "hint": "sudo pacman -S npm"},
                   {"cmd": "chromium", "hint": "sudo pacman -S chromium"}],
      "project_dirs": {
        ".claude/skills/playwright-cli": {"from": "npm:<path in package, set by manual check>", "hash": "sha256:..."},
        ".playwright": {"from": "vendor:playwright", "hash": "sha256:..."}},
      "leftovers": [".playwright/output"]
    },
    "web-design-guidelines": {
      "kind": "skill", "layers": ["project"],
      "source": {"type": "fetched", "name": "rules",
                 "url": "https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/<commit>/<file>",
                 "sha256": "..."},
      "project_dirs": {".claude/skills/web-design-guidelines": {"from": "vendor:web-design-guidelines", "template": "SKILL.md", "hash": "sha256:..."}}
    },
    "taste": {"kind": "skill", "layers": ["project"], "source": {"type": "vendored", "tag": "v2.1.2"},
              "project_dirs": {".claude/skills/taste": {"from": "vendor:taste-skill", "hash": "sha256:..."}}},
    "archify": {"kind": "skill", "layers": ["project"], "source": {"type": "vendored", "tag": "v3.2.0"},
                "project_dirs": {".claude/skills/archify": {"from": "vendor:archify", "hash": "sha256:..."}},
                "leftovers": []}
  }
}
```

Naming is kept as above: `layers` is an array (a tool is machine and/or project, per the plan), and packs and tools are object keys. The `pack-manifest` spec will be aligned to these names.

Archify is committed to `packs/vendor/archify/` already patched (update check disabled); the patch is documented in `packs/vendor/archify/README.md`, there is no `patch` field, and the pinned hash covers the patched bytes.

State files (all carry `"schema_version": 1`; missing keys default to `{}`/`[]`):

```
machine.json  {tools: {<tool>: {current: "0.1.22", versions: {"0.1.22": {prefix, at}},
                                bins: {<bin>: <link target>}, projects: [<key>]}}}
projects.json {projects: {<key>: {tools: {<tool>: {version, via: ["web"|"direct"],
                                  dirs: [<rel dir>], files: [{path, sha256}], at}}}}}
ignored.json  {projects: {<key>: [<pack>]}}
hints.json    {projects: {<key>: {<pack>: <epoch>}}}
```

Tree hash: inside the dir, every entry except `./.gitignore`, NUL-sorted, one line `type\0x\0path\0sha256` (`path` keeps the `./` prefix, e.g. `./sub/a`; `type` f/d/l, `x` = user exec bit, sha256 of content or link target), the whole stream through `sha256sum`. `normalize_modes` runs first (dirs 755, files 644 or 755).

## Data Flow and Algorithms

```
add:  deps → resolve names → key → lock_wait → clean_stages → PREFLIGHT (tmp only)
      → machine layer (npm) → project layer (stage → hash → mv) → state commit → messages
                   └──── any failure: undo_run (reverse order), "nothing was written" ────┘
```

**project_key**: `realpath` of `--cwd`/`$PWD`; `env -u GIT_DIR -u GIT_WORK_TREE git -C <abs> rev-parse --show-toplevel`, then `realpath`; else the cwd realpath.

**add <pack|tool>**
1. Preflight, writes only to a `mktemp -d` outside the project: `requires` (`command -v`, `min` via `version_ge`); `fetch_verified` (`curl -fsSL`, sha256); `npm_pack_verified` (`npm pack <pkg>@<ver> --pack-destination tmp`, local sha512 vs manifest). Classify each target dir: *absent* → new; *journaled, files match, hash == pinned* → no-op; *journaled, files match, hash differs* → replace (re-sync); *journaled, a file edited* → warn, skip; *unjournaled, hash == pinned* → adopt; *anything else* → refuse the whole run. Bin links: refuse if `$AI_PACK_BIN/<bin>` exists and is not in `machine.json` bins. Shadow scan (warn only): `find ~/.claude/skills -maxdepth 4 -name SKILL.md` plus the glob `~/.claude/plugins/cache/*/*/*/skills/*/SKILL.md` (plugin skills sit at depth 6, e.g. `cache/ai-dotfiles/flow/0.1.0/skills/fill-gaps/SKILL.md`); match dir name or frontmatter `name`. This clarifies plan.md:138, whose "maxdepth 4" only holds for `~/.claude/skills`.
2. Machine layer (npm, if `current` != manifest version and no prefix): `npm install --prefix <tool>@<ver>.staging --ignore-scripts --no-audit --no-fund <tarball>`; `mv -T` → `<tool>@<ver>`; undo = `rm -rf`. `link_switch`: `ln -s` to `$BIN/.ai-pack-<bin>.tmp`, `mv -T` onto `$BIN/<bin>`; undo restores the previous target.
3. Project layer: `stage_new` makes `<proj>/.claude/.ai-pack-stage-<id>/` (its own `.gitignore` `*` first), `cp -a` the source, `render_template`, `normalize_modes`, add `.gitignore`, `tree_hash` ≠ pinned → abort + undo. New: `mkdir -p` parent, `mv -T`; undo `rm -rf`. Replace: `mv -T --exchange <stage> <target>` (without `-T`, coreutils 9.12 fails with "cannot exchange a and b/a"); undo runs the same exchange again; old content deleted after commit.
4. Commit under the lock: journal entries (files + sha256), `via`, `machine.json` versions/bins/projects; clear undo; remove stages. Print `/reload-plugins` or "restart Claude in this project"; on a machine version change, "restart your Claude sessions".

**remove <pack|tool> [--purge]**: with `--purge`, in this order: (1) take the lock, (2) drop and print `machine.json` project entries whose root no longer exists, (3) refuse (list them, exit 1) if any live project other than this one uses the tool. Nothing else changes before that check. Then `clean_stages`. Drop the pack (or `direct`) from `via`; a tool deactivates only when `via` is empty, else print who still needs it. Per deactivated dir: missing → drop; delete files whose sha256 matches; edited file → keep dir, warn "delete <path> to re-add"; only `.gitignore` left → delete dir; `.gitignore` + leftovers → keep both, print leftovers; other files → keep, warn. Drop journal entry and refcount. Purge: remove bin links pointing into our prefixes, all prefixes, the machine entry.

**list**: read-only (no lock, no state write). Rows fit in 70 columns. Per pack: ✔ if any tool is active in this project, else ·. Per tool: active (journal entry + real presence of its dirs) with `(via <pack>)`; "adoptable" (no journal entry, target exists, tree hash == pinned; `add` adopts it); journal version vs manifest version (`3.2.0 -> 3.3.0 available`); `machine.json` current vs journal version (`(machine 0.1.23)`); "shadowed by <path>". Projects whose root no longer exists are skipped.

**hint --cwd**: every error is silence (exit 0). Newer schema → silent. For each pack with detect rules: skip if ignored, any tool active, or shown < 30 days (`AI_PACK_NOW`). Match root `files_any`, or `package_deps_any` against `dependencies + devDependencies` keys of root `package.json`. On a match: `lock_try` (busy → silent), re-read `hints.json`, write epoch, print `v1\t<signal> detected; suggested: ai-pack add <p>  (ai-pack ignore <p>)`.

**pack-hint.sh**: `hook_off`; `source == startup`; `cwd` from input; `ai-pack` from PATH else `${XDG_BIN_HOME:-$HOME/.local/bin}/ai-pack`; `timeout 1.5`; strip `v1\t`; `jq -n '{systemMessage: $m}'`.

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit-ish | key, tree hash, template determinism, schema rules, `version_ge` | `ai-pack-core.test.sh`, black box through `bin/ai-pack` |
| Integration | add/remove/purge/adopt/rollback/re-sync (swap two dirs with `mv -T --exchange`, assert no nesting and undo swaps back)/collisions/shadow (nested personal skill + depth-6 plugin cache skill)/drift/`list` 70 columns, adoptable, dead roots | `ai-pack-skill.test.sh`, `ai-pack-npm.test.sh`: fake HOME, fixture manifest + tiny vendor dirs (pins via `ai-pack hash`), stubs on PATH: `npm` (pack/install; `FAKE_NPM_FAIL=install` simulates a mid-install network error), `curl` (serves `$FAKE_CURL/<name>`, missing → exit 6), `node` (prints `v22.x`), `chromium` (present; removing it tests the "sudo pacman -S chromium" error); two worktrees, subdir and symlink fixtures |
| Manifest | real `packs.json` pins equal `ai-pack hash` of vendored dirs; names unique | `ai-pack-manifest.test.sh` |
| Lint scope | a fixture repo with a failing shell script under `packs/vendor/` still passes `check-shell.sh` | new case in the existing `scripts/tests/checks.test.sh` |
| Hook | `systemMessage` only, never `additionalContext`, timeout/missing/unknown prefix silent, 30 days, `flock` held → silent, two parallel runs → one hint, silent in the dotfiles repo itself (real `packs.json`, cwd = repo root) | `pack-hint.test.sh`; `hooks-off.test.sh` case; `make mutate` |

Deliberate deviation: the plan and proposal name one `scripts/tests/ai-pack.test.sh`. The tests are split into `ai-pack-{core,skill,npm,manifest}.test.sh` so that each chained PR ships its own tests and `scripts/run-tests.sh` runs them in parallel.

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: ai-pack copies vendored files but never classifies or executes them | — | — |
| Git repository selection | Applicable: project key from `git rev-parse` | realpath first, `git -C <abs>`, unset `GIT_DIR`/`GIT_WORK_TREE`, realpath of top-level | relative `--cwd`, absolute, symlinked path, subdirectory, second worktree, non-git dir, `GIT_DIR` set in env |
| Commit state | N/A: never runs `git commit` or reads the index | — | — |
| Push state | N/A: never pushes | — | — |
| PR commands | N/A: no PR automation | — | — |

## Migration / Rollout

No migration (new state dir). Suggested chained PRs, with estimated authored lines (code + tests):

| PR | Scope | Est. lines |
|---|---|---|
| 1 | Core: `bin/ai-pack`, `common.sh`, `state.sh`, `tree.sh` hash, `hash`, `ignore/unignore`, deps + schema checks | ~350 |
| 2a | Skill `add` from vendored sources: stage, `mv -T` / `mv -T --exchange`, journal, adoption, undo stack | ~380 |
| 2b | Fetched sources + `render_template` + shadow scan + `list` | ~370 |
| 3 | `remove` and `--purge` for skills (edits, leftovers, dead roots, purge order) | ~350 |
| 4 | Kind npm (pack/integrity, staging prefix, `link_switch`, `machine.json`, npm purge) | ~400 |
| 5 | Real `packs.json` + `packs/vendor/` + `check-shell.sh` exclusion + `checks.test.sh` case + `upstreams.json` (after the manual check) | ~200 + vendored bytes |
| 6 | `hint` + `pack-hint.sh` + hooks.json + Makefile + version bump | ~300 |
| 7 | `docs/packs.md`, README rows, roadmap line | ~200 |

ASSUMPTION: PR 5's vendored third-party bytes (taste-skill, Archify) do not count toward the 400-line budget. This is not automatic: it needs an explicit maintainer `size:exception` (see `plugins/toolkit/skills/chained-pr/SKILL.md:32`). Without one, PR 5 is split by vendored tool.

## Open Questions

- [ ] Path of the Playwright skill inside the npm package (`project_dirs.from`), from the early manual check; non-blocking (field already modeled).
- [ ] Whether taste-skill needs extra vendored files; affects only `packs/vendor/taste-skill` and its pin.
