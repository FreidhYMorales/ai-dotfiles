#!/usr/bin/env bash
# A solo plan that passed review: handoff should end in a backlog, not SDD or tasks.md.
set -eu
mkdir -p docs/plans/bike-rental
cat >docs/plans/bike-rental/plan.md <<'DOC'
# Plan: bike-rental

- Status: reviewed
- Deadline: none
- Mode: solo
- Supersedes: none

## Product vision

- **v1:** a shop rents bikes by the hour. Staff check a bike out to a customer,
  check it back in, and see which bikes are out.

## Decisions

- Stack: Go + SQLite, server-rendered pages. One shop, staff accounts only.

## Scope

| Item | Priority |
|---|---|
| Check a bike out to a customer | MUST |
| Check a bike back in and see the hours charged | MUST |
| See which bikes are out | MUST |
| Staff sign-in | MUST |

## Plan-review resolutions

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| R1.1 | hourly rate not stated | 5 EUR per started hour | user |
DOC
cat >docs/plans/bike-rental/plan-review-1.md <<'DOC'
# Plan review: bike-rental
Verdict: PASS WITH CHANGES
Summary: one gap (the hourly rate), resolved as R1.1.
DOC
printf 'check:\n\tgo test ./...\n' >Makefile
