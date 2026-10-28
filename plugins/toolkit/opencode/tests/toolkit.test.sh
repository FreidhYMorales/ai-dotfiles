#!/usr/bin/env bash
# Tests for the OpenCode toolkit plugin. Run: bash plugins/toolkit/opencode/tests/toolkit.test.sh
# Calls follow a real OpenCode 2.1.4 `execute.before` capture (story 05).
set -u

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/toolkit.ts"
failures=0

# before CALL_JSON: load the plugin with a fake V2 context, run its
# execute.before hook on CALL_JSON; print "pass" or "blocked: <message>".
before() {
  node --input-type=module - "$PLUGIN" "$1" <<'EOF' 2>&1
const [plugin, call] = process.argv.slice(2);
const hooks = {};
const ctx = { tool: { hook: async (name, cb) => { hooks[name] = cb; return { dispose: async () => {} }; } } };
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

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
