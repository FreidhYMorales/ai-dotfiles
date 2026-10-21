# Design: Claude Code look and feel

## Technical Approach

Two independent deliverables, per the approved plan (`docs/plans/look-and-feel/plan.md`, not reopened here) and specs `statusline` and `look-band`:

1. `claude/statusline.sh` stays bash: one jq read, bar and color helpers, then segments joined in the new order.
2. `plugins/look/` is a TypeScript mod. Pure logic lives in `hooks/lib/*.ts` and never receives `$`.
   - **Validator rule**: `$` may be passed only to functions declared at the top level of a file, either `register.tsx` itself or a sibling file the module imports. An inner closure that takes `$` as a parameter is rejected. Closures that capture `$` (`onPress`, `$.clock.after` callbacks) are accepted.
   - **Effect code** lives in `hooks/register/*.ts` (`ingest`, `ci`, `backup`, `dismiss`, `timers`, `band`), so `register.tsx` only wires hooks.
   - **Hooks** only record events and schedule work. The render hook reads atoms and calls `buildBand`.
   - **Writes** go through `$.clock.after(0, …)`, an `onPress` handler, or a timer.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|---|---|---|---|
| Runtime for the band | bash command hooks; TS mod | Hooks cannot draw above the prompt | TS mod, an **explicit exception** to config.yaml's "plain bash, no new runtime deps": no other API draws a band, and the plan approved it. The exception covers `plugins/look/` and the CI install only. Nothing at user runtime needs node (the engine runs the mod) |
| Where `$` may go | everything in register.tsx; top-level functions in imported sibling files | One file would outgrow a slice | `hooks/register/*.ts` holds the top-level `$` functions; `lib/` stays pure and is unit-tested directly |
| Agent item id | agentId from the result; `tool_use_id` from the input | agentId arrives only after `next` | Record the running item from `e.tool_use_id` before awaiting `next(e)`. The later notification matches it through `toolUseId` |
| Who owns "known" | separate `known` set; running map | A separate set duplicates state | A notification is ingested only if its `id`/`toolUseId` is in `running` (known and unfinished are the same thing). Expiry or a finish removes the item, so later notifications are ignored |
| Where displayed state lives | module vars; atoms | Module vars go stale (spike) | Everything drawn lives in atoms. Module vars hold only timer handles, in-flight flags and the deferred queue |
| Row model | JSX built inline; pure `BandRow[]` then JSX | Inline JSX cannot be tested without mounting | `buildBand(state, maxRows, bodyColumns, now) -> BandRow[]` (pure); register.tsx maps rows to `Text`/`Button` |
| Version pin | hardcoded in CI and the wrapper; one file | Two copies drift | `plugins/look/tests/claude-code.version` (`2.1.305`) is read by the wrapper and by CI |
| CI skip safety | wrapper always skips without `claude`; env override | A broken install would pass silently | CI sets `LOOK_REQUIRE_CLAUDE=1`; the wrapper then fails instead of skipping |
| Where mod tests run | separate CI step; through `make check` | A separate step behaves differently from local runs | The wrapper is discovered by `run-tests.sh` (`plugins/*.test.sh`), so `make check` is the same gate locally and in CI |

## Data Flow

```
tool.call(Bash, bg) ─┐
agent.spawn(bg) ─────┼─> after(0) ─> running atom ──┐
UserMessage render ──┘   (read props.task, next(e)) │
   └─> queue -> after(0) -> applyTransition ──> running / shellFails / alerts + toast
CI poll (60s|5m) ─> git/gh argv ─> normalizeRollup ─> $.store look:ci:* ─> ci atom
backup poll (5m) ─> fs.read state ─> backupRules ─> alerts
5s tick ─> $.store.keys() filtered by look:dismiss: ─> prune ─> dismissed atom
1s tick (only while running non-empty) ─> now atom; expire shells > 30 min
60s tick (only while agents run) ─> $.agent.list() ─> applyTransition
AbovePrompt render ─> read atoms ─> buildBand ─> JSX | next(e)
```

Timers start from `session.start` and at module load, behind `ensureTimers()` (idempotent). `session.cwd` re-resolves the root and drops CI state for any other root or branch. Error handling works the same way everywhere. `logOnce(tag, err)` (in `register/timers.ts`, backed by a module `Set` of tags) wraps every timer callback, poll and render. The render returns `next(e)` on error.

## File Changes

| File | Action | Description |
|---|---|---|
| `claude/statusline.sh`, `scripts/tests/statusline.test.sh` | Modify | New order, `bar PCT` with 48 steps, 7d meter, budgets, zellij removed |
| `plugins/look/.claude-plugin/plugin.json` | Create | name, version, description, `"types": "./types/index.d.ts"` |
| `plugins/look/hooks/hooks.json` | Create | `modules: ["register.tsx"]`, no command hooks |
| `plugins/look/hooks/register.tsx` | Create | Hook wiring, `/band clear`, JSX |
| `plugins/look/hooks/register/{ingest,ci,backup,dismiss,timers,band}.ts` | Create | Top-level `$` functions |
| `scripts/tests/install.test.sh` | Modify (slice 2) | Expected plugin list at lines 112-113 gains `look@ai-dotfiles` |
| `plugins/look/hooks/lib/{label,status,ci,backup,dismiss,layout,toast,glyphs}.ts` | Create | Pure logic |
| `plugins/look/types/index.d.ts` | Create | Frozen state contract |
| `plugins/look/tests/*.test.ts`, `tests/look.test.sh`, `tests/claude-code.version` | Create | Mod tests, wrapper, pin |
| `.claude-plugin/marketplace.json`, `install.sh` | Modify | `look` entry; `PLUGINS=(flow sdd toolkit look)` |
| `.github/workflows/check.yml` | Modify | pacman `nodejs npm`; `npm i -g @anthropic-ai/claude-code@$(cat …version)` + `install.cjs`; `LOOK_REQUIRE_CLAUDE=1` |
| `upstreams.json` | Modify | `anthropics/claude-code`, releases, reviewed `v2.1.305` |
| `README.md`, `docs/look.md` | Modify/Create | Rows; rules, keys, "last verified" version |

