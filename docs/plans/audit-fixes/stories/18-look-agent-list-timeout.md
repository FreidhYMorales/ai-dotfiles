# Story 18: Stop the look agent.list test from failing at the 5 s watchdog

## Story

18. As the dotfiles owner, I want the look test "an agent missing from agent.list on two polls in a row is stopped" to stop failing CI at the 5 s watchdog, so that a red run means something again. (idea 19, from #15)

## Acceptance criteria

- [ ] Given the look test "an agent missing from agent.list on two polls in a row is stopped, with no alert", when it runs on a slow runner, then it has the same 30 s budget as the other polling look tests instead of the 5 s default, and a check in `make check` fails if that case loses it.
- [ ] Given the agent tracking it covers is broken (Ghost never stopped, or an alert raised), when the look tests run, then that case still fails.

## Plan

- Give that one case the 30 s budget the other polling look tests already declare.
- Pin it with a structural check run by `make check`, red first, so the budget cannot silently go away.
- Prove criterion 2 with a deliberate break of the stop logic (mutant), run once, then reverted; no new look test.

## Out of scope

- Other look cases without a budget, in `agent.test.tsx` or elsewhere.
- Changing the harness's 5 s default, the CI workflow or the pinned Claude Code version.
- Any change to the agent tracking code itself.

## Suggestions (your call)

- Assumption: the fix is the budget only; the CI failure was `(fail) ... [5030.28ms]` and green on rerun, and locally look runs 74/74 in 1.57 s, so there is no logic bug to chase.
- Story 01 (L3) found that look cases without a budget hit the watchdog and "the failing case varies"; the neighbour "the 60 s agent.list poll finishes an agent whose notification never came" advances the clock the same way and has no budget either. Adding it there too would widen this story; say so if you want it.
- Assumption: Risk none: test-only change, pinned by a check that runs here; the CI flake itself cannot be reproduced locally, so the only proof on CI is the next green runs.

## Size

small
Risk: none

## Log

- L1 request: /flow:story 18
- L2 approved (user, 2026-11-04), scope: that one case only.
- L3 test list approved (2): a structural check in a new `look-budgets.test.sh`, and a one-off mutant for criterion 2. Mode C.
- L4 commits: e327f84 test (red: "FAIL agent.list two-polls case has the 30 s budget") → 2be9666 fix.
- L5 evidence: `look-budgets.test.sh` "All cases passed"; look suite "74 pass, 0 fail"; `make check` "All checks passed (7 steps)"; tamper check empty.
- L6 criterion 2: mutant `missed < 2` → `missed < 3` in the look ingest poll made the case fail on its assertions in 245 ms ("73 pass, 1 fail"); reverted, tree clean.
- L7 Risk: none (no verifier).
- L8 after close: CI run 41917612081 (1a5a0f2) failed on the neighbouring case "the 60 s agent.list poll finishes an agent whose notification never came" [5033.65ms]; the one-case scope was too narrow. Follow-up: story 19 (idea 21).
