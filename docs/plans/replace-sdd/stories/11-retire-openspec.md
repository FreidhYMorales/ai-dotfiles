# Story 11: Retire openspec

## Story

11. As a developer, I want `openspec/` deleted and the legacy `openspec/changes/` plan lookup dropped from the flow skills so that the repo holds only what is used and history stays in git. Requires: #10

## Acceptance criteria

- [ ] Given the repo, when I list its tree, then `openspec/` is gone and no test, doc or config outside history points into it, with `make check` green.
- [ ] Given any flow skill that looks up a plan, backlog or story (the Claude source and the generated OpenCode and Antigravity copies), when I read its lookup step, then it names only `docs/plans/<feature>/` and no legacy path.
- [ ] Given the flow eval cases that start from a plan or backlog (`backlog-from-plan`, `story-from-backlog`, `handoff-solo-to-backlog`, `pair-proposes-test-list`), when `make eval PLUGIN=flow` runs them, then they pass.

## Plan

- Delete `openspec/` as a whole (specs, archive and their `.gitkeep` files); git keeps the history.
- Drop the legacy clause from every flow skill's lookup step and from the legacy rows of the backlog skill's gates and the story skill's output contract.
- Regenerate the OpenCode and Antigravity goldens from the new source.
- Update the structural tests that pin the old lookup line or allowlist `openspec/`.
- Run the four eval cases as acceptance and record the result in the log.

## Out of scope

- History: `docs/plans/**`, `docs/ideas.md` and `docs/upstream/**` keep naming `openspec` as written.
- A flow plugin version bump (stories #26 and #29 changed flow skills without one).
- Any other skill wording change, or the full eval suite.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 3 (skill text read by Claude, OpenCode and agy), item 6 (the wording is graded only by a paid eval)

## Log

- L1 request: /flow:story 11
- L2 assumptions: deleting tracked files is not item 1 (git keeps them, local and remote); `flow-handoff.test.sh` pins the old lookup line and `no-sdd.test.sh` allowlists `openspec/changes/archive/`, so pair changes those two tests as this story's criteria require (pair stop rule 3 still asks before each); idea 03 in `docs/ideas.md` already records that this revisits idea 01.
