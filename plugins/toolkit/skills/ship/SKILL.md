---
name: ship
description: "Trigger: ship it, commit and push, push this, deliver the change, /toolkit:ship. Verify with make check, commit as work units, push, and watch CI until it is green."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load when finished work must reach the remote: the user says ship / commit and push / súbelo, or approves a proposed commit. Not for planning or partial work: if checks fail, fix first.

## Hard Rules

- `make check` must pass before any commit. Never weaken, skip or `--no-verify` a check or hook (gitleaks included) to get green.
- Conventional commits, one work unit per commit (`toolkit:work-unit-commits`). Attribution follows the user's instructions (their CLAUDE.md wins).
- Pushing is outward-facing: push only when the user approved it in this turn ("ship it" counts). Never force-push.
- Done means CI is green on the pushed commit, not "pushed", when the repo has an active workflow.
- Report failures faithfully with the failing log lines.

## Decision Gates

| Situation | Action |
|---|---|
| No `check` target in the root Makefile | Run the project's documented test/lint commands; say which |
| On the default branch and the repo uses a PR flow (AGENTS.md, branch protection) | Create a branch and open a PR with `gh pr create` instead of pushing to it |
| Branch is behind its upstream | Save `git rev-parse HEAD`, `git pull --rebase`, then rerun `make check` only when `git diff --name-only <saved sha> HEAD` lists files; then push |
| No remote | Stop after commit and say so |
| No active workflow | After the push, when `gh workflow list --all` shows no workflow `active` (none, or all disabled): look for no run; say CI was skipped because no workflow is active; done is `make check` green and the pushed SHA |
| CI fails | Read `gh run view <id> --log-failed`, report the cause, propose the fix; push a fix only after approval |
| A pre-commit hook rejects the commit | Fix the cause and create a NEW commit; never amend blindly or bypass |

## Execution Steps

1. `make check` from the git root, once (allow up to 10 minutes (Claude: Bash `timeout` 600000), or run it in the background and read the result); on failure stop and fix.
2. `git status --short` and `git diff --stat`; group changes into work units.
3. Show the planned commits (type, scope, subject) and the push target. Ask once unless already approved.
4. Commit each unit; then push.
5. When `gh workflow list --all` shows an `active` workflow, find the run for the pushed SHA (`gh run list --commit <sha>`), then `gh run watch <id> --exit-status`; use a long timeout or run it in the background; otherwise follow the "No active workflow" gate.
6. Save a short engram note: commits, SHA, CI result.

## Output Contract

Commit SHAs with subjects, push target (or PR URL), CI result with run URL, or that CI was skipped because no workflow is active, and any follow-up (e.g. plugin update, restart).
