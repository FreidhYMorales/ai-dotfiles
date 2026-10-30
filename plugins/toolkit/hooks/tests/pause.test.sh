#!/usr/bin/env bash
# Tests for pause.sh. Run: bash plugins/toolkit/hooks/tests/pause.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pause.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# engram stub: records its argv (one per line) and its working directory.
mkdir -p "$TMP_ROOT/bin"
cat >"$TMP_ROOT/bin/engram" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$TMP_ROOT/engram.args"
pwd >"$TMP_ROOT/engram.cwd"
EOF
chmod +x "$TMP_ROOT/bin/engram"

repo="$TMP_ROOT/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null \
  commit -q --allow-empty -m "feat: first"
printf 'x\n' >"$repo/dirty.txt"

# run PROMPT [ENV...]: run the hook; context in $LAST_CONTEXT.
LAST_CONTEXT=""
LAST_EXIT=0
run() {
  local prompt=$1
  shift
  rm -f "$TMP_ROOT"/engram.*
  local out="$TMP_ROOT/hook.out"
  jq -n --arg p "$prompt" --arg c "$repo" \
    '{hook_event_name: "UserPromptSubmit", prompt: $p, cwd: $c}' |
    env PATH="$TMP_ROOT/bin:$PATH" "$@" bash "$HOOK" >"$out" 2>/dev/null
  LAST_EXIT=$?
  LAST_CONTEXT=$(jq -r '.hookSpecificOutput.additionalContext // empty' <"$out" 2>/dev/null)
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

has() { [[ $LAST_CONTEXT == *"$1"* ]]; }
saved() { rg -q -- "$1" "$TMP_ROOT/engram.args" 2>/dev/null; }

echo "== pause requests =="

for prompt in 'pausa' 'Pausa, me tengo que ir' 'pause' '  PAUSAR ya'; do
  run "$prompt"
  assert "'$prompt' triggers the pause protocol" has 'PAUSE REQUESTED'
done

run 'pausa'
assert 'protocol forbids starting new work' has 'Do not start new work'
assert 'protocol asks for a short reply' has '5 lines'
assert 'protocol mentions how to resume' has 'cz'
assert 'checkpoint is saved to engram' saved '^save$'
assert 'checkpoint upserts one topic' saved '^checkpoint/pause$'
assert 'checkpoint records the branch' saved 'branch: main'
assert 'checkpoint records uncommitted files' saved 'dirty.txt'
assert 'checkpoint records the last commit' saved 'feat: first'
assert 'engram runs in the project directory' \
  test "$(cat "$TMP_ROOT/engram.cwd" 2>/dev/null)" == "$repo"

# Approval pin: the Claude protocol stays word for word.
claude_protocol="PAUSE REQUESTED. The user may close the terminal in seconds. A checkpoint was already saved to engram (topic checkpoint/pause). Do not start new work and make at most one more tool call. Reply in at most 5 lines: what was in progress, anything still running and whether it is safe to stop it (or how to stop it cleanly), uncommitted changes, and how to resume: reattach with \`cz\` from the project (the session keeps running if Claude was started with cz), or \`cz --continue\` / \`claude --continue\` after a reboot."
assert 'the Claude protocol is unchanged' test "$LAST_CONTEXT" == "$claude_protocol"

echo "== everything else =="

for prompt in 'no hagas pausa' 'sigamos' 'pausado el deploy?'; do
  run "$prompt"
  assert "'$prompt' is ignored" test -z "$LAST_CONTEXT"
  assert "'$prompt' exits 0" test "$LAST_EXIT" -eq 0
done
run 'pausa' SKIP_PAUSE_HOOK=1
assert 'SKIP_PAUSE_HOOK=1 is ignored' test -z "$LAST_CONTEXT"
assert 'SKIP_PAUSE_HOOK=1 exits 0' test "$LAST_EXIT" -eq 0

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
