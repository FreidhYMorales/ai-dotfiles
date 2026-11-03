#!/usr/bin/env bash
# Recovery on a clean machine: docs/recovery.md lists every package the setup
# needs, and the CI drill installs exactly those. Run: bash scripts/tests/recovery.test.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

assert() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    failures=$((failures + 1))
  fi
}

echo "== recovery.md package line =="

packages=$(bash "$ROOT/scripts/recovery-packages.sh" 2>&1)
for pkg in git github-cli jq ripgrep restic sqlite openssl procps-ng gitleaks \
  make shellcheck zellij bubblewrap socat; do
  assert "the package line lists $pkg" rg -qxF "$pkg" <<<"$packages"
done

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
