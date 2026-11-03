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

echo "== the drill checks its tools first =="

# drill_without TOOL: run the drill with a PATH holding every /usr/bin command
# but TOOL; output in $drill_out, exit status in $drill_exit.
drill_without() {
  local bin="$TMP_ROOT/bin-no-$1"
  mkdir -p "$bin"
  ln -s /usr/bin/* "$bin/"
  rm -f "$bin/$1"
  drill_out=$(PATH="$bin" bash "$ROOT/scripts/recovery-e2e.sh" "$ROOT" 2>&1)
  drill_exit=$?
}

for tool in zellij bwrap; do
  drill_without "$tool"
  assert "a PATH without $tool fails the drill" test "$drill_exit" -ne 0
  assert "the failure names $tool" rg -q "missing tool: $tool\b" <<<"$drill_out"
  assert "no drill step runs without $tool" test -z "$(rg '^== ' <<<"$drill_out")"
done

echo "== the CI drill installs from the doc =="

job=$(awk '/^  recovery:$/ {p = 1; next} p && /^  [a-z][a-z-]*:$/ {exit} p' "$ROOT/.github/workflows/check.yml")
assert 'the recovery job is found' rg -q 'recovery-e2e.sh' <<<"$job"
assert 'the recovery job installs the packages the doc lists' \
  rg -q 'pacman .*\$\(bash scripts/recovery-packages.sh\)' <<<"$job"
assert 'the recovery job keeps no package list of its own' test -z "$(rg 'pacman .*gitleaks' <<<"$job")"
# A clean container has no ripgrep before the packages are installed.
no_rg="$TMP_ROOT/bin-no-rg"
mkdir -p "$no_rg"
ln -s /usr/bin/* "$no_rg/"
rm -f "$no_rg/rg"
assert 'the package list is read without ripgrep' \
  rg -qxF zellij <<<"$(PATH="$no_rg" bash "$ROOT/scripts/recovery-packages.sh" 2>&1)"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
