# Apply progress: look-and-feel

## PR 1: Status line (tasks 1.1-1.3) - done

Mode: Strict TDD. Branch: feat/look-statusline.

### TDD Cycle Evidence

| Task | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| 1.1 | 21 new cases failed against the old script (`bash scripts/tests/statusline.test.sh`: "21 case(s) failed") | - | - |
| 1.2 | - | same file: "All cases passed" | - |
| 1.3 | - | `make check`: All checks passed (7 steps) | helpers split into `color`, `bar`, `meter`, `trunc`; README rows updated |

Safety net: 22 pre-existing cases passed before edits.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test | `bash scripts/tests/statusline.test.sh` exit 0, all cases passed |
| Runtime harness | JSON piped into `claude/statusline.sh`, worst case 6-char model: 94 + place visible chars (test budget 110) |
| Rollback boundary | `claude/statusline.sh`, `scripts/tests/statusline.test.sh`, README rows 19 and 115 |

### Notes

- Worst case measured ~106 columns with a 4-char model, over the plan ~100. The test budget is 110. Branch cap 20 excludes the dirty `*`.
- Eighth-block glyphs still need the 30-second zellij look (task 7.2).

## Task 0 and PR 2: Scaffold, CI, pin (tasks 0.1, 2.1-2.4) - done

Mode: Strict TDD. Branch: feat/look-scaffold (stacked-to-main, PR 1 already merged). Claude Code 2.1.305 installed, equal to the pin.

### TDD Cycle Evidence

| Task | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| 2.1 | `scripts/tests/look-wrapper.test.sh`: 7 cases failed, wrapper and pin file missing. `claude plugin test plugins/look`: "no hooks module to load". `install.test.sh`: FAIL "all plugins are installed" (expects `look@ai-dotfiles`) | - | - |
| 2.2 | - | wrapper test: "All cases passed" (13); `claude plugin validate`: passed; `claude plugin test`: 1 pass 0 fail; install.test.sh no FAIL | wrapper made bash-only (no `dirname`, tests caught it under a stub PATH); engine types dir gitignored |
| 2.3 | - | `actionlint .github/workflows/check.yml` exit 0; `npm view @anthropic-ai/claude-code@2.1.305` exists, postinstall is `node install.cjs` | - |
| 2.4 | - | `make check`: All checks passed (7 steps) | - |

Task 0.1: `claude plugin validate|test` run fine. Headless `claude -p --plugin-dir plugins/look` does NOT lay `.claude-plugin/types/` (the docs say only hot-reloaded sessions do), so nothing generated exists locally; `tsc` is not installed. Type-checking falls back to the 2.1.304 declaration file when needed; `plugins/*/.claude-plugin/types/` is gitignored at the repo root.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test | `bash plugins/look/tests/look.test.sh` exit 0 (validate passed, 1 test passed); `bash scripts/tests/look-wrapper.test.sh` all 13 cases passed |
| Runtime harness | `claude plugin test` on the idle mod (AbovePrompt mount, engine drawing passes through). Also run under `unshare -rn` (no network) with a temp HOME: passes, so validate/test need no auth or model call |
| Rollback boundary | `plugins/look/`, `scripts/tests/look-wrapper.test.sh`, marketplace entry, `install.sh` PLUGINS, `install.test.sh` line 113, `.gitignore`, check.yml steps, upstreams entry |

### Stop hook timing (task 2.4, for the PR body)

`make check` is what the require-check Stop hook runs. hyperfine, 3 runs each, same machine:

| | mean | min | max |
|---|---|---|---|
| before (main + PR 1) | 1.3 min (± 0.2) | 1.1 min | 1.4 min |
| after (this PR) | 1.4 min (± 0.1) | 1.3 min | 1.4 min |

The look wrapper alone takes about 1.1 s (1155, 1083, 1131 ms); it runs in parallel with the other test files, so the difference is within run-to-run noise.

### Deviations and notes

- `tests/idle.test.tsx`, not `.ts`: the test returns JSX, and a `.ts` file fails to load (Syntax Error).
- Added `scripts/tests/look-wrapper.test.sh` (not in the task list) so the wrapper's SKIP / require / version-warning behavior has its own RED/GREEN, using stub `claude` binaries on a restricted PATH.
- The wrapper also runs `claude plugin validate` before `claude plugin test`, and isolates HOME and XDG dirs in a temp dir.
- The contract `types/index.d.ts` declares only `PluginState.look` (no `$` noun); `validate` reports "declares on $: nothing" which is expected.
- `plugin.json` carries `author` and `license: MIT` to match the other plugins; `validate` also warns about a missing icon and README (plugin-directory checks, not enforced).
- CI install path (`npm install -g` + `install.cjs`) was verified only by the npm registry check and actionlint; it first runs in the PR's CI.
- Installed plugin order in `install.test.sh` is sorted: `flow look sdd toolkit`.

