# Story 01: flow:backlog

## Story

01. As a developer, I want `flow:backlog` to turn an idea or a plan into a numbered one-line story list in `backlog.md` so that I start from a walking skeleton instead of a full spec.

## Acceptance criteria

- [x] Given a bare idea with gaps, when I ask for a backlog, then the skill asks one question with a suggestion and invents nothing (eval `backlog-asks-on-gap`).
- [x] Given an approved plan and a Makefile, when I ask for the backlog, then it proposes stories in the line grammar, story 01 is a walking skeleton, and `Test command: make check` is detected (eval `backlog-from-plan`).
- [x] The file format is a fixed contract (structural test `scripts/tests/flow-backlog.test.sh`).

## Plan

Built without the loop (stories 01-03 build the loop itself).

## Out of scope

`flow:story`, `flow:pair`, the `link_skills` exclusion (story 03).

## Size

normal · Risk: item 3 (the file format is a contract other skills parse)

## Log

- L1 request: build `flow:backlog` per `docs/plans/replace-sdd/plan.md`.
- L2 red: `fa863a8` test alone, `bash scripts/tests/flow-backlog.test.sh` exit 1 (17 cases failed, skill missing). Green: `749467e`, test passes, `make check` all 7 steps passed.
- L3 eval `backlog-from-idea` failed 3 runs (with 0.33 / 0.44 / 0.22): a single-turn case cannot grade both "ask one question" and "propose the backlog"; the skill kept asking about real gaps. Also a real defect: story 01 came out as "sign in".
- L4 fix `6cb8212`: walking skeleton = smallest slice of the core value; supporting concerns never story 01 alone (example from another domain to avoid eval leakage). Eval split in `cfdc398` into `backlog-asks-on-gap` and `backlog-from-plan` (user approved the test change).
- L5 eval results 2026-10-27: `backlog-asks-on-gap` with 1.00, without 0.00 (Δ +1.00, 6 runs, $0.54); `backlog-from-plan` with 1.00, without 0.00 (Δ +1.00, 6 runs, $0.63). Total eval spend for the story ≈ $2.87.
