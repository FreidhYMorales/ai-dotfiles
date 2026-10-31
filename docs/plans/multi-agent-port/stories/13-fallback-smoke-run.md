# Story 13: recorded smoke run of the fallback

## Story

13. As a developer, I want a recorded smoke run of a high-risk story in OpenCode and Antigravity so that I trust the fallback before I need it. Requires: #27, #28, #29, #30, #31, #32, #12

## Acceptance criteria

- [ ] Given a fresh `./install.sh`, a restarted OpenCode service and a throwaway toy repo with one high-risk story, when I run `/flow-backlog` → `/flow-story` → `/flow-pair` in OpenCode with the reviewer role on a strong model, then the `flow-verifier` subagent runs and returns a verdict, and the run is recorded in `docs/multi-agent.md`.
- [ ] Given the same toy repo in Antigravity, when I run `/flow-plan-review` and the same loop, then the reviewer returns a review and the high-risk story ends in NEEDS DECISION; without agy quota the agy half is recorded "format-verified, run pending" instead.
- [ ] Given the three agents, when each tries `ls` and when an engram observation saved in OpenCode is searched from Antigravity and Claude, then `ls` is blocked in all three, the observation is found, and each result is recorded per agent.

## Plan

- Re-run `./install.sh` and restart the OpenCode service before anything else (R4 risks: live install drift, stale service).
- Build the toy repo in the scratchpad: a tiny CLI with one function, a `make check`, and one story that touches an install-like or input-reaching change so it is high risk.
- Drive OpenCode non-interactively where it can be driven; the agy half needs the user's quota and may be run by the user.
- Record per target in `docs/multi-agent.md`: agent version, commands, verifier or reviewer verdict, the three demo checks, pass/fail; OpenCode `/flow-plan-review` is already recorded (#08 L6) and is referenced, not repeated.
- A failure found during the run is recorded and becomes a new backlog story; it is not fixed inside this one.

## Out of scope

- Fixing any defect the smoke reveals (new stories via `/flow:idea` or the backlog).
- The real agy checks of #17 (hook payloads, Stop gate, sentinels on 1.4.9, registry tools).
- Remaining OpenCode commands (#14) and the README/install.sh header docs (#15).
- Committing the toy repo or making the smoke an automated test.

## Suggestions (your call)

- Keep the per-target result as one small table in `docs/multi-agent.md`, like the sentinel tables already there, so #15 can link it.

## Size

normal
Risk: item 6 (a live multi-agent run no test here can pin)

## Log

- L1 request: /flow:story 13
- Assumption: the agy half may close as "format-verified, run pending" when agy quota is out (plan item 8, R4-Q2); this story still closes.
- Assumption: the toy repo lives in the scratchpad and is never committed (plan "Toy repo").
- Assumption: `opencode run --standalone` can be driven from the shell as in #08 L6; agy runs need the user.
- Assumption: the reviewer ran on `opencode/big-pickle` (user's pick; `opencode/nemotron-3-ultra-free` no longer exists in the catalog); `models.json` left at `inherit`.
- C1 (OpenCode 2.2.2): pass. `/flow-backlog`, `/flow-story 01` (Risk: item 2), `/flow-pair 01` (user-run; Claude auto mode refused to launch `opencode run --auto` for pair): toy commits e5eb168→ec8ccb7, 2fb1169→7723abd, 182b300, 97d2683; `flow-verifier` subagent ran, PASS; no red marker. The raw verifier `Verdict:` line is not recoverable (`opencode export` does not exist in 2.2.2).
- C2 (agy 1.4.9, user-run, Gemini 3.8 Flash): `/flow-plan-review` pass (subagent, PASS WITH CHANGES, `plan-review-1.md`; the no-plan gate also held). `/flow-pair 02` FAIL: the `flow-verifier` subagent (conversation 10bbf01e) made only engram calls (14 `mem_search`, 5 `mem_context`), no command, yet reported `make check` passed and `Verdict: PASS`; pair closed the story instead of NEEDS DECISION. Defect → backlog #37. agy asked for approval on almost every command.
- C3: `ls` blocked in OpenCode (also `sed`) and Claude; in agy not exercised (model chose `eza`), left to #17. Engram obs #961-963 saved in OpenCode found from Claude and agy (#962): pass.
- Recorded in `docs/multi-agent.md` "Smoke run".
- C2 evidence: the `make check` runs the user approved were the main agy session (38e7d3d2); the verifier (10bbf01e) reasoned "The absence of a bash tool prevents running `make check` directly" and "a line-by-line analysis ... to bypass the missing tool constraint", then still wrote `make check` pass, against its rubric (a check it could not run is NEEDS DECISION).
- Re-run after #37 (agy 1.4.12, warning shown by install; Gemini 3.8 Flash; toy story 03, Risk: item 2, 3): the session loaded the new check step (4× "stop with NEEDS DECISION, do not run the `flow-verifier` agent and leave the story open", 0× the old clause), yet the main agent still spawned `flow-verifier`; the verifier (conversation fdeb8177) again reasoned "absence of a bash tool creates the NEEDS DECISION verdict" and wrote `Verdict: PASS`; pair closed the story (toy f68c7ab). C2 still FAIL: the prompt-only fix is not obeyed by this model.
