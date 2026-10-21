# Archive report: look-and-feel

**Closed**: 2026-10-20
**Archived to**: `openspec/changes/archive/2026-10-20-look-and-feel/`
**Store mode**: openspec (no Engram observation IDs; artifacts are the files listed below)
**Status**: closed. Verify verdict PASS WITH WARNINGS (0 CRITICAL). All 24 tasks in `tasks.md` are checked. No stale-checkbox reconciliation was needed.

## Final state at close

This section describes the state at close. Where it differs from `verify-report.md`, `apply-progress.md` or the delta specs, this section wins. Those files are intermediate snapshots.

- Status line worst case is about 106 to 108 columns. The delta spec said "about 100"; the user accepted the wider budget.
- `/band clear` dismisses all alerts, clears running items and clears shell-failure rows.
- CI cache: an entry is fresh for 60 s when checks are pending or there is no open PR (`pr: 0`), and for 5 min otherwise (PR #28).
- Agent fallback: an agent absent from `$.agent.list()` on 2 consecutive polls finishes as stopped (dim toast, no alert). An agent listed with an ended status finishes with that status.
- Toast merge applies only to ends drawn within 2 s. Claude delivers task notifications one per turn, so near-simultaneous ends usually give two toasts. This is documented behaviour, not a defect.
- There is no `session.cwd` event. The CI root is re-resolved on each poll, and `classic.CwdChanged` schedules a poll.
- Verify verdict at verification time: PASS WITH WARNINGS (re-verified after the earlier CRITICAL was resolved by the survey test and the different-commands test). Source: `verify-report.md`, which is a snapshot.

## What shipped

Pull requests #19 to #29, merged to `main`. The change covers:

- Status line: `claude/statusline.sh` rewritten (one jq read, eighth-block bars, new segment order, 7d meter, zellij removed), with its test and README rows.
- Look mod: `plugins/look/` scaffold, idle render, `plugin.json`, `hooks/hooks.json`, types contract, marketplace and install wiring, pinned Claude Code version (2.1.305), and the `look.test.sh` wrapper.
- Band: pure lib (`label`, `status`, `layout`, `glyphs`), shell ingestion, toasts, expiry, agents, dismissals, CI polling with the shared cache, and the backup alert.
- Docs: `docs/look.md` (rules, keys, pinned version, manual checklist) and README rows.
- CI: the check job runs the mod tests via `claude plugin test` with `LOOK_REQUIRE_CLAUDE=1`.

## Main specs synced

Both capabilities are new, so both were created (ADDED):

- `openspec/specs/statusline/spec.md`
- `openspec/specs/look-band/spec.md`

Method: the delta specs were copied verbatim with `cp`, and the readback was an empty `diff -r`. The final-state facts above were then folded in by targeted edits. The `# Delta for ...` title became `# <capability>`, and the `## ADDED Requirements` wrapper was removed, as in the `opt-in-packs` archive. The edits are:

- statusline: "Length budget and right truncation" (about 106 to 108 columns).
- look-band: "Shell expiry" (`/band clear` scope, new "Clear" scenario); "CI alerts" (no `session.cwd`); "CI polling and shared cache" (60 s / 5 min rule, PR #28); "Agent alerts" (2-poll fallback and ended status); "Toasts" (merge scope, new "Separate turns" scenario).

## Open warnings (not closed)

These come from `verify-report.md` (WARNING level). They are not blocking under the Verification Gate.

1. Collapsed band (ctrl+x ctrl+a) keeps alerts hidden. This relies on host behaviour (the host does not render `AbovePrompt` when collapsed). It has no code, scenario or test, and it was not verified live. The requirement text in the Idle and yielding section is kept as written.
2. Hot reload: the assumption that atoms survive a reload and that no double tick occurs was not verified in a live session. The test only runs `session.start` repeatedly. The manual check remains open in `docs/look.md`.
3. A real pull request with failing CI was not checked live. It is covered by `ci-poll.test.tsx`.

## Manual checks done

From `verify-report.md` (manual section, at verification time):

- Status line bars rendered correctly.
- Background shell running line and its done toast.
- Failed shell dim row, removed by a later passing run.
- `/band clear`.
- Backup alert shown in both panes (temporary edit, restored).
- Cross-pane dismissal, with the other pane idle, cleared within about 5 s.
- Digit hotkey `1` on an empty composer.
- Live CI item "CI #28" shown within a minute and cleared after green.

Not done live: hot reload, and a real PR with failing CI.

## Traceability

- Source artifacts (archived with this report): `proposal.md`, `design.md`, `specs/statusline/spec.md`, `specs/look-band/spec.md`, `tasks.md`, `apply-progress.md`, `verify-report.md`, `state.yaml`.
- Main specs created by this archive: `openspec/specs/statusline/spec.md`, `openspec/specs/look-band/spec.md`.
- `tasks.md` was not edited during archive.
