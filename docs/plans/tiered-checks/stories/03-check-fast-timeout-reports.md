# Story 03: A check-fast timeout is reported, not blocked

## Story

03. As a developer, I want a check-fast timeout reported without blocking the turn so that a slow machine never makes the agent fix healthy code. Requires: #01

## Acceptance criteria

- [ ] Given a trusted repo whose `make check-fast` runs past its 60 s limit, when a turn ends, then the turn ends without being blocked and a system message says `check-fast` timed out and shows the elapsed time.
- [ ] Given a `make check-fast` that fails for a real reason, or a fallback `make check` that times out, when a turn ends, then the turn is blocked with the failure tail exactly as today.
- [ ] Given Antigravity and a `check-fast` timeout, when a turn ends, then agy stops without continuing the turn, and `docs/multi-agent.md` says agy does not show the timeout message.

## Plan

- The hook tells a `check-fast` timeout (exit 124) apart from a real failure and turns only that case into a non-blocking system message with the elapsed time; the `check` fallback keeps its blocking 300 s timeout.
- A timed-out run is never cached as green, so the next turn end runs `check-fast` again.
- The agy adapter passes the non-blocking result through as a stop; one adapter test pins it and `docs/multi-agent.md` notes the dropped message.
- Tests reuse the stub `timeout` on `PATH` (records its arguments, exits 124; no environment override); the existing "a check-fast timeout blocks" case flips to the new behaviour; the hook header says a `check-fast` timeout reports.
- Release: bump the `toolkit` plugin and rerun `./install.sh`.

## Out of scope

- Changing the 60 s or 300 s limits, or making the `check` fallback timeout non-blocking.
- Any other hook message, the trust and red-marker rules, or the green cache key.
- `/flow:pair`, ship, the verifier, docs beyond the hook header and the agy note, `NOTCH`, OpenCode or `delegate-local`.

## Suggestions (your call)

- The hook already branches on `status -eq 124` for the blocking message; the new case can sit next to it, before the `stop_hook_active` check, so a timeout never counts as a block in the turn.

## Size

normal
Risk: item 3, 5 (the hook's behaviour on a `check-fast` timeout is the contract every trusted repo gets; hook and plugin release)

## Log

- L1 request: /flow:story 03
- Assumptions: "elapsed time" is the wall time the hook measured around `make check-fast`, in whole seconds; with the stub `timeout` it is near 0, so tests check that a number of seconds is shown, not its value. A timeout on a second stop in the same turn reports the same non-blocking message.
