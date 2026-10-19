# Tasks: Opt-in packs

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~2,350 authored (+ vendored third-party bytes in PR 5) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 -> 2a -> 2b -> 3 -> 4 -> 5 -> 6 -> 7 (per-PR: 350 / 380 / 370 / 350 / 400 / 200+vendor / 300 / 200) |
| Delivery strategy | ask-on-risk (resolved: chained PRs) |
| Chain strategy | stacked-to-main |

Decision needed before apply: No (resolved: chained PRs, stacked-to-main)
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

Resolved decisions: (a) chain strategy is stacked-to-main (PR 1 targets main; each later PR targets the previous PR branch); (b) PR 5 vendored third-party bytes get a maintainer `size:exception` (resolved; authored lines stay within budget). Open: PR 4 sits at the 400 limit: split `link_switch` out if it overruns.

### Suggested Work Units

| Unit | Goal | PR | Focused test | Runtime harness | Rollback boundary |
|------|------|----|--------------|-----------------|-------------------|
| 0 | Manual check, findings recorded | none | N/A | real run, see Phase 0 | notes only |
| 1 | Core CLI, hash, ignore | PR 1 | `bash scripts/tests/ai-pack-core.test.sh` | `ai-pack hash <dir>`, `ai-pack ignore x` in temp HOME | `bin/ai-pack`, `packs/lib/{common,state,tree}.sh` |
| 2a | Skill add (vendored) | PR 2a | `bash scripts/tests/ai-pack-skill.test.sh` | fixture add in a temp git repo | `plan.sh`, `cmd.sh` add |
| 2b | Fetched, template, shadow, list | PR 2b | same | `ai-pack list` width check | `sources.sh` fetch, `list` |
| 3 | remove, purge (skills) | PR 3 | same | add then remove in temp repo | remove code |
| 4 | npm kind | PR 4 | `bash scripts/tests/ai-pack-npm.test.sh` | stub npm in fake HOME | npm code in `sources.sh`/`plan.sh` |
| 5 | Real manifest + vendor | PR 5 | `bash scripts/tests/ai-pack-manifest.test.sh` | `make check` | `packs/packs.json`, `packs/vendor/` |
| 6 | Hint + hook | PR 6 | `bash plugins/toolkit/hooks/tests/pack-hint.test.sh` | hook run from a vite fixture | hook, hooks.json, version bump |
| 7 | Docs | PR 7 | `make check` | N/A: docs only | docs files |

Chain bases (stacked-to-main): PR 1 base = `main`; each later PR base = the previous PR branch.

## Phase 0: Early manual check (no PR; blocks marked tasks)

- [ ] 0.1 Confirm project skills load from `<proj>/.claude/skills/` incl. a hand-copied taste-skill v2.1.2 (needs extra files?). Blocks 6.2 (taste vendor files), 6.3.
- [ ] 0.2 Run `playwright-cli install --skills` in a scratch dir; record where it writes and the skill path inside the npm package. Blocks 6.3 (`project_dirs.from`); phases 1-5 are unaffected (fixture manifest).
- [ ] 0.3 Real `playwright-cli open` + snapshot with `/usr/bin/chromium`, then `git status`, then remove output. Confirms `.playwright/output` leftover. Blocks 6.2, 6.3, 8.1.
- [ ] 0.4 Apply the Archify patch (disable update check), write `archify/README.md` notes. Blocks 6.2.
- [ ] 0.5 Check where `systemMessage` renders next to other startup messages. Blocks 7.2 (message wording).
- [ ] 0.6 Run the hook from a launcher without `~/.local/bin` on PATH. Blocks 7.2 (fallback path).
- [ ] 0.7 Start `claude` from a subdirectory; record behavior. Blocks 8.1 (documented either way).

Phases 1-5 (PRs 1-4) can start without Phase 0.

## Phase 1: PR 1 Core (spec: Commands and project key, Startup dependency check, State files and locking, Ignore and unignore)

- [x] 1.1 RED: create `scripts/tests/ai-pack-core.test.sh`: project key cases (relative `--cwd`, absolute, symlink, subdir, second worktree, non-git, `GIT_DIR` set), missing `jq` prints pacman line and writes nothing, newer/older schema, deterministic tree hash under two umasks, `version_ge`, ignore round trip. Check: fails, then passes at 1.5.
- [x] 1.2 GREEN: `bin/ai-pack` (deps check, env seams, dispatch) and `packs/lib/common.sh`.
- [x] 1.3 GREEN: `packs/lib/state.sh` (read/write via temp + `mv -f`, `lock_wait`, `lock_try`, schema rules).
- [x] 1.4 GREEN: `packs/lib/tree.sh` (`tree_hash`, `normalize_modes`) and `packs/lib/cmd.sh` (`hash`, `ignore`, `unignore`).
- [x] 1.5 REFACTOR: run `bash scripts/tests/ai-pack-core.test.sh`, then `make check` (shellcheck via `check-shell.sh`).

## Phase 2: PR 2a Skill add (spec: Preflight, Self-ignoring whole-dir, Journal after move, Adoption, Rollback, Re-sync)

