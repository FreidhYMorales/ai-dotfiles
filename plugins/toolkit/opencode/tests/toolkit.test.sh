#!/usr/bin/env bash
# Tests for the OpenCode toolkit plugin. Run: bash plugins/toolkit/opencode/tests/toolkit.test.sh
# Calls follow real OpenCode 2.1.4 captures: `execute.before` (story 05) and
# the session `context` hook (story 19).
set -u

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/toolkit.ts"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# Isolate the session-start hooks from this machine: fake os-release, empty XDG dirs.
WS="$TMP_ROOT/project"
mkdir -p "$WS" "$TMP_ROOT/home" "$TMP_ROOT/bin"
printf 'PRETTY_NAME="Fakedistro 1"\n' >"$TMP_ROOT/os-release"
export HOME="$TMP_ROOT/home" XDG_CONFIG_HOME="$TMP_ROOT/config" XDG_STATE_HOME="$TMP_ROOT/state"
export OS_RELEASE_FILE="$TMP_ROOT/os-release"
unset AI_HOOKS_OFF SKIP_HOST_INFO SKIP_BACKUP_STATUS

# A fake V2 plugin context for the project $WS; registered hooks land in `hooks`.
cat >"$TMP_ROOT/fake-ctx.mjs" <<EOF
export const hooks = {};
const register = async (name, cb) => { hooks[name] = cb; return { dispose: async () => {} }; };
export const ctx = { location: { directory: "$WS" }, tool: { hook: register }, session: { hook: register } };
EOF

# before CALL_JSON: load the plugin with a fake V2 context, run its
# execute.before hook on CALL_JSON; print "pass" or "blocked: <message>".
before() {
  node --input-type=module - "$PLUGIN" "$1" "$TMP_ROOT/fake-ctx.mjs" <<'EOF' 2>&1
const [plugin, call, fake] = process.argv.slice(2);
const { hooks, ctx } = await import(fake);
const { default: def } = await import(plugin);
await def.setup(ctx);
try {
  await hooks["execute.before"](JSON.parse(call));
  console.log("pass");
} catch (error) {
  console.log(`blocked: ${error.message}`);
}
EOF
}

# shell_call COMMAND: a shell tool call as OpenCode sends it.
shell_call() {
  jq -nc --arg cmd "$1" '{tool: "shell", sessionID: "ses_1", agent: "build", messageID: "msg_1",
    id: "call_1", input: {command: $cmd}}'
}

# expect LABEL WANT_PREFIX CALL_JSON
expect() {
  local label=$1 want=$2 got
  got=$(before "$3")
  if [[ $got == "$want"* ]]; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s)\n' "$label" "$got"
    failures=$((failures + 1))
  fi
}

echo "== opencode: legacy tools are blocked =="
expect 'ls is blocked with the Claude message' 'blocked: Use eza instead of ls.' "$(shell_call 'ls -la')"
expect 'grep is blocked with the Claude message' 'blocked: Use rg instead of grep.' "$(shell_call 'git log | grep fix')"

echo "== opencode: everything else passes =="
expect 'a modern tool passes' 'pass' "$(shell_call 'rg foo')"
expect 'the legacy-cli marker passes' 'pass' "$(shell_call 'ls # legacy-cli')"
expect 'a read call passes' 'pass' \
  '{"tool": "read", "sessionID": "ses_1", "id": "call_2", "input": {"filePath": "/tmp/ls"}}'
# Only the shell tool is checked, whatever another tool's input holds.
expect 'a non-shell tool with a command field passes' 'pass' \
  '{"tool": "task", "sessionID": "ses_1", "id": "call_3", "input": {"command": "ls -la"}}'

# Unlike the Claude hook, the OpenCode plugin fails closed.
echo "== opencode: a malformed shell call is blocked =="
expect 'a shell call without input is blocked' 'blocked: toolkit: malformed shell call' \
  '{"tool": "shell", "sessionID": "ses_1", "id": "call_4"}'
expect 'a shell call without a command is blocked' 'blocked: toolkit: malformed shell call' \
  '{"tool": "shell", "sessionID": "ses_1", "id": "call_5", "input": {}}'
expect 'a shell call with a non-string command is blocked' 'blocked: toolkit: malformed shell call' \
  '{"tool": "shell", "sessionID": "ses_1", "id": "call_6", "input": {"command": ["ls"]}}'

