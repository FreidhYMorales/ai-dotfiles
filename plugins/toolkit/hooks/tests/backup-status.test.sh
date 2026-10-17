#!/usr/bin/env bash
# Tests for backup-status.sh. Run: bash plugins/toolkit/hooks/tests/backup-status.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backup-status.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# machine NAME: a HOME with engram-backup configured. Prints it.
machine() {
  local home="$TMP_ROOT/$1"
  mkdir -p "$home/.config/restic" "$home/.local/state/engram-backup"
  printf 'ENGRAM_BACKUP_REPOS="/x"\n' >"$home/.config/restic/engram.env"
  printf '%s\n' "$home"
}

# status HOME MODE OK AGE [FAILED]: write MODE.json, AGE like "3 days ago".
status() {
  local home=$1 mode=$2 ok=$3 age=$4 failed=${5:-}
  jq -n --arg mode "$mode" --argjson ok "$ok" --arg failed "$failed" \
    --arg time "$(date -u -d "$age" +%Y-%m-%dT%H:%M:%SZ)" \
    '{mode: $mode, time: $time, ok: $ok, failed: ($failed | if . == "" then [] else [.] end)}' \
    >"$home/.local/state/engram-backup/$mode.json"
}

# run HOME [SOURCE]: run the hook; message in $LAST_MESSAGE.
LAST_MESSAGE=""
LAST_EXIT=0
run() {
  local home=$1 source=${2:-startup} out="$TMP_ROOT/hook.out"
  jq -n --arg s "$source" '{hook_event_name: "SessionStart", source: $s}' |
    env -u XDG_STATE_HOME -u XDG_CONFIG_HOME HOME="$home" bash "$HOOK" >"$out" 2>/dev/null
  LAST_EXIT=$?
  LAST_MESSAGE=$(jq -r '.systemMessage // empty' <"$out" 2>/dev/null)
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

says() { [[ $LAST_MESSAGE == *"$1"* ]]; }
silent() { [[ -z $LAST_MESSAGE && $LAST_EXIT -eq 0 ]]; }

echo "== healthy =="

home=$(machine healthy)
status "$home" backup true '3 hours ago'
status "$home" verify true '2 days ago'
run "$home"
assert 'recent good backup and verify stay silent' silent

echo "== problems =="

home=$(machine failed)
status "$home" backup false '1 hour ago' '/home/me/Files/backups/restic-engram'
status "$home" verify true '1 day ago'
run "$home"
assert 'a failed backup is reported' says 'engram backup FAILED'
assert 'the failing repository is named' says 'restic-engram'
assert 'reporting exits 0' test "$LAST_EXIT" -eq 0

home=$(machine stale)
status "$home" backup true '3 days ago'
status "$home" verify true '1 day ago'
run "$home"
assert 'a backup older than 2 days is reported' says 'last engram backup was 3 days ago'

home=$(machine stale-verify)
status "$home" backup true '1 hour ago'
status "$home" verify true '9 days ago'
run "$home"
assert 'a verify older than 8 days is reported' says 'last verified 9 days ago'

home=$(machine verify-failed)
status "$home" backup true '1 hour ago'
status "$home" verify false '1 day ago' '/x'
run "$home"
assert 'a failed verify is reported' says 'engram backup verify FAILED'

home=$(machine never)
run "$home"
assert 'no recorded backup is reported' says 'no engram backup recorded yet'
assert 'no recorded backup points to the fix' says 'engram-backup'

echo "== stays out of the way =="

home="$TMP_ROOT/unconfigured"
mkdir -p "$home"
run "$home"
assert 'machines without engram-backup stay silent' silent

home=$(machine resume)
run "$home" resume
assert 'resume stays silent' silent

run "$home" startup
run_message=$LAST_MESSAGE
SKIP_BACKUP_STATUS=1 run "$home"
assert 'SKIP_BACKUP_STATUS=1 stays silent' silent
assert 'the skip only applies when set' test -n "$run_message"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
