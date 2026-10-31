# Story 38: no flow-verifier agent in Antigravity

## Story

38. As a developer, I want the `flow-verifier` agent left out of the Antigravity build and install, so that no shell-less agy subagent can hand pair a made-up PASS. Requires: #37

## Acceptance criteria

- [ ] Given a fresh generation, when I look at the Antigravity agents, then only `flow-plan-reviewer` is there, while OpenCode still gets both `flow-plan-reviewer` and `flow-verifier`.
- [ ] Given a machine where an earlier install linked `flow-verifier` into agy's agents dir, when I run the installer, then that link is removed and reported as pruned, and the `flow-plan-reviewer` link stays.

## Plan

- The generator stops emitting the verifier for Antigravity only; its agy golden is removed.
- The installer's existing prune of links into the build dir removes the stale agy link; no new delete logic.
- `docs/multi-agent.md` says agy has no verifier agent, so a high-risk story there ends in NEEDS DECISION and is finished in Claude or OpenCode.
- The live proof is the agy `/flow-pair` re-run that closes #13.

## Out of scope

- Changing the agy `flow-pair` wording (#37) or the source `pair` and `verifier` used by Claude.
- Giving any agy agent a shell tool (#17).
- The OpenCode verifier or its permissions (#28).

## Suggestions (your call)

- If #17 later proves `run_command`, bringing the agy verifier back is the same one-line generator switch, together with the #37 wording.

## Size

normal
Risk: item 1, 5, 6 (the installer removes a link in agy's config dir; whether agy then stops at NEEDS DECISION is proven only live)

## Log

- L1 request: /flow:story 38
- Assumption: three existing assertions that expect the agy verifier change with this story (the agy `flow-verifier` golden in the generator tests, the agy link in the agy install test, and the agy half of the role model map loop); approving this story approves those test changes.
- Assumption: the stale link is pruned because the installer already removes dangling links that point into the build dir (#36).