# context SESSION_ID...: load the plugin once, call its session `context` hook
# once per id with a fresh base system; print the resulting systems as a JSON
# array, or "threw: <message>".
context() {
  node --input-type=module - "$PLUGIN" "$TMP_ROOT/fake-ctx.mjs" "$@" <<'EOF' 2>&1
const [plugin, fake, ...sessions] = process.argv.slice(2);
const { hooks, ctx } = await import(fake);
const { default: def } = await import(plugin);
await def.setup(ctx);
const systems = [];
try {
  for (const sessionID of sessions) {
    const request = { sessionID, model: {}, system: [{ type: "text", text: "base" }], messages: [] };
    await hooks["context"](request);
    systems.push(request.system);
  }
  console.log(JSON.stringify(systems));
} catch (error) {
  console.log(`threw: ${error.message}`);
}
EOF
}

# expect_context LABEL FILTER [ENV...] -- SESSION_ID...: the systems satisfy the jq FILTER.
expect_context() {
  local label=$1 filter=$2 got
  shift 2
  local env=()
  while [[ $1 != -- ]]; do
    env+=("$1")
    shift
  done
  shift
  got=$(
    ((${#env[@]})) && export "${env[@]}"
    context "$@"
  )
  if jq -e "$filter" >/dev/null 2>&1 <<<"$got"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s)\n' "$label" "$got"
    failures=$((failures + 1))
  fi
}

echo "== opencode: the session starts with the host info =="
expect_context 'host info alone is appended as one system part' \
  '(.[0] | length) == 2 and .[0][0] == {type: "text", text: "base"} and .[0][1].type == "text"
    and (.[0][1].text | contains("Fakedistro 1"))' \
  AI_HOOKS_OFF=pack-hint,backup-status -- ses_1

# A fake ai-pack that hints only for this project, and a configured backup
# that never ran: all three hooks speak.
cat >"$TMP_ROOT/bin/ai-pack" <<EOF
#!/usr/bin/env bash
[[ "\$*" == "hint --cwd $WS" ]] && printf 'v1\tpack: try the web pack\n'
EOF
chmod +x "$TMP_ROOT/bin/ai-pack"
mkdir -p "$XDG_CONFIG_HOME/restic"
touch "$XDG_CONFIG_HOME/restic/engram.env"
expect_context 'host info, pack hint and backup note are appended as one system part' \
  '(.[0] | length) == 2 and (.[0][1].text | contains("Fakedistro 1") and contains("pack: try the web pack")
    and contains("no engram backup recorded yet"))' \
  PATH="$TMP_ROOT/bin:$PATH" -- ses_1

# A counting ai-pack: each run of the session-start hooks leaves one line.
echo "== opencode: the hooks run once per session =="
mkdir -p "$TMP_ROOT/counting"
cat >"$TMP_ROOT/counting/ai-pack" <<EOF
#!/usr/bin/env bash
echo run >>"$TMP_ROOT/pack-calls"
printf 'v1\tpack: try the web pack\n'
EOF
chmod +x "$TMP_ROOT/counting/ai-pack"
expect_context 'every call of a session gets the same block' \
  'length == 3 and all(.[]; length == 2) and .[0][1] == .[1][1] and .[0][1] == .[2][1]
    and (.[0][1].text | contains("pack: try the web pack"))' \
  PATH="$TMP_ROOT/counting:$PATH" -- ses_1 ses_1 ses_2
calls=$(wc -l <"$TMP_ROOT/pack-calls" 2>/dev/null || echo 0)
if [[ $calls -eq 2 ]]; then
  printf 'PASS  %s\n' 'two calls in one session and one in another run the hooks twice'
else
  printf 'FAIL  %s (got: %s runs)\n' 'two calls in one session and one in another run the hooks twice' "$calls"
  failures=$((failures + 1))
fi

echo "== opencode: nothing to say leaves the system untouched =="
untouched='. == [[{type: "text", text: "base"}]]'
expect_context 'all hooks silent leaves the system as it was' "$untouched" \
  AI_HOOKS_OFF=host-info,pack-hint,backup-status -- ses_1
# A jq that breaks only the hooks' final `jq -n` output: host-info prints garbage.
real_jq=$(command -v jq)
mkdir -p "$TMP_ROOT/badjq"
cat >"$TMP_ROOT/badjq/jq" <<EOF
#!/usr/bin/env bash
[[ \$1 == -n ]] && { echo 'not json {'; exit 0; }
exec "$real_jq" "\$@"
EOF
chmod +x "$TMP_ROOT/badjq/jq"
expect_context 'a hook that prints something unreadable leaves the system as it was' "$untouched" \
  AI_HOOKS_OFF=pack-hint,backup-status PATH="$TMP_ROOT/badjq:$PATH" -- ses_1
# No bash on the PATH: the hooks cannot even start.
mkdir -p "$TMP_ROOT/nobash"
ln -sf "$(command -v node)" "$TMP_ROOT/nobash/node"
expect_context 'hooks that cannot start leave the system as it was' "$untouched" \
  PATH="$TMP_ROOT/nobash" -- ses_1

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
