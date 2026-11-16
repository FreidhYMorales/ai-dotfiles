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
- L2 branch: `story/04-pair-focused-test-loop` from `main` (afec9d4 story commit). Safety net green before any change: `flow-pair`, `flow-verifier`, `gen-agents`, `no-sdd`.
- L3 test list approved as proposed (9 items, item 9 manual).
- L4 steps: ccb78ab → 503ca68 (green, refactor and "do N" on the focused test); 3b67b95 → 4d084c0 (focused test defined, `Test command:` fallback); 54b125c → 50a936f (final full run with long-run wording and its repeat points); 1467c88 → a41d0be (a green full run repeats only after a change); b80f84b → 7c3cfd4 (verifier long-run line under its checks); d201918 (generated-pair pin, green at once since the goldens were regenerated in each feat; its 4 cases fail on the ccb78ab tree); 097fba1 → da51db6 (flow 0.11.0; the exact flow pin in `no-sdd.test.sh` relaxed to `at_least 0.11.0`, pre-approved in story 01). Goldens regenerated in each pair and verifier feat commit; step numbers and the step-6 verifier sentence unchanged, so `gen.sh` patterns untouched. `make check` "All checks passed (8 steps)" after every green step.
- L5 evals (claude plugin eval, one run of each case): `pair-stops-on-test-change` with 1.00 / without 0.00 ($0.85); `pair-empty-verifier-report` re-graded, with 1.00 / without 1.00 ($0.65), graders unchanged; `pair-proposes-test-list` with 0.83 / without 0.00 ($0.78): one with-run lost `branch-name` because the sandbox has no shell and the model stopped before step 2 (its test list still passed). Step 2 is untouched by this story.
- L6 release: `./install.sh` run from this branch; `claude plugin list` shows flow 0.11.0 read from the working copy.
- L7 manual (C3, user, 2026-11-16): a new Claude Code session ran `/flow:pair 02` in the worktree `DOTFILES IA-story-02`; its first step went red (ea8cf4e) to green (cda8afe) within the same minute, rerunning only `scripts/tests/checks.test.sh` and no `make check` before the `feat:` commit, so the new step 4 was loaded. Installed copies checked by content: `~/.config/opencode/skills/flow-pair/SKILL.md` and `~/.gemini/antigravity-cli/skills/flow-pair/SKILL.md` carry "rerun the focused test until green" and "once on the final tree"; `~/.config/opencode/agents/flow-verifier.md` carries the long-run line (Antigravity has no verifier, #38).
- L8 full run: last green `make check` at da51db6; since then only the story file changed, so no rerun before the verifier (the new dedup rule).
