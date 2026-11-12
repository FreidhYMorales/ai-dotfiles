# Plan review: tiered-checks
Verdict: PASS WITH CHANGES
Summary: The plan text resolves all 11 findings from review 4: the `no-sdd` pin is pre-approved, the NOTCH branches are settled, the fill-gaps clause is gone, OpenCode auto-allow is dropped, the mode variable is set inline, and the Risk items and the verifier line are added. One new major finding. The generator rewrites the `pair` skill for agy and OpenCode by matching its exact step 6 sentence and its step 7 number, and a test pins both. The `pair` story rewrites exactly those steps, so it can hit stop rule 3 halfway through, or silently drop the agy NEEDS DECISION guard. The other findings are minor. The MUST work fits, since there is no deadline.

## Findings
| # | Category | Severity (blocker/major/minor) | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | Gap | major | The generator matches `pair` text in two places. The agy NEEDS DECISION guard (#38, the fake-PASS fix) is a `sed` on the step 6 sentence "invoke the `flow-verifier` agent on the story diff…; if it is not available…". The Claude-only `make eval pending` line is anchored on `^7\. \*\*Done\.\*\*`. Tests pin both outputs: the step-7 regex at `gen-agents.test.sh:184-185` and the agy check-step text at `:347-349`. The `pair` row rewrites step 4.3 and step 6 (final-tree run, regression round, dedupe). If the regression round becomes its own step, Done becomes step 8 and `:185` fails. Changing that test trips stop rule 3, and the plan does not pre-approve it. Rewording the verifier sentence stops the agy `sed` from matching. The plan only names "goldens regenerated". | `scripts/gen-agents/gen.sh:63,80-81`; `scripts/tests/gen-agents.test.sh:184-185,347-349`; plan Scope row "`/flow:pair`" | In the `pair` row, add these rules: keep the step numbers (put the regression round inside step 6) and keep the verifier sentence word for word, or update the `gen.sh` `sed` patterns in the same story. If renumbering cannot be avoided, pre-approve the change to `:185` in the story, as the Release row does for `no-sdd`. |
| 2 | Contradiction | minor | The Docs story changes the hook's trust and red-marker messages in `require-check.sh`. That file is a toolkit hook (high-risk items 3 and 5) with message tests, but the Docs row names only item 6. The Docs story also runs after Release, so the change needs another toolkit bump. "Skill bumps follow the release rule" does not cover a hook. | Plan Scope row "Docs" ("the hook header and its trust and red-marker messages"); `require-check.sh:2-8,42,68`; `require-check.test.sh:92,137` | Move the hook header and message edits into the hook story, which already edits and tests that file, before Release. |
| 3 | Contradiction | minor | The slow-test report "answers idea 27's question". Idea 27 asks why `make check` *with a bench change* runs about 100 s longer. Bench validation (about 135 s) runs in `check-bench.sh`, not in `make test`, so a top-five list of test files cannot explain it. | Plan Scope row "`make test` prints the five slowest"; `docs/ideas.md:291,293`; `scripts/check.sh:9` | Reword it as "shows where the tests step spends its time". Leave idea 27's bench question open, or have the report print step times for each `check.sh` step too. |
| 4 | Contradiction | minor | Demo 2 says "runs the suite once at the end". Every MUST story here is high risk, so pair runs `Test command:` in step 6 and the verifier always runs it again (Check 1). That is at least two full runs per story. The dedupe rule only skips a third run. | Plan "Demo priorities" 2, Core model; `plugins/flow/agents/verifier.md` Checks 1 | State it plainly: "once, plus the verifier's run for high-risk stories". Or settle question 1. |
| 5 | Technical | minor | "A full run is repeated only when code or tests changed since the last green full run" gives no way to decide. In `AI`, `check` also lints and validates docs and skills, so whether a change is "code or tests" is a judgement call. | Plan Scope row "`/flow:pair`" | Define it: record the HEAD sha of the green run; rerun when the tree is dirty or when `git diff --name-only <sha>` lists anything other than the story file and the backlog. |
| 6 | Gap | minor | NOTCH `docs/architecture.md:109` lists the Make targets (`check`, `fmt`, `fmt-check`, `lint`, `test`, `smoke`) and would not name `check-fast`. | NOTCH `docs/architecture.md:109`; plan Scope row "`NOTCH`" | Add `:109` to the NOTCH row. |
| 7 | Gap | minor | The Docs story must make the clean-install `SYS` gate row "name `check-fast`", but nothing says what `SYS`'s fast tier contains. The `SYS` gate holds `bash -n`, shellcheck, shfmt, a test and a dry-run deploy, so this edit scopes another plan's MUST row. | Plan line 19, Scope row "Docs"; `docs/plans/clean-install/plan.md:105` | Write the contents into that row: `check-fast` = `bash -n`, shellcheck and `shfmt -d`; the test and the dry-run stay in `check`. |
| 8 | Technical | minor | Core model says the agy adapter "parses" today's wording. It does not: it passes the hook's stderr through as `reason`. Only its test pins the prefix with `startswith("make check failed")`. The constraint holds, but for a different reason. | `plugins/toolkit/hooks/agy/require-check.sh:24-26`; `agy-require-check.test.sh:49` | Reword it: "which the agy adapter test pins". |
| 9 | Gap | minor | The hook story adds branches (`check-fast` selection, a non-blocking 124) to a file that is in the `make mutate` list. Mutation runs are outside `make check`, and idea 22 already tracks hook mutation survivors. | `Makefile` `HOOKS ?= … require-check …`; `docs/ideas.md` §22 | Add `make mutate HOOKS=require-check` to the hook story's evidence (log only, not a gate). |

