# Story 39: the Antigravity PreToolUse hook in a real session

## Story

39. As a developer, I want the Antigravity PreToolUse hook checked in a real agy session (first a `deny` probe under `--dangerously-skip-permissions`, every agy hook check recorded "unproven" if the flag bypasses it; then the payload agy really sends and the toolkit hook's `ask` answer) so that the agy tool rules rest on proven behaviour. Requires: #05, #16

## Acceptance criteria

- [x] Given a temporary probe hook that logs agy's PreToolUse payload and answers `deny`, when the user runs a command in agy under `--dangerously-skip-permissions`, then `docs/multi-agent.md` records whether the command was blocked and the payload's real shape; if the command ran, it records that the flag bypasses hooks and marks every agy hook check (this story's and #40's) "unproven" (manual check).
- [x] Given the toolkit hook installed and no flag, when agy runs a modern command (`eza`), then agy still shows its own approval prompt (the `ask` answer keeps agy's permission flow), and the recorded payload carries the tool name and command line where the adapter reads them; the result is recorded per check (manual check).
- [x] Given the checks are done, when I look at agy's `hooks.json`, then the probe is gone and the `toolkit` and herdr keys are exactly as before.

## Plan

- Back up agy's `hooks.json`, then add the probe as its own key next to `toolkit`, never inside it; remove it and compare with the backup at the end.
- The user runs agy (Claude Code's auto mode refuses `--dangerously-skip-permissions`); Claude prepares the probe, reads the payload log and records the results.
- Run the `deny` probe first: if the flag bypasses hooks, skip the `ask` check under the flag and record the outcome as "unproven", as the plan allows (R5-Q3).
- Record the findings in the Hooks part of `docs/multi-agent.md`, with the agy version they were run on.
- A mismatch between the real payload and what the adapter reads is recorded and becomes a new backlog story; it is not fixed here.

## Out of scope

- The Stop gate and the session-start hook in a real session (#40).
- Rules and skills sentinels, `.bak-*` in the agents dir (#41); subagent engram and registry tools (#42).
- Any change to the adapter, the Claude hook, the installer or the version pin.
- Re-proving that `ls` is denied (already shown live in #13).

## Suggestions (your call)

- Install the probe with the same jq merge-through-`mktemp` pattern the installer uses (#35), so a herdr rewrite during the run does not clash with a half-written file.

## Size

normal
Risk: item 5, 6 (a temporary hook in agy's runtime config; agy's real hook behaviour is only checkable by hand)

## Log

- L1 request: /flow:story 17
- L2 split: story 17 held about nine live checks (more than 3 criteria), so 17 → #39 (PreToolUse probe, payload, `ask`), #40 (Stop gate, session start), #41 (rules and skills sentinels, agents-dir `.bak-*`), #42 (subagent engram, `find_by_name`/`run_command`). #40 requires #39 because a bypassed probe makes its hook checks "unproven" too.
- L3 assumptions for approval: the installed agy is 1.4.12 while the installer pins 1.4.9, so results are recorded against 1.4.12; the user runs every agy session; no code changes, so no automated test and no `test:`/`fix:` commits.
- L4 pair (agy 1.4.12, Gemini 3.8 Flash; probe as its own `probe39` key, matcher `run_command`, logging the payload): `deny` under `--dangerously-skip-permissions` blocked `echo probe39-hola > /tmp/probe39.txt` ("tool call denied by pre-tool hook"), file not created, so the flag does not bypass hooks and nothing is "unproven". Without the flag `eza /tmp` got agy's own "Run this command?" prompt; the real payload replayed through the adapter answers `{"decision": "ask"}`. Payload carries `.toolCall.name` = `run_command` and `.toolCall.args.CommandLine`, where the adapter reads them; no mismatch, no new story. Probe removed; `jq -S` diff of `hooks.json` against the backup empty, keys `herdr`, `toolkit`.
- L5 commits: c68382a docs(multi-agent): record the agy PreToolUse live checks; 78f1a76 docs(multi-agent): note the probe answered ask during the eza check. `make check`: "All checks passed (7 steps)".
- L6 verifier: PASS (C1-C3 pass; caveat that the probe also answered `ask` during the `eza` check, recorded in 78f1a76).
- Risk: item 5, 6 (a temporary hook in agy's runtime config; agy's real hook behaviour is only checkable by hand)
