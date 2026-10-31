# Story 33: install tests split so make check fits the Stop gate

## Story

33. As a developer, I want `install.test.sh` split into files that run in parallel so that `make check` takes about a minute and the Stop gate never times out on a turn end.

## Acceptance criteria

- [ ] Given this machine with nothing else running, when I run `make check`, then it passes in at most 70s (it takes 131s today; manual timing recorded in the story log).
- [ ] Given the split, when I run `make check`, then every install case of today still runs and passes: the sorted `PASS` labels of the new files equal those of the current `install.test.sh` (the stable list recorded first).
- [ ] Given any one of the new install test files, when I run it alone with `bash`, then it passes without the others.

## Plan

- Record the current install cases (their `PASS` labels) and the current timing before moving anything.
- Move the shared setup (sandbox, stubs, `install`, `assert` and friends) into one sourced helper that is not a test file, so the runner does not run it.
- Split the cases by area into 3-4 test files that the existing parallel runner picks up as they are; each case moves unchanged.
- Point the `no-sdd` scan's install exclusion at the files that carry the retired-plugin cases.

## Out of scope

- Changing any assertion or case, or speeding up `install.sh` itself.
- `engram-backup.test.sh` (51s) and the other test files.
- The `require-check` hook, its 300s timeout or a lock against overlapping runs.
- CI workflow changes.

## Suggestions (your call)

- The sections already group by target (Claude, OpenCode, Antigravity links and rules, Antigravity skill sweeps and hooks); splitting along those headers keeps each file readable.

## Size

normal
Risk: item 5 (the test harness `make check` and CI run)

## Log

- L1 request: "/flow:story 33"
- L2 assumptions for approval: "about a minute" is pinned as at most 70s for a lone `make check` (the next slowest file, `engram-backup.test.sh`, takes 51s); the case list is compared by `PASS` labels, not by count only; the `no-sdd` test excludes `install.test.sh` by path today (`no-sdd.test.sh:57`), so its exclusion list changes with the split, which is an existing-test change to approve in `/flow:pair`; story logs and docs that cite `bash scripts/tests/install.test.sh` as a past command stay as history.
- L3 approved by the user ("si, apruebo").
- L4 verification list approved ("si"): 1 baseline sorted PASS labels of the current install.test.sh, 2 after the split the labels of all new files diff empty with no FAIL, 3 each new file passes alone, 4 manual lone `make check` at most 70s. Existing test change approved: `no-sdd.test.sh` excludes `install*.test.sh` instead of `install.test.sh`. No permanent new test (it would rerun the suites and cost the time this story removes).
- L5 baseline: current install.test.sh → 247 PASS labels, 0 FAIL. Split 0bfc27d (refactor; shared setup and `REMAINING`, the one cross-section variable, in the sourced `install-lib.sh`; `no-sdd.test.sh` excludes `install*.test.sh`, approved). V2: the four new files give 247 PASS labels, `diff` against the baseline empty, 0 FAIL. V3 each alone: claude 22s, opencode 32s, agy 26s, agy-skills 40s, all "All cases passed". V4 (C1, manual): lone foreground `make check` → "All checks passed (7 steps)" in 57s (was 131s). README updated in the next commit.
