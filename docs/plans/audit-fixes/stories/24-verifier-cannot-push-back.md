# Story 24: The verifier cannot push back

## Story

24. As the dotfiles owner, I want the verifier to work on scratch clones that cannot push back and to prove my refs did not change, so that a verification can never pollute my repo unnoticed. (idea 24, from #22)

## Acceptance criteria

- [ ] Given a verifier that needs more than inspection and the `Test command:`, such as running a mutant, when it experiments, then its rules allow that only in a scratch clone with its remotes removed before anything runs, and a caller's prompt cannot widen them.
- [ ] Given `/flow:pair` running the verifier, when the verifier returns, then pair compares the repo's refs from before and after, and any difference ends in NEEDS DECISION naming the refs, whatever the verdict says, with nothing repaired automatically.
- [ ] Given the generated OpenCode verifier and pair skill, when I read them, then they carry the same rules, and Antigravity keeps ending a high-risk story in NEEDS DECISION without running a verifier.

## Plan

- Replace the verifier's read-only rule with one that says exactly what may run where: inspection and the `Test command:` in the repo, every experiment in a clone with no remotes.
- Add the before and after ref comparison to pair's check step, kept out of the sentence the Antigravity generator rewrites.
- Regenerate the OpenCode and Antigravity copies and their golden files.
- Pin the new rules in the structural tests, bump the flow plugin version, and run the existing verifier and pair evals, since only a paid eval can grade how an agent behaves.

Assumptions:

- The comparison covers every ref and `HEAD`. A ref moved by the user or another session during the run also stops at NEEDS DECISION; a false stop is cheaper than a missed one.
- No new eval: a pair eval would need a fake verifier that really moves a ref. The structural tests pin the wording and the existing evals guard against regressions.
- This story's own verifier may run the installed plugin version rather than the edited one, so this run compares the refs by hand and states the rule in the verifier's prompt.

## Out of scope

- `make check` under an exported `GIT_DIR` (#23) and the bench step's small gaps (#25).
- A sandbox or a hook that blocks pushes at the tool level.
- The `Test command:` itself, which still runs in the repo.
- Cleaning up scratch clones left by earlier runs.

## Suggestions (your call)

## Size

normal
Risk: item 6 (how an agent follows its instructions, graded only by a paid eval)

## Log

- L1 request: /flow:story 24
- L2 evidence: the scratchpad of story 22 holds about 15 clones whose `origin` is this repo, including `gd`, `idx`, `m1` and `mainc`. The caller's prompts for both story 22 verifiers said to use "clones in a scratch directory" and asked for `GIT_DIR` runs, without saying to remove the remote, although the agent's rules say read-only. So the caller shares the cause. Still not proven which run pushed.
- L3 commits: de6bea9 test → e95ff1c fix; 012c3f4 → 4510349; 140fca3 → a3d24b5; guard f9aa57c; bafb343 → b1021d4. The user approved changing `scripts/tests/no-sdd.test.sh:35-37` for the version bump before it was made.
- L4 evals, 2026-11-05: `verifier-catches-tampered-test` with 0.89, without 0.00, pass rate 0.67; `verifier-passes-good-story` with 0.75, without 0.25, pass rate 0.33; `pair-empty-verifier-report` 1.00 with and without. Below threshold for both verifier cases. Failing reports say the subagent had no shell, and none mentions the new rules. `docs/plans/replace-sdd/stories/04-verifier.md` L8 records 1.00 and 0.89 for the same cases. These evals cannot fail on the new rules, so they prove nothing about them. Not re-run after the correction batch.
- L5 first verifier: FAIL, tests caught removed rules but not weakened ones. Refs unchanged around the run. Batch: b5d2518 → c303655 and adf24ee → b798d1a, with both wording changes approved by the user; adf24ee also replaced the assertions that pinned the earlier wording, which the caller announced but the user did not separately approve. b798d1a was committed with `make check` red by a script that did not gate on it; a6c1a10 repaired the glued step 7.
- L6 recheck: FAIL, so NEEDS DECISION. C2 and C3 pass. C1 fails: whole-rule weakenings N1-N8 stay green because the tests pin fragments. The `git -C` clause has no test, and read literally forbids a read-only `git -C <repo> log`. Tamper check fails as written on adf24ee. The recheck made clones and a helper script outside them on the caller's instruction to follow the branch's rules, though its installed definition says read-only with no exception: the caller widened the rules, which C1 says must not work. Story stays open; the user decides.