Prior review status: all findings #1-#11 of `plan-review-4.md` are resolved in the plan text. You can see them in the Release row (pin relaxed), the NOTCH row (local branches deleted after the `-vv` check), line 19, Research line 31, the inline variable in the `AI` row, the Risk items on every row, Release bumping toolkit only, NOTCH `architecture.md:99`, the agy note in `docs/multi-agent.md`, the verifier line placed outside Hard Rules, and the gap table order. Review 4's unnamed risks are covered by the elapsed time in the timeout message and the rule that the verifier's run counts only when its pass line is shown.

## Scope vs deadline
| Item | Est. dev-days | Cut (MUST/SHOULD/LATER) |
|---|---|---|
| Hook: `check-fast` preference, per-target cache, non-blocking timeout, stub-timeout tests, agy test (+ hook messages from finding 2) | 0.8 | MUST |
| `AI` `check-fast`: changed-files mode, sourced-lib rule, parallel shellcheck, unset on the full path, tests, measurements | 0.8 | MUST |
| Release: toolkit bump, `install.sh`, `no-sdd` pin relaxed, demo 1 live | 0.15 | MUST |
| `/flow:pair` + verifier: focused loop, regression round, dedupe, check-3 line, `gen.sh` patterns (finding 1), goldens, evals | 1.0 | MUST |
| `toolkit:ship` | 0.25 | MUST |
| Docs: about 15 files, templates, goldens, clean-install rows | 0.45 | MUST |
| `NOTCH` (+0.25 if gap 5 fails) | 0.35 | MUST |
| OpenCode rule | 0.15 | SHOULD |
| Slowest-five report | 0.25 | SHOULD |
| `delegate-local` | 0.25 | SHOULD |
| Background or remote runs | 0.5-1 | LATER |

Total MUST: about 3.8 (4.05 if NOTCH needs the changed-files mode) dev-days vs available: no deadline, solo, before clean-install stage 2 -> fits

SHOULD ranked by demo value: the OpenCode rule (demo 1 in a second agent), then the slow-test report, then `delegate-local` (parked).

## Unnamed risks
- **The new hook needs a new session.** Claude Code loads hooks at session start, so after Release plus `./install.sh` the current session keeps running the old 300 s hook. Demo 1 can then look broken. Likelihood: high. Mitigation: the Release row checks demo 1 in a new session.
- **agy runs the hook from the working copy.** The adapter calls the hook from `$REPO_DIR` (`install.sh:430-436`), not from the installed plugin. In agy, whatever branch is checked out in `AI` is the live hook, so the half-built hook story is live before Release, and "checked on the installed plugin" does not apply to agy. Likelihood: medium, if agy is used during the plan. Mitigation: say so in the Release row and avoid agy sessions in `AI` while the hook story is open.
- **NOTCH may already fail its fast tier.** If `lint-qml` or `fmt-check` is not green on NOTCH `main` today, then once trust is set every dirty turn blocks on problems the story did not cause. Likelihood: unknown (unmeasured, gap 5). Mitigation: in the NOTCH story, run `make fmt-check lint` on `main` first and make "green on main" an acceptance precondition before trust is set.
- **A merge to `main` goes untested until ship or CI.** After a `--no-ff` merge into a `main` that moved, nothing runs the suite on the merged result, and the hook sees a clean tree and skips. Likelihood: low, since stories run one at a time. Mitigation: accepted by gap 6; mention it in the docs line on what a green hook means.
- **The plan folder is not committed.** `docs/plans/tiered-checks/` is untracked, and the clean-install plan has uncommitted edits that the Docs story will edit too. Likelihood: medium. Mitigation: commit both before handoff.

## Questions for the user (max 5)
1. In a high-risk `pair` story, should pair skip its own full `Test command:` run before the verifier and use the verifier's result when its report shows the command and a pass line? Why it matters: every MUST story here is high risk, so each one pays for two full suites (about 3 min each) at the end, which goes against demo 2. Recommendation: keep both. The verifier is independent, and pair's own run is the one that catches a red suite before the regression round. Just reword demo 2 (finding 4).

Recommendations I resolved myself (technical):
- Keep pair's step numbers and the exact verifier sentence, or update the `gen.sh` patterns in the same story (finding 1).
- Move the hook message and header edits into the hook story (finding 2).
- Define "changed since the last green full run" by HEAD sha plus a dirty-tree check (finding 5).
- Spell out `SYS`'s `check-fast` contents in the clean-install row (finding 7).
- Log a `make mutate HOOKS=require-check` run in the hook story (finding 9).
