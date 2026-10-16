#!/usr/bin/env bash
# Tests for prefer-modern-cli.sh. Run: bash plugins/toolkit/hooks/tests/prefer-modern-cli.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/prefer-modern-cli.sh"
failures=0

# run_raw EXPECTED_EXIT LABEL STDIN
run_raw() {
  local expected=$1 label=$2 input=$3 actual
  printf '%s' "$input" | bash "$HOOK" >/dev/null 2>&1
  actual=$?
  if [[ $actual -eq $expected ]]; then
    printf 'PASS  [exit %d] %s\n' "$actual" "$label"
  else
    printf 'FAIL  [want %d, got %d] %s\n' "$expected" "$actual" "$label"
    failures=$((failures + 1))
  fi
}

# check EXPECTED_EXIT COMMAND: wraps COMMAND in a Bash tool payload.
check() {
  local payload
  payload=$(jq -n --arg cmd "$2" '{tool_name: "Bash", tool_input: {command: $cmd}}')
  run_raw "$1" "$2" "$payload"
}

block() { check 2 "$1"; }
allow() { check 0 "$1"; }

echo "== must block =="
block 'grep -r foo .'
block 'egrep x f'
block 'ls -la'
block 'find . -name x'
block 'cat file.txt'
block 'sed -n 1,5p f'
block 'git log | grep fix'
block 'cd src && find .'
block 'npm run lint; ls'
block '/usr/bin/grep x f'
block 'FOO=1 grep x f'
block 'command grep x'
block '\grep x'

echo "== must allow =="
allow 'rg foo'
allow 'fd x'
allow 'eza -la'
allow 'bat -p f'
allow 'git grep foo'
allow 'lsblk'
allow 'echo "ls and grep are words"'
allow "cat <<'EOF' > f"
allow 'cat > out.txt <<EOF'
allow "git commit -m \"\$(cat <<'EOF'
msg
EOF
)\""
allow 'grep foo f # legacy-cli'
run_raw 0 'non-Bash payload (Read)' '{"tool_name":"Read","tool_input":{"file_path":"x"}}'
run_raw 0 'empty stdin' ''
run_raw 0 'invalid JSON stdin' 'not json {'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
