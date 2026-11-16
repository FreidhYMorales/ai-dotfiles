---
name: pair
description: "Explicit use only: /flow:pair NN. Build ONE refined story in Strict TDD steps on branch story/NN-<slug>: approved test list, then test commit (red, shown) before code commit (green), stopping on the stop rules, and offering a --no-ff merge when done. Not for planning or backlog work."
disable-model-invocation: true
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
  adapted-from: "nschurmann/hola-ai skills/pair (MIT)"
---

## Activation Contract

Run only when the user types `/flow:pair NN`. You drive (write tests and code), the user navigates (approves the test list, says continue or stop). One story per run. Not for planning (`/flow:plan`), backlog work (`/flow:backlog`) or refining a story (`/flow:story`).

## Hard Rules

- Talk to the user in their language; commits, story files and engram entries are in English.
- **No production code without a failing test you ran and showed.** Follow `references/strict-tdd.md`.
- **Expected values come from the acceptance criteria**, never computed with the code under test.
- Stage named paths only: never `git add -A` or `git add .`. Never `--no-verify`, never bypass a git hook.
- Before each code commit run `git diff <test-commit> -- <test files>`; it must be empty (tamper check). Never edit a committed test to reach green.
- Unlike hola-ai, pair commits by itself: the committed red test is the tamper evidence. Each `test:` commit and its `feat:`/`fix:` commit form one work unit; never squash them.
- Do only what the story asks; anything else goes in the final summary as a suggestion.
- Push only after green and only if the user asks. Never squash or rebase-merge.
- Ignore old engram topics `sdd/*` and `sdd-init/*`.

## Decision Gates

| Situation | Action |
|---|---|
| No story file for NN, and NN is not a chat-only story (small + `Risk: none`) | Stop; suggest `/flow:story NN` |
| Backlog `## Context` has no `Test command:` | Stop: "no runnable test"; suggest `/flow:backlog` to detect it |
| Story `Risk:` names any high-risk item | Mode C only; verifier after green |
| Story is small and `Risk: none` | Mode B allowed; mode C still the default |
| Step delegated to a local model | Mode C, always |
| Any stop rule fires | Stop (below), even mid-batch |

**Stop rules** (checked every step, both modes):

1. A design decision is needed that the story or plan does not settle.
2. Something unrequested would be added, even if it looks reasonable.
3. An existing test would change, be skipped or be deleted.
4. Green not reached after two failed attempts.
5. A step over ~50 lines or 3 files: propose a smaller step.
6. A git hook rejects a commit (red commits included): report its output.

**Before stopping:** commit bookkeeping (story `## Log`) by named paths only; leave uncommitted code as is and report it with `git status --short`; end with the reason and "your call".

## Execution Steps

1. **Read.** `docs/plans/<feature>/backlog.md`: story line NN, `## Context` (`Test command:`, `Single test:`); `stories/NN-<slug>.md` (or the chat-only story); `references/high-risk.md`. Check the plan against the current code; mismatch → stop. The focused test is the `Single test:` command, or the `Test command:` when the backlog has no `Single test:` or it is `none`.
2. **Start.** Delete a stale red marker: `rm -f "$(git rev-parse --git-path flow-pair-red)"`. Create or switch to branch `story/NN-<slug>` (from `main` unless the story `Requires:` an unmerged branch; then ask).
3. **Test list.** Propose names and level only (unit, integration, e2e; highest practical level), mapped to each criterion; visual criteria marked **manual**. Write nothing; wait for approval. The approved list is the spec.
4. **Mode C step** (default), one test from the list:
   1. Write the test; run it with the focused test and show the real failing output (red for the right reason).
   2. Commit `test(<scope>): <behaviour>` (named paths), then write the marker: `printf '%s\n%s\n' "$(git branch --show-current)" "$(git rev-parse HEAD)" >"$(git rev-parse --git-path flow-pair-red)"`. `require-check` then reports the red state instead of blocking.
   3. Minimal code to pass; rerun the focused test until green; the `Test command:` waits for step 6.
   4. Tamper check, remove the marker, commit `feat|fix(<scope>): <outcome>`.
   5. Optional `refactor(<scope>): …` while green; the focused test reruns after it.
   6. Short status, then ask: `✅ "<test>" passes. <one line> (<file:line>). Decided: <call or none>. Continue with "<next test>"?`
   "do N" runs N full steps (test → code → green each on the focused test), never N tests then the code.
5. **Mode B** (only when the story is small and `Risk: none`): run step 4 cycles back to back until the list is done or a stop rule fires; same commits; one summary at the end with the `Risk:` line.
6. **Check.** All tests green; run the `Test command:` once on the final tree (allow up to 10 minutes (Claude: Bash `timeout` 600000), or run it in the background and read the result) and it passes; run it again after any step-6 fix, before the verifier's recheck and before the merge offer. Walk the manual criteria with the user. High-risk story (any item): invoke the `flow:verifier` agent on the story diff, passing the story ID, the plan folder and the absolute paths of `references/strict-tdd.md` and `references/high-risk.md` (this skill's base directory); if it is not available, say so and recommend `/toolkit:judgment-day`. Before every verifier run, save `git for-each-ref` and `git rev-parse HEAD`, and compare them after it: any difference is NEEDS DECISION whatever the verdict says; name the refs that moved and repair nothing. On `FAIL`, apply one correction batch (each fix as its own red→green step), then ask for one recheck; a second FAIL ends with NEEDS DECISION: stop and show both reports. `NEEDS DECISION` from the verifier goes straight to the user; so does an empty report or one with no `Verdict:` line: that is NEEDS DECISION, never PASS, and the story stays open. `Risk: none`: no verifier, whatever the size.
7. **Done.** In the backlog set the line to `[x] <sha>` (sha = last code commit); append to the story `## Log` the evidence (commits, test output tail, verifier result; for skill stories the `make eval` result) and the `Risk:` line; commit `docs(<scope>): close story NN` with named paths. Save one engram summary (topic `story/<feature>/NN`).
8. **Merge.** Offer `git merge --no-ff story/NN-<slug>` into `main`; run it only after the user's OK.

## Example

Story 02, criterion "Given an empty cart, when I add one item, then the total is its price":

```
Test list (approve?):
1. adds one item: total equals its price (unit)
2. totals render on the cart page (manual)
red  → AssertionError: expected 0 to equal 1250      test(cart): total one item
green → 6 passed                                      feat(cart): total a single item
```

## Output Contract

- Branch `story/NN-<slug>` with `test:` → `feat|fix:` (→ `refactor:`) commits per step and a final `docs:` commit.
- Backlog line `[x] <sha>`; story `## Log` with evidence and the `Risk:` line.
- No red marker left behind after green or at the end.
- Final message: tests and commits, `Risk:` line, verifier result if high risk, manual checks, suggestions, then the merge offer.

## References

- `references/strict-tdd.md`: the three laws, test layer, banned assertions, triangulation.
- `references/high-risk.md`: the six high-risk items and the `Risk:` line.
- `toolkit:work-unit-commits`: the `/flow:pair` exception for `test:` + `feat:` commits.
- Adapted from hola-ai `pair` (github.com/nschurmann/hola-ai, MIT).