## PR 3a: Pure lib (tasks 3a.1-3a.3) - done

### TDD Cycle Evidence

| Task | RED | GREEN | REFACTOR |
|---|---|---|---|
| 3a.1 / 3a.2 | `bash plugins/look/tests/look.test.sh`: 3 fail ("cannot import ../hooks/lib/{label,glyphs,status}: no such file"), 1 pass | same command: 17 pass, 0 fail | Cut `Look` to the fields `buildBand` reads; `label` reuses `truncate` from `layout`. No behavior change |
| 3a.3 | n/a | `make check`: All checks passed (7 steps) | |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test | `bash plugins/look/tests/look.test.sh` (validate passed, 17 tests) |
| Runtime harness | N/A: pure functions |
| Rollback boundary | `plugins/look/hooks/lib/{label,status,layout,glyphs}.ts`, `plugins/look/tests/{label,status,layout}.test.ts` |

### Deviations and notes

- `layout.ts` declares a structural `Look` type (the fields `buildBand` reads) instead of importing `PluginState` from the ambient module, so the file loads in tests without the generated types. `PluginState['look']` is assignable to it.
- `shellLabel(description, key, max)` and `truncate`, `formatElapsed` are extra exports (the design lists only `buildBand`).
- `=value` is masked as `=*`. String width: one column per code point (Nerd Font PUA is one column; wide CJK/emoji unmeasured), documented in `truncate`.
- Alert rows reserve 6 more columns for the `[n ✕]` button drawn by register. Alerts, shell-failure rows and activity share the `maxRows` budget, in that order; the overflow folds into one `+N more` row (a joined activity line counts its items).
- Hotkeys are the 1-based index among non-dismissed alerts, omitted past 9.

## PR 3b: Shell ingestion, toasts, expiry (tasks 3b.1-3b.3) - done

### TDD Cycle Evidence

| Task | RED | GREEN | REFACTOR |
|---|---|---|---|
| 3b.1 / 3b.2 | `bash plugins/look/tests/look.test.sh`: 9 fail, 17 pass (new `tests/ingest.test.tsx` against the idle register: no toast, no row, no tick) | same command: 24 pass, 0 fail (the 9 became 7 after merging overlapping tests) | Tests merged (unknown/repeated id, tick/reload); atoms declared per file; `Tone` aligned with `mapStatus` (`failed`) |
| 3b.3 | n/a | `make check`: All checks passed (7 steps) | |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test | `bash plugins/look/tests/look.test.sh` (validate passed, 24 tests) |
| Runtime harness | `$.ui.mount` of `AbovePrompt` and `UserMessage` with `mock.clock` |
| Rollback boundary | `plugins/look/hooks/register/{ingest,timers,band}.ts(x)`, `hooks/lib/toast.ts`, `hooks/register.tsx`, `tests/ingest.test.tsx` |

### Open question 3 (atoms survive a hot reload): settled by documentation, not by a test

- `claude plugin test` loads the plugin once and offers no reload, so no test can re-run `register`. The reference (types, `$.state`) states that named values are "held by the host for the session, plain data that survives a hot reload of the plugin's code", and `atom` has a `shape` option for "a reload of the plugin's code" that finds the value absent. So atoms do survive; nothing needs rework.
- What the test does prove: the state is the host's (read from outside the module via `state.set`), a second and third `session.start` leave exactly one 1 s tick, and `syncTick` on `session.start` rebuilds the tick from the atoms, which is the reload path (module variables, including the timer handle, are lost on a reload; the engine drops the old timers).
- Not verified in a real interactive session; add it to the PR 7 manual checks.

### Deviations and notes

- `register/band.tsx`, not `.ts`: it returns JSX. The test is `ingest.test.tsx`, not `.ts`, for the same reason.
- No `register/state.ts`: the validator reads an atom only where it is declared in the same file, so `ingest`, `timers` and `band` each declare the few atoms they use (same keys and initials).
- Toasts have no color in the API (`ToastOptions` is only `timeoutMs`): the tone is the glyph (`✓`/`✕`/`⋯`). A toast within 2 s of the batch start replaces the plugin's own previous toast with a count line (`✓ 2 done`); the first one shows at once.
- A test cannot make a hook beneath the plugin throw or poison a read (a thrown hook is skipped, a `state.get` answer is ignored), so the render-error test calls `renderBand` with a fake `$` whose `state.get` rejects.
- `session.start` is the only timer entry: `register` has no `$`, so there is no "at module load" start. `syncTick` is idempotent and also runs after every start and finish.
- Validator note: `tool.call` is listed as a "gating hook without .catch"; the hook never denies, so no `.catch` was added.

