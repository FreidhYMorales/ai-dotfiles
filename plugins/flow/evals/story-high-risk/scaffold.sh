#!/usr/bin/env bash
# Workspace after /flow:backlog: story 03 permanently deletes a user's data,
# so it is high risk (item 1) and must get a story file.
set -eu
mkdir -p docs/plans/plant-watering
cat >docs/plans/plant-watering/plan.md <<'DOC'
# Plan: plant-watering

- Status: approved
- Mode: solo

## Product vision

- **v1:** a small hosted app where people track their house plants and log
  waterings; each person sees only their own plants.

## Decisions

- Stack: Flask + PostgreSQL, server-rendered pages.
- Accounts: email and password; each person owns their plants and waterings.
- Deleting an account is permanent: the account, its plants and its watering
  log are removed at once; there is no undo and no grace period.

## Scope (v1)

- Sign up and sign in.
- Add a plant and log waterings.
- Delete my account and all my data.

## Out of scope

- Data export, admin tools, shared plants.
DOC
cat >docs/plans/plant-watering/backlog.md <<'DOC'
# Backlog: plant-watering

## Context

- What: a hosted app where each person tracks their own house plants and waterings. Plan: docs/plans/plant-watering/plan.md.
- Stack: Flask + PostgreSQL, server-rendered pages
- Expensive decisions: accounts (each person owns their data)
- Test command: make check
- Single test: pytest <file>

## Backlog

01. [x] 3f2a91c As a plant owner, I want to add a plant and see it in my list so that I know what I am tracking.
02. [x] 8c41d07 As a plant owner, I want to sign up and sign in so that only I see my plants. Requires: #01
03. [ ] As a plant owner, I want to delete my account and all my plants and waterings so that none of my data stays on the server. Requires: #02
DOC
printf 'check:\n\tpytest\n' >Makefile
printf '# AGENTS.md\n\nConventional commits. Strict TDD.\n' >AGENTS.md
