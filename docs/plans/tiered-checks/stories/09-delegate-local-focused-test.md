# Story 09: delegate-local hands the worker the focused test

## Story

09. As a developer using local workers, I want delegate-local to hand the worker the focused test and rerun the full suite after applying so that workers start fast without weakening the safeguard.

## Acceptance criteria

- [ ] Given a delegated task in a repo whose backlog has a `Single test:` line, when Claude writes the worker prompt, then the command the worker must pass is that focused test filled in for the task (the `Test command:` when there is no `Single test:` or it is `none`; `make check` when there is no backlog), never the full suite.
- [ ] Given the worker's diff applied to the real repo, when Claude verifies it, then Claude reruns the full `Test command:` (or `make check`) once on the applied tree, with the long-run wording, and reports the change as rejected or fixes it itself when that run is red; pi still runs once per task, with no retry that feeds back the failure.
- [ ] Given the change, when I run `make check` and read the generated OpenCode copy of the skill, then it matches the new text, the `toolkit` plugin is bumped and installed with `./install.sh`, and `make check` is green.

## Plan

- The prompt step names where the worker's command comes from: the backlog's `Single test:`, with the same fallback chain `/flow:pair` uses.
- The independent check in the worker clone stays (rerun the focused test, diff the tests, mutate to confirm new tests bite).
- The apply step names the full `Test command:` as the one full run, after applying and before reporting, with the long-run wording `ship` and `pair` use.
- Goldens regenerated, `bash scripts/tests/gen-agents.test.sh` as the focused test; `toolkit` bumped and reinstalled.

## Out of scope

- A worker retry with the failure tail, or any loop around pi (plan "Superseded").
- Changing the delegation table, the default model, `pi-box` or the bench.
- Lifting the skill's DRAFT status or its explicit-use-only activation.
- The evals `delegate-local-explicit` and `delegate-local-no-fire`: they grade firing, not the commands.
- The slow-test report (10) and OpenCode's rule (11).
- Antigravity: the user will not use it, so no criterion checks its copy; its golden is regenerated only because the generator and `gen-agents.test.sh` still produce and pin it. Dropping Antigravity from the generator is a separate idea.

## Suggestions (your call)

- Hard Rule "If it fails twice, do the task yourself" reads like a second run is allowed; one clause saying the second run is a new task, not a retry that feeds back the failure, would keep it from contradicting criterion 2.

## Size

normal
Risk: item 6 (skill prompt wording; no test would catch a worker given the wrong command or a skipped full run)

## Log

- L1 request: /flow:story 09
- Assumptions: plan row "`delegate-local`" (SHOULD, 0.25) and finding 2 are the whole story and fit 3 criteria. Today `SKILL.md:51` asks for "the exact command that must pass" with no source, and `:56` already runs `make check` after applying; this story names the `Single test:` / `Test command:` source for both. Hard Rule `:20` ("fails twice") stays: a separate run, not a retry loop. No test pins the skill text beyond the goldens (`gen-agents.test.sh`) and the two evals, which grade firing only. `toolkit` is at 0.19.0, so the bump is 0.20.0. The plan calls for a verifier (finding 12).
- L2 approved (2026-11-17): with Antigravity removed from criterion 3 (the user will not use it; OpenCode stays).
