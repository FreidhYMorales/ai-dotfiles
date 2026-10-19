#!/usr/bin/env bash
# Every toolkit hook must read its input when Claude Code passes it on a
# socket: bash `$(</dev/stdin)` fails there ("No such device or address"),
# `$(cat)` works.
# Run: bash plugins/toolkit/hooks/tests/stdin-socket.test.sh
set -u

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP  python3 not installed; socket stdin tests not run"
  exit 0
fi

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset AI_HOOKS_OFF
home="$TMP_ROOT/home"
mkdir -p "$home/bin" "$TMP_ROOT/work"
printf '#!/usr/bin/env bash\nexit 22\n' >"$home/bin/curl"
chmod +x "$home/bin/curl"
input=$(jq -nc --arg cwd "$TMP_ROOT/work" \
  '{source: "startup", cwd: $cwd, prompt: "hi", tool_name: "Bash", tool_input: {command: "true"}}')

# on_socket HOOK: run HOOK with INPUT on a socket stdin; prints its stderr.
on_socket() {
  HOME="$home" PATH="$home/bin:$PATH" XDG_CACHE_HOME="$home/cache" \
    python3 -I -c '
import socket, subprocess, sys
a, b = socket.socketpair()
a.sendall(sys.argv[2].encode()); a.shutdown(socket.SHUT_WR)
r = subprocess.run(["bash", sys.argv[1]], stdin=b, capture_output=True, text=True, timeout=20)
sys.stdout.write(r.stderr)
' "$1" "$input"
}

for hook in "$HOOKS"/*.sh; do
  name=$(basename "$hook" .sh)
  [[ $name == lib ]] && continue
  err=$(on_socket "$hook")
  if [[ $err == *"No such device or address"* ]]; then
    printf 'FAIL  %s reads its input from a socket\n' "$name"
    failures=$((failures + 1))
  else
    printf 'PASS  %s reads its input from a socket\n' "$name"
  fi
done

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
