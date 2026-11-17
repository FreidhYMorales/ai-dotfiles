# Plan review: retire-antigravity
Verdict: PASS WITH CHANGES
Summary: All nine plan-review-1 findings and both of its questions are resolved in the plan. The resolutions sit in "Plan-review resolutions" and the Scope rows, and I spot-checked them against the code. One new major problem: the Installer row names a deletion range in `ai-update.test.sh` that also holds the OpenCode regeneration tests. The other new findings are minor and are about how the new structural tests are written.

## Findings
| # | Category | Severity (blocker/major/minor) | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | Technical correctness (test scope) | major | The Installer row says agy cases leave `ai-update (:128, :723-765)`. That range is not agy-only. It also holds the OpenCode regeneration cases (`regen-opencode` :725-737), the failed-generation case (`regen-fail` :749-753) and the "nothing installed" case (`regen-none` :761-764). Followed literally, the range deletes OpenCode coverage of `regenerate_agents`, which is a delivery path (high-risk item 5). | Plan "Scope" row 1; `scripts/tests/ai-update.test.sh:723-765` | Replace the range with the agy cases only. Delete `regen-agy` (:739-742). Rewrite `regen-both` (:744-747) so it expects `--target opencode`; this is the RED case the row already names. Remove the `.gemini` mkdir from `regen-check` (:756). Rename the section header (:723). Keep `regen-opencode`, `regen-fail` and `regen-none`. |
| 2 | Gap (RED coverage) | minor | The ai-update RED only covers "Antigravity dir plus OpenCode passes `--target opencode`". Nothing pins the case where only `~/.gemini/antigravity-cli` exists. After the change, `install.sh` should not run at all in that case. Today's `regen-agy` case is deleted, not turned into this check. | Plan "Scope" row 1; `bin/ai-update:376-379`; `scripts/tests/ai-update.test.sh:739-742` | Turn `regen-agy` into "Antigravity dir only: nothing is regenerated" with `no_install`, instead of deleting it. |
| 3 | Technical correctness (new test) | minor | The `no-agy` scan's exclusion list (`docs/plans/`, `docs/ideas.md`, `packs/vendor/`) leaves out the test file itself. That file has to contain `agy`/`antigravity`, so the scan would always fail. The plan also asks for no guard against a scan that finds nothing. The `no-openspec` test it copies has both: it excludes itself and checks that the scan sees `docs/ideas.md`. | Plan "Scope" row 4; `scripts/tests/no-openspec.test.sh:42-46` | Add `scripts/tests/no-agy.test.sh` to the exclusions. Add the guard that the raw scan still sees `docs/ideas.md`. |
| 4 | Technical correctness (new test) | minor | The Toolkit RED pins "both manifests say 0.22.0" with no file and no comparison named. An exact-equality check breaks on the next toolkit bump. The repo's convention is `at_least` in `no-sdd.test.sh`. | Plan "Scope" row 3; `scripts/tests/no-sdd.test.sh:65-68` | Put the case in `no-sdd.test.sh` (or the new `no-agy.test.sh`) using `at_least 0.22.0`, plus `test ! -e plugins/toolkit/hooks/agy`. |
| 5 | Gap (ordering) | minor | `no-openspec.test.sh:37` asserts that `golden/antigravity/skills` exists. The Generator row edits it, which is correct. But the Toolkit and Docs rows depend on Generator, and the plan states the order without saying the Docs `no-agy` test must come last, after every agy edit. It is implied but not explicit, and an early `no-agy` RED would stay red across stories. | Plan "Scope" order line; `scripts/tests/no-openspec.test.sh:37` | One phrase in row 4: the `no-agy` test is written in the Docs story only, after the other three rows are merged. "Requires the other three rows" nearly says this already; make it about the test. |

## Scope vs deadline
| Item | Est. dev-days | Cut (MUST/SHOULD/LATER) |
|---|---|---|
| Installer (install.sh, ai-update, 7 test files, fake agy removal, port-docs/tiered-docs install.sh assertions, ai-update case triage per findings 1 and 2, verifier for items 3 and 5) | 0.75 | MUST |
| Generator (gen.sh, models.json, 26 goldens, 4 rewritten gen-agents cases, 3 other test files, OpenCode golden diff gate) | 0.4 | MUST |
| Toolkit (delete adapters and 3 tests, bump to 0.22.0, structural case, rerun install) | 0.15 | MUST |
| Docs (multi-agent.md rewrite, README, .gitignore, idea 20, #47, no-agy test) | 0.4 | MUST |

Total MUST: 1.7 dev-days vs available: open-ended (solo, before the reinstall) -> fits

## Unnamed risks
- The live `~/.gemini/config/hooks.json` `toolkit` key points at `plugins/toolkit/hooks/agy/*`, which the Toolkit story deletes. If agy is launched before the reinstall (for example by habit or by a herdr/zellij layout), every hook errors. Likelihood: low. Mitigation: already accepted in "Data gaps". Not launching agy until the reinstall is enough.
- The Installer story removes the fake `agy` from `install-lib.sh`, but a real `agy` binary is still on this machine. If the sandbox `PATH` reaches `/usr/bin` and the Installer RED runs before the detection code changes, the result is masked either way. The new RED deliberately puts a fake `agy` on `PATH`, so it does not depend on the host. Likelihood: low. Mitigation: build the RED's fake `agy` inside the sandbox (as the plan implies) and do not rely on the host binary.
- The `rg -i 'agy'` pattern matches a substring. A future unrelated word containing "agy" in a tracked file would fail `no-agy`. Today no tracked file outside history has a false hit (verified with `git ls-files | rg -v history | xargs rg -il`). Likelihood: low. Mitigation: if it ever happens, use `\bagy\b` plus `antigravity` and `\.gemini`.
- The regeneration command in `verify.sh:6` (`rm -rf golden && gen.sh golden`) run with a different `GEN_REPO_PATH` silently rewrites the OpenCode goldens. Likelihood: low. Mitigation: already covered by the Generator row's hard gate (`git diff main -- scripts/gen-agents/golden/opencode` empty).

## Questions for the user (max 5)
None. plan-review-1's product questions (the reinstall starts from an empty home; idea 20 and #47 are updated) are answered in the plan. Everything above is technical, and the suggested fixes resolve it.
