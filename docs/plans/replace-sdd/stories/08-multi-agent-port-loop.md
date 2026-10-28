# Story 08: multi-agent-port ports the loop

## Story

08. As a developer, I want the `multi-agent-port` plan to drop the SDD port so that it ports the new loop instead. Requires: #10

## Acceptance criteria

- [ ] Given the `multi-agent-port` plan, when I read its vision, scope, smoke and demo priorities, then they port the loop (`flow:backlog` → `flow:story` → `flow:pair` with the `flow:verifier` agent) and name no SDD agent, skill or `/sdd:*` command.
- [ ] Given the plan's research and data gaps, when I read them, then every fact about the code matches the repo today (no `plugins/sdd` paths; the relative-path and agent-name findings point to the flow skills and agents that have them).
- [ ] Given `make check`, when the plan names SDD again, then a structural test fails.

## Plan

- Rewrite the plan's SDD item as a loop item: the three loop skills and the verifier agent through the generator.
- Swap the SDD parts of the vision, slash-command item, manual smoke and demo priorities for the loop (smoke: backlog → story → pair on the toy repo).
- Refresh the research and data-gap lines that cite `plugins/sdd` with the current flow files.
- Pin it with a small structural test run by `make check`.

## Out of scope

- `plan-review-1.md`: history, stays as written (already allowlisted).
- Re-reviewing the plan or starting its implementation.
- Any change to `install.sh`, the generator or the other agents' setup.

## Suggestions (your call)

- After this story, run `/flow:plan-review` on `multi-agent-port`: review 1 found issues in SDD parts that no longer exist, and item 5's estimate changes.

## Size

small
Risk: none

## Log

- L1 request: "si" (to "¿Arranco con `/flow:story 08`?").
- L2 assumptions for approval: item 5 becomes "(A) Loop: `backlog`, `story`, `pair` skills and the `verifier` agent through the generator" with its estimate cut from 2 to 1 dev-day (3 skills + 1 agent instead of 10 agents + orchestrator); item 7 keeps `/flow:*` only; the data-gap example `sdd:new` becomes `flow:story` → `flow-story`; the plan stays `Status: draft`.
- L3 approved by the user ("si").
- L4 test list approved (3 structural tests, 1 manual). Red: `9c6efeb`, `plan names no sdd` failed. Plan rewritten (uncommitted): the new test passes, but `no-sdd.test.sh` fails because the new test file names sdd and is not on its allowlist. Stop rule 3 (an existing test would change): waiting for the user.
