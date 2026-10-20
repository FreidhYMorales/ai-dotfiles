# Apply progress: opt-in-packs

Mode: Strict TDD. Chain strategy: stacked-to-main. Branch: `feat/ai-pack-core`.

## Batch 1: PR 1 core (unit 1)

Completed: 1.1, 1.2, 1.3, 1.4, 1.5. Remaining: Phases 0, 2-9 (not in this batch).

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 1.1 | `scripts/tests/ai-pack-core.test.sh` | Integration (black box) + sourced unit | N/A (new) | Written; ran with no `bin/ai-pack`: 38 FAIL, 10 PASS (negative assertions only) | 48/48 pass | 8 key cases, 2 missing deps, 3 schema cases, 5 `version_ge`, 9 hash cases, ignore round trip | shellcheck fixes (SC2015, SC2016); `make check` green |
| 1.2 | same | Integration | N/A (new) | covered by 1.1 | pass | key, deps, usage errors | clean |
| 1.3 | same | Integration | N/A (new) | covered by 1.1 | pass | newer, older, corrupt schema; lock held and free | `lock_wait`/`lock_try` split into explicit steps |
| 1.4 | same | Unit + integration | N/A (new) | covered by 1.1 | pass | empty dir, one file (documented line format), umask 022/077, exec bit, link, `.gitignore` rules | clean |
| 1.5 | same | `make check` | 19 existing test files pass | n/a | 7/7 steps pass | n/a | n/a |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test | `bash scripts/tests/ai-pack-core.test.sh`: exit 0, 48 PASS, 0 FAIL |
| Runtime harness | Temp HOME: `ai-pack hash .` printed `sha256:...`; `ignore x` and `unignore x` ran from a non-git dir and reported the cwd key |
| Rollback boundary | `bin/ai-pack`, `packs/lib/{common,state,tree,cmd}.sh`, `scripts/tests/ai-pack-core.test.sh` |

### Deviations from design

