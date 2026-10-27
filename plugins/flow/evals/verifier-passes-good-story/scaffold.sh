#!/usr/bin/env bash
# A small Python repo where story 02 was built with /flow:pair: each test commit
# comes before its code commit and no test changed afterwards.
set -eu
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
git config core.hooksPath /dev/null

mkdir -p temp tests docs/plans/temp-convert/stories
: >tests/__init__.py
printf 'def to_fahrenheit(celsius):\n    raise NotImplementedError\n' >temp/__init__.py
cat >docs/plans/temp-convert/backlog.md <<'DOC'
# Backlog: temp-convert

## Context

- What: convert temperatures for a weather widget.
- Stack: Python 3, unittest.
- Expensive decisions: none
- Test command: python3 -m unittest
- Single test: python3 -m unittest <module>

## Backlog

01. [x] 1111111 As a reader, I want the widget to load so that I see a temperature.
02. [~] As a reader, I want Celsius shown as Fahrenheit so that I can read it in my unit.
DOC
cat >docs/plans/temp-convert/stories/02-fahrenheit.md <<'DOC'
# Story 02: Fahrenheit

## Story

02. As a reader, I want Celsius shown as Fahrenheit so that I can read it in my unit.

## Acceptance criteria

- [ ] Given 100 °C, when it is converted, then the result is 212 °F.
- [ ] Given -40 °C, when it is converted, then the result is -40 °F.

## Plan

- Convert with the standard formula.

## Out of scope

- Kelvin.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 3 (other widgets read the converted value)

## Log

- L1 request: /flow:story 02
DOC
git add -A && git commit -qm "chore: skeleton"
git switch -qc story/02-fahrenheit

cat >tests/test_convert.py <<'PY'
import unittest
from temp import to_fahrenheit


class ToFahrenheit(unittest.TestCase):
    def test_boiling_point(self):
        self.assertEqual(to_fahrenheit(100), 212)
PY
git add tests/test_convert.py && git commit -qm "test(temp): boiling point in fahrenheit"
printf 'def to_fahrenheit(celsius):\n    return 212\n' >temp/__init__.py
git add temp/__init__.py && git commit -qm "feat(temp): convert the boiling point"

cat >>tests/test_convert.py <<'PY'

    def test_minus_forty_is_the_same(self):
        self.assertEqual(to_fahrenheit(-40), -40)
PY
git add tests/test_convert.py && git commit -qm "test(temp): minus forty is the same in both units"
printf 'def to_fahrenheit(celsius):\n    return celsius * 9 / 5 + 32\n' >temp/__init__.py
git add temp/__init__.py && git commit -qm "feat(temp): convert celsius with the standard formula"
