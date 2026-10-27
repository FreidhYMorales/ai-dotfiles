# Backlog: replace-sdd

## Context

- What: replace the `sdd` plugin with a just-in-time loop (`flow:backlog` → `flow:story` → `flow:pair`) and a risk-gated verifier. Plan: `docs/plans/replace-sdd/plan.md`.
- Stack: Claude Code plugins (markdown skills and agents), bash, `make check`.
- Expensive decisions: removing `sdd` is one-way for this repo (history stays in git); the backlog and story file formats become contracts for `next` and later for other agents.
- Test command: `make check` (skill stories: a bash structural test in `scripts/tests/`; evals are acceptance only).
- Single test: `bash scripts/tests/<name>.test.sh`
- Gate: story 07 waits until `notch-workspaces-osd` in `QUICKSHELL NOTCH` is archived.

## Backlog

01. [ ] As a developer, I want `flow:backlog` to turn an idea or a plan into a numbered one-line story list in `backlog.md` so that I start from a walking skeleton instead of a full spec.
02. [ ] As a developer, I want `flow:story` to refine one story into 2-3 acceptance criteria, a short plan, out of scope and a size/risk line so that I plan only what I build next. Requires: #01
03. [ ] As a developer, I want `flow:pair` to build a story in red→green steps that commit the test before the code and stop on the stop rules so that I review small diffs and catch test tampering. Requires: #02
04. [ ] As a developer, I want a story that names a high-risk item to get a fresh read-only verifier so that risky changes get a second look and small ones do not. Requires: #03
05. [ ] As a developer, I want `/flow:plan`'s handoff to write `backlog.md` and `next`/`split` to read it so that large projects end in the same loop. Requires: #01
06. [ ] As a developer, I want the always-on rules to size work by understanding, risk and resumability so that delegation and verification no longer depend on file counts. Requires: #04
07. [ ] As a developer, I want the `sdd` plugin and every reference to it removed so that there is one workflow to maintain and port. Requires: #03, #05, #06
08. [ ] As a developer, I want the `multi-agent-port` plan to drop the SDD port so that it ports the new loop instead. Requires: #07