- `cmd.sh` carries only `hash`, `ignore`, `unignore` here (as tasks.md 1.4 says); the other commands land in later PRs.
- `AI_PACK_LOCK_WAIT` (default 30) is an extra test seam so the held-lock test does not wait 30 s.
- `tree_hash` does not call `normalize_modes` (the hash uses only the owner exec bit, so it is mode independent; normalization stays for the staging step in PR 2a).
- `project_key` also unsets `GIT_COMMON_DIR` (besides `GIT_DIR` and `GIT_WORK_TREE`).
- The default state dir honors `XDG_STATE_HOME` (documented in the `bin/ai-pack` help text).
- Tree hash lines keep the `./` path prefix; design.md now says so.
- Corrective round: `tree_hash` reads the owner exec bit from the mode (`stat -c %a`) instead of `[[ -x ]]`; the test now isolates git (temp HOME, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM=1`). The 654 vs 644 case cannot fail as a non-root user (RED not observable here); it guards root and foreign-owner runs.
- `tasks.md` header: chain strategy set to stacked-to-main, PR 5 `size:exception` marked resolved.

## Batch 2: PR 2a skill add from vendored sources (unit 2a)

Branch: `feat/ai-pack-skill-add`. Completed: 2.1, 2.2, 2.3, 2.4. Remaining: Phases 0, 3-9.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 2.1 | `scripts/tests/ai-pack-skill.test.sh` | Integration (black box, fixture manifest + tiny vendor dirs) | core test 48/48 | committed failing: 22 FAIL | n/a | n/a | n/a |
| 2.2 | same | Integration | n/a | covered by 2.1 | `tree.sh` stage_new/clean_stages, `plan.sh` | new/noop/replace/adopt/skip/refuse, rollback of a replace via exchange | shellcheck SC2034 fix |
| 2.3 | same | Integration | n/a | covered by 2.1 | `cmd_add`, EXIT/INT/TERM traps, journal after move | two worktrees, preflight, foreign, adoption, re-sync, edited, rollback, stale stage | clean |
| 2.4 | same | `make check` | all pass | n/a | 36/36 pass, 7/7 steps | n/a | n/a |

### Deviations from design

- Rollback is an EXIT trap (plus `trap 'exit 130' INT TERM` so signals run it) instead of `trap undo_run INT TERM`; one path covers `die`, signals and normal failure. The signal path is not covered by a test.
- Vendor dir is `$(dirname $AI_PACK_MANIFEST)/vendor`; `vendor:` sources only, no template, `kind: skill` only (others die with "supported yet"; PR 2b/4 extend `load_plan`).
- Required commands and their min versions are checked before the lock; stale-stage cleanup and classification run under it.
- An edited journaled dir keeps its old journal entry and is skipped; the rest of the pack still installs.

### Batch 2 corrective round (gatekeeper findings)

- HIGH fixed: `classify` now treats any file in an installed dir that is not in the journal (besides the top-level `.gitignore`) as a hand edit: warn and skip, so a user-added file is never swapped out. RED: extra-file tests failed (same-version re-add and version bump) before the fix.
- LOW fixed: dirs created by the run (`.claude`, `.claude/skills`, ...) are tracked (`mkdir_tracked`) and removed on failure if still empty, after stages are cleaned. Rollback test now asserts `.claude` is gone.
- LOW fixed: new TERM test runs `add` in its own process group against a vendor dir holding a fifo (hashing the staged copy blocks), sends TERM mid-run, and asserts non-zero exit, no `.claude`, no state.
- Cosmetic: usage column alignment in `bin/ai-pack`.
- Evidence: RED commit ad96847 (7 FAIL); GREEN 45 PASS, 0 FAIL; `make check` 7/7.

## Batch 3: PR 2b fetched sources, template, shadow, list (unit 2b)

Branch: `feat/ai-pack-sources-list`. Completed: 3.1, 3.2, 3.3, 3.4. Remaining: Phases 0, 4-9.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 3.1 | `scripts/tests/ai-pack-skill.test.sh` | Integration (curl stub on PATH, fixture manifest) | 45/45 | committed failing (a8cfd4d): 17 FAIL | n/a | n/a | n/a |
| 3.2 | same | Integration | n/a | covered by 3.1 | `sources.sh` `fetch_verified`, `tree.sh` `render_template` | checksum mismatch, curl exit 6, two projects render identically | n/a |
| 3.3 | same | Integration | n/a | covered by 3.1 | `plan.sh` shadow scan, `cmd_list` | dir name, frontmatter name, nested personal skill, depth-6 plugin cache, drift, machine version, via, missing, adoptable, 70 columns, no state change | n/a |
| 3.4 | same | `make check` | all pass | n/a | 75/75 pass x3, 7/7 steps | n/a | `tool_dirs` shared by `load_plan` and `list` |

### Deviations from design

- `list` shows the current project only, so "skip projects whose root is gone" is satisfied trivially: other projects are never read; the test seeds a dead-root entry and asserts it is neither shown nor dropped.
- Shadow match uses the dir name and the frontmatter name of the vendored SKILL.md (copy) against both the dir name and frontmatter name of each candidate.
- Fetch happens in `load_plan` (before any project write) into a `mktemp -d` removed by the EXIT trap; the fetched file is named after the tool, the marker uses `source.name`.
- `list` output uses the plan glyphs (check, dot, warning) and truncates every line to 70 characters.

### Batch 3 corrective round (gatekeeper findings)

- Security: `fetch_verified` refuses any URL not starting with `https://` before calling curl and passes `--proto '=https' --proto-redir '=https'`. RED: http:// and file:// manifests were fetched (test commit "cover https-only fetch...", 8 FAIL then 9 with the UTF-8 case).
- `list` truncation is character-safe in any locale (`cut70`: substring cut under `LC_ALL=C.UTF-8`, then trailing partial bytes dropped if the locale is missing). RED: invalid UTF-8 under `LC_ALL=C` with a non-ASCII shadow path (fixture needs an odd byte offset to trigger the cut mid-character).
- `list` tool-name column is sized to the longest tool name (cap 24); the test checks that the mark column is aligned with a 21-character tool name.
- Test width checks now measure characters with `LC_ALL=C.UTF-8` so they hold under the C locale too.
- Evidence: targeted test 88 PASS, 0 FAIL, three runs each in the default locale and `LC_ALL=C`; `make check` 7/7.

## Batch 4: PR 3 remove and purge for skills (unit 3)

Branch: `feat/ai-pack-remove`. Completed: 4.1, 4.2, 4.3. Remaining: Phases 0, 5-9.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 4.1 | `scripts/tests/ai-pack-skill.test.sh` | Integration (fixture manifest with a leftover and an extra pack, machine.json fixture) | 88/88 | committed failing (4684c0d): 37 FAIL | n/a | n/a | n/a |
| 4.2 | same | Integration | n/a | covered by 4.1 | `packs/lib/remove.sh` (`cmd_remove`, `remove_dir`), `remove` wired in `bin/ai-pack` | clean remove, edited file, user-added file, leftover, hand-removed dir/file, shared by pack, by name, direct, lock held, refusal, dead roots, plain remove refcount | SC1007 fix |
| 4.3 | same | `make check` | all pass | n/a | targeted 3 runs pass (default x2, `LC_ALL=C` x1), 7/7 steps | n/a | n/a |

### Deviations from design

- New file `packs/lib/remove.sh` instead of growing `cmd.sh`.
- "delete <path> to re-add" prints the dir (re-adding needs the dir gone); the warning names the offending file.
- `--purge` also refuses when another pack in this project still needs the tool (this project then counts as a user). In this PR purge only deletes the `machine.json` entry; prefix and bin-link removal lands with npm in PR 4.
- A journaled file already missing is treated as removed, so a rerun after a crash is quiet.
- Empty parents (`.claude/skills`, `.claude`) are not removed.

### Batch 4 corrective round (gatekeeper findings)

- Medium B fixed: journaled file paths must start with the tool dir, contain no `..`, and their resolved parent must stay under the dir; otherwise warn and keep the dir.
- Medium E fixed: `remove` requires `realpath "$PROJ/$rel" == "$PROJ/$rel"` (no symlinked component). `add` now refuses (`inside_project`, before any write) when a target dir resolves outside the project, e.g. a stow-managed `.claude` or `.claude/skills`.
- Low fixed: journal dirs must be non-empty, not `.`, relative, and declared in the manifest `project_dirs`; others are ignored with a warning.
- Low fixed: a `.gitignore` that is not exactly `*` (or is a symlink) counts as a hand edit and keeps the dir.
- Low fixed (deviation 6 withdrawn): `add` journals the parent dirs it created (`projects.<key>.created`); the last `remove` rmdirs them only if still empty.
- Evidence: RED commit shows 15 FAIL (symlinked-subdir case already held because the extra-file scan catches it). GREEN: 170 PASS, 0 FAIL, three runs (default x2, `LC_ALL=C` x1); `make check` 7/7.

## Batch 5: PR 4 kind npm, machine layer (unit 4)

Branch: `feat/ai-pack-npm`. Completed: 5.1, 5.2, 5.3, 5.4. Remaining: Phases 0, 6-9.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 5.1 | `scripts/tests/ai-pack-npm.test.sh` | Integration (npm/node/chromium stubs, fixture npm package and manifest) | skill test 170/170 | committed failing (12d6b50): 27 FAIL, 39 PASS | n/a | n/a | n/a |
| 5.2 | same | Integration | n/a | covered by 5.1 | `sources.sh` (`npm_pack_verified`, `npm_install_prefix`, `link_set`, `link_switch`), new `machine.sh`, `plan.sh` and `cmd_add` wiring | add, re-add noop, integrity mismatch, install failure (fresh and upgrade), rollback after the machine layer, foreign file and symlink at the bin path, missing requires, implicit npm, upgrade A/B | shellcheck SC2034/SC2015, shfmt `-i 2 -ci` |
| 5.3 | same | Integration | n/a | covered by 5.1 | `npm_purge` called from `cmd_remove` | live-user refusal, all prefixes and link removed, relinked bin kept, unrecorded prefix kept | n/a |
| 5.4 | same | `make check` | all pass | n/a | 66 PASS, 0 FAIL, three locale runs; skill test passes; 7/7 steps | n/a | n/a |

### Deviations from design

- New file `packs/lib/machine.sh` (preflight, apply, record, purge); `link_switch` stays in `sources.sh`.
- `NPM_ROOT` and `BIN_DIR` are set in `bin/ai-pack`; bin link target is `<prefix>/node_modules/.bin/<bin>`; manifest `bins` is an array of names.
- A bin path is allowed only if journaled in `machine.json` and still a symlink into `NPM_ROOT/<tool>@*`; otherwise refused before any write.
- An existing unrecorded prefix is refused, never deleted. Removals go through `npm_owned` (basename `<tool>@<ver>[.staging]`, parent is `NPM_ROOT`, not a symlink).
- No `npm pack` when the version is already recorded and its prefix exists.
- `machine.json` is written after the link switch and project moves, before the project journal; the restart notice prints only when a previous `current` differs.
- Implicit `npm` requirement added in `check_requires` for kind npm. Fixture uses `fix-chromium` so a real chromium on a dev box cannot mask the test.
- Journal version for npm tools is `source.version`.
- Size: 450 insertions vs main (code 168, tests 282); over the 400 budget by test volume. `link_switch` was not split out.

### Batch 5 corrective round (gatekeeper findings)

- Low fixed (rollback window): `cmd_add` now writes `projects.json` (`commit_journal`) before `machine.json` (`machine_record`), so a failed journal write leaves `machine.json` unchanged while undo removes the new prefix and restores the old link. RED (test commit "cover machine.json staying unchanged..."): 1 FAIL ("machine.json not written"). The failure is forced with a `projects.json` of `schema_version` 99 (state_write refuses it), not with permissions, so it also holds as root in CI.
- Low fixed (docs): design.md now names `XDG_DATA_HOME` / `XDG_BIN_HOME` instead of `AI_PACK_DATA` / `AI_PACK_BIN`, and states the commit order. Disclosed deviation: the code never had `AI_PACK_DATA` / `AI_PACK_BIN` seams; tests isolate through `HOME` instead.
- Info (keep for PR 7 docs): npm transitive dependencies (for Playwright, `playwright` and `playwright-core`) are integrity-checked by npm itself against the registry metadata, but they are not pinned in the manifest. Only the top-level tarball is pinned (sha512).
