# Story 08: the notch gets a check-fast tier and a trusted hook

## Story

08. As a developer of the notch, I want a check-fast tier there and the hook trusted so that the notch gets a gate between turns without grabbing the keyboard. Requires: #01, #07

## Acceptance criteria

- [ ] Given the `QUICKSHELL NOTCH` repo trusted and on a branch with uncommitted changes, when a turn ends, then the hook runs `make check-fast` (format check and lint only; no `node --test`, no QML probe, no smoke, so the keyboard is never grabbed) and the turn finishes in under 10 s at idle, while a formatting or lint error blocks the turn naming `check-fast`; `make check` still runs the full suite.
- [ ] Given the notch repo's `AGENTS.md`, `docs/development.md` and `docs/architecture.md`, when I read them, then they give the agent rule ("A story, a ship and CI are done when `make check` passes. Between turns the hook runs `check-fast`."), name both targets, and `AGENTS.md` says the hook checks formatting and `make fmt` is the fix; the notch backlog's `Single test:` reads `node --test <test file>`.
- [ ] Given `require-check.trusted` set in the notch repo, when I check the order it was set in, then `make fmt-check lint` was green on notch `main` before any change, `check-fast` is on notch `main`, every unmerged local branch (`story/44-charging-feedback`, `story/50-screensaver-phase`) has that `main` merged in, and the local `feat/27-wallpaper-foundation` and `feat/34-quick-wallpaper` are gone after `git branch -vv` showed each matching its `origin/` branch, which stays.

## Plan

- Gate first: `make fmt-check lint` on notch `main` must be green before any change; if it is red, stop and ask.
- Notch `check-fast` = `fmt-check` + `lint`, measured with hyperfine at idle; if it is over 10 s, only changed files are formatted and linted (plan question 5).
- Notch docs get the agent rule, the two targets and the `make fmt` fix; the notch backlog's `Single test:` line is widened so QML probes have a focused command.
- Delivery: the work lands on notch `main` through a notch story branch, then `main` is merged into the open story branches, the two stale local branches are deleted, and only then is the repo trusted.
- Proof: a turn ending in a new session in the notch repo, with an edit and with a formatting error, logged as evidence.

## Out of scope

- Any change to the hook, this repo's `check-fast`, the flow or toolkit plugins (stories 01-07), `delegate-local` (09), the slow-test report (10), OpenCode's rule (11).
- The notch `ci` target and GitHub workflow: CI keeps running what it runs today.
- Notch feature code, the QML probes and their keyboard handling, and the content of stories 44 and 50 beyond merging `main` into them.
- Deleting any remote branch, or any local branch other than `feat/27` and `feat/34`.

## Suggestions (your call)

- Notch `main` is checked out in the OpenCode worktree `~/.local/share/opencode/worktree/cabbeb/notch-story-37` (story 37, already merged), so the notch's own checkout cannot switch to `main`; merging there or removing that worktree first (after confirming it is clean) keeps the delivery step simple.

## Size

normal
Risk: item 5 (notch Makefile target becomes the hook's gate and the repo is trusted, so the hook starts running `make` there)

## Log

- L1 request: /flow:story 08
- Assumptions: the story file lives here; its code and doc changes are committed in the `QUICKSHELL NOTCH` repo (backlog `## Context`). Plan row 79 is the whole story and fits 3 criteria. Today the notch is untrusted (`require-check.trusted` unset), `check` = `fmt-check lint test qml-test smoke`, and `fmt-check` + `lint` (`qmlformat`, `deno fmt --check`, `qmllint`, `deno lint`) are unmeasured. The doc lines to change are `AGENTS.md:35`, `docs/development.md:3,62,118` and `docs/architecture.md:99,109`, as in the plan. Notch stories 44 and 50 are `[~]` (39 and 42 commits ahead of `main`); the plan says to run this story when no notch story is in progress, so `/flow:pair 08` waits until both close, unless the user decides otherwise. `feat/27` and `feat/34` match `origin` today; `feat/33`, `story/28-*` and `story/29` hold nothing beyond `main` and stay. "Under 10 s at idle" follows story 01's measure.
- L2 approved (2026-11-17): as proposed.
- L3 user decision (2026-11-17): run story 08 now despite notch stories 44 and 50 being `[~]`, in a separate notch worktree; notch story 44 will be discarded by the user (its local branch has 39 commits and no `origin` copy, so it is not deleted here) and story 50 continues in parallel after `main` is merged into it. The notch branch is `story/tiered-checks-08-check-fast` (notch has its own story 08), worktree `~/Documents/MISC/notch-tiered-checks-08`, from notch `main` f6615b2.
