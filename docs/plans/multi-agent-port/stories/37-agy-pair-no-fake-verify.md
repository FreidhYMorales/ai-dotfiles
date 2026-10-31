# Story 37: agy pair stops at NEEDS DECISION instead of trusting a shell-less verifier

## Story

37. As a developer, I want the Antigravity `flow-pair` to end a high-risk story in NEEDS DECISION without trusting a verifier that cannot run the test command, so that agy never closes a high-risk story on an unverified PASS. Requires: #25, #27

## Acceptance criteria

- [ ] Given the `pair` skill generated for Antigravity, when I read its check step, then a high-risk story is told to stop with NEEDS DECISION without invoking `flow-verifier`, to leave the story open and to finish it in Claude or OpenCode; no instruction to invoke the verifier is left in that step.
- [ ] Given the `pair` skill generated for OpenCode, when I read its check step, then it still invokes `flow-verifier` exactly as today.

## Plan

- The agy words step rewrites the verifier clause of pair's check step instead of appending a line after it, while agy has no shell tool; never a hand edit.
- The agy check step keeps the rest of the step (manual criteria, `Risk: none` rule) and says the story stays open, so the Done step does not run for a high-risk story.
- Red first in the generator tests on the fixture `pair`, then regenerate the agy `flow-pair` golden; the OpenCode golden must not change.
- The live proof is the agy `/flow-pair` re-run that closes story #13, not this story.

## Out of scope

- Giving the agy verifier a shell tool or proving `run_command` (#17).
- Changing the `flow-verifier` agent itself or the source `pair` skill used by Claude.
- Re-running the smoke (#13) or any OpenCode behaviour.

## Suggestions (your call)

- The agy `flow-verifier` still told itself "a check you could not run is NEEDS DECISION" and wrote PASS anyway; a generated line in the agy verifier ("you have no shell: the `Test command:` row is always NEEDS DECISION") would be a second guard, if you want defence in depth once #17 gives it a shell.

## Size

normal
Risk: item 6 (whether a model obeys the rewritten step is proven only by a live agy run)

## Log

- L1 request: /flow:story 37
- Assumption: the generated `flow-verifier` agent stays in the agy build, unused by pair until #17 proves a shell tool.
- Assumption: the source of the defect is the appended line at `scripts/gen-agents/gen.sh` (agy_words), found in the #13 smoke (agy conversation 10bbf01e).
