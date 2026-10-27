# Story 04: flow:verifier

## Story

04. As a developer, I want a story that names a high-risk item to get a fresh read-only verifier so that risky changes get a second look and small ones do not. Requires: #03

## Acceptance criteria

- [x] Given a high-risk story whose tests are green on its branch, when `flow:verifier` checks it, then I get a verdict per acceptance criterion (pass/fail with evidence), a check that each test commit came before its code commit and the test files did not change afterwards, the security checklist when the story names item 2, and no file is changed.
- [x] Given the verifier reports a failure, when pair applies one correction batch and the verifier rechecks, then a second failure ends with "needs your decision" instead of another round.
- [x] Given a story with `Risk: none`, when pair finishes it, then the verifier is not called.

## Plan

- A new read-only agent in the flow plugin, briefed with the story file, the branch diff against `main` and the references already in `pair/references/`.
- Its report has a fixed shape pair can read: one row per criterion, the commit-order and tamper check, the security checklist when it applies, and a final verdict.
- pair's check step calls it only when the `Risk:` line names an item, with one correction batch and one recheck, then hands the decision to the user.
- A structural test pins the agent's contract and the bound in pair; evals cover a passing story, a tampered test and a `Risk: none` story.

## Out of scope

- Replacing `toolkit:judgment-day` (it stays as an explicit dual review).
- Running the verifier on every story or on size alone.
- Fixing code itself: the verifier only reports.
- Porting the agent to OpenCode/Antigravity (`multi-agent-port`).

## Suggestions (your call)

- Reuse the shape of `plugins/flow/agents/plan-reviewer.md` (frontmatter, Hard Rules, fixed output) so both agents read alike. (Done.)
- pair should show the verifier's `Verdict:` line verbatim instead of paraphrasing it (eval run 2 dropped it).
- The read-only rule is text only: with Bash the agent could still write, same as `plan-reviewer`.
- Neither the tests nor the story pin whether a converted value is an int or a float (seen by the verifier in the clean eval); worth a criterion in real projects.

## Size

normal
Risk: item 3 (pair parses the verifier's verdict), item 6 (the agent's behaviour is graded by paid evals)

## Log

- L1 request: `/flow:story 04` (after the user said "listo, ya reinicie y actualice").
- L2 assumptions for approval: the agent is `plugins/flow/agents/verifier.md` with tools Read, Grep, Glob, Bash and read-only by rule (plan R1.15); the verdict is PASS / FAIL / NEEDS DECISION; evals call the agent through the Agent tool if the eval runner allows it, else through a pair prompt that reaches the check step.
- L3 approved by the user ("si").
- L4 test list approved (4 structural tests, 2 acceptance evals); the `Risk: none` eval dropped in favour of a structural test (pair cannot run git in the eval sandbox).
- L5 cycles (mode C, then "do 3"): 3e91612→226eab0 agent and inputs; 6165fa5→d334e83 checks and fixed report; 6a88eea→d3e5ade one correction batch then NEEDS DECISION; 5136ff5→245965e `Risk: none` skips the verifier. 245965e was committed while `make check` was red (shellcheck SC2016 in the test, a chaining mistake); fixed in b070f97 with comment-only directives (user approved touching the committed test); later commits gate on `make check`.
- L6 verifier (general-purpose agent following `verifier.md`, since the new agent loads only after a restart): Verdict: PASS on C1-C3, commit order, tamper check and assertions.
- L7 eval run 1: Agent tool works in evals. Real defect: reference paths only existed in this repo. Cycle 1a2b7cd→c2a7344: pair passes absolute reference paths, the agent falls back to `${CLAUDE_PLUGIN_ROOT}`. The clean case cannot reach PASS without a shell, so its grader accepts PASS or NEEDS DECISION but never FAIL (2e277a6, user approved).
- L8 eval results: `verifier-passes-good-story` with 1.00, without 0.25 (Δ +0.75, $0.84); `verifier-catches-tampered-test` with 0.89, without 0.00 (Δ +0.89, $0.83): tamper named in 3/3 runs, the main session paraphrased the verdict line in one. Accepted by the user. Story eval spend ≈ $3.29.
- L9 Risk: item 3, item 6.
