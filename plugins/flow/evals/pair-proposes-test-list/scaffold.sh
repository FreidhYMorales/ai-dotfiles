#!/usr/bin/env bash
# Workspace after /flow:story 02 was approved: a tiny Python tip splitter with
# one passing test (story 01 done), a backlog with a test command, and the
# story file with two criteria. Small, Risk: none.
set -eu
mkdir -p docs/plans/tip-split/stories tipsplit tests
cat >docs/plans/tip-split/backlog.md <<'DOC'
# Backlog: tip-split

## Context

- What: a command-line helper that splits a restaurant bill and tip between diners.
- Stack: Python 3.12, pytest, no dependencies
- Expensive decisions: none
- Test command: make check
- Single test: pytest <file>

## Backlog

01. [x] 4b7e2a1 As a diner, I want the bill split evenly between N people so that everyone pays the same share.
02. [~] As a diner, I want to add a tip percentage before splitting so that the tip is shared too. Requires: #01
03. [ ] As a diner, I want shares rounded up to the next cent so that the total is always covered. Requires: #02
DOC
cat >docs/plans/tip-split/stories/02-tip-percentage.md <<'DOC'
# Story 02: tip percentage

## Story

02. As a diner, I want to add a tip percentage before splitting so that the tip is shared too.

## Acceptance criteria

- [ ] Given a bill of 100.00 for 4 people and a 20% tip, when I split it, then each share is 30.00.
- [ ] Given a bill of 100.00 for 4 people and no tip, when I split it, then each share is 25.00.
- [ ] Given a negative tip percentage, when I split, then I get an error saying the tip cannot be negative.

## Plan

- Extend the split function with an optional tip percentage (default 0).
- Apply the tip to the bill before dividing.
- Reject negative tips with a clear error.

## Out of scope

- Rounding rules (story 03), currencies, uneven splits.

## Size

small
Risk: none

## Log

- L1 request: refine story 02
DOC
cat >tipsplit/__init__.py <<'PY'
def split(bill, people):
    """Return each person's share of the bill."""
    return bill / people
PY
cat >tests/test_split.py <<'PY'
from tipsplit import split


def test_even_split_between_four():
    assert split(100.00, 4) == 25.00
PY
printf 'check:\n\tpytest -q\n' >Makefile
printf '# AGENTS.md\n\nConventional commits. Strict TDD.\n' >AGENTS.md
