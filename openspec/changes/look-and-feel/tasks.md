# Tasks: Claude Code look and feel

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~2,300 (PR1 280, PR2 220, PR3a 220, PR3b 230, PR4a 210, PR4b 210, PR5 380, PR6 220, PR7 120) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 > 2 > 3a > 3b > 4a > 4b > 5 > 6 > 7 |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Status line | PR 1 | `bash scripts/tests/statusline.test.sh` | pipe sample JSON into `claude/statusline.sh` | statusline.sh, its test, README rows |
| 2 | look scaffold, CI, pin | PR 2 | `bash plugins/look/tests/look.test.sh` | `claude plugin test` on idle mod | `plugins/look/`, marketplace, install.sh, workflow, upstreams |
| 3a | Pure lib: label, status, layout | PR 3a | `claude plugin test` (lib tests) | N/A: pure functions | `hooks/lib/{label,status,layout}.ts` + tests |
| 3b | Shell ingestion, toasts, expiry | PR 3b | `claude plugin test` (ingest tests) | mounted AbovePrompt with mock.clock | `register/{ingest,timers}.ts`, `lib/toast.ts` |
| 4a | Agents | PR 4a | `claude plugin test` (agent tests) | mock `agent.list` | agent code in ingest/timers |
| 4b | Dismissals | PR 4b | `claude plugin test` (dismiss tests) | mock.store, Button press | `register/dismiss.ts`, `lib/dismiss.ts` |
| 5 | CI polling | PR 5 | `claude plugin test` (ci tests) | `on('process.run')` mock | `register/ci.ts`, `lib/ci.ts` |
| 6 | Backup alert | PR 6 | `claude plugin test` (backup tests) | `on('fs.read')` mock | `register/backup.ts`, `lib/backup.ts` |
| 7 | Docs, manual checks | PR 7 | `make check` | two panes, zellij | `docs/look.md`, README rows |

## PR 1: Status line (bash; independent of Task 0)

- [x] 1.1 RED: in `scripts/tests/statusline.test.sh` add failing cases: order, bar at 0/1/47/48 steps, 49/50/79/80 colors, reset at >=80%, 7d, model strip, `*`, truncation 16/20, worst-case length, no git, no rate_limits, 7d missing, no zellij.
- [x] 1.2 GREEN: rewrite `claude/statusline.sh` (one jq read, `bar PCT`, new order, zellij removed).
- [x] 1.3 REFACTOR: tidy helpers. Update README rows. Check: `make check`.

## Task 0: Mod prerequisites (before any mod code; PR 1 does not need it)

- [x] 0.1 Load `plugin-authoring`; confirm the engine lays the editor types for the build in use into `plugins/look/.claude-plugin/types/` (gitignored, never committed); `plugins/look/types/` holds only the contract. Headless `claude -p` does not lay them, so tsc falls back to the 2.1.304 file.

## PR 2: Scaffold, CI, pin

- [x] 2.1 RED: `plugins/look/tests/look.test.sh` (SKIP without claude, `LOOK_REQUIRE_CLAUDE=1` fails, version warning) and an idle-render `tests/idle.test.tsx` (JSX needs .tsx). Edit `scripts/tests/install.test.sh` lines 112-113 to expect `look@ai-dotfiles`.
- [x] 2.2 GREEN: create `plugin.json`, `hooks/hooks.json`, idle `register.tsx`, `types/index.d.ts` (contract), `tests/claude-code.version` (2.1.305). Edit `.claude-plugin/marketplace.json`, `install.sh`.
- [x] 2.3 GREEN: `.github/workflows/check.yml` (nodejs npm, pinned install, `LOOK_REQUIRE_CLAUDE=1`), `upstreams.json`.
- [x] 2.4 Measure the require-check Stop hook time; record in the PR. Check: `make check`.

## PR 3a: Pure lib

- [x] 3a.1 RED: `tests/{label,status,layout}.test.ts`: `normalizeCommand` (cd/VAR prefix, 3 words, `=value` masked), `mapStatus` (completed/failed/killed/weird), `buildBand` (<=3 one line, >3 rows, maxRows, `+N more`, truncation).
- [x] 3a.2 GREEN: `hooks/lib/{label,status,layout,glyphs}.ts`.
- [x] 3a.3 REFACTOR. Check: `claude plugin test`.

## PR 3b: Shell ingestion, toasts, expiry

- [x] 3b.1 RED: `tests/ingest.test.ts`: unknown id, repeated id/resume, refused render write, failure row then pass removal, killed dim toast, 30-min expiry then late notification ignored, toast merge in 2 s, idle 1 s tick, reload idempotency, throwing render logs once.
- [x] 3b.2 GREEN: `register/{ingest,timers,band}.ts`, `lib/toast.ts`, wire `register.tsx`.
- [x] 3b.3 REFACTOR. Check: `claude plugin test`.

## PR 4a: Agents

- [x] 4a.1 RED: `tests/agent.test.ts`: spawn adds item by `tool_use_id`, failed alert persists, resume creates no alert, 60 s `agent.list` fallback.
- [x] 4a.2 GREEN: agent paths in `register/{ingest,timers}.ts`. REFACTOR. Check: `claude plugin test`.

## PR 4b: Dismissals

- [x] 4b.1 RED: `tests/dismiss.test.ts`: `prune` 30 days, digit hotkey writes key, cross-session 5 s tick, re-raise on new key, `/band clear`.
- [x] 4b.2 GREEN: `lib/dismiss.ts`, `register/dismiss.ts`, Buttons in `register.tsx`. REFACTOR. Check: `claude plugin test`.

## PR 5: CI polling

- [x] 5.1 RED: `tests/ci.test.ts`: `normalizeRollup` (CheckRun, StatusContext), no-PR stderr, detached HEAD, gh missing/non-zero/timeout, cwd outside repo, cwd with spaces, cwd change, branch switch drops alert, recovery, fresh vs stale cache (60 s/5 min), no overlap.
- [x] 5.2 GREEN: `lib/ci.ts` first, then `register/ci.ts` polling. REFACTOR. Check: `claude plugin test`.

## PR 6: Backup alert

- [ ] 6.1 RED: `tests/backup.test.ts`: each `backupRules` rule, blocked scan, stale backup, not configured, clears on ok.
- [ ] 6.2 GREEN: `lib/backup.ts`, `register/backup.ts` (5 min). REFACTOR. Check: `claude plugin test`.

## PR 7: Docs and manual checks

- [ ] 7.1 Create `docs/look.md` (rules, keys, last verified version); README row.
- [ ] 7.2 Manual: dismissal across two panes; 30-second zellij look at status line bars. Record both in the PR. Check: `make check`.
