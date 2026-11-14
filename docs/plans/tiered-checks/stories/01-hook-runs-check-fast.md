# Story 01: The Stop hook runs a check-fast tier

## Story

01. As a developer, I want the Stop hook to run a check-fast tier instead of the full make check in this repo so that a turn ends in seconds.

## Acceptance criteria

- [ ] Given this repo with uncommitted changes, when a turn ends, then the hook runs `make check-fast` (static checks over the repo, no tests or bench) and the turn finishes in under 10 s at idle, while a lint or validation error still blocks the turn with its failure tail and names `check-fast`.
- [ ] Given a trusted repo whose Makefile has no `check-fast` target, when a turn ends, then the hook runs `make check` exactly as today, with today's messages; and given a Makefile that defines only `check-fast`, the hook runs it.
- [ ] Given the toolkit plugin bumped and `./install.sh` run, when a new Claude Code session ends a turn with a docs-only change here, then the turn finishes in seconds with no tests run.

## Plan

- The hook detects a `check-fast` target the same way it detects `check` today, prefers it, and falls back to `check`. The green-tree cache keeps its current key: the hashed state already includes the Makefile, so a green fast run cannot skip a full one on the same tree (approved by the user at the test list, L3).
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
- L2 branch: `plan/tiered-checks` merged to `main` (96ca3ff, user OK); `story/01-hook-runs-check-fast` from it. Safety net: `require-check.test.sh` (56 cases) and `agy-require-check.test.sh` green before any change.
- L3 test list approved, with one deviation: no per-target cache key (the cached state already hashes the Makefile).
- L4 steps: 5f09413 → c61dd73 (prefer `check-fast`); 9644dfc → ee6022e (failure names its target); 8d0cb8f → 71a524c (`check-fast` alone gates); 402214a → 3d2aa56 → 8698889 (messages and the 60 s / 300 s limits; 3d2aa56 adds one `# shellcheck disable=SC2016` comment to the committed test, approved by the user under stop rule 3); 7b25c6a (agy pin, green at once since ee6022e already delivered it; fails on the pre-ee6022e hook); b9592bf → 2fd58dd → 5b02047 (`check-fast` target; 2fd58dd makes the test's step match literal with `grep -qF`, approved by the user under stop rule 3); 1ca1454 pin then e94466c refactor (parallel shellcheck); 9887000 hook header; a2b8270 toolkit 0.17.0.
- L5 measurements (hyperfine, load about 3.6): `check-shell.sh` 11.2 s serial → 6.1 s parallel; `make check-fast` 7.4 s. `make mutate HOOKS=require-check`: 47/50 killed (94%); survivors are pre-existing lines 13 (`lib.sh` source), 18 (input JSON check) and 72 (marker `-n`/`-f`), none in the new target or limit code.
- L6 release: `./install.sh` run from this branch before the verifier (user chose A); `claude plugin list` shows toolkit 0.17.0 read from the working copy. C3 manual (user, 2026-11-14): a new Claude Code session in this repo made a docs-only edit to `backlog.md`; the turn ended with no hook message and the hook's green cache was written at 13:41:48, the turn's end; rerunning the hook on that tree with an empty cache took 7.26 s, 7.18 s and 7.33 s. The edit was then reverted. A first try ran in `QUICKSHELL NOTCH` by mistake and showed the new untrusted message, proving the new hook was loaded.
- L7 verifier (flow:verifier) 1: FAIL. C1 PASS (7.09/7.38/6.97 s), C2 FAIL: a `check-fast` listed only in `.PHONY` was detected and hid a red `check`; C3 NEEDS DECISION (no evidence logged then). Also flagged: the cache deviation and the mutate run missing from the log. Refs and HEAD unchanged across the run.
- L8 correction: 4aad281 → a59fb55 (`check-fast` counts only with a recipe or prerequisites; the prerequisite-only "Not a target" and prerequisites-built cases pin the fix). `make check` green.
