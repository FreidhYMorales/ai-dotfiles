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

echo "== the drill runs the real systemctl with no user bus =="

drill="$ROOT/scripts/recovery-e2e.sh"
assert 'the drill stubs claude only' rg -qx 'for tool in claude; do' "$drill"
# Without a bus the real systemctl cannot touch the caller's own timers.
assert 'the drill installs with no user bus' rg -q 'env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR' "$drill"
assert 'the drill checks the install explained the timers' rg -qF "rg -q 'timers not enabled'" "$drill"

echo "== the drill runs only a verified engram release =="

# fake_release DIR BODY: a release dir (as ENGRAM_RELEASE_URL serves it) whose
# archive holds an `engram` script running BODY, with a matching checksums.txt.
fake_release() {
  local dir=$1 body=$2 asset=engram_3.6.1_linux_amd64.tar.gz
  mkdir -p "$dir/pkg"
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$dir/pkg/engram"
  chmod +x "$dir/pkg/engram"
  tar -czf "$dir/$asset" -C "$dir/pkg" engram
  (cd "$dir" && sha256sum "$asset" >checksums.txt)
}

bad="$TMP_ROOT/release-bad"
fake_release "$bad" "touch '$TMP_ROOT/bad-engram-ran'"
printf '%064d  engram_3.6.1_linux_amd64.tar.gz\n' 0 >"$bad/checksums.txt"
drill_out=$(ENGRAM_RELEASE_URL="file://$bad" bash "$drill" "$ROOT" 2>&1)
drill_exit=$?
assert 'an archive not matching checksums.txt fails the drill' test "$drill_exit" -ne 0
assert 'the failure names the checksum mismatch' rg -q 'checksum mismatch' <<<"$drill_out"
assert 'the mismatched engram never runs' test ! -e "$TMP_ROOT/bad-engram-ran"
assert 'no drill step runs with an unverified engram' test -z "$(rg '^== ' <<<"$drill_out")"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
