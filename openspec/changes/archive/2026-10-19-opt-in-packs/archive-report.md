# Archive report: opt-in-packs

**Closed**: 2026-10-19
**Archived to**: `openspec/changes/archive/2026-10-19-opt-in-packs/`
**Store mode**: openspec (no Engram observation IDs; artifacts are the files listed below)
**Status**: closed as intentional-with-warnings. Task 9.1 (SHOULD, Ponytail eval) is still open and was deliberately deferred to v2 by the maintainer. Its checkbox is left unchecked on purpose; it is not stale.

## Final state at close

This section describes the state at close. Where it differs from `verify-report.md` or `apply-progress.md`, this section wins. Those two files are intermediate snapshots.

- All 8 implementation PRs are merged, plus 3 fix PRs. `make check` passes all 7 steps on `main`, and CI is green.
- The verify verdict at verification time was PASS WITH WARNINGS, with 0 CRITICAL, 5 WARNING and 3 SUGGESTION. All of them were fixed in PR #11, except the open 9.1 task.
- Phase 0: tasks 0.1 to 0.7 are checked. 0.5 was confirmed by the maintainer in a real session. 0.6 does not apply to the maintainer's setup (Claude is only started from a terminal). The PATH-less fallback was simulated in Phase 0 and is covered by `pack-hint.test.sh`.

## What shipped

- Packs: `web` (Playwright CLI, Chromium from the system, design skills, vendored taste-skill and archify) and `diagrams`.
- Kinds: `skill` (vendored or fetched with a pinned sha256 and checked against a tree hash) and `npm` (machine layer with pinned tarball sha512, refcounted shared tools, purge rules).
- `ai-pack` CLI in `bin/ai-pack` with `packs/lib/` (`cmd`, `plan`, `tree`, `sources`, `machine`, `remove`) and manifest `packs/packs.json`.
- `pack-hint` SessionStart hook (`plugins/toolkit/hooks/pack-hint.sh`, registered in `hooks.json`): a thin systemMessage hint, silent on failure, opt-out supported, 30-day cadence.
- Docs: opt-in packs guide, README row for `bin/ai-pack` and the `pack-hint` hook, roadmap entry.

## Pull requests

| PR | Role |
|---|---|
| #1 | Implementation: core (unit 1) |
| #3 | Implementation: skill add from vendored sources (unit 2a) |
| #5 | Implementation: fetched sources, template, shadow, list (unit 2b) |
| #6 | Implementation: remove and purge for skills (unit 3) |
| #7 | Implementation: kind npm, machine layer (unit 4) |
| #8 | Implementation: real manifest and vendored trees (unit 5) |
| #9 | Implementation: startup hint (unit 6) |
| #10 | Implementation: docs (unit 7) |
| #2 | Fix: hook stdin socket |
| #4 | Fix: CI check job on `archlinux:latest` |
| #11 | Fix: verify findings (restart notice, spec and plan amended for vendored MIT rules, characterization tests, Phase 0 closed) |

## Final test suites

`make check` on `main` runs 7 steps, and all pass (run at archive time, `set -o pipefail`). The packs-related suites are:

- `scripts/tests/ai-pack-core.test.sh`
- `scripts/tests/ai-pack-skill.test.sh`
- `scripts/tests/ai-pack-npm.test.sh`
- `scripts/tests/ai-pack-manifest.test.sh`
- `plugins/toolkit/hooks/tests/pack-hint.test.sh`
- `plugins/toolkit/hooks/tests/hooks-off.test.sh`
- `plugins/toolkit/hooks/tests/stdin-socket.test.sh`

Test counts from `apply-progress.md` were per-batch snapshots and are not repeated here. Current pass/fail comes from the `make check` run.

## Specs synced

Main specs were created under `openspec/specs/` because none existed for these capabilities:

- `openspec/specs/pack-manifest/spec.md`
- `openspec/specs/ai-pack-cli/spec.md`
- `openspec/specs/pack-hint/spec.md`

