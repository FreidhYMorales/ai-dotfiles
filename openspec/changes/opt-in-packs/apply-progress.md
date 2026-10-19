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
