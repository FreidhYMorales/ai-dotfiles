#!/usr/bin/env bash
# A solo skill project: story 01 closed outside Claude with its eval pending,
# story 02 closed the same way but its eval ran later in Claude, story 03 is
# startable.
set -eu
mkdir -p docs/plans/release-notes/stories
cat >docs/plans/release-notes/backlog.md <<'DOC'
# Backlog: release-notes

## Context

- What: a flow skill that drafts release notes from merged stories.
- Stack: Claude Code plugin skills, bash tests.
- Expensive decisions: notes are generated from story logs only.
- Test command: make check
- Single test: bash scripts/tests/<name>.test.sh

## Backlog

01. [x] 3c1d2e4 As a maintainer, I want a release-notes skill that lists merged stories so that I can write notes faster.
02. [x] 7a9b0c1 As a maintainer, I want the notes grouped by feature so that they read well.
03. [ ] As a maintainer, I want breaking changes flagged at the top so that users see them first. Requires: #01
DOC
cat >docs/plans/release-notes/stories/01-list-stories.md <<'DOC'
# Story 01: list merged stories

## Log

- L1 request: "/flow-story 01"
- L2 closed in OpenCode: make check green; make eval pending (needs Claude).
DOC
cat >docs/plans/release-notes/stories/02-group-by-feature.md <<'DOC'
# Story 02: group by feature

## Log

- L1 request: "/flow-story 02"
- L2 closed in OpenCode: make check green; make eval pending (needs Claude).
- L3 make eval PLUGIN=flow: pass (run later in Claude).
DOC