Requirements and scenarios are copied as-is, including the dated 2026-10-19 amendment note in `pack-manifest`. The only change is the delta wrapper: the `# Delta for <capability>` title became `# <capability>`, and the `## ADDED Requirements` header and its blank line were removed. The archived delta under `specs/` is unchanged.

## Deviations (summary)

Source: plan section "Post-implementation changes" (this section wins over the plan's original decisions) and `apply-progress.md` deviation notes.

- web-design-guidelines rules: were fetched at add time from a pinned commit. Now vendored as `packs/vendor/web-design-guidelines/rules.md` with the upstream MIT LICENSE (commit 4ecfb9f). Upstream added a LICENSE in 2025-09, so `add` needs no network for this tool.
- archify vendored tree: `examples/*.html` (11.9 MB) left out. Documented in `packs/vendor/README.md`.
- taste project dir: `.claude/skills/design-taste-frontend`, not `.claude/skills/taste`, because Claude lists project skills by directory name and the frontmatter name is `design-taste-frontend`.
- `pack-hint` timeout: `PACK_HINT_TIMEOUT` widens the internal cut. The hook `timeout` stays at 2. Slow CI runners made the test flaky.
- CI image: the check job moved from `ubuntu-24.04` to `archlinux:latest`. Ubuntu 24.04 ships coreutils 9.4, which has no `mv --exchange`.
- Post-change notice: `add` prints "restart Claude in this project" when a tool writes outside `.claude/skills/`, otherwise "run /reload-plugins". Found by verify.
- Code never had `AI_PACK_DATA` or `AI_PACK_BIN` seams. Tests isolate through `HOME`. design.md now names `XDG_DATA_HOME` and `XDG_BIN_HOME`.
- `tree_hash` does not call `normalize_modes`. The hash uses only the owner exec bit, so it is mode independent.
- Message wording for the hint is `<signal> detected: ai-pack add <pack> (ai-pack ignore <pack>)`, 51 characters. The 70-column budget did not fit the plan's "package.json + vite" prefix.

## Deferred to v2

- Task 9.1: Ponytail eval (3 over-build-tempting cases, with and without, verdict recorded). SHOULD, not started. Listed in the README roadmap and in the plan's "Deferred to v2".
- `bigcode` pack (codebase-memory-mcp, kinds `binary` and `mcp`).
- Brand `DESIGN.md` (taste-skill and web-design-guidelines cover v1).
- Ponytail adoption, only if the eval shows less code without losing input handling.
- Kind `plugin`, since no v1 tool needs it after vendoring taste-skill.
- More packs (data, mobile, infra), when a real project needs one.
- `ai-pack doctor` and `prune`. `list` shows drift, and `--purge` already drops dead roots.

## Lessons learned

- The validator found data loss on re-sync (hand edits and user-added files must be kept, not swapped out).
- Journal paths allowed escapes through symlinks and `..`. Fixed by requiring the tool dir prefix, no `..`, a resolved parent under the dir, and no symlinked component in `remove`.
- `mv --exchange` needs `-T` and coreutils >= 9.5. Ubuntu 24.04 is too old, which is why CI moved to Arch.
- Socket stdin in the hook broke the stdin-socket case. Fixed in PR #2.
- Parallel test load on CI made timing-based hint tests flaky. The cut is now configurable.
- Arch CI image was missing `diffutils`, which the tests need.
- Write the failing test first in each batch (Strict TDD). The RED evidence in `apply-progress.md` caught real defects, including http and file URLs being fetched and a `hint` that exited 1 when `curl` was missing.

## Traceability

- Source artifacts (openspec mode, archived with this report): `proposal.md`, `design.md`, `specs/` (3 delta files), `tasks.md`, `apply-progress.md`, `verify-report.md`.
- Plan: `docs/plans/packs/plan.md`, status line updated to "shipped".
- Open task at close: 9.1 (see above). `tasks.md` was not edited during archive.
