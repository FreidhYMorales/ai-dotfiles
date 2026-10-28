# Story 10: drop every SDD reference outside history

## Story

10. As a developer, I want every reference to SDD gone outside history so that there is one workflow to read and maintain. Requires: #09

## Acceptance criteria

- [ ] Given the always-on rules, when a session loads them, then they no longer mention SDD or `/sdd:*`, and "Strict TDD: enabled" stays.
- [ ] Given the README, the multi-agent doc and the flow and toolkit skills, when I read them, then they describe only the backlog → story → pair loop (no SDD phases, commands or forecasts, no file-count delegation), and every plugin whose files changed has a bumped version.
- [ ] Given the repo, when I run `make check`, then a test fails on any case-insensitive whole-word "sdd" outside an explicit allowlist of history and retirement files, and it passes today.

## Plan

- Remove the SDD sentence from the always-on rules; keep Strict TDD.
- Rewrite the README (plugin table, workflow diagram, handoff row, eval note, roadmap), the multi-agent doc and the upstream-watch note so they name only flow, toolkit and look.
- Reword the toolkit commit and chained-PR skills and the flow references (threat-matrix origin, "4+ files" delegation) without SDD terms; bump flow and toolkit.
- Remove the project's SDD config file.
- A structural test runs the whole-word search and compares hits with the allowlist.

## Out of scope

- `docs/plans/`, `docs/ideas.md`, `docs/upstream/`, `openspec/specs/`, `openspec/changes/archive/` (history).
- Old engram `sdd/*` and `sdd-init/*` topics.
- The `multi-agent-port` plan (story 08).
- Other projects (quickshell, proyecto_san_sebastian).

## Suggestions (your call)

- The `--dry-run` message of the prune ("pruned broken link" after the dry-run line, verifier note from story 09) could be fixed here or in its own small story; it is not an SDD reference.

## Size

normal
Risk: item 6 (always-on rules and skill wording, behaviour graded only by paid evals)

## Log

- L1 request: `/flow:story 10`
- L2 assumptions for approval: the allowlist is the plan's list (install retirement lines, `install.test.sh`, `docs/upstream/`, `docs/plans/`, `docs/ideas.md`, `openspec/changes/archive/`, `packs/vendor/`) plus the files whose job is to name SDD in order to reject or ignore it: `plugins.test.sh`, the flow tests and the handoff eval that assert "no SDD", and the flow skills' "Ignore old engram topics `sdd/*`" line (those topics still exist in engram). The `flow-rules.test.sh` pin "SDD sentence stays until story 07" flips to "SDD sentence is gone" (an existing test changes; approval asked at pair time). Done roadmap items about SDD are dropped from the README. `openspec/config.yaml` is deleted (plan decision; nothing reads it).
- L3 approved by the user ("si").
