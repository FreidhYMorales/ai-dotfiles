#!/usr/bin/env bash
# Tests for AI_HOOKS_OFF: one variable silences any toolkit hook.
# Run: bash plugins/toolkit/hooks/tests/hooks-off.test.sh
# Each hook gets an input where it would normally speak or block, so silence
# proves the switch, not a quiet default.
set -u

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset AI_HOOKS_OFF

# Fixtures that make each hook speak.
home="$TMP_ROOT/home"
mkdir -p "$home/.config/restic" "$home/plugins" "$home/mkt/.claude-plugin" "$home/bin" "$home/cache"
printf 'ENGRAM_BACKUP_REPOS="/x"\n' >"$home/.config/restic/engram.env"
jq -n '{plugins: {"demo@mkt": [{version: "0.1.0"}]}}' >"$home/plugins/installed_plugins.json"
jq -n --arg l "$home/mkt" '{mkt: {installLocation: $l}}' >"$home/plugins/known_marketplaces.json"
jq -n '{plugins: [{name: "demo", version: "0.2.0"}]}' >"$home/mkt/.claude-plugin/marketplace.json"
printf '#!/usr/bin/env bash\necho "engram 3.4.0"\n' >"$home/bin/engram"
printf '#!/usr/bin/env bash\nexit 22\n' >"$home/bin/curl"
chmod +x "$home/bin/engram" "$home/bin/curl"
repo="$TMP_ROOT/repo"
mkdir -p "$repo"
git -C "$repo" init -q
printf 'check:\n\texit 1\n' >"$repo/Makefile"
# A vite project and an ai-pack on PATH make pack-hint speak.
vite="$TMP_ROOT/vite"
mkdir -p "$vite"
git -C "$vite" init -q
printf '{"devDependencies":{"vite":"5"}}\n' >"$vite/package.json"
ln -s "$HOOKS/../../../bin/ai-pack" "$home/bin/ai-pack"

# speak HOOK INPUT [ENV...]: run HOOK; "exit:<code> out:<bytes>" in $RESULT.
RESULT=""
speak() {
  local hook=$1 input=$2 out code
  shift 2
  rm -rf "$home/state" # pack-hint shows once; start every run fresh
  out=$(printf '%s' "$input" | env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME="$home" XDG_STATE_HOME="$home/state" PATH="$home/bin:$PATH" \
    CLAUDE_PLUGINS_DIR="$home/plugins" UPDATE_CHECK_CACHE="$home/cache/latest" XDG_CACHE_HOME="$home/cache" \
    "$@" bash "$HOOKS/$hook.sh" 2>/dev/null)
  code=$?
  # 126/127 means the hook never ran: count it as a broken harness, not as "speaking".
  ((code == 126 || code == 127)) && code="broken"
  RESULT="exit:$code out:${#out}"
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

silent() { [[ $RESULT == "exit:0 out:0" ]]; }
active() { [[ $RESULT != "exit:0 out:0" && $RESULT != exit:broken* ]]; }

cases=(
  "host-info|{\"source\":\"startup\"}"
  "update-check|{\"source\":\"startup\"}"
  "backup-status|{\"source\":\"startup\"}"
  "pack-hint|{\"source\":\"startup\",\"cwd\":\"$vite\"}"
  "engram-resume-fallback|{\"source\":\"resume\"}"
  "pause|{\"prompt\":\"pausa\",\"cwd\":\"$repo\"}"
  "prefer-modern-cli|{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"grep x f\"}}"
  "require-check|{\"cwd\":\"$repo\",\"stop_hook_active\":false}"
)

for entry in "${cases[@]}"; do
  hook=${entry%%|*}
  input=${entry#*|}
  echo "== $hook"
  speak "$hook" "$input"
  assert "$hook speaks by default" active
  speak "$hook" "$input" AI_HOOKS_OFF="$hook"
  assert "$hook is silenced by name" silent
  speak "$hook" "$input" AI_HOOKS_OFF="other, $hook "
  assert "$hook is silenced from a list with spaces" silent
  speak "$hook" "$input" AI_HOOKS_OFF=all
  assert "$hook is silenced by all" silent
  speak "$hook" "$input" AI_HOOKS_OFF="${hook}x,x$hook"
  assert "$hook ignores names that only contain it" active
done

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
