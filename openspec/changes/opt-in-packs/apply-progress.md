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
