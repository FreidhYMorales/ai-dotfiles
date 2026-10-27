# Story 06: always-on rules size by understanding and risk

## Story

06. As a developer, I want the always-on rules to size work by understanding, risk and resumability so that delegation and verification no longer depend on file counts. Requires: #04

## Acceptance criteria

- [x] Given the always-on rules, when I read how work is sized, delegated and verified, then they decide by understanding (one bounded read), risk (the items in `high-risk.md`, pointed to, not copied) and resumability (request plus `git diff`), and no rule decides by a file count.
- [x] Given a new piece of work, when I read the Workflow section, then it names the loop (`/flow:backlog` → `/flow:story` → `/flow:pair`, verifier only for a high-risk story) and keeps the full planning chain for new or large projects; "Strict TDD: enabled" and the SDD sentence stay.
- [x] Given the rules file, when I run `make check`, then it passes with the file at 59 lines or fewer and a structural test pins the pointer to `high-risk.md`, the loop in the Workflow line and the absence of file-count rules.

## Plan

- Rewrite the Delegation rules in terms of a bounded read, the high-risk items and resumability; keep "never run parallel writers" and the fresh worker for tests, builds and installs.
- Add one sizing/verification line that points to the single high-risk list instead of repeating it.
- Rewrite the Workflow line: the loop as the default path, the planning chain for new or large projects, handoff ending in the backlog.
- A structural test pins the three contracts; an acceptance eval checks that a small multi-file change is not delegated just for its file count.

## Out of scope

- The "4+ files" delegation wording inside the `research`, `foundation` and `plan` skills (skill-local; a later story or story 07 sweep).
- Removing the SDD sentence or any `sdd` reference (story 07).
- Copying the six high-risk items into the rules file.
- The OpenCode/Antigravity rule files (`multi-agent-port`).

## Suggestions (your call)

- `AGENTS.md` at the repo root is a symlink to `claude/CLAUDE.md`, so this change also reaches any agent that reads `AGENTS.md`; no extra file to touch.

## Size

normal
Risk: item 6 (always-on prompt wording, behaviour graded only by a paid eval)

## Log

- L1 request: `/flow:story 06 , sube a memoria lo que quedo pendiente o no se subio para tenerlo guardado.`
- L2 assumptions for approval: "always-on rules" = `claude/CLAUDE.md` only (plan row for story 06); the skill-local "4+ files" lines stay; the Workflow line follows the approved plan decision "backlog direct, full plan only for new/large".
- L3 approved by the user ("si, lo apruebo").
- L4 test list approved: 5 structural tests in `scripts/tests/flow-rules.test.sh` plus one acceptance eval; the 59-line limit stays with `checks.test.sh`.
- L5 user approved changing the committed assertion of test 1 (stop rule 3): the repo path does not resolve outside this repo because `claude/CLAUDE.md` is the global rules file; the list is now named "`references/high-risk.md` of the `flow:pair` skill".
- L6 cycles (mode C): 185fe1c→8827425 pointer to the high-risk list; b40bd8a→37b41fd pointer named by skill; 199b02b→8626245 no file counts; 081855b→7c6c132 size by bounded read, risk, resumability; 63510a5→68a738f loop leads the Workflow section; 9ff18ab pin (green from the start; removing two pinned strings fails 2 cases). Every code commit gated on `make check` ("All checks passed (7 steps)"); `claude/CLAUDE.md` at 40 lines.
- L7 test 6 (paid eval `rules-size-by-risk`) dropped with the user's approval: `make eval` compares with and without the flow plugin, while the rules live outside it, so both arms carry them. Replaced by a manual check: in a real session, a small change touching 4 files is done inline with no sub-agent (pending, user).
- L8 verifier (`flow:verifier`): Verdict: PASS. Note: the file-count check bans only the three old phrasings.
- L9 Risk: item 6 (always-on prompt wording, behaviour graded only by a paid eval).
