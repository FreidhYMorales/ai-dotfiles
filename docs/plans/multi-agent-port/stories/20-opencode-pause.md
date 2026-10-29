# Story 20: pause in OpenCode

## Story

20. As a developer, I want `pause` in OpenCode so that I can stop an OpenCode session safely with a checkpoint saved. Requires: #19

## Acceptance criteria

- [ ] Given an OpenCode session in a project, when my message starts with "pausa", "pausar" or "pause", then a pause checkpoint (branch, last commit, uncommitted files) is saved to engram before the model answers, and the model gets the pause protocol whose resume line says `opencode --continue`, never `cz` or `claude --continue`.
- [ ] Given the same session, when the model is called again for that message (tool calls) or I send a message that is not a pause, then no new checkpoint is saved and no pause protocol is added.
- [ ] Given the pause hook is switched off, fails or prints nothing readable, when I send "pausa", then the session goes on normally; and in Claude the pause protocol stays word for word as today.

## Plan

- Capture one real OpenCode 2.2.2 hook call first (the version moved from 2.1.4): which hook sees the user's new message and its shape (the `context` hook's `messages`, or a message event if V2 has one), so the tests use the real shape.
- Pin each criterion in tests first (red): the plugin test harness with a fake V2 context, and the existing `pause` hook tests for the agent-aware resume line.
- The Claude `pause` hook stays the single source of the checkpoint and the protocol text; its input gains which agent calls it, and only the resume line changes for OpenCode.
- The toolkit plugin runs the hook once per user message that starts a pause, with the project directory, and adds its text to the model context for that turn; nothing to say or a failure leaves the context untouched and never throws.
- Update the Hooks row of `docs/multi-agent.md`; confirm once in a real `opencode run --standalone` that "pausa" saves a checkpoint and the reply follows the protocol.

## Out of scope

- `pause` in Antigravity (plan: v1 uses a rule line); `update-check` (deferred by the plan).
- Changing the checkpoint content, the trigger words or the Claude behaviour; installer changes (`toolkit.ts` is already linked).

## Suggestions (your call)

- none

## Size

normal
Risk: item 1, 6 (writes an engram checkpoint; what the OpenCode model sees and does on pause is only confirmed in a real run)

## Log

- L1 request: "/flow:story 20"
- L2 decision (user, "si, la sugerida"): the Claude hook stays the single source of the text; it learns the calling agent and words the resume line `opencode --continue` for OpenCode; Claude output unchanged.
- L3 assumptions for approval: installed OpenCode is now 2.2.2 (`--continue` resumes the last session, checked in `--help`), so step 0 re-captures the hook shape; detection runs once per user message, not per model call, so tool-call loops neither re-save nor re-inject; the pause text reaches the model through the same system context channel as story 19 unless the capture shows a better per-message one.
- L4 approved by the user ("si").
