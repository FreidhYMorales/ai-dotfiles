#!/usr/bin/env bash
# install.sh tests: which targets it accepts and resolves. Antigravity is no
# longer a target (retire-antigravity story 01).
# Run: bash scripts/tests/install-targets.test.sh
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

echo "== --target antigravity is rejected =="

home=$(sandbox target-antigravity)
install "$home" --target antigravity
assert 'it exits non-zero' test "$LAST_EXIT" -ne 0
assert 'it names the unknown target' rg -qxF 'unknown target: antigravity' <<<"$LAST_OUTPUT"
assert 'it installs nothing for Claude' test ! -e "$home/.claude"
assert 'it installs nothing under ~/.gemini' test ! -e "$home/.gemini"

finish_cases
