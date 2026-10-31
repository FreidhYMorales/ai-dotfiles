---
name: flow-research
description: "Trigger: research first, prior art, competitors, which library, policies, feature ideas, /flow-research. Optional pre-planning research that yields a short v1/v2 findings brief."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load before `/flow-plan` when a feature has open questions about prior art, competitors, libraries, external constraints or policies, or when the user asks to research first. Skip it when the user already knows what to build and how.

## Hard Rules

- Talk to the user in their language; write the brief and engram entries in English.
- Delegate broad reading (web, more than one bounded read, long source docs) to ONE read-only research subagent; keep only its compressed findings in this thread.
- Use the context7 MCP (`resolve-library-id`, then `query-docs`) for library and framework docs; never answer library APIs from memory.
- Check external usage policies and limits that can block the plan (e.g. map-tile usage policies, API quotas, licensing, store rules).
- Every finding carries a source (URL, file path, or doc id) and a tag: `v1` (affects what we build now), `v2` (later), or `info`.
- Do not decide scope here. Feed findings into `/flow-plan`.
- Keep the brief short: at most ~1 page.

## Decision Gates

| Question type | Tool |
|---|---|
| Library / framework API, version, setup | context7 MCP |
| Competitors, prior art, policies | research subagent with WebSearch/WebFetch |
| User's own source docs or data | research subagent reading the files read-only |
| A finding would change the core model | Flag it at the top of the brief as "design-changing" |

## Execution Steps

1. Ask the user (one question) what they most need to know, unless the request already says it.
2. Launch one research subagent with: the questions, the source paths, "read-only, cite sources, return under 400 words, tag each item v1/v2/info".
3. Run context7 lookups for candidate libraries in parallel with the subagent.
4. Merge results into the brief format below. Drop anything without a source.
5. Save the brief to engram (`mem_save`, type `discovery`, topic `research/<feature>`). For another project use `engram save "<title>" "<content>" --type discovery --project <name>`.
6. Plan lookup: `docs/plans/<feature>/plan.md` first, then legacy `openspec/changes/<change>/plan.md` (legacy plans stay read-write). If a plan file exists, append the brief to its `## Research` section; otherwise keep it for `/flow-plan` to insert.
7. Recommend `/flow-plan` next.

## Output Contract

```
## Research brief: <feature>
Design-changing: <finding or "none">
| # | Finding | Tag (v1/v2/info) | Source |
Libraries: <name — why — risk>
Constraints/policies: <limit — impact>
Feature ideas worth adding: <idea — v1 or v2 — cost>
```

Final message: the brief, where it was saved, next step `/flow-plan`.
