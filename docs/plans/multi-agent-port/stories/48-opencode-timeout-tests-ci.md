# Story 48: OpenCode hook-timeout tests pass on the CI runner

## Story

48. As a developer, I want the OpenCode hook-timeout tests to pass on the CI runner under the parallel suite while still proving each hook is cut off at its timeout, so that `main` is green again and a real failure is not hidden by a known flake (CI red since d3993c5: "the pack hint is cut off at its 2 s timeout (took 4s)", "the pause hook ... (took 7s)"). Requires: #34

## Acceptance criteria

- [x] Given the full parallel `make check` on a single CPU (the CI-like setup that reproduced the pack-hint flake in #514), when it runs twice in a row, then every OpenCode hook-timeout case passes both times.
- [x] Given a hook that is no longer cut off at its timeout (the cut-off removed by hand), when the OpenCode plugin tests run, then the matching timeout case fails, so the tests still prove the cut-off.
- [x] Given the fix on `main`, when GitHub Actions runs `check`, then it is green (manual check).

## Plan

- First reproduce the red on one CPU with the full parallel suite, to confirm the cause is the time the whole case takes under load (plugin start-up and the other hooks), not the cut-off itself.
- Change how the timeout cases judge "cut off": the limit must leave room for start-up under load but stay well below how long the stub hook hangs, so a missing cut-off still fails.
- Prove the second criterion by hand with the cut-off removed, then restore it.
- Push and watch the CI run.

## Out of scope

- The hooks' own timeout values in the hooks config, and the plugin's cut-off code.
- The `look` plugin test that also failed once on CI (d3993c5); a new story if it fails again.
- Making the whole suite serial.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 4, 5 (timing under parallel test runs; the CI check)

## Log

- L1 request: "si, y luego vamos con el timeout de opencode"
- L2 assumptions for approval: the cause is the margin (timeout + 2 s) measured over the whole case while the suite runs in parallel, as in #514; reproduction with `docker --cpus=1`; changing the existing timeout cases is the point of the story, so the pair test list will name each changed assertion for approval.
- L3 approved: "si, aprobado".
- L4 red (approved list, no test commit: the failing cases already exist): full `make check` in `archlinux:latest` with `docker --cpus=1` (CI's tool set, no Claude Code): "the pack hint is cut off at its 2 s timeout (took 5s)", "the pause hook ... (took 9s)", "the shell check is cut off at the 10 s default (took 12s)". Also failing there, out of scope: `plugins/toolkit/hooks/tests/pack-hint.test.sh` (parallel-sessions and fallback cases; green on CI).
- L5 fix a32d3dc: hanging stub 20 s → 60 s; limits 4/7/12 s → 12/15/20 s (timeout + 10 s), approved in the test list. Two full `make check` runs in the same 1-CPU container: the OpenCode plugin tests passed both times (only `pack-hint.test.sh` failed, as before). Local `make check`: "All checks passed (7 steps)".
- L6 mutation (criterion 2): the plugin's `spawnSync` `timeout` removed by hand: the three cases failed (took 180s, 241s, 120s); the plugin was restored with `git checkout`.
- L7 verifier: PASS (C1 from the logged container runs, C2 from the 60 s stub against the 20 s limit; plugin code unchanged vs main).
- L8 manual (criterion 3): merged as e3051fe and pushed; GitHub Actions run 41542453058 on `main`: check success, recovery success.
- Risk: item 4, 5 (timing under parallel test runs; the CI check)
