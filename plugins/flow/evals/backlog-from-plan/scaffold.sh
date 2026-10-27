#!/usr/bin/env bash
# Workspace state right after an approved /flow:plan: a complete plan, a Makefile, no code.
set -eu
mkdir -p docs/plans/grocery-list
cat >docs/plans/grocery-list/plan.md <<'DOC'
# Plan: grocery-list

- Status: approved
- Mode: solo

## Product vision

- **v1:** one household shares a grocery list. Members add items, tick them off
  while shopping, and clear the ticked items afterwards.

## Decisions

- Stack: Flask + SQLite, server-rendered pages.
- One household only; every member has the same rights.
- Accounts: open sign-up with email and password; members stay signed in.
- No real-time sync: the list updates on page reload.
- English only, no offline mode.

## Scope (v1)

- Sign up and sign in.
- Add an item with an optional quantity.
- See the shared list.
- Tick an item off, untick it.
- Clear all ticked items.
- Edit or delete an item.

## Out of scope

- Several households, roles, shops or categories, prices, notifications.
DOC
printf 'check:\n\tpytest\n' >Makefile
printf '# AGENTS.md\n\nConventional commits.\n' >AGENTS.md
