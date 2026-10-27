#!/usr/bin/env bash
# A solo project with a backlog and no tasks.md: only story 02 is startable
# (03 waits for 02, 05 waits for 04, which is still in progress).
set -eu
mkdir -p docs/plans/invoicing
cat >docs/plans/invoicing/backlog.md <<'DOC'
# Backlog: invoicing

## Context

- What: a freelancer issues invoices to clients.
- Stack: Ruby on Rails, SQLite.
- Expensive decisions: one currency (EUR), single user.
- Test command: bin/rails test
- Single test: bin/rails test <file>

## Backlog

01. [x] 4f2a9c1 As a freelancer, I want to create an invoice with one line so that I can bill a client.
02. [ ] As a freelancer, I want invoices numbered in sequence so that my accounting stays in order. Requires: #01
03. [ ] As a freelancer, I want to send an invoice as a PDF so that the client can pay it. Requires: #02
04. [~] As a freelancer, I want to keep a list of clients so that I do not retype their details.
05. [ ] As a freelancer, I want to pick a saved client on a new invoice so that billing is faster. Requires: #01, #04
DOC