## Interfaces / Contracts

```ts
export type LookItem = { id: string; toolUseId?: string; kind: 'ci'|'agent'|'shell';
  label: string; key?: string /* normalized cmd */; startedAt: number }
export type LookAlert = { source: string /* dismiss source key */; kind: 'ci'|'agent'|'backup'; text: string }
export type LookShellFail = { key: string; label: string; at: number }
export type LookCi = { root: string; branch: string; pr: number; headSha: string;
  state: 'pending'|'ok'|'failed'; failing: string[] }
declare module 'claude-code' { interface PluginState { look: {
  running: Record<string, LookItem>; shellFails: Record<string, LookShellFail>;
  alerts: LookAlert[]; ci: LookCi | null; dismissed: string[]; now: number } } }
```

`$.store` keys:
- `look:dismiss:ci:<root>:<branch>:<pr>:<sha>`, `look:dismiss:backup:<rule>:<time>`, `look:dismiss:agent:<id>`, each storing `{ at }`. Keys older than 30 days are pruned.
- `look:ci:<root>:<branch>`, storing `{ at, pr, headSha, checks }`.

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit (bash) | bar glyphs at 0/1/47/48 steps, colors, order, worst-case length, reset >= 80%, degraded states | `statusline.test.sh` pipes JSON in and checks the output with ANSI codes stripped |
| Unit (TS) | `normalizeCommand`, `mapStatus`, `normalizeRollup`, gh no-PR parse, `backupRules` (each rule plus scan), `prune`, `buildBand` (≤3, >3, `+N more`, truncation), toast merge | `*.test.ts` with `claude-code/testing` `expect`, no `$` |
| Integration | ingestion (unknown id, repeated id, resume), refused render write, reload idempotency, CI flow through `on('process.run')`, backup through `on('fs.read')`, digit Button press, `/band clear` | `$.ui.mount` AbovePrompt, `mock.clock`/`mock.store` (`claude plugin test` has no real store) |
| Integration | 30-minute shell expiry, after which a late notification is ignored | `mock.clock` advanced 30 min, then the notification is raised |
| Integration | 60 s agent fallback: `on('agent.list')` reports `completed` without a notification | `mock.clock` advanced 60 s |
| Integration | error fallback: a throwing poll or render returns `next(e)` and logs once over two failures | Hook that throws; the log count is asserted |
| Manual | dismissal across two panes, eighth blocks in zellij | Recorded in the PR |

## Threat Matrix

| Boundary | Applicability | Design response | RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no file is classified or run | - | - |
| Git repository selection | Applicable | The root is always `git -C <session cwd> rev-parse --show-toplevel`. Later calls use `-C <root>` and `cwd: root`, re-resolved on `session.cwd`. A path with spaces is safe because argv is used, never a shell. No root means no CI | cwd outside a repo; cwd with spaces; cwd change |
| Commit state | N/A: read-only | - | - |
| Push state | N/A: no push | - | - |
| PR commands | Applicable | Argv `['gh','pr','view',branch,'--json',…]`, no shell, 10 s timeout, one call in flight. Detached `HEAD` skips the call. Any failure other than "no pull requests found" yields no CI items and is logged once | detached HEAD; no-PR stderr; non-zero gh; timeout |

Shell commands are only parsed into labels and never run. `=value` is masked.

## Migration / Rollout

No data migration. PR slices, with estimated authored lines (budget 400):

| # | Slice | Est. lines | Split if oversized |
|---|---|---|---|
| 1 | Status line, its tests and README rows | ~280 | - |
| 2 | `look` scaffold: contract, idle register, wrapper, pin, CI, upstreams, `install.test.sh` | ~220 | - |
| 3 | Shells: ingestion, labels, status, shellFails, toasts, expiry, base layout | ~450 (risk) | 3a: `lib/label`, `lib/status`, `lib/layout` with their unit tests. 3b: ingestion, toasts, expiry with integration tests |
| 4 | Agents and dismissals: spawn, 60 s fallback, store keys, hotkeys, `/band clear`, pruning | ~420 (risk) | 4a: agents. 4b: dismissals |
| 5 | CI polling and the shared cache | ~380 | Normalization (pure) before polling |
| 6 | Backup alert | ~220 | - |
| 7 | `docs/look.md` and the manual checks | ~120 | - |

Rollback: revert a slice, or remove `look` from PLUGINS and the marketplace.

## Open Questions

- [x] Store keys with spaces and `/` work. Verified in a real engine: `look:ci:/home/u/My Repo:main` was written and read back. Roots are used raw.
- [x] `$` may be passed to functions imported from the module's own files. Verified: the validator reports `calls: $.store.set (via f)`.
- [ ] Atoms are assumed to survive a hot reload. The reload test confirms or refutes this.
