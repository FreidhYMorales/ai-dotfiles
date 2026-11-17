# Story 06: ship runs make check once

## Story

06. As a developer, I want ship to run make check once so that shipping does not repeat the full suite.

## Acceptance criteria

- [ ] Given finished work on a branch that is not behind its upstream, when `/toolkit:ship` runs, then `make check` runs once before the first commit, allowed up to 10 minutes or run in the background with the result read, and it does not run again before the push.
- [ ] Given a branch behind its upstream, when ship rebases before the push, then `make check` runs again only if the rebase changed the tree (the `HEAD` saved just before the rebase against the new one shows changed files); otherwise it pushes without a second run.
- [ ] Given the toolkit plugin bumped and `./install.sh` run, when a new session loads `/toolkit:ship` (Claude, and the generated OpenCode and Antigravity copies), then it carries the run-once rule and the long-run wording, and the `ship-verifies-first` and `ship-no-fire-on-commit-question` evals pass.

## Plan

- Ship's step 1 gets the long-run wording (as in pair's step 6 and the verifier) with no other change.
- The "behind its upstream" gate saves `HEAD` just before the rebase and reruns `make check` only when the rebase changed files since it; the Hard Rule "`make check` must pass before any commit" stays.
- Goldens regenerated, with the generator test as the focused test; the two ship evals run once each, results logged.
- Release: bump toolkit, run `./install.sh`, check criterion 3 in a new session.

## Out of scope

- The Stop hook, `check-fast`, pair, `delegate-local`, docs and templates, OpenCode's agent rule, `NOTCH` (stories 01-05, 07-11).
- Skipping `make check` at ship because pair or the hook already ran it: ship always runs it once (plan, Risks row).
- CI watching, commit grouping or any other ship step.

## Suggestions (your call)

- No eval exercises the rebase gate; `ship-verifies-first` only checks that the checks come first. A new case would grade criterion 2 instead of reading it; it costs one more paid run.

## Size

normal
Risk: item 5, 6 (toolkit plugin release and install; skill wording graded only by paid evals)

## Log

- L1 request: /flow:story 06
- Assumptions: the plan's `toolkit:ship` row is the whole story. Today ship already runs `make check` at step 1 and again on every rebase; "once" means the rerun happens only when the rebase changed the tree, and the run gets the long-run wording. A fix after a rejected pre-commit hook changes the tree, so it still needs a green run before the new commit (Hard Rule unchanged). The toolkit bump is a minor version (0.19.0). Each affected eval runs once, as in stories 04 and 05; no new eval case unless you take the suggestion.
- L2 approved (2026-11-17): as proposed, no new eval case.
- L3 branch: `story/06-ship-runs-check-once` from `main` (ca2126b story commit). Safety net green before any change: `gen-agents`, `no-sdd`. Test list approved as proposed (6 items, item 6 manual).
- L4 user decision (2026-11-17, stop rule 1): C2 compared the step-1 `HEAD` with the post-rebase one, but step 1 runs before the commits, so that diff always lists the own commits and would rerun every time. Now the gate saves `HEAD` just before `git pull --rebase` (commits done, the checked tree) and reruns only when `git diff --name-only <saved sha> HEAD` lists files; step 1 no longer records `HEAD`, and test 1's HEAD assertion (22d280a) is replaced by the gate assertions. C2 and the plan updated to match.
- L5 user decision (2026-11-17, stop rule 3): `toolkit-ship.test.sh` got one file-level `# shellcheck disable=SC2016` line for its literal markdown backticks; no assertion changed. d165e5b (generated ship pin) passed at once since the goldens were regenerated in each feat; its 4 cases fail on the ca2126b tree.
- L6 steps: 22d280a → 98b6b0c (long-run wording in step 1); 692f8bb → 7ac8e6f (rebase gate reruns only on changed files); d165e5b (generated ship pin); 42cbcc7 (SC2016 directive); 0fd3ebd → c37f844 (toolkit 0.19.0). `./install.sh` run: `claude plugin list` shows toolkit 0.19.0 from the working copy; the installed OpenCode and Antigravity `toolkit-ship` copies carry the rebase gate at line 28.
- L7 evals (claude plugin eval, one run of each case, $0.74): `ship-verifies-first` with 1.00 / without 0.67; `ship-no-fire-on-commit-question` with 1.00 / without 1.00 (skill not fired, as expected).
- L8 manual (C3, user, 2026-11-17): a new Claude Code session, asked how often `/toolkit:ship` runs `make check` and when it reruns after a rebase, answered once at step 1 (`SKILL.md:35`, up to 10 minutes or in the background) and, when behind, save `HEAD`, `git pull --rebase`, rerun only when `git diff --name-only <saved sha> HEAD` lists files (`SKILL.md:28`), else push directly.
- L9 full run: `make check` "All checks passed (8 steps)" at 06e4a6d; since then only the story file changed.
