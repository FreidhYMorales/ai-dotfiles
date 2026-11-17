# Story 05: a red final suite in /flow:pair becomes a regression round

## Story

05. As a developer, I want a red final suite in /flow:pair to become a regression round so that late regressions get fixed without breaking Strict TDD. Requires: #04

## Acceptance criteria

- [ ] Given the step-6 full run red on tests the story did not add, when `/flow:pair` handles it, then it runs a regression round: for each failing existing test it shows that test's output (no `test:` commit, no red marker), commits one `fix:`, reruns that test file, and logs the `fix:` in the story `## Log` naming the test it turns green; then the `Test command:` runs again under story 04's repeat rule.
- [ ] Given a regression round, when fixing it needs an existing test changed, skipped or deleted, then pair stops on stop rule 3; when the `Test command:` is still red after the round, then pair stops on stop rule 4.
- [ ] Given the flow plugin bumped and `./install.sh` run, when a new session loads `/flow:pair` and the verifier (Claude, and the generated OpenCode and Antigravity copies), then pair carries the round inside step 6, the verifier's check 3 accepts a regression-round `fix:` with no new `test:` commit only when the story `## Log` names the existing test it turns green, and the affected pair and verifier evals pass.

## Plan

- Pair's step 6 gains the regression round after the final full run, pointing at stop rules 3 and 4 and at story 04's repeat rule; step numbers and the step-6 verifier sentence stay word for word, so the generator's patterns keep matching.
- The verifier's check 3 gets one line for the regression-round `fix:`; its pinned Hard Rules stay untouched.
- Goldens regenerated, with the generator test as the focused test of the skill steps; the affected pair and verifier evals run once each, results logged.
- Release: bump flow, run `./install.sh`, check criterion 3 in a new session.

## Out of scope

- Mode B or per-cycle full runs; any retry loop beyond stop rule 4.
- `toolkit:ship`, `delegate-local`, docs and templates, OpenCode's agent rule, `NOTCH` (stories 06-11).
- Changing story 04's focused-test loop or its full-run dedup rule.

## Suggestions (your call)

- No current eval exercises a regression-round `fix:` (the verifier evals are `verifier-passes-good-story` and `verifier-catches-tampered-test`). A new verifier eval case would make criterion 3 graded instead of read; it costs one more paid run.

## Size

normal
Risk: item 5, 6 (flow plugin release and install; skill and verifier wording graded only by paid evals)

## Log

- L1 request: /flow:story 05
- Assumptions: the plan's `/flow:pair` row (regression round) and the verifier's check-3 line are the whole story, as story 04 left them out. "A test the story did not add" means a test not on the story's approved test list. The flow bump is a minor version (0.12.0). "Evals budgeted" means each affected eval runs once, as in story 04; no new eval case unless you take the suggestion.
- L2 approved (2026-11-17): as proposed, no new eval case.
