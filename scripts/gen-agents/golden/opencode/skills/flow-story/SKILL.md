---
name: flow-story
description: "Trigger: refine story NN, detail this story, acceptance criteria for a backlog story, /flow-story. Refine ONE backlog story into 2-3 Given/When/Then criteria, a short plan, out of scope and a size/risk line, then wait for approval. Not for writing code or for creating a backlog."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
  adapted-from: "nschurmann/hola-ai skills/story (MIT)"
---

## Activation Contract

Load when the user wants one story from `backlog.md` refined right before building it. Not for creating or editing the backlog as a whole (that is `/flow-backlog`) or for writing code (that is `/flow-pair`).

## Hard Rules

- Talk to the user in their language; story files and engram entries are in English.
- **Writes no code.** The output is a story for approval; implementation is `/flow-pair`.
- **Invent nothing.** Use only the story line, the plan, the backlog context and the code. A real ambiguity is a question; anything else is a stated assumption.
- Ask at most ONE question at a time, with your suggested answer, then stop and wait. Ask only when the answer changes the criteria or the size.
- Criteria describe what the user sees or gets, never how it is built.
- The simplest thing that meets the criteria: no layers, abstractions or configuration "for the future".
- Suggest, do not decide: patterns go under `## Suggestions (your call)` only with a concrete signal in the code.
- The section layout below is a contract `/flow-pair` and `flow-verifier` parse; never deviate from it.
- Ignore old engram topics `sdd/*` and `sdd-init/*`.

## Decision Gates

| Situation | Action |
|---|---|
| No `backlog.md` found | Stop; suggest `/flow-backlog` first |
| Story ID missing or not `[ ]`/`[~]` | Show the open stories; ask which one |
| Story needs more than 3 criteria | Propose a split (below); refine the first new story |
| Any item from `"/repo path/plugins/flow/skills/pair/references/high-risk.md"` applies | Size `normal`, name it on the `Risk:` line, write the file |
| Size `small` and `Risk: none` | Chat-only is allowed: small + `Risk: none` may stay in chat with no file (offer the file anyway) |
| Story file already exists | Edit it in place; append to `## Log`, never rewrite L1 |

## Execution Steps

1. Look up the backlog: `docs/plans/<feature>/backlog.md` first, then legacy `openspec/changes/<change>/backlog.md`. Read the story line, `## Context`, the plan next to it, and the stories it `Requires:`.
2. Read `AGENTS.md`/`CLAUDE.md` and the code the story touches (a bounded look, not the whole repo).
3. Ask one question if a real ambiguity remains; otherwise list your assumptions inside the story for approval.
4. Write 2-3 acceptance criteria as checkboxes: `- [ ] Given <context>, when <action>, then <result>.`
5. More than 3 needed: split. In `backlog.md` the original line becomes `NN. [-] split → #NN, #NN ...` and the new stories are appended with the next free IDs in the backlog line grammar.
6. Write `## Plan`: at most 5 bullets on how the story cuts through the layers; no file names, no code.
7. Write `## Out of scope` (what must not sneak in) and `## Suggestions (your call)` (optional).
8. Size it with `"/repo path/plugins/flow/skills/pair/references/high-risk.md"`: `small` or `normal`, plus the `Risk:` line (`Risk: item N (reason)` or `Risk: none`).
9. Write `docs/plans/<feature>/stories/NN-<slug>.md` from `"/repo path/plugins/flow/skills/story/templates/story.md"` (unless chat-only applies), with `## Log` L1 = the user's request verbatim.
10. Mark the backlog line `[~]`. Show the story; wait for the user's approval and adjust until they say yes.
11. On approval: save one engram entry and name the next step `/flow-pair NN`.

## Example

Backlog line `04. [ ] As a librarian, I want to mark a loan returned so that the book shows as available.`:

```
- [ ] Given a book on loan, when I mark it returned, then it shows as available.
- [ ] Given a book already available, when I try to mark it returned, then nothing changes and I see why.
small
Risk: none
```

## Output Contract

- `docs/plans/<feature>/stories/NN-<slug>.md` with `## Story`, `## Acceptance criteria`, `## Plan`, `## Out of scope`, `## Suggestions (your call)`, `## Size`, `## Log` (legacy plans: `stories/` next to the backlog).
- `backlog.md`: the story line marked `[~]` (or split as above).
- Engram: one `decision` entry (`engram_mem_save`, topic `story/<feature>/NN`) with the story path, size and `Risk:` line.
- Final message: the story, the `Risk:` line, a request for approval, then next step `/flow-pair NN`.

## References

- `"/repo path/plugins/flow/skills/story/templates/story.md"`: the file template.
- `"/repo path/plugins/flow/skills/pair/references/high-risk.md"` (`"/repo path/plugins/flow/skills/pair/references/high-risk.md"`): the six high-risk items, the size rule and the `Risk:` line.
- Adapted from hola-ai `story` (github.com/nschurmann/hola-ai, MIT).
