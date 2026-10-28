#!/usr/bin/env bash
# Tests for the Antigravity SessionStart adapter.
# Run: bash plugins/toolkit/hooks/tests/agy-session-start.test.sh
# Payloads follow agy's SessionStart contract (bundled agy-customizations docs).
set -u

ADAPTER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/agy/session-start.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# Isolate the hooks from this machine: fake os-release, empty XDG dirs.
WS="$TMP_ROOT/workspace"
mkdir -p "$WS" "$TMP_ROOT/home" "$TMP_ROOT/bin"
printf 'PRETTY_NAME="Fakedistro 1"\n' >"$TMP_ROOT/os-release"
export HOME="$TMP_ROOT/home" XDG_CONFIG_HOME="$TMP_ROOT/config" XDG_STATE_HOME="$TMP_ROOT/state"
export OS_RELEASE_FILE="$TMP_ROOT/os-release"
unset AI_HOOKS_OFF SKIP_HOST_INFO SKIP_BACKUP_STATUS

# session_payload DIR: a SessionStart payload as agy sends it.
session_payload() {
  jq -n --arg dir "$1" '{conversationId: "c1", workspacePaths: [$dir], modelName: "auto"}'
}

# expect LABEL FILTER STDIN [ENV...]: the adapter's stdout satisfies the jq FILTER.
expect() {
  local label=$1 filter=$2 input=$3 out
  shift 3
  out=$(printf '%s' "$input" | env "$@" bash "$ADAPTER" 2>/dev/null)
  if jq -e "$filter" >/dev/null 2>&1 <<<"$out"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s)\n' "$label" "$out"
    failures=$((failures + 1))
  fi
}

# one_message: exactly one injected system message step.
one_message='(.injectSteps | length) == 1 and (.injectSteps[0] | keys) == ["systemMessage"]'

echo "== agy: the session starts with the host info =="
expect 'host info alone arrives as one system message' \
  "$one_message and (.injectSteps[0].systemMessage.systemMessage | contains(\"Fakedistro 1\"))" \
  "$(session_payload "$WS")" AI_HOOKS_OFF=pack-hint,backup-status

# A fake ai-pack that hints only for this workspace, and a configured backup
# that never ran: all three hooks speak.
cat >"$TMP_ROOT/bin/ai-pack" <<EOF
#!/usr/bin/env bash
[[ "\$*" == "hint --cwd $WS" ]] && printf 'v1\tpack: try the web pack\n'
EOF
chmod +x "$TMP_ROOT/bin/ai-pack"
mkdir -p "$XDG_CONFIG_HOME/restic"
touch "$XDG_CONFIG_HOME/restic/engram.env"
expect 'host info, pack hint and backup note arrive as one system message' \
  "$one_message and (.injectSteps[0].systemMessage.systemMessage |
    contains(\"Fakedistro 1\") and contains(\"pack: try the web pack\") and contains(\"no engram backup recorded yet\"))" \
  "$(session_payload "$WS")" PATH="$TMP_ROOT/bin:$PATH"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
