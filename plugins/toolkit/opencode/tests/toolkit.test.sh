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

# Pause: the context requests carry the whole history (OpenCode 2.2.2 capture,
# story 20); `opencode run` wraps the prompt in literal double quotes.
# turns MESSAGES_JSON...: load the plugin once, call its `context` hook once per
# argument (one session, each a messages array); print the systems as a JSON array.
turns() {
  node --input-type=module - "$PLUGIN" "$TMP_ROOT/fake-ctx.mjs" "$@" <<'EOF' 2>&1
const [plugin, fake, ...turns] = process.argv.slice(2);
const { hooks, ctx } = await import(fake);
const { default: def } = await import(plugin);
await def.setup(ctx);
const systems = [];
try {
  for (const messages of turns) {
    const request = { sessionID: "ses_p", model: {}, system: [{ type: "text", text: "base" }], messages: JSON.parse(messages) };
    await hooks["context"](request);
    systems.push(request.system);
  }
  console.log(JSON.stringify(systems));
} catch (error) {
  console.log(`threw: ${error.message}`);
}
EOF
}

# user_msg ID TEXT: a user message as OpenCode sends it.
user_msg() {
  jq -nc --arg id "$1" --arg t "$2" '{id: $id, role: "user", content: [{type: "text", text: $t}], metadata: {}}'
}

# An engram stub: each save leaves its argv on one line.
mkdir -p "$TMP_ROOT/engram"
cat >"$TMP_ROOT/engram/engram" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$TMP_ROOT/engram-saves"
EOF
chmod +x "$TMP_ROOT/engram/engram"

# expect_pause LABEL FILTER SAVES MESSAGES_JSON...: the systems satisfy FILTER and
# engram saved SAVES checkpoints (session-start hooks off).
expect_pause() {
  local label=$1 filter=$2 want=$3 got saves
  shift 3
  rm -f "$TMP_ROOT/engram-saves"
  got=$(AI_HOOKS_OFF=host-info,pack-hint,backup-status PATH="$TMP_ROOT/engram:$PATH" turns "$@")
  saves=$(rg -c 'checkpoint/pause' "$TMP_ROOT/engram-saves" 2>/dev/null || echo 0)
  if jq -e "$filter" >/dev/null 2>&1 <<<"$got" && [[ $saves -eq $want ]]; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s; checkpoints: %s)\n' "$label" "$got" "$saves"
    failures=$((failures + 1))
  fi
}

echo "== opencode: pausa saves a checkpoint and adds the pause protocol =="
paused='(.[0] | length) == 2 and .[0][0] == {type: "text", text: "base"}
  and (.[0][1].text | startswith("PAUSE REQUESTED") and contains("opencode --continue"))'
expect_pause 'pausa adds the OpenCode protocol and saves one checkpoint' "$paused" 1 \
  "[$(user_msg msg_1 'pausa')]"
expect_pause 'a quoted prompt from opencode run pauses too' "$paused" 1 \
  "[$(user_msg msg_1 '"pausa, me voy"')]"

echo "== opencode: one checkpoint per pause message =="
p=$(user_msg msg_1 'pausa')
loop='{"id": "msg_2", "role": "assistant", "content": [{"type": "text", "text": "saving"}]}, {"role": "tool", "content": []}'
expect_pause 'a tool loop keeps the protocol and saves no second checkpoint' \
  'length == 2 and all(.[]; length == 2) and .[0][1] == .[1][1]
    and (.[1][1].text | startswith("PAUSE REQUESTED"))' 1 \
  "[$p]" "[$p, $loop]"
expect_pause 'the next message that is not a pause drops the protocol' \
  'length == 2 and (.[0] | length) == 2 and .[1] == [{type: "text", text: "base"}]' 1 \
  "[$p]" "[$p, $loop, $(user_msg msg_3 'sigamos')]"

echo "== opencode: a silent or failing pause hook leaves the system untouched =="
# expect_pause_untouched LABEL ENV...: "pausa" with ENV leaves the system as it was.
expect_pause_untouched() {
  local label=$1 got
  shift
  local env=("$@")
  got=$(
    export AI_HOOKS_OFF=host-info,pack-hint,backup-status "${env[@]}"
    turns "[$p]"
  )
  if jq -e "$untouched" >/dev/null 2>&1 <<<"$got"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s)\n' "$label" "$got"
    failures=$((failures + 1))
  fi
}
expect_pause_untouched 'SKIP_PAUSE_HOOK=1 leaves the system as it was' SKIP_PAUSE_HOOK=1
expect_pause_untouched 'a pause hook that prints something unreadable leaves the system as it was' \
  PATH="$TMP_ROOT/badjq:$PATH"
expect_pause_untouched 'a pause hook that cannot start leaves the system as it was' PATH="$TMP_ROOT/nobash"

# A hanging hook is cut off at its timeout from plugins/toolkit/hooks/hooks.json
# (10 s when it has none); the stubs below sleep far longer than that. Each
# case may take up to 10 s over its timeout: plugin start-up under the
# parallel suite on a busy CI runner (story 48); a missing cut-off still fails,
# because the hanging stub sleeps 60 s.
# expect_fast LABEL MAX_SECONDS START: the case since START took under MAX_SECONDS.
expect_fast() {
  local took=$((SECONDS - $3))
  if ((took < $2)); then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s (took %ss)\n' "$1" "$took"
    failures=$((failures + 1))
  fi
}
# A jq that hangs only inside the hook named by HANG_HOOK (every hook runs jq;
# a stub of a tool the hook calls, like ai-pack, may have its own timeout).
mkdir -p "$TMP_ROOT/hang"
cat >"$TMP_ROOT/hang/jq" <<EOF
#!/usr/bin/env bash
[[ \$(ps -o args= -p \$PPID) == *"/\$HANG_HOOK.sh"* ]] && sleep 60
exec "$real_jq" "\$@"
EOF
chmod +x "$TMP_ROOT/hang/jq"
# A pack hint with something to say, so the cut-off is what silences it.
cat >"$TMP_ROOT/hang/ai-pack" <<'EOF'
#!/usr/bin/env bash
printf 'v1\tpack: try the web pack\n'
EOF
chmod +x "$TMP_ROOT/hang/ai-pack"

echo "== opencode: a hanging hook is cut off at its timeout =="
start=$SECONDS
expect_context 'a hanging pack hint is dropped and the host info still arrives' \
  '(.[0] | length) == 2 and (.[0][1].text | contains("Fakedistro 1") and (contains("pack:") | not))' \
  AI_HOOKS_OFF=backup-status HANG_HOOK=pack-hint PATH="$TMP_ROOT/hang:$PATH" -- ses_1
expect_fast 'the pack hint is cut off at its 2 s timeout' 12 "$start"
start=$SECONDS
expect_pause_untouched 'a hanging pause hook leaves the system as it was' \
  HANG_HOOK=pause PATH="$TMP_ROOT/hang:$TMP_ROOT/engram:$PATH"
expect_fast 'the pause hook is cut off at its 5 s timeout' 15 "$start"
# Fails open, like the Claude hook: a legacy command passes when the check hangs.
start=$SECONDS
HANG_HOOK=prefer-modern-cli PATH="$TMP_ROOT/hang:$PATH" \
  expect 'a hanging shell check lets the call through' 'pass' "$(shell_call 'ls -la')"
expect_fast 'the shell check is cut off at the 10 s default' 20 "$start"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