- [x] 2.1 RED: `scripts/tests/ai-pack-skill.test.sh` (fixture manifest, tiny vendor dirs, stubs): add new, two-worktree clean `git status`, missing requirement writes nothing, foreign target refused, adopt by hash, edited copy warns and unchanged, re-sync with `mv -T --exchange` and no nesting, second tool fails then rollback, stale stage deleted, notice "run /reload-plugins".
- [x] 2.2 GREEN: `tree.sh` (`stage_new`, `clean_stages`) and `plan.sh` (classification, preflight, apply, `undo_push`/`undo_run`, `trap` INT/TERM).
- [x] 2.3 GREEN: `cmd_add` for vendored sources and journal commit in `cmd.sh`.
- [x] 2.4 REFACTOR: `bash scripts/tests/ai-pack-skill.test.sh` plus `make check`.

## Phase 3: PR 2b Fetched, template, shadow, list (spec: Pinned sources, List output, Shadow warning, Machine-wide upgrade view)

- [x] 3.1 RED: extend `ai-pack-skill.test.sh`: curl stub (checksum mismatch and exit 6 write nothing), `{{FETCHED:name}}` template determinism, shadow (nested personal skill plus depth-6 plugin cache), `list` (70 columns, adoptable, drift, via, dead roots skipped, no state write).
- [x] 3.2 GREEN: `sources.sh` (`fetch_verified`), `tree.sh` (`render_template`).
- [x] 3.3 GREEN: shadow scan in `plan.sh` and `cmd_list` in `cmd.sh`.
- [x] 3.4 REFACTOR: dedupe helpers, run `ai-pack-skill.test.sh` and `make check`.

## Phase 4: PR 3 Remove and purge (spec: Remove behavior, Refcounts, Purge rules)

- [ ] 4.1 RED: extend `ai-pack-skill.test.sh`: hand-edited file warns and prints "delete <path> to re-add", leftover kept and printed, hand-removed dir tolerated, shared tool kept via `via`, purge refusal "still used by", dead roots dropped, purge ordering (lock, dead roots, refuse).
- [ ] 4.2 GREEN: `cmd_remove` and `--purge` in `cmd.sh`, `clean_stages` under lock.
- [ ] 4.3 REFACTOR: `ai-pack-skill.test.sh` plus `make check`.

## Phase 5: PR 4 npm kind (spec: npm machine layer, Machine-wide upgrade)

- [ ] 5.1 RED: `scripts/tests/ai-pack-npm.test.sh`: sha512 mismatch writes nothing, `FAKE_NPM_FAIL=install` removes staging and leaves `machine.json`, bin collision refused, missing chromium prints pacman line plus "nothing was written", version bump shows machine 0.1.23 in another project and "restart your Claude sessions", purge removes prefixes and links.
- [ ] 5.2 GREEN: `sources.sh` (`npm_pack_verified`, `npm_install_prefix`, `link_switch`) and machine layer in `plan.sh`; `machine.json` commit.
- [ ] 5.3 GREEN: npm purge in `cmd_remove`.
- [ ] 5.4 REFACTOR: `bash scripts/tests/ai-pack-npm.test.sh` plus `make check`.

## Phase 6: PR 5 Real manifest and vendor (spec: pack-manifest all; depends on Phase 0)

- [ ] 6.1 RED: `scripts/tests/ai-pack-manifest.test.sh` (schema_version 1, names unique, pack tools defined, node min 22, chromium hint, `web` and `diagrams` membership, detect rules, pins equal `ai-pack hash` of vendor dirs, no committed web-design-guidelines rules). Add case to `scripts/tests/checks.test.sh`: failing script under `packs/vendor/` still passes.
- [ ] 6.2 GREEN: vendor `packs/vendor/{taste-skill,archify}` (patched, `README.md`), in-house `web-design-guidelines` template, `playwright` config (`cli.config.json`).
- [ ] 6.3 GREEN: `packs/packs.json` with pins from `ai-pack hash`; `scripts/check-shell.sh` skips `packs/vendor/*`; `upstreams.json` pins.
- [ ] 6.4 REFACTOR: `make check`; if no `size:exception`, split into 5a/5b.

## Phase 7: PR 6 Hint and hook (spec: pack-hint all; Makefile; version bump)

- [ ] 7.1 RED: `plugins/toolkit/hooks/tests/pack-hint.test.sh` (vite hint plus `hints.json`, 31 vs 5 days via `AI_PACK_NOW`, silent: ignored, active, partly active, corrupt `package.json`, newer schema, timeout, missing binary, unknown prefix, `flock` held, two parallel runs give one hint, real repo root silent; `systemMessage` only; PATH fallback); `AI_HOOKS_OFF=pack-hint` case in `hooks-off.test.sh`.
- [ ] 7.2 GREEN: `cmd_hint` in `cmd.sh`; `plugins/toolkit/hooks/pack-hint.sh`; `hooks.json` startup entry `"timeout": 2`.
- [ ] 7.3 GREEN: Makefile `HOOKS` += `pack-hint`; toolkit 0.10.1 to 0.11.0 in `plugins/toolkit/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
- [ ] 7.4 REFACTOR: `make check` and `make mutate`.

## Phase 8: PR 7 Docs

- [ ] 8.1 Create `docs/packs.md` (usage, Chromium/playwright-cli pair, subdirectory behavior from 0.7); README rows and roadmap line. Check: `make check`.

## Phase 9: SHOULD

- [ ] 9.1 Ponytail eval: 3 over-build-tempting cases, with vs without, verdict recorded in `docs/packs.md` or the plan. Check: verdict file exists.
