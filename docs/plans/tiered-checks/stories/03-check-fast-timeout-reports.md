# Story 03: A check-fast timeout is reported, not blocked

## Story

03. As a developer, I want a check-fast timeout reported without blocking the turn so that a slow machine never makes the agent fix healthy code. Requires: #01

## Acceptance criteria

- [ ] Given a trusted repo whose `make check-fast` runs past its 60 s limit, when a turn ends, then the turn ends without being blocked and a system message says `check-fast` timed out and shows the elapsed time.
- [ ] Given a `make check-fast` that fails for a real reason, or a fallback `make check` that times out, when a turn ends, then the turn is blocked with the failure tail exactly as today.

## Plan

- The hook tells a `check-fast` timeout (exit 124) apart from a real failure and turns only that case into a non-blocking system message with the elapsed time; the `check` fallback keeps its blocking 300 s timeout.
- A timed-out run is never cached as green, so the next turn end runs `check-fast` again.
- Tests reuse the stub `timeout` on `PATH` (records its arguments, exits 124; no environment override); the existing "a check-fast timeout blocks" case flips to the new behaviour; the hook header says a `check-fast` timeout reports.
- Release: bump the `toolkit` plugin and rerun `./install.sh`.

## Out of scope

- Changing the 60 s or 300 s limits, or making the `check` fallback timeout non-blocking.
- Any other hook message, the trust and red-marker rules, or the green cache key.
- `/flow:pair`, ship, the verifier, docs beyond the hook header, `NOTCH`, OpenCode or `delegate-local`.
- Antigravity: no adapter test and no `docs/multi-agent.md` note (L2); the adapter already stops when the hook exits 0, so it needs no change.

## Suggestions (your call)

- The hook already branches on `status -eq 124` for the blocking message; the new case can sit next to it, before the `stop_hook_active` check, so a timeout never counts as a block in the turn.

## Size

normal
Risk: item 3, 5 (the hook's behaviour on a `check-fast` timeout is the contract every trusted repo gets; hook and plugin release)

## Log

- L1 request: /flow:story 03
- Assumptions: "elapsed time" is the wall time the hook measured around `make check-fast`, in whole seconds; with the stub `timeout` it is near 0, so tests check that a number of seconds is shown, not its value. A timeout on a second stop in the same turn reports the same non-blocking message.
- L2 scope change (user, 2026-11-17): criterion 3 (Antigravity) dropped with its adapter test and docs note; the user mostly uses Claude and OpenCode and may drop agy support later (a separate `/flow:idea`). Branch `story/03-check-fast-timeout-reports` from `main`; safety net `require-check.test.sh` and `agy-require-check.test.sh` green before any change.
- L3 test list approved: 1. a check-fast timeout reports without blocking (replaces "a check-fast timeout blocks", pre-approved); 2. a timeout on a second stop reports the same message; 3. a check timeout still blocks with its 300 s message (pin). Docs: hook header. Release: toolkit 0.18.0, `./install.sh`.
- L4 steps: 74dd1d7 → cd47f8a (a `check-fast` timeout reports without blocking, never cached; red: 4 cases failed, hook exited 2; replaces "a check-fast timeout blocks", pre-approved); 7680211 pin (same message on a second stop; green at once since cd47f8a, fails on the 74dd1d7 hook); b7c484f pin (a `check` timeout keeps its blocking 300 s message; a mutant making every timeout non-blocking fails it); 772724b hook header; 79d079f toolkit 0.18.0 (`plugin.json` and `marketplace.json`).
- L5 full suite at 79d079f: `make check` "All checks passed (8 steps)".
- L6 verifier (flow:verifier): PASS. C1 PASS, C2 PASS, C3 n/a (dropped, L2); commit order, tamper check and assertions PASS; its own mutant (caching a timed-out run as green) was caught by two tests; `make check` "All checks passed (8 steps)". Refs and HEAD unchanged across the run.
- L7 release: `./install.sh` run from this branch after the verifier (user OK); `claude plugin list` shows toolkit 0.18.0 read from the working copy.
- Risk: item 3, 5 (the hook's behaviour on a `check-fast` timeout is the contract every trusted repo gets; hook and plugin release)
