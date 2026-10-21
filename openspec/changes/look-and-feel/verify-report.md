# Verify report: look-and-feel

Mode: openspec, Strict TDD. Date 2026-10-20. Claude Code installed 2.1.306 (pin 2.1.305; the wrapper warns, tests still run).

## Verdict: FAIL (1 CRITICAL, 5 WARNING, 4 SUGGESTION)

The only CRITICAL is a scenario with no covering test (Survey). The behavior is one line in `band.tsx` and is fixed by one test; everything else passes.

## Completeness

All tasks checked (0.1, 1.x to 7.x). Task 7.2 was the only open one; the manual evidence (below) satisfies its text (dismissal across two panes + 30-second zellij look at the bars), so it is now marked done.

## Execution evidence

| Command | Result |
|---|---|
| `make check` | exit 0, "All checks passed (7 steps)", 1:14 |
| `bash plugins/look/tests/look.test.sh` | 72 pass, 0 fail, 11 files; plugin validate passed |
| `bash scripts/tests/statusline.test.sh` | 34 PASS, "All cases passed" |
| `bash scripts/tests/look-wrapper.test.sh` | 13 PASS (SKIP, require, version warning) |
| `claude plugin validate plugins/look` | "Validation passed" (directory-only warnings) |

No coverage tool or linter configured for the mod (skipped, not a failure).

## TDD compliance

Apply-progress has a TDD Cycle Evidence table for every slice (1, 2, 3a, 3b, 4a, 4b, 5, 6) with RED then GREEN counts; all referenced test files exist and pass now. PR 7 is docs-only (no test needed). Triangulation adequate (multiple cases per rule: bars at 0/1/42/47/48, colors 49/50/79/80, cache 59999/60001/299999/300001 ms). Safety net recorded for PR 1; the other slices were new files.

## Assertion quality

No tautologies, no ghost loops. Heavy use of `toBeDefined()` / `toBeUndefined()` on `band($, regex)` lookups: the regex is the value assertion, so acceptable. Tests are integration-level (mounted band, mock clock) plus pure unit tests; no mock-count assertions.

## Spec compliance (27 requirements, 49 scenarios)

| Spec | Requirements | Scenarios compliant | Partial | Untested |
|---|---|---|---|---|
| statusline | 9 | 15/15 | 0 | 0 |
| look-band | 18 | 31/34 | 2 | 1 |

Statusline: every scenario maps to a passing case in `scripts/tests/statusline.test.sh` (order, 0%, 42%, 1/47/48 steps, colors 49/50/79/80, reset 80/79, 7d, model strip, `*`, truncation 15+`…`/19+`…`, worst case, no git, no rate_limits, one quota missing, no zellij) and `make check` (gate).

Look-band mapping (test file): Idle `idle.test.tsx`; Error fallback `ingest.test.tsx` (throwing render); Deferred write, unknown/repeated id, expiry, killed, merge, tick `ingest.test.tsx`; Failure then pass `ingest.test.tsx`; Mapping `status.test.ts`; CI alerts, polling, fresh/stale, no PR (60 s), gh missing, detached, branch switch, recovery `ci-poll.test.tsx` + `ci.test.ts`; Backup (stale, scan, not configured, clear) `backup*.test.ts(x)`; Agents (failed, resume, vanished, 60 s) `agent.test.tsx`; Layout (3 items, overflow) `layout.test.ts`; Dismissal (hotkey, cross-session, re-raise, prune, `/band clear`) `dismiss.test.tsx`; Mod tests in CI (no claude, version mismatch) `scripts/tests/look-wrapper.test.sh`.

Non-compliant or partial scenarios:

- Survey (yield while `hasSurvey`): UNTESTED. Code at `plugins/look/hooks/register/band.tsx:19`; every test passes `hasSurvey: false`.
- Hot reload: PARTIAL. The test runs `session.start` repeatedly and checks one tick; the atoms-survive-reload assumption rests on the docs and was not verified in a live session (manual box still open in `docs/look.md`).
- Different commands (two rows): PARTIAL. `label.test.ts` proves the keys differ; no test asserts two separate rows in the band.

## Manual evidence (2026-10-20, Claude Code 2.1.305, two zellij panes, in docs/look.md)

Status line bars OK; background shell running line and done toast; failed shell dim row removed by a later pass; `/band clear`; backup alert in both panes (temporary edit, restored); cross-pane dismissal with the other pane idle within ~5 s; digit hotkey `1` on empty composer; live CI item "CI #28" within a minute and cleared after green. Not live: hot reload; a real PR with failing CI (covered by `ci-poll.test.tsx`).

Task 7.2 verdict: sufficient. Done.

## Design coherence

Matches, with documented deviations: agent code lives in `register/ingest.ts` not `timers.ts` (circular import); `register/band.tsx` / `.tsx` test files (JSX); no `session.cwd` event, root re-resolved per poll plus `CwdChanged`; no module-load timer start (no `$`), so `session.start` is the only entry; CI glyph U+F407; "no open PR" cache is 60 s (PR #28, spec and docs updated; test present). Accepted by the user: vanished agent stops after 2 missed polls; `/band clear` also clears shell-failure rows; status line worst case ~106 columns vs "about 100" (test budget 110; the test run printed 108 for its worst case).

## Issues

CRITICAL
1. Scenario "Survey" (look-band, Idle and yielding) has no covering test. Add a case mounting the band with an alert and `hasSurvey: true` and assert it yields (`next(e)`).

WARNING
1. Requirement clause "collapsed band (ctrl+x ctrl+a) keeps alerts hidden" has no code, scenario or test. It relies on the host not rendering `AbovePrompt` when collapsed (plan: "user intent"). Not verified live.
2. Hot reload (atoms survive, no double tick after reload) not verified live; documentation-only assumption.
3. "Different commands" has no band-level assertion of two rows.
4. Status line worst case exceeds the spec's "about 100" (~106 to 108 columns); accepted by the user, but the spec text still says 100.
5. `docs/look.md` manual checklist is stale: "Real PR CI" is unchecked although the live CI #28 item was observed (the failing-CI half was not). Split that line before archive.

SUGGESTION
1. Spec text for `/band clear`, 60 s no-PR cache and vanished agent should be synced to the delta specs at archive (code and docs already follow the final behavior).
2. Pin is 2.1.305 while 2.1.306 is installed; consider a pin bump after a run.
3. `docs/look.md` notes toasts do not merge when notifications arrive on separate turns; consider noting this in the spec's Toasts scenario.
4. The Alert row uses the fail glyph for all kinds (documented); backup/CI glyphs could differentiate later.
