# Story 04: flow:verifier

## Story

04. As a developer, I want a story that names a high-risk item to get a fresh read-only verifier so that risky changes get a second look and small ones do not. Requires: #03

## Acceptance criteria

- [ ] Given a high-risk story whose tests are green on its branch, when `flow:verifier` checks it, then I get a verdict per acceptance criterion (pass/fail with evidence), a check that each test commit came before its code commit and the test files did not change afterwards, the security checklist when the story names item 2, and no file is changed.
- [ ] Given the verifier reports a failure, when pair applies one correction batch and the verifier rechecks, then a second failure ends with "needs your decision" instead of another round.
- [ ] Given a story with `Risk: none`, when pair finishes it, then the verifier is not called.

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

- Reuse the shape of `plugins/flow/agents/plan-reviewer.md` (frontmatter, Hard Rules, fixed output) so both agents read alike.

## Size

normal
Risk: item 3 (pair parses the verifier's verdict), item 6 (the agent's behaviour is graded by paid evals)

## Log

- L1 request: `/flow:story 04` (after the user said "listo, ya reinicie y actualice").
- L2 assumptions for approval: the agent is `plugins/flow/agents/verifier.md` with tools Read, Grep, Glob, Bash and read-only by rule (plan R1.15); the verdict is PASS / FAIL / NEEDS DECISION; evals call the agent through the Agent tool if the eval runner allows it, else through a pair prompt that reaches the check step.
- L3 approved by the user ("si").
