# Story 02: flow:story

## Story

02. As a developer, I want `flow:story` to refine one story into 2-3 acceptance criteria, a short plan, out of scope and a size/risk line so that I plan only what I build next.

## Acceptance criteria

- [x] Given a backlog story with no ambiguity, when I ask to refine it, then the skill shows 2-3 Given/When/Then criteria, a plan of at most 5 bullets without file names or code, and a `Risk:` line, and asks for approval (eval `story-from-backlog`).
- [x] Given a story that permanently deletes user data, when I refine it, then it is sized `normal` with `Risk: item 1, 2` and belongs in a story file (eval `story-high-risk`).
- [x] The story file sections and the high-risk reference are a fixed contract (structural test `scripts/tests/flow-story.test.sh`).

## Plan

Built without the loop (stories 01-03 build the loop itself).

## Out of scope

`flow:pair`, `flow:verifier`, `claude/CLAUDE.md` pointing to the high-risk list (story 06).

## Suggestions (your call)

None.

## Size

normal · Risk: item 3 (story file format and `high-risk.md` are contracts other skills parse)

## Log

- L1 request: build `flow:story` and `plugins/flow/skills/pair/references/high-risk.md` per `docs/plans/replace-sdd/plan.md`.
- L2 red: `47d5555` test alone, `bash scripts/tests/flow-story.test.sh` exit 1 (30 cases failed, files missing). Green: `dc2a699`, test passes, `make check` all 7 steps passed.
- L3 decision: item 1 covers deleting, overwriting or migrating existing data and irreversible effects; adding a record is not item 1.
- L4 eval `story-from-backlog`: with 1.00, without 0.11 (Δ +0.89, 6 runs, $0.81).
- L5 eval `story-high-risk` first run: with 0.83 (run 3 split jury: the sandbox refused the file write, the skill's sizing and risk were right). Fix `cfc86d6` (user approved the test change): no Write/Edit in the case, the grader judges intent. Re-run: with 1.00, without 0.00 (Δ +1.00, 6 runs, $0.89). Story eval spend ≈ $2.66.
