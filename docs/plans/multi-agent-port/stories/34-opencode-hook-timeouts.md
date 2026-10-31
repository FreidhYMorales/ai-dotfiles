# Story 34: OpenCode hooks cut off at their timeouts

## Story

34. As a developer, I want each OpenCode hook cut off at its timeout, with a timed-out shell check letting the call through, so that a stuck hook never freezes an OpenCode session. Requires: #19, #20

## Acceptance criteria

- [ ] Given a session-start or pause hook that hangs, when OpenCode builds a session's context, then that hook is stopped at its timeout from the Claude hooks config (host-info 5 s, pack-hint 2 s, backup-status 5 s, pause 5 s) and the session goes on without its text.
- [ ] Given the shell check (`prefer-modern-cli`, no timeout in the Claude config) hangs, when OpenCode runs a shell command, then the check is stopped after 10 s and the command runs (fail open, like the Claude hook).
- [ ] Given a hook that answers in time, when it runs, then its result is unchanged: a legacy command is still blocked and the session-start and pause texts still arrive.

## Plan

- Each hook call in the OpenCode plugin gets the per-hook timeout of the Claude hooks config, with a 10 s default for a hook that has none.
- A timed-out shell check counts as "allow"; a malformed shell call still blocks, as today.
- A timed-out context hook says nothing, the same path as a hook that fails today.
- One plugin test with a hanging hook pins that it is cut off and the direction it fails; the existing plugin tests stay unchanged.
- Fix the plugin header's OpenCode version (2.1.4 → 2.2.2), as the plan's R6-9 assigns to this work.

## Out of scope

- The installer hardening split out to #35 and #36.
- agy hook timeouts (already copied into the agy `toolkit` key).
- A `require-check` Stop hook in OpenCode: OpenCode closes work through its `AGENTS.md` rule (#31).
- Changing the timeouts themselves in the Claude hooks config.

## Suggestions (your call)

- Read the timeouts from the Claude hooks config at load time instead of copying the numbers: the plan calls them "the per-hook values of `plugins/toolkit/hooks/hooks.json`", one source cannot drift, and a test can point the plugin at a stub hooks dir with short timeouts so the hang test stays fast.

## Size

normal
Risk: item 5 (OpenCode runtime plugin; a timed-out shell check now lets the call through)

## Log

- L1 request: /flow:story 22
- L2 split: #22 held five independent changes (OpenCode hook timeouts, three agy installer fixes, prune outside the repo); split into #34, #35, #36 and #34 refined first.
- L3 test list approved: three hang tests (pack-hint 2 s, pause 5 s, shell check 10 s default); criterion 3 covered by the existing plugin tests, unchanged. Timeouts read from the Claude hooks config at load time.
- L4 commits: 2891cee test → 7950056 feat (session-start); ee7863c test → 2a7f061 feat (pause); 6a83bdd test → 11bb719 feat (shell check, fail open); 2d4916f docs (header 2.2.2).
- L5 decision: hangs are simulated with a PATH `jq` that sleeps only inside the hook named by HANG_HOOK; an `ai-pack` stub was trivially green because pack-hint.sh already cuts ai-pack at 1.5 s.
- L6 evidence: `bash plugins/toolkit/opencode/tests/toolkit.test.sh` → "All cases passed" (~20 s); `make check` → "All checks passed (7 steps)", also twice under `taskset -c 0` (one CPU, the PR #9 flake setup).
- L7 verifier: PASS. Optional notes: host-info and backup-status timeouts are not pinned on their own; the timing bounds have 2 s slack under parallel `make check`.
- Risk: item 5 (OpenCode runtime plugin; a timed-out shell check now lets the call through)
