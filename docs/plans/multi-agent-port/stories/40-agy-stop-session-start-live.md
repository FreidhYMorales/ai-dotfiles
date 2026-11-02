# Story 40: the Antigravity Stop gate and session-start hook in a real session

## Story

40. As a developer, I want the Antigravity Stop gate and session-start hook checked in a real agy session (the gate continues on a failing check, lets a cancel stop, and what `executionNum` counts; the session-start context arrives) so that agy's turn end and session start rest on proven behaviour. Requires: #06, #18, #39

## Acceptance criteria

- [ ] Given a throwaway repo with uncommitted changes and a `make check` that fails, when agy ends a turn without a tool call, then agy continues with the check's failure as the reason and the next turn end is let stop (no trap), and `docs/multi-agent.md` records the real Stop payloads and what `executionNum` counts over two user turns in the same session (manual check).
- [ ] Given the same repo, when the user cancels a running turn, then agy stops without the gate holding it, and the recorded `terminationReason` of that payload is not `NO_TOOL_CALL` (manual check).
- [ ] Given the toolkit hooks installed, when a new agy session starts in a workspace, then the model can quote the session-start context (host info), and the recorded SessionStart payload carries `workspacePaths` where the adapter reads it (manual check).

## Plan

- Back up agy's `hooks.json`, add a logging probe for Stop and SessionStart as its own key next to `toolkit` (as in #39), remove it at the end and compare with the backup.
- Claude prepares the throwaway repo (git, a dirty file, a failing `check` target slow enough to cancel) and the probe; the user runs agy, under `--dangerously-skip-permissions` if they like (#39 proved the flag does not bypass hooks).
- Claude reads the payload log, replays the real payloads through the adapters and records each check with the agy version in the "Antigravity hooks" part of `docs/multi-agent.md`.
- A mismatch between agy's real behaviour and what the adapters assume (for example `executionNum` counting user turns, so a second turn's failing check is never gated) is recorded and becomes a new backlog story; it is not fixed here.

## Out of scope

- Any change to the adapters, the Claude hooks, the installer or the version pin.
- PreToolUse (done in #39); rules and skills sentinels, `.bak-*` in the agents dir (#41); subagent engram and registry tools (#42).
- The `/flow:pair` red-marker path in agy (covered by #06's golden test).

## Suggestions (your call)

- Make the probe answer nothing that decides (`{}`) for Stop, so only the toolkit gate decides continue or stop; if agy rejects `{}`, record it and drop the probe from Stop, relying on the replay.

## Size

normal
Risk: item 5, 6 (a temporary hook in agy's runtime config; agy's real Stop and session-start behaviour is only checkable by hand)

## Log

- L1 request: /flow:story 40
- L2 assumptions for approval: run on the installed agy 1.4.12; the user runs every agy session; no code changes, so no automated test and no `test:`/`fix:` commits; the cleanup of the probe is checked like #39's (backup diff empty) though it is not its own criterion, to stay at three.
- L3 pair (agy 1.4.12): C1 fail of agy vs adapter: every normal turn end sends `executionNum: 0`, the adapter gates only ≥ 1, so `make check` never runs; after a probe-forced `continue` the toolkit gate ran (inferred `executionNum` 1) and the next Stop carried 2; recorded in 3707a16, backlog #43 added. C2: esc stopped agy, no Stop hook ran at all (agy had moved `sleep 60` to a background task). C3 pass: SessionStart injection quoted by the model. Probe removed, `hooks.json` diff against the backup empty. `make check`: "All checks passed (7 steps)".
- L4 verifier: NEEDS DECISION: the doc is accurate; the user decides whether to close with C1 handed to #43 and C2's `terminationReason` clause met vacuously. Notes: say `executionNum` 1 is inferred, mention the background task; #43 as written skips the check after a continue forced by another Stop hook.
