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
- L3 branch: `story/05-pair-regression-round` from `main` (e95cefa story commit). Safety net green before any change: `flow-pair`, `flow-verifier`, `gen-agents`, `no-sdd`. Test list approved as proposed (8 items, item 8 manual).
- L4 steps: e0694d8 → 201a0c5 (regression round in step 6); 52c6c39 → e4b6f2b (full run again after the round); 279f59a → 9e1f343 (stop rules 3 and 4 in the round); a106bf6 (generated pair pin, green at once since the goldens were regenerated in each feat; its 4 cases fail on the e95cefa tree); 838c733 → a4c0578 (verifier check 3 accepts a logged regression-round fix); 486301f → 94ae6eb (flow 0.12.0; new `at_least 0.12.0` asserts beside the untouched 0.11.0 ones). Step numbers and the step-6 verifier sentence unchanged, so `gen.sh` patterns untouched.
- L5 evals (claude plugin eval, one run of each case, $3.94): `pair-stops-on-test-change` with 1.00 / without 0.00; `pair-empty-verifier-report` re-graded, with 1.00 / without 1.00; `pair-proposes-test-list` with 1.00 / without 0.00; `verifier-passes-good-story` with 0.67 / without 0.25 (below threshold); `verifier-catches-tampered-test` with 0.78 / without 0.00 (below threshold). The failing verifier reports say its sandbox session had no shell (only Read, Grep, Glob), so it could not run the `Test command:` or `git diff`; none mentions the new check-3 line, and neither case holds a regression-round `fix:`. Same cause and range as audit-fixes 24 L4 (0.89 / 0.75 on 2026-11-05).
- L6 user decision (2026-11-17): C3 evals accepted; the two verifier cases stay below threshold for the known no-shell sandbox, not rerun.
- L7 manual (C3, user, 2026-11-17): a new Claude Code session, asked what step 6 of `/flow:pair` does on a red final `Test command:`, described the regression round from `SKILL.md:64` (output shown, no `test:` commit or red marker, one `fix:` per test, rerun the file, `## Log` names the test, full run again under the repeat rule) and stop rules 3 and 4, and named the verifier check-3 change (a4c0578). Installed copies checked by content: `~/.config/opencode/skills/flow-pair/SKILL.md` and `~/.gemini/antigravity-cli/skills/flow-pair/SKILL.md` carry the round; `~/.config/opencode/agents/flow-verifier.md` carries the check-3 line; `claude plugin list` shows flow 0.12.0 read from the working copy.
- L8 full run: `make check` "All checks passed (8 steps)" at e62423f; since then only the story file changed.
