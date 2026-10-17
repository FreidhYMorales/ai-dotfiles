#!/usr/bin/env bash
# Tests for bin/cz. Run: bash scripts/tests/cz.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/cz"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# Stubs record their argv, one argument per line.
mkdir -p "$TMP_ROOT/bin"
for tool in zellij claude; do
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s" "$@" >"%s/%s.args"\n' \
    "$tool" "$TMP_ROOT" "$tool" >"$TMP_ROOT/bin/$tool"
  chmod +x "$TMP_ROOT/bin/$tool"
done

# run DIR [ENV...] -- [ARGS...]: run cz from DIR with the stubs first on PATH.
run() {
  local dir=$1
  shift
  local envs=()
  while (($#)) && [[ $1 != -- ]]; do
    envs+=("$1")
    shift
  done
  [[ ${1:-} == -- ]] && shift
  rm -f "$TMP_ROOT"/*.args
  (cd "$dir" && env -u ZELLIJ PATH="$TMP_ROOT/bin:$PATH" "${envs[@]}" bash "$SCRIPT" "$@")
}

args() { tr '\n' ' ' <"$TMP_ROOT/$1.args" 2>/dev/null; }

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

same() { [[ $1 == "$2" ]]; }

repo="$TMP_ROOT/My Project_v2"
mkdir -p "$repo/src"
git -C "$repo" init -q

echo "== session per project =="

run "$repo" --
assert 'attaches or creates a session running claude' \
  same "$(args zellij)" 'zellij attach --create claude-my-project-v2 -- claude '

run "$repo/src" --
assert 'subdirectories share the repo session' \
  same "$(args zellij)" 'zellij attach --create claude-my-project-v2 -- claude '

plain="$TMP_ROOT/notes"
mkdir -p "$plain"
run "$plain" --
assert 'outside git the folder names the session' \
  same "$(args zellij)" 'zellij attach --create claude-notes -- claude '

echo "== arguments and nesting =="

run "$repo" -- --continue
assert 'arguments reach claude' \
  same "$(args zellij)" 'zellij attach --create claude-my-project-v2 -- claude --continue '

run "$repo" ZELLIJ=0 -- --continue
assert 'inside zellij it runs claude directly' same "$(args claude)" 'claude --continue '
assert 'inside zellij it does not nest a session' test ! -e "$TMP_ROOT/zellij.args"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
