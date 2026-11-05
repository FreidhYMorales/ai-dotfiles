# Story 20: Repo lists match reality

## Story

20. As the dotfiles owner, I want the README's toolkit row, the `make mutate` hook list and the repo's `.gitignore` to match what is really there, so that the repo tells the truth about itself. (idea 16, from #12)

## Acceptance criteria

- [ ] Given the toolkit skills and hooks on disk, when I read the README's toolkit row, then each one is named, and `make check` fails when one is left out.
- [ ] Given a toolkit hook with its own test file, when I run `make mutate`, then that hook is mutated, and `make check` fails when one is left out.
- [ ] Given a clone with no personal git ignore file, when `.claude/settings.local.json` exists, then `git status` does not list it.

## Plan

- Name what the README's toolkit row lacks today: the `delegate-local` skill and the `protect-credentials` and `hooks-path` hooks.
- Add `backup-status`, `protect-credentials` and `hooks-path` to the `make mutate` list; `lib.sh` stays out because it is a helper with no test file of its own.
- Run the mutation testing on those three hooks and keep the README's "remaining survivors are equivalent mutants" claim true.
- Ignore the local settings file in the repo's own `.gitignore`.
- Pin the two lists with a test in `make check`, so the next new hook or skill cannot drift unnoticed.

Assumptions:

- The audit named only `delegate-local` and `backup-status`; `protect-credentials` and `hooks-path` came later (stories 02 and 14) and have the same gap, so they are included.
- A surviving mutant that is not equivalent gets the README's claim corrected and a new idea in `docs/ideas.md`, not new hook tests in this story.

## Out of scope

- The `taste-skill` license (#21) and the bench validation (#22).
- A full README audit beyond the toolkit row and the mutation claim.
- Stronger tests for the three hooks.

## Suggestions (your call)

## Size

small
Risk: none

## Log

- L1 request: /flow:story 12
- L2 split: idea 16 holds five independent gaps, more than 3 criteria fit, so #12 became #20, #21 and #22.
