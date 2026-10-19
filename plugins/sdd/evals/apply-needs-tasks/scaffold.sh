#!/usr/bin/env bash
# Shared tiny CLI plus a change that has only a proposal (no spec, design or tasks).
set -eu
mkdir -p src tests openspec/specs
cat >src/cli.py <<'PY'
import sys


def main(argv):
    cnt = len(argv)
    print(f"{cnt} argument(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
PY
cat >tests/test_cli.py <<'PY'
from src.cli import main


def test_counts_arguments(capsys):
    assert main(["a", "b"]) == 0
    assert capsys.readouterr().out == "2 argument(s)\n"
PY
cat >openspec/config.yaml <<'YAML'
schema: spec-driven
project: tiny-cli
strict_tdd: true
test_command: pytest
YAML
mkdir -p openspec/changes/add-json-flag
cat >openspec/changes/add-json-flag/proposal.md <<'MD'
# Proposal: add-json-flag

## Intent
Let scripts consume the CLI output: `--json` prints `{"count": N}`.

## Scope
- In: `--json` flag in src/cli.py, tests.
- Out: other output formats.
MD
