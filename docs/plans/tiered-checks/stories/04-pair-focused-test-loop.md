# Story 04: /flow:pair loops on the focused test and runs the full suite once

## Story

04. As a developer, I want /flow:pair to loop on the focused test and run the full suite once on the final tree so that TDD does not wait on the suite at every step.

## Acceptance criteria

- [ ] Given a backlog with a `Single test:`, when `/flow:pair` runs a red, green or refactor step (including each step of "do N"), then only the focused test runs; the `Test command:` runs on the final tree with the long-run wording ("allow up to 10 minutes (Claude: Bash `timeout` 600000)", or run in the background and read the result), and again after any step-6 fix, before the verifier's recheck and before the merge offer; given no `Single test:` or `Single test: none`, every step runs the `Test command:` as today.
- [ ] Given a green full run recorded at a `HEAD`, when pair reaches a later point that asks for the full run, then it reruns only if the tree is dirty or `git diff --name-only <sha>` lists anything besides the story file and the backlog; the `docs:` close commit does not force a rerun, and the verifier's own run counts only when its report shows the command and its pass line.
- [ ] Given the flow plugin bumped and `./install.sh` run, when a new session loads `/flow:pair` and the verifier (Claude, and the generated OpenCode and Antigravity copies), then they carry the new rules, the verifier has the long-run wording as a new line under its checks, and the pair evals pass, with `pair-empty-verifier-report` re-graded.

## Plan

- Pair's step 4 points red, green, refactor and "do N" at the focused test, with the `Test command:` fallback; step 6 gains the final full run, its repeat points and the dedup rule. Step numbers and the step-6 verifier sentence stay word for word, so the generator's patterns keep matching; if either must change, the generator patterns change here and the renumbering pre-approves the change to the generator test's step pin.
- The verifier gets the long-run wording as one new line under its checks, outside its pinned Hard Rules.
- Goldens regenerated, with the generator test as the focused test of the skill steps; the affected pair evals updated and run once each, `pair-empty-verifier-report` re-graded, results logged.
- Release: bump flow, relax the exact flow pin in the no-sdd test to `at_least` (pre-approved in story 01), run `./install.sh`, check criterion 3 in a new session.

## Out of scope

- The regression round for a red final suite and the verifier's check-3 line about regression `fix:` commits (story 05).
- `toolkit:ship`, `delegate-local`, docs and templates, OpenCode's agent rule, `NOTCH` (stories 06-11).
- Any per-change test selection or background suite runner.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 5, 6 (flow plugin release and install; skill wording graded only by paid evals)

## Log

- L1 request: /flow:story 04
- Assumptions: the plan's `/flow:pair` row is split along the backlog: story 04 takes everything except the regression round and the verifier's check-3 line, which go to story 05. The flow bump is a minor version (0.11.0). "Evals budgeted" means each affected pair eval runs once, not the whole flow suite.
