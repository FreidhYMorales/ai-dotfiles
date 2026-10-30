# Story 24: Support-file references resolved in generated skills

## Story

24. As a developer, I want the generator to turn bare support-file references into absolute repo paths only when the file exists in that skill's dir, with `verify.sh` flagging any it missed, so that generated skills never point at missing files and skill-creator's layout prose stays intact.

## Acceptance criteria

- [ ] Given a skill that names a file in its own dir (`references/x.md`, `templates/x.md`, `cheatsheets/x.md`, `assets/x`, plain or as a markdown link), when it is generated for OpenCode and Antigravity, then each reference is the absolute, quoted repo path of that file.
- [ ] Given a skill whose text names `references/` or `assets/` as a directory, or a support path that does not exist in its dir (as in `skill-creator`), when it is generated, then that text is unchanged.
- [ ] Given generated output that still holds a bare reference to a file that exists in its source skill dir, when `make check` runs, then it fails and names the file and line.

## Plan

- One rewrite step in the generator's skill pipeline, for both targets, that checks each bare support path against the source skill's dir before rewriting it.
- The leftover scan in `verify.sh` gains the same check, so a form the rewrite misses fails `make check`.
- Tests use a fixture source tree (as the unmapped-tool case does): one skill with real support files, one with skill-creator-style directory prose.
- The `flow-plan-review` goldens stay the same, since that skill has no bare support references; they are regenerated only if they change.

## Out of scope

- Generating the support files themselves through the rewrite (SHOULD item 8b).
- Generating more skills (#09, #10); the skill-creator golden named in plan item 4d lands with #10, which generates it.
- The agy agent mapping and the pair empty-report rule (#25, #26).

## Suggestions (your call)

- `plugin_paths` already takes the plugin; the new step can take the skill dir the same way, so the existence check reads the source tree (`GEN_SOURCE`), not the output repo path.

## Size

normal
Risk: item 5 (generator output both agents load)

## Log

- L1 request: "/flow:story 23"
- L2 split: #23 had four outcomes (support refs, agy agent mapping, agy pair line, source pair rule); user approved splitting into #24 (4d), #25 (4e agy mapping plus the agy `flow-pair` line), #26 (source pair rule with `make eval`); #09 now requires #24-#26 and #10 requires #24.
- L3 assumptions for approval: a sibling-skill path such as `../pair/references/high-risk.md` (in `story`) counts as a bare support reference and is rewritten when the file exists; the check runs against the source tree, so goldens stay independent of the checkout path; skill-creator behaviour is pinned with a fixture now and a golden in #10.
- L4 built (pair, mode C): 73b7daf (+3496821 shellcheck directive only) → adc0a36 own support files; b662ea5 → 90127e3 markdown links; 832afae → 08b3b3d sibling skill files; aebae82 directory prose and missing files stay (pin: green on first run from the existence check; a mutation with an unconditional rewrite fails it); 73de3b8 → 0f05602 `verify.sh` flags bare references with file and line.
- L5 verifier: FAIL (C1 had no case for `cheatsheets/` and `assets/`); correction ea21e91 adds that case (pin; a mutation without those dirs fails it); recheck PASS on all three criteria. Known weak assertion kept under the stop rule: `a bare support path fails` also passes on the stale-golden failure; C3 is pinned by `bare: names the file and line`.
- L6 evidence: `make check` → "All checks passed (7 steps)"; `bash scripts/tests/gen-agents.test.sh` → "All cases passed". Risk: item 5 (generator output both agents load).
