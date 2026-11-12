# Story 01: The Stop hook runs a check-fast tier

## Story

01. As a developer, I want the Stop hook to run a check-fast tier instead of the full make check in this repo so that a turn ends in seconds.

## Acceptance criteria

- [ ] Given this repo with uncommitted changes, when a turn ends, then the hook runs `make check-fast` (static checks over the repo, no tests or bench) and the turn finishes in under 10 s at idle, while a lint or validation error still blocks the turn with its failure tail and names `check-fast`.
- [ ] Given a trusted repo whose Makefile has no `check-fast` target, when a turn ends, then the hook runs `make check` exactly as today, with today's messages; and given a Makefile that defines only `check-fast`, the hook runs it.
- [ ] Given the toolkit plugin bumped and `./install.sh` run, when a new Claude Code session ends a turn with a docs-only change here, then the turn finishes in seconds with no tests run.

## Plan

- The hook detects a `check-fast` target the same way it detects `check` today, prefers it, and falls back to `check`; its green-tree cache is keyed by the target that ran, so a green fast run never skips a full one.
- This repo gains a `check-fast` target running the shell, json, structure, settings, skills and workflows steps over the whole repo; shellcheck runs in parallel so the whole-repo lint fits the budget.
- The hook header and its trust and red-marker messages name the target that ran; the fallback path keeps today's wording, which the agy adapter test pins.
- Tests cover the target choice, the fallback, a `check-fast`-only Makefile, the per-target cache and one agy adapter case; one `make mutate HOOKS=require-check` run is logged as evidence, not a gate.
- Release: bump the toolkit plugin, run `./install.sh`, and check criterion 3 in a new session (hooks load at session start); no agy session in this repo while the story is open, since agy runs the hook from the working copy.

## Out of scope

- Linting only changed files (story 02) and the non-blocking `check-fast` timeout (story 03); this story keeps a plain `check-fast` timeout of 60 s that blocks like today's.
- Any change to `/flow:pair`, ship, the verifier, docs beyond the hook header, `NOTCH`, OpenCode or `delegate-local`.
- Bumping the flow plugin; the pre-approved relaxing of the flow pin in `scripts/tests/no-sdd.test.sh:35-37` goes with the first story that bumps flow (story 04).
- CI changes: `make check` stays the CI gate.

## Suggestions (your call)

- `scripts/check.sh` already loops over named steps with a summary; the `check-fast` recipe can call the same step scripts directly, so `make check` keeps its exact output.

## Size

normal
Risk: item 3, 5 (the `check-fast` target becomes the hook's contract for every trusted repo; hook, Makefile and plugin release)

## Log

- L1 request: /flow:story 01
- Assumptions: "under 10 s" is measured at idle on this machine with the whole-repo parallel lint; the full-lint case under load is measured in story 02. The 60 s `check-fast` timeout blocks in this story and becomes non-blocking in story 03.
