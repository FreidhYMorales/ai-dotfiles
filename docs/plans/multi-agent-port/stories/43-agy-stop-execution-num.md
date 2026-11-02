# Story 43: the agy Stop gate counts executionNum from 0

## Story

43. As a developer, I want the agy Stop gate to treat `executionNum` 0 as a normal turn end and 1 or more as a re-entry, so that a failing `make check` really holds an agy turn (story #40 saw agy send 0 on every normal turn end, so the gate never runs; with that rule a `continue` forced by another Stop hook makes the gate skip its check, so decide whether that is acceptable). Requires: #06, #40

## Acceptance criteria

- [ ] Given a repo with uncommitted changes and a failing `make check`, when agy ends a normal turn (`NO_TOOL_CALL`, `executionNum` 0), then agy continues with the check's failure as the reason.
- [ ] Given agy is already continuing because of a Stop hook (`executionNum` 1 or more), or the payload has no usable `executionNum` (missing, null, a string, negative), when the turn ends with the check still failing, then agy is let stop.
- [ ] Given the fix installed, when the user ends a real agy turn in a repo with a failing `make check`, then agy continues once with the failure and then stops, and `docs/multi-agent.md` records it in place of the #40 failure (manual check).

## Plan

- Shift the adapter's reading of `executionNum` by one: 0 is the first turn end and runs the check, 1 or more maps to Claude's `stop_hook_active` and lets go; anything that is not a number ≥ 0 still lets agy stop.
- The adapter's existing tests use 1 as the first turn end and 0 as unreadable; they move to the real values (0 first, 1 a re-entry, a negative number unreadable). This changes existing tests on purpose; pair confirms each change with the user.
- Update the hook contract text that states the old rule (the plan's Core model and the adapter's comments) and the #40 row in `docs/multi-agent.md`.
- The user runs one real agy turn in a throwaway repo; Claude reads the transcript and records the result.

## Out of scope

- Telling the gate's own `continue` apart from another Stop hook's: agy does not say which hook continued, and Claude's `stop_hook_active` has the same meaning (any Stop hook), so a continue forced by another hook lets the gate go (assumption below).
- The cancel path (agy runs no Stop hook on a cancel, #40), SessionStart, PreToolUse, the installer, the timeouts and the version pin.
- The Claude `require-check` hook and the OpenCode plugin.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 6 (agy's real Stop behaviour is only checkable by hand)

## Log

- L1 request: /flow:story 43
- L2 assumptions for approval: the edge case in the story line is accepted, since it matches Claude's `stop_hook_active` (true after any Stop hook's continue) and agy's payload names no hook; the evidence is #40's live payloads on agy 1.4.12 (0 on a normal end, 2 after two continues); existing adapter tests change values on purpose (pair stop rule 3 is pre-agreed here, still shown per test).
