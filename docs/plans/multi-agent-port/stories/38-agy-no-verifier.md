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
- Red 1: 97ed3c3 `test(gen-agents): no flow-verifier agent is built or linked for agy` (the three approved assertion changes); FAIL `no agy verifier agent is generated`, FAIL `no agy verifier agent is linked`.
- 6ad4a52 `test(gen-agents): unroll the one-entry agy model map loop`: shellcheck SC2043 failed `make check` on the one-entry loop; the user approved this separate test commit (same assertion, same expectation).
- Green 1: 59b2a85 `fix(gen-agents): build no flow-verifier agent for agy`; agy verifier golden removed, OpenCode goldens unchanged; tamper vs 6ad4a52 empty.
- C2 pin: 7c62b3c `test(install): prune an earlier agy verifier link`, green from the start on the existing prune (#36). Red shown live against the pre-fix generator (`git show 97ed3c3:scripts/gen-agents/gen.sh`): FAIL `the old agy verifier link is removed`, FAIL `output reports the pruned verifier link`.
- Docs: 7527a31 `docs(multi-agent): Antigravity has no verifier agent`. `make check` "All checks passed (7 steps)".
- Verifier: FAIL on commit order only (the C2 test was committed after the fix that makes it pass; both criteria, tamper and assertions PASS). The user explicitly accepted the test-after-code order, with the live red above as evidence; history not rewritten.
- Risk: item 1, 5, 6 (the installer removes a link in agy's config dir; whether agy then stops at NEEDS DECISION is proven only live)
