#!/usr/bin/env bash
# Workspace right after /flow:backlog: an approved plan, a backlog in the line
# grammar, a Makefile, no code. Story 02 leaves no open question.
set -eu
mkdir -p docs/plans/plant-watering
cat >docs/plans/plant-watering/plan.md <<'DOC'
# Plan: plant-watering

- Status: approved
- Mode: solo

## Product vision

- **v1:** one person tracks their house plants: each plant has a name and a
  watering interval in days; the person logs a watering and sees which plants
  are due today.

## Decisions

- Stack: Flask + SQLite, server-rendered pages.
- Single user, no accounts, runs locally.
- A plant is due when days since its last watering >= its interval; a plant
  never watered is due.
- Dates are local calendar days; no reminders or notifications.

## Scope (v1)

- Add a plant with a name and an interval in days.
- Log that a plant was watered today.
- See the plants due today.
- Edit a plant's interval.

## Out of scope

- Accounts, photos, reminders, fertilizer, several homes.
DOC
cat >docs/plans/plant-watering/backlog.md <<'DOC'
# Backlog: plant-watering

## Context

- What: a local app where one person tracks house plants and sees which are due for water. Plan: docs/plans/plant-watering/plan.md.
- Stack: Flask + SQLite, server-rendered pages
- Expensive decisions: none
- Test command: make check
- Single test: pytest <file>

## Backlog

01. [x] 3f2a91c As a plant owner, I want to add a plant with a watering interval and see it in my list so that I know what I am tracking.
02. [ ] As a plant owner, I want to log that I watered a plant today so that it stops showing as due.
03. [ ] As a plant owner, I want to see the plants due today so that I water the right ones. Requires: #02
04. [ ] As a plant owner, I want to edit a plant's interval so that it matches the season. Requires: #01
DOC
printf 'check:\n\tpytest\n' >Makefile
printf '# AGENTS.md\n\nConventional commits. Strict TDD.\n' >AGENTS.md
