# Story 18: session-start hooks in Antigravity

## Story

18. As a developer, I want the session-start hooks (host info, pack hint, backup status) in Antigravity so that agy starts with the same context as Claude. Requires: #05

## Acceptance criteria

- [ ] Given a new agy session in a workspace, when the toolkit SessionStart hook runs, then agy receives one injected system message with the same host info Claude gets, plus the pack hint and the backup notes whenever those hooks have something to say.
- [ ] Given every hook has nothing to say, fails, or the payload is empty or malformed, when the SessionStart hook runs, then the session starts normally with nothing injected.
- [ ] Given `./install.sh --target antigravity` (once or twice), when it runs, then the `toolkit` key of agy's `hooks.json` also holds the SessionStart hook with a timeout that covers the Claude hooks' own (5 + 2 + 5 s), and every other key (herdr) keeps its value.

## Plan

- Pin each criterion in tests first (red): adapter tests fed agy's documented SessionStart payload, with the three Claude hooks steered by their own switches and fakes; an installer sandbox test for the hooks.json shape.
- The three Claude hooks stay the single source; one thin adapter maps agy's payload to their input (`cwd` from `workspacePaths[0]`, `source` = startup) and joins what they return, context and messages alike, into one injected step.
- SessionStart is not a gate: anything unreadable or failing injects nothing and never blocks the session.
- Update the Hooks row of `docs/multi-agent.md`.

## Out of scope

- OpenCode (story 19) and `pause` (story 20); `update-check` (deferred by the plan).
- Changing the Claude hooks or their tests.
- A real agy run: added to story 17 (waiting on agy quota).

## Suggestions (your call)

- none

## Size

normal
Risk: item 5 (runtime config written by the installer), item 6 (what agy shows from an injected step can only be confirmed by hand)

## Log

- L1 request: "/flow:story 07"
- L2 split: story 07 had 3 hook sets in 2 agents plus installer wiring (more than 3 criteria), and OpenCode's V2 way to inject context is unproven, so 07 → #18 (agy session start), #19 (OpenCode session start), #20 (OpenCode `pause`).
- L3 assumptions for approval: agy's SessionStart contract comes from its bundled docs (input: common fields only; output `{"injectSteps":[{"systemMessage":{"systemMessage":…}}]}`); agy sends no `source`, so it is `startup` (plan Core model). Claude splits model context (host info) from user-only messages (pack hint, backup status); agy has one injected system message, so both go there (the plan lets each target choose). The real-agy check joins story 17.
- L4 approved by the user ("si"). Story 17 also covers the real-agy session-start check and now requires #16, #06, #18.
- L5 test list approved: 4 adapter tests (`plugins/toolkit/hooks/tests/agy-session-start.test.sh`, fake os-release, fake `ai-pack`, throwaway XDG dirs), 1 installer test; SessionStart timeout 15 s; story 06's exact whole-key assertion relaxed to `.toolkit.Stop == …` (user-approved up front, stop rule 3) with a new exact assertion including SessionStart.
- L6 cycles (mode C): 4beada9→3dad84b host info arrives as one system message; 24ec01f all three hooks join into one message (test-only, green on first run; running only host-info was shown to fail it); eb53b90→35d3443 nothing to say injects `{}`; 476a6a8→90e9d46 an unreadable payload injects `{}`; 6e6a632→3a3d619 the agy `toolkit` key holds SessionStart with timeout 15.
- L7 verifier: FAIL on C2 (no test for "a hook fails"; a JSON payload without a usable `workspacePaths` still injected the host info). User decision: such a payload is malformed and injects nothing. Correction batch: a32ce32 a failing hook injects nothing (test-only, green on first run; the code already dropped it); 65eea8a→a671015 a missing, non-list or empty `workspacePaths` injects `{}`.
