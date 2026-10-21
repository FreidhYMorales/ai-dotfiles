# Proposal: Claude Code look and feel

Source of truth: `docs/plans/look-and-feel/plan.md` (approved; reviews 1-2 and spikes 1-2 resolved). Decisions there are not reopened here.

## Intent

The screen is noisy where it should be calm and silent where it matters: the status line hides the 7d quota and buries meters behind the place, and background shells, agents, CI and backup failures go unnoticed. v1 shows meters first and adds a band above the prompt that appears only while something runs or failed.

## Scope

### In Scope
- Status line redesign in `claude/statusline.sh`: order `ctx · 5h [↻HH:MM] · 7d · model · repo ⎇ branch[*]`, 6-cell eighth-block bars with dim track, per-meter colors, reset only at >= 80%, length budgets, zellij name removed; tests (order, worst-case length) and README rows.
- New plugin `plugins/look/` (scaffold, marketplace entry, `install.sh` PLUGINS, README row).
- Band mod: background shells (toast + dim failure row), background agents, CI of the current branch's PR, backup alert (backup-status rules + scan.json), shared `$.store` dismissals (digit hotkeys, `/band clear`), merged toasts, error fallback.
- Mod tests via `claude plugin test` + `plugins/look/tests/look.test.sh` wrapper; CI check job installs pinned Claude Code 2.1.305; upstream-watch entry for the pin.
- `docs/look.md`; manual two-pane and zellij checks.

### Out of Scope
- Theme tweaks beyond `dark-ansi`.
- v2 sources (PR review state, engram save failures, upstream news), `/band` history.
- Desktop, VS Code, mobile surfaces; other terminals.

## Capabilities

### New Capabilities
- `statusline`: segment order, bars, colors, reset rule, truncation budgets, degraded states.
- `look-band`: band ingestion, alerts, shell rows, activity layout, dismissals, toasts, polling, mod tests in CI.

### Modified Capabilities
- None (existing `ai-pack-cli`, `pack-manifest`, `pack-hint` are unaffected).

## Approach

- Deliver the status line first: it is independent bash work under the existing test runner.
- Regenerate mod types for the build in use, then build the band as a TypeScript mod: render hook reads only; transitions deferred via `$.clock.after(0)`; known-id ingestion; atoms for everything drawn; idempotent timers.
- Freeze the `$.state` types contract and `$.store` key layout (`look:dismiss:*`, `look:ci:*`) early.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `claude/statusline.sh`, `scripts/tests/statusline.test.sh` | Modified | Redesign |
| `plugins/look/` | New | Band mod, types, tests |
| `.claude-plugin/marketplace.json`, `install.sh` | Modified | Register `look` |
| `.github/workflows/check.yml` | Modified | nodejs/npm, pinned Claude Code, mod tests |
| upstream-watch config | Modified | `anthropics/claude-code` releases |
| `README.md`, `docs/look.md` | Modified/New | Rows and band docs |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Mod API drift (2.1.304 vs 2.1.305, future updates) | Med | CI pin, wrapper version warning, upstream-watch, "last verified" in docs |
| Total work (~7.1 dev-days) exceeds 400-line budget | High | Chained PRs; status line as first slice |
| Stale/re-rendered notifications | Med | Known-id ingestion; resume and reload tests |
| Eighth-block glyphs in zellij | Low | 30-second visual check |
| CI time growth | Low | Keep mod tests fast; measure in check job |
| TypeScript mod and CI nodejs/npm diverge from the config's "plain bash, no new runtime deps" design rule | Med | Plan-approved exception, scoped to `plugins/look/` and CI; design records it |

## Rollback Plan

- Status line: revert its commits; script is self-contained.
- Band: remove `look` from `install.sh` PLUGINS and the marketplace (or disable the plugin); revert the CI job steps. No persisted data beyond `$.store` keys under `~/.claude/plugins/store/look*`, safe to delete.

## Dependencies

- Claude Code 2.1.305 (mod API), `gh` authenticated (optional), engram-backup state files (optional), Nerd Font set A.

## Success Criteria

- [ ] Status line tests assert meters-before-place order and worst-case length; `make check` passes.
- [ ] Idle session draws nothing above the prompt.
- [ ] Mod tests pass in CI on the pinned version.
- [ ] A dismissal in one pane clears the alert in another (manual check).
