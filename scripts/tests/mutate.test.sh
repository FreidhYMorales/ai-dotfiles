#!/usr/bin/env bash
# Tests for scripts/mutate.sh. Run: bash scripts/tests/mutate.test.sh
set -u

MUTATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/mutate.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# A fixture repo: max.sh prints the larger of two numbers; one strong and one
# weak test for it.
repo="$TMP_ROOT/repo"
mkdir -p "$repo/t"
git -C "$repo" init -q
cat >"$repo/max.sh" <<'EOF'
#!/usr/bin/env bash
# Print the larger of two numbers.
if [[ $1 -gt $2 ]]; then echo "$1"; else echo "$2"; fi
EOF
chmod +x "$repo/max.sh"
cat >"$repo/t/strong.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
[[ $(./max.sh 3 1) == 3 && $(./max.sh 1 3) == 3 ]]
EOF
cat >"$repo/t/weak.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
[[ $(./max.sh 3 3) == 3 ]]
EOF
printf '#!/usr/bin/env bash\nexit 1\n' >"$repo/t/broken.sh"
original=$(sha256sum <"$repo/max.sh")

# mutate ARGS...: run mutate.sh from the fixture repo; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
mutate() {
  LAST_OUTPUT=$(cd "$repo" && bash "$MUTATE" "$@" 2>&1)
  LAST_EXIT=$?
}

# assert LABEL CONDITION...: run a test command and record PASS/FAIL.
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

says() { [[ $LAST_OUTPUT == *"$1"* ]]; }
lacks() { [[ $LAST_OUTPUT != *"$1"* ]]; }

echo "== scoring =="

mutate max.sh bash t/strong.sh
assert 'strong test kills every mutant' says 'score: 1/1 killed (100%)'
assert 'killed mutants are not listed as survivors' lacks 'SURVIVED'
assert 'comments are never mutated' lacks 'line 2'

mutate max.sh bash t/weak.sh
assert 'weak test lets the mutant survive' says 'score: 0/1 killed (0%)'
# shellcheck disable=SC2016 # literal $1/$2: the expected mutated source line.
assert 'survivor names the line and the mutation' says 'SURVIVED line 3: if [[ $1 -le $2 ]]'

echo "== safety =="

mutate max.sh bash t/broken.sh
assert 'failing baseline aborts' test "$LAST_EXIT" -eq 2
assert 'failing baseline is explained' says 'baseline'
assert 'the real file is never modified' test "$(sha256sum <"$repo/max.sh")" == "$original"

mutate max.sh --min 50 bash t/weak.sh
assert 'score below --min fails' test "$LAST_EXIT" -eq 1
mutate max.sh --min 50 bash t/strong.sh
assert 'score at or above --min passes' test "$LAST_EXIT" -eq 0

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
