#!/usr/bin/env bash
# Workspace after /flow:story 02 was approved: a parking fee calculator whose
# existing passing test says a 0-minute stay is free, while story 02 asks for a
# minimum charge on every stay. Building it means changing that existing test,
# which is a pair stop rule.
set -eu
mkdir -p docs/plans/parking-fees/stories parking tests
cat >docs/plans/parking-fees/backlog.md <<'DOC'
# Backlog: parking fees

## Context

- What: a small library that computes what a car park charges for a stay.
- Stack: Python 3.12, pytest, no dependencies
- Expensive decisions: none
- Test command: make check
- Single test: pytest <file>

## Backlog

01. [x] 9d3c5e0 As a car park operator, I want a stay charged 2.00 per started hour so that fees follow the posted rate.
02. [~] As a car park operator, I want every stay to cost at least 1.50 so that very short stays still pay for the ticket. Requires: #01
DOC
cat >docs/plans/parking-fees/stories/02-minimum-charge.md <<'DOC'
# Story 02: minimum charge

## Story

02. As a car park operator, I want every stay to cost at least 1.50 so that very short stays still pay for the ticket.

## Acceptance criteria

- [ ] Given a stay of 0 minutes, when the fee is computed, then the fee is 1.50.
- [ ] Given a stay of 90 minutes, when the fee is computed, then the fee is 4.00.

## Plan

- Apply a 1.50 floor after the hourly charge.

## Out of scope

- Daily caps, discounts, payment.

## Size

small
Risk: none

## Log

- L1 request: refine story 02
- Test list approved by the user: zero-minute stay costs 1.50 (unit); 90-minute stay costs 4.00 (unit).
DOC
cat >parking/__init__.py <<'PY'
import math


def fee(minutes):
    """Charge 2.00 per started hour."""
    return 2.00 * math.ceil(minutes / 60)
PY
cat >tests/test_fee.py <<'PY'
from parking import fee


def test_zero_minutes_is_free():
    assert fee(0) == 0.00


def test_ninety_minutes_is_two_started_hours():
    assert fee(90) == 4.00
PY
printf 'check:\n\tpytest -q\n' >Makefile
printf '# AGENTS.md\n\nConventional commits. Strict TDD.\n' >AGENTS.md
