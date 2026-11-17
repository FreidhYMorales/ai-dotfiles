# Story 11: OpenCode's generated rule runs check-fast before done

## Story

11. As a developer using OpenCode, I want its generated rule to run make check-fast before done so that OpenCode stops paying the full suite every turn. Requires: #01

## Acceptance criteria

- [ ] Given the generated OpenCode rules, when OpenCode reads its before-done line, then it is told to run `make check-fast` from the git root when the root Makefile defines it and the tree has uncommitted changes, fix any failure first, and still skip it on the `/flow-pair` red marker.
- [ ] Given a repo whose Makefile has `check` but no `check-fast`, when OpenCode reads the same line, then it is told to run `make check` instead, as the `require-check` hook does.
- [ ] Given `docs/multi-agent.md`, when I read how OpenCode gates done, then it says `make check-fast` when the Makefile defines it, else `make check`.

## Plan

- The generator's OpenCode-only rule line changes from `make check` to the hook's order: `check-fast` when defined, else `check`; the red-marker skip stays word for word.
- The OpenCode golden is regenerated; the `gen-agents.test.sh:125-126` assertion changes to the new wording (pre-approved by the plan).
- `docs/multi-agent.md` OpenCode sentence matches.
- `./install.sh` reruns so the installed OpenCode rules carry the new line.

## Out of scope

- OpenCode permissions or auto-allow lists (the plan dropped them; the `make check` allow belongs to the read-only verifier).
- The full-suite runs at story end, ship and CI (`pair`, `ship` and CI keep `make check`).
- Antigravity, which already has the Stop gate.
- A timeout rule: the hook's 60 s non-blocking timeout has no counterpart in a rule line.

## Suggestions (your call)

- Assumption: no plugin bump; only generated output and docs change.

## Size

normal
Risk: item 6 (OpenCode obeying a rule line cannot be tested here; only its text is pinned)

## Log

- L1 request: /flow:story 11
