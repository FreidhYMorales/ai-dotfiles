# Story 06: ship runs make check once

## Story

06. As a developer, I want ship to run make check once so that shipping does not repeat the full suite.

## Acceptance criteria

- [ ] Given finished work on a branch that is not behind its upstream, when `/toolkit:ship` runs, then `make check` runs once before the first commit, allowed up to 10 minutes or run in the background with the result read, and it does not run again before the push.
- [ ] Given a branch behind its upstream, when ship rebases before the push, then `make check` runs again only if the rebase changed the tree since the green run (the recorded `HEAD` against the new one shows changed files); otherwise it pushes without a second run.
- [ ] Given the toolkit plugin bumped and `./install.sh` run, when a new session loads `/toolkit:ship` (Claude, and the generated OpenCode and Antigravity copies), then it carries the run-once rule and the long-run wording, and the `ship-verifies-first` and `ship-no-fire-on-commit-question` evals pass.

## Plan

- Ship's step 1 gets the long-run wording (as in pair's step 6 and the verifier) and records the `HEAD` of the green run.
- The "behind its upstream" gate reruns `make check` only when the rebase changed files since that `HEAD`; the Hard Rule "`make check` must pass before any commit" stays.
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
