# Story 21: OpenCode pause skips a user message without an id

## Story

21. As a developer, I want the OpenCode pause hook to skip a user message without an id instead of throwing so that a malformed history never breaks a session. Requires: #20

## Acceptance criteria

- [ ] Given a new OpenCode session whose latest user message has no id, when the model is called (even if the text is "pausa"), then the call goes on without an error, no checkpoint is saved, no pause protocol is added and the session-start context is still there.
- [ ] Given a pause message with an id already handled in that session, when the next user message has no id, then no new checkpoint is saved and the earlier pause protocol is no longer added.
- [ ] Given user messages that carry ids, when I send "pausa" and then a normal message, then the behaviour is exactly as in story 20 (one checkpoint, protocol on that message only).

## Plan

- Pin each criterion in the plugin test harness first (red), with a fake context whose latest user message lacks an id.
- The pause step of the OpenCode plugin treats a user message without an id as "not a pause": it runs no hook and forgets any earlier pause of the session, so nothing carries over.
- The session-start block and the tool hook stay untouched.

## Out of scope

- Any change to the Claude `pause` hook, its trigger words, the checkpoint content or the resume line.
- Guessing an id or a fallback key for id-less messages (e.g. hashing the text); `pause` in Antigravity.
- A real `opencode run`: the 2.2.2 capture (story 20, L7) shows user messages always carry an id, so this is a defensive fix pinned by tests.

## Suggestions (your call)

- none

## Size

small
Risk: none

## Log

- L1 request: "/flow:story 21"
- L2 assumptions for approval: today a first user message without an id throws because no pause entry exists yet and the protocol is read from it (story 20, L11); "skip" means that message is never a pause, so no checkpoint and no protocol, and an earlier pause protocol leaves with it as with any new user message (story 20, L6); no real-run check, the harness pins the shape.
- L3 approved by the user ("si, apruebo").
