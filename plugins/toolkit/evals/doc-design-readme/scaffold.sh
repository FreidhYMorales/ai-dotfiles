#!/usr/bin/env bash
# A dense one-block README draft that buries the setup steps in prose.
set -eu
cat >README.md <<'MD'
# tally

tally is a small command line tool that we started in 2021 because the old
spreadsheet kept breaking, and over time it grew to count words, lines and
characters in files much like wc but with JSON output, which is what the
reporting job uses. To work on it you need Python 3.11 or newer, and you should
create a virtual environment with python -m venv .venv and activate it, then
install the dev dependencies with pip install -e '.[dev]', and after that the
tests run with pytest, although the slow ones are skipped unless you pass
--runslow. Releases are cut by the maintainers from main on Fridays. If the
tests fail on a fresh clone it is usually because the venv is not active.
Formatting uses ruff format and lint uses ruff check, both run in CI.
MD
