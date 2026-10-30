# Story 29: skill stories close with the eval pending outside Claude

## Story

29. As a developer, I want the generated `flow-pair` to let a skill story close with "make eval pending (needs Claude)" in its log, and `/flow:next` to list pending evals, so that a skill story is not blocked outside Claude and the eval is not forgotten. Requires: #27

## Acceptance criteria

- [ ] Given the generated `flow-pair` in OpenCode or Antigravity, when a skill story reaches Done, then pair tells me to record `make eval pending (needs Claude)` in the story log and close the story, instead of asking for a `make eval` result it cannot get.
- [ ] Given a backlog with a closed story whose log says `make eval pending (needs Claude)` and no later `make eval` result, when I run `/flow:next`, then it lists that story under "Pending evals" with `make eval PLUGIN=<plugin>` to run in Claude.
- [ ] Given Claude Code, when a skill story reaches Done, then `/flow:pair` still records the `make eval` result (the pending line exists only in the generated skills).

## Plan

- The generator appends one sentence to the Done step of the target `flow-pair` (both targets), pinned by the goldens.
- The source `next` skill gains a short rule: in backlog mode, after the Ready/Blocked lists, list closed stories whose log holds the pending line with no later eval result.
- A new `next` eval case (a backlog with one pending-eval story) grades that `/flow:next` lists it; it runs with `make eval` in Claude.
- The Claude `pair` skill is unchanged.

## Out of scope

- Running the pending evals or any marker file outside the story log.
- Generating `next` for the targets (#10); OpenCode and agy keep the raw `next`, which reads the same rule.
- Changing how Claude's pair records eval results.

## Suggestions (your call)

- The literal phrase `make eval pending (needs Claude)` is the only link between pair and next; keep it identical in both places.

## Size

normal
Risk: item 3 (the pending-eval log phrase pair writes and next parses), item 6 (the `/flow:next` wording is graded only by a paid eval)

## Log

- L1 request: "/flow:story 29"
- L2 assumptions for approval: the pending line goes into both targets' `flow-pair` (R6-Q3 says "the target pair"); a story counts as pending until a later Log line records a `make eval` result; `/flow:next` changes in the source skill, so Claude sees the list too (harmless: Claude stories never write the pending line); the next eval case runs here in Claude, so this story closes with a real `make eval` result.
- L3 approved by the user ("si").
- L4 test list approved ("si"): 1 generated flow-pair Done step (both targets) carries the pending line (golden + literal assert); 2 Claude pair has no pending line (regression pin, green from start); 3 new flow-next.test.sh: next rule and the new eval case structure; 4 paid `make eval PLUGIN=flow CASE='next-*'`.
