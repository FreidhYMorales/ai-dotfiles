# Story 06: the make check Stop gate in Antigravity

## Story

06. As a developer, I want the `make check` Stop gate in Antigravity, which lets a red pair step through and never traps me after I cancel, so that agy cannot finish on a broken tree. Requires: #05

## Acceptance criteria

- [ ] Given agy ends a turn normally in a repo whose `make check` fails, when the toolkit Stop hook runs, then agy is told to continue with the same failure tail Claude gets; when `make check` passes, or agy is already continuing from this gate, agy is let stop.
- [ ] Given I cancel, agy stops for any other reason, the payload is missing or malformed, or a `/flow:pair` red marker is on the branch, when the Stop hook runs, then agy is let stop and never told to continue.
- [ ] Given `./install.sh --target antigravity` (once or twice), when it runs, then the `toolkit` key of agy's `hooks.json` also holds the Stop hook with a timeout of at least 330 s, next to the PreToolUse hook, and every other key (herdr) keeps its value.

## Plan

- Pin each criterion in tests first (red): adapter tests fed agy's documented Stop payload against throwaway repos with a passing and a failing `make check`; installer sandbox tests for the hooks.json shape.
- The Claude `require-check` hook stays the single source of the gate; a thin adapter maps agy's payload to its input (`cwd` from `workspacePaths[0]`, a later execution to the "already continuing" flag) and its block to agy's continue.
- The adapter runs the gate only on a normal turn end; anything else, unreadable input included, lets agy stop.
- The red marker keeps its Claude behaviour (no block); in agy its message is dropped, since a Stop that lets agy stop carries no message.
- Update the Hooks row of `docs/multi-agent.md`.

## Out of scope

- Session-start hooks and `pause` (story 07); OpenCode (no hook can block finishing there; plan: rule-only, v2).
- Changing `require-check.sh` or its tests.
- A real agy run: added to story 17 (waiting on agy quota).

## Suggestions (your call)

- none

## Size

normal
Risk: item 4 (re-entry: a gate that keeps telling agy to continue would trap the session), item 5 (runtime config written by the installer), item 6 (agy's real Stop behaviour can only be confirmed by hand)

## Log

- L1 request: "/flow:story 06"
- L2 assumptions for approval: agy's Stop contract comes from its bundled docs (`terminationReason`, `executionNum`, `workspacePaths`; stdout `{"decision":"continue","reason":…}` blocks the stop, any other decision lets it stop); the adapter answers `{"decision":"stop"}` to let agy stop. "Already continuing" is `executionNum > 1`, as the plan's Core model says. Timeout 330 s matches the Claude hook (`require-check` runs `make check` with a 300 s limit). The real-agy check of this gate joins story 17.
- L3 approved by the user ("si"). Backlog: story 17 also covers the real-agy check of this gate and now requires #16, #06.
- L4 test list approved: 6 adapter tests (`plugins/toolkit/hooks/tests/agy-require-check.test.sh`), 1 installer test. File: `plugins/toolkit/hooks/agy/require-check.sh`.
- L5 cycles (mode C): b6b4c73→ec8e124 a failing check continues with the tail; 9e47579→5541d0c a passing check stops; 3fa52c2→059cb82 `executionNum > 1` maps to `stop_hook_active` and stops; 33687c2→682817a only `NO_TOOL_CALL` is gated; bb27718 unreadable payload stops (test-only, green on first run; a fallback to the hook's cwd was shown to make it fail), then 723798a refactor: no workspace stops explicitly; 1b86dd9 a red marker stops (test-only; the same repo without the marker continues).
- L6 test 7 (user-approved, stop rule 3): story 05's exact `.toolkit == {PreToolUse: …}` assertion became `.toolkit.PreToolUse == …`; a new assertion pins the whole key with `Stop: [{type, command, timeout: 330}]` (flat list, per agy's docs). 50b126b→e135274.
