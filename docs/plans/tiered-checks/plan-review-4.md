# Plan review: tiered-checks
Verdict: PASS WITH CHANGES
Summary: All 10 findings from review 3 are resolved in the plan text (release row, parallel shellcheck plus a non-blocking timeout, unsetting the mode variable, `# shellcheck source=` detection, the verifier check-3 line, deduplicated full runs, NOTCH branches, item numbers, the permissions template, the "dirty tree" wording). Two major gaps remain, and both would stop a MUST story partway. (1) The release bump breaks an existing exact-version test, which trips stop rule 3. (2) Both NOTCH stale branches hold real work, so the "delete when empty" path never applies and the trust step needs a user decision the plan has not taken yet. The rest are minor. The MUST work fits, since there is no deadline.

## Findings
| # | Category | Severity (blocker/major/minor) | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | Gap | major | The Release row bumps `flow`, but an existing test pins flow at exactly 0.10.1 in both `plugin.json` and the marketplace. Any flow bump turns `make check` red. The fix means changing an existing test, which is stop rule 3, and the plan does not pre-approve it. The toolkit pin was already relaxed to `at_least` for this exact reason, but flow's was not. | `scripts/tests/no-sdd.test.sh:35-37`; precedent `:43-47` and commit `44ea2b3`; plan Scope row "Release" | In the release story, pre-approve changing `:35-37` to `at_least 0.10.1` (the same pattern as `:45-47`) and list it in the approved test list. |
| 2 | Gap | major | Both NOTCH branches the plan wants to delete "when `git log main..<branch>` shows no own work" do have own work: `feat/27-wallpaper-foundation` has 72 commits and `feat/34-quick-wallpaper` has 149. So the "ask the user" path is certain. Merging `main` into a branch 149 commits behind can conflict, so trust (an acceptance criterion) can stall at the end of the last MUST story. Both local branches match their `origin/` counterparts, so deleting the local copies loses nothing. | Plan Scope row "`NOTCH`", Gap 11; NOTCH `git branch --no-merged main`, `git log --oneline main..<b> \| wc -l` = 72 / 149, `git branch -vv` shows no ahead/behind | Settle it now (question 1). Recommendation: delete the local branches, since they are on `origin`, and accept that checking one out later falls back to the full `check`. |
| 3 | Contradiction | minor | Platforms says clean-install row 105 "is updated at its next `/flow:fill-gaps`". The Docs row instead makes it a done criterion of the docs story (review 2 #11). After the clean-install handoff, that plan lives in a separate `clean-install-plan` repo reached through a symlink, so the edit must be committed there. | Plan line 19 vs Scope row "Docs"; `docs/plans/clean-install/plan.md:60` | Drop the fill-gaps clause on line 19. Say the clean-install edit is committed in whichever repo holds that plan at the time. Also update its gap 8 (`:139`), which cites idea 27. |
| 4 | Technical | minor | The OpenCode SHOULD says `make check-fast` "joins its auto-allowed commands" (Research line 31, `gen.sh:133`). That allow list belongs to the read-only `flow-verifier` subagent, not to the main OpenCode agent. The verifier never runs `check-fast`. | `scripts/gen-agents/gen.sh:114-134`, `:249` | Drop the auto-allow part of that row, or retarget it to wherever the main agent's permissions live. Fix Research line 31. |
| 5 | Technical | minor | The plan does not say how the `check-fast` recipe runs json/structure/settings/skills/workflows. If it reuses `check.sh` with a step subset (the natural way to get keep-going plus a summary), the planned `unset` in `check.sh` cancels the changed-files mode. `make lint` (`Makefile:8-10`) calls `check-shell.sh` directly, so a leaked variable still narrows it. | Plan Scope row "`AI` `check-fast`"; `Makefile:5-10`; `scripts/check.sh:5-15` | Have the recipe set the variable inline on the `check-shell.sh` call only (`VAR=1 bash scripts/check-shell.sh`), and call the other steps directly. If a `check.sh` subset is used, unset the variable only on the full path. |
| 6 | Gap | minor | Some rows name no high-risk item. The Docs row edits the `bootstrap`/`foundation` skills and templates (item 6). The NOTCH row adds a Makefile target and turns on a gate (item 5). The Release row bumps versions and runs `install.sh` (item 5). Line 86 lists only hook/Makefile/pair/ship. | Plan Scope rows "Docs", "`NOTCH`", "Release"; line 86; `pair/references/high-risk.md` items 5-6 | Add `Risk: item 6` to Docs and `Risk: item 5` to NOTCH and Release. Each then gets a verifier, per `pair` step 6. |
| 7 | Contradiction | minor | Release order contradicts the row text. The release comes right after the hook and `AI` `check-fast` (line 86), but the row names `pair`, `ship`, `delegate-local`, the verifier, `bootstrap` and `foundation` as the reason for the bumps, and none of those has changed yet. | Plan Scope row "Release"; line 86 order | Release bumps `toolkit` for the hook only. Each later skill story bumps its own plugin and reruns `./install.sh` (the row already hints at this). |
| 8 | Gap | minor | NOTCH `docs/architecture.md:99` describes the quality-gate recipe ("`make check` … read-only, non-interactive, in order"), but the NOTCH row does not update it. The plan updates the matching foundation template (`architecture.md:67-72`) for new repos only. | NOTCH `docs/architecture.md:72,99`; plan Scope row "`NOTCH`" | Add `docs/architecture.md:99` to the NOTCH story. |
| 9 | Gap | minor | On agy the non-blocking `check-fast` timeout is invisible. The adapter discards the hook's stdout, where the systemMessage goes, and returns `stop`. | `plugins/toolkit/hooks/agy/require-check.sh:23-24`; plan Core model "A `check-fast` timeout is reported" | Accept it and document it in `docs/multi-agent.md`, or pass the systemMessage into agy's stop reason if agy shows one. Add one agy test either way. |
| 10 | Gap | minor | The verifier's Hard Rules are pinned as whole lines (`grep -qxF`). If the long-run wording is folded into the existing Bash rule instead of added as a new line, `flow-verifier.test.sh` breaks (stop rule 3). One eval prompt ("make check passes. I already ran …") interacts with the new dedupe rule. | `scripts/tests/flow-verifier.test.sh:52-61`; `plugins/flow/evals/pair-empty-verifier-report/case.yaml:12` | Add the long-run wording as a new line under Checks, not inside Hard Rules. Re-grade that eval in the `pair` story. |
| 11 | Minor | minor | The gap table puts gap 9 after gaps 10-11. | Plan "Data gaps & assumptions" | Reorder. |

Prior review status: findings #1-#10 of `plan-review-3.md` are all resolved in the plan text (Scope rows 74-81, Core model lines 51-54, the resolution table at lines 165-179). Its unnamed risks are covered by the release row, the non-blocking timeout, the NOTCH `make fmt` note, the verifier line and the dedupe rule.

## Scope vs deadline
| Item | Est. dev-days | Cut (MUST/SHOULD/LATER) |
|---|---|---|
| Hook: `check-fast` preference, per-target cache, non-blocking timeout, stub-timeout tests, agy test | 0.75 | MUST |
| `AI` `check-fast`: inline mode variable, merge-base list, sourced-lib rule, parallel shellcheck, unset on the full path, tests, measurements | 0.8 | MUST |
| Release (toolkit bump, `install.sh`, demo 1 live, `no-sdd` pin relaxed) | 0.15 | MUST |
| `/flow:pair` + verifier (focused loop, regression round, dedupe, check-3 line, goldens, evals) | 0.8 | MUST |
| `toolkit:ship` | 0.25 | MUST |
| Docs (around 15 files, templates, goldens, clean-install rows) | 0.5 | MUST |
| `NOTCH` (+0.25 if gap 5 fails; plus the branch decision) | 0.35 | MUST |
| OpenCode rule | 0.15 | SHOULD |
| Slowest-five report | 0.25 | SHOULD |
| `delegate-local` | 0.25 | SHOULD |
| Background/remote runs | 0.5-1 | LATER |
Total MUST: about 3.6 (3.85) dev-days vs available: no deadline, solo, before clean-install stage 2 -> fits

SHOULD ranked by demo value: OpenCode rule (demo 1 in a second agent), then the slow-test report, then `delegate-local` (parked).

## Unnamed risks
- Stage 3 of clean-install runs `git init` in `AI`, which leaves no `HEAD` and no `origin/main`. Every turn then lints every script, and every flow bump goes through the `no-sdd` pin. Likelihood: certain during stage 3. Impact: time only, once shellcheck runs in parallel. Mitigation: the full-lint measurement already planned, plus finding 1.
- Under load, a `check-fast` timeout is never cached, so every stop waits the full 60 s and then passes. Turns get slower with no red shown. Likelihood: low-medium. Mitigation: show the elapsed time in the systemMessage, so the user sees it and can run `SKIP_REQUIRE_CHECK=1` or wait for the load to drop.
- The NOTCH trust step stalls at the end of the plan because of the branch decision. Story 44 is also in progress, and the NOTCH story waits for it. Likelihood: high. Mitigation: finding 2 and question 1, decided now.
- The verifier's self-reported `Test command:` result now replaces pair's own final run. A verifier that ran a shard, or timed out without saying so, lets an unproven tree through to the merge offer. Likelihood: low. Mitigation: the verifier's run counts only when its report shows the command and a pass line; otherwise pair reruns.

## Questions for the user (max 5)
1. NOTCH `feat/27-wallpaper-foundation` (72 own commits) and `feat/34-quick-wallpaper` (149) are both pushed and match `origin`. Before trusting NOTCH, may their local copies be deleted? Why it matters: trust waits on them, and merging `main` into a branch that far behind can conflict. Recommendation: delete the local branches. They stay on `origin`, and checking one out later simply falls back to the full `check`.

Recommendations I resolved myself (technical):
- In the release story, pre-approve relaxing `scripts/tests/no-sdd.test.sh:35-37` to `at_least`.
- Release bumps toolkit only; each skill story bumps its own plugin.
- The `check-fast` recipe sets the mode variable inline on `check-shell.sh` only.
- Drop the OpenCode auto-allow claim, since `gen.sh:133` is the verifier's list.
- Add `Risk:` items to the Docs, NOTCH and Release rows.
- Add NOTCH `docs/architecture.md:99` to the NOTCH story.
- Add the verifier's long-run wording as a new line, not an edit of a pinned Hard Rule.
- Remove the stale fill-gaps clause on plan line 19.
