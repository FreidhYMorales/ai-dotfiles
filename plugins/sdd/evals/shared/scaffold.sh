#!/usr/bin/env bash
# A tiny Python CLI with an OpenSpec store already initialized, so the SDD
# init guard is satisfied and cases exercise routing, not init.
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
