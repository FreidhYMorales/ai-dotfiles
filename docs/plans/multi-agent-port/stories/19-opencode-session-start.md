# Story 19: session-start hooks in OpenCode

## Story

19. As a developer, I want the session-start hooks (host info, pack hint, backup status) in OpenCode so that OpenCode starts with the same context as Claude. Requires: #05

## Acceptance criteria

- [x] Given a new OpenCode session in a project, when the model is called, then its system context carries one block with the same host info Claude gets, plus the pack hint and the backup notes whenever those hooks have something to say.
- [x] Given a session that keeps going, when the model is called again, then the same block is there without the hooks running again; a second session runs them once for itself.
- [x] Given every hook has nothing to say or fails, when the model is called, then the system context is left as it was and the session goes on normally.

## Plan

- Capture one real OpenCode 2.1.4 `context` hook call first (as story 05 did for `execute.before`), so the tests use its real shape.
- Pin each criterion in tests first (red): the existing plugin test harness with a fake V2 context, the three Claude hooks steered by their switches and fakes, as in story 18.
- The Claude hooks stay the single source; the existing toolkit plugin runs them once per session with the project directory, joins what they return, context and messages alike, and appends it to the system context on each model call of that session.
- Nothing to say, a failing hook or an unreadable result leaves the system context untouched and never throws.
- Update the Hooks row of `docs/multi-agent.md`; confirm once in a real `opencode run` that the model sees the host info.

## Out of scope

- `pause` (story 20); `update-check` (deferred by the plan); Antigravity (story 18, done).
- Changing the Claude hooks or their tests; installer changes (the plugin is already linked by story 05).

## Suggestions (your call)

- none

## Size

normal
Risk: item 6 (what the OpenCode model actually sees can only be confirmed in a real run)

## Log

- L1 request: "/flow:story 19"
- L2 assumptions for approval: OpenCode V2 has no session-start event that can add context; its `context` hook runs on each model call with the system parts (engram.ts uses it the same way), so the plugin runs the hooks once per session id and appends the cached block on each call. The project directory comes from the plugin context (`ctx.location.directory`), `source` is `startup`. As in story 18, pack hint and backup notes go into the same block (OpenCode has no user-only channel the plugin can reach). No installer change: `toolkit.ts` is already linked.
- L3 approved by the user ("si").
- L4 test list approved: step 0 and a final step are manual real OpenCode runs; 4 integration tests in the plugin test file; the existing `before()` harness gains `session.hook` and `location` in its fake context (no assertion changes; user-approved, stop rule 3).
- L5 capture (step 0, OpenCode 2.1.4, temporary plugin removed afterwards): `ctx.location.directory` is the project dir; `ctx.session.hook("context", cb)` gets `{sessionID, model, system: [{type: "text", text}…], messages, options, agent, tools}` once per model call.
- L6 cycles (mode C): 1737e75 (+52768e4 shfmt) → 3b8a07b host info appended; a17fcd3 → 082ece3 pack hint and backup notes join the block; 0c1685b → 8446921 one run per session id (Map cache); 85be048 → cb83ca5 silent, unreadable or unstartable hooks leave the system untouched (per-hook try/catch). Every code commit gated on `make check`.
- L7 real OpenCode 2.1.4 run: plain `opencode run` talks to the background `opencode serve --service`, which never sees the shell env and loads plugins at start (a first control run was therefore meaningless). With `--standalone` and a fake os-release "Zebradistro 42": hooks on → the model answered `Zebradistro 42`; hooks off → `NOT IN CONTEXT`. Documented in `docs/multi-agent.md` (a763156).
- L8 verifier (`flow:verifier`): Verdict: PASS on C1-C3, commit order, tamper check (52768e4 only reformats a harness loop) and assertions; red replayed for every test commit.
- L9 Risk: item 6.
