# Story 10: drop every SDD reference outside history

## Story

10. As a developer, I want every reference to SDD gone outside history so that there is one workflow to read and maintain. Requires: #09

## Acceptance criteria

- [x] Given the always-on rules, when a session loads them, then they no longer mention SDD or `/sdd:*`, and "Strict TDD: enabled" stays.
- [x] Given the README, the multi-agent doc and the flow and toolkit skills, when I read them, then they describe only the backlog → story → pair loop (no SDD phases, commands or forecasts, no file-count delegation), and every plugin whose files changed has a bumped version.
- [x] Given the repo, when I run `make check`, then a test fails on any case-insensitive whole-word "sdd" outside an explicit allowlist of history and retirement files, and it passes today.

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
- L4 test list approved: 7 structural tests (1 in `flow-rules.test.sh`, 2-7 in the new `no-sdd.test.sh`); the story 06 pin "SDD sentence stays until story 07" flips to "SDD sentence is gone" with the user's approval (stop rule 3). One big allowlist test was split per area to keep each green step small; the allowlist test came last as a pin.
- L5 cycles (mode C): 1463aa0→1720d8e rules drop the SDD sentence; 87d8164→50e7f83 README describes the loop (flow skills and `verifier` listed, `docs/upstream/` row, done SDD roadmap items dropped); 83550e5→29f7ea5 multi-agent doc lists the loop skills as Claude-only, upstream note; a303e2b→b0a560c toolkit sizes chained PRs from stories and task lists, 0.14.0; d3d33bc→0589a7a flow delegates by bounded reads, high-risk origin reworded, 0.10.0; 99fcdd5→e3d1647 `openspec/config.yaml` removed; 8982da2 allowlist pin (planted `/sdd:new` in a doc and `# sdd leftovers` in `install.sh` each fail it; it also asserts the scan sees the retirement line). Every code commit gated on `make check` ("All checks passed (7 steps)").
- L6 verifier (`flow:verifier`): Verdict: PASS; rewritten text checked against the repo.
- L7 evals: not run (paid); the verifier suggests `make eval PLUGIN=toolkit CASE='chained-pr-*'` and `make eval PLUGIN=flow` if wanted (user's call).
- L8 Risk: item 6 (always-on rules and skill wording, behaviour graded only by paid evals).
