#!/usr/bin/env bash
# Tests for bin/engram-backup. Run: bash scripts/tests/engram-backup.test.sh
# Uses real restic and sqlite3 against throwaway repositories.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/engram-backup"
failures=0

for tool in restic sqlite3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP  $tool not installed; engram-backup tests not run"
    exit 0
  fi
done

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# sandbox NAME [REPO...]: HOME with an engram DB and a config listing REPOs
# (default: two local repos). Prints the HOME.
sandbox() {
  local home="$TMP_ROOT/$1" repos
  shift
  repos=${*:-"$home/repo-a $home/repo-b"}
  mkdir -p "$home/.engram" "$home/.config/restic"
  sqlite3 "$home/.engram/engram.db" \
    "CREATE TABLE observations(title TEXT); INSERT INTO observations VALUES ('kept');"
  printf '{"mode":"x"}\n' >"$home/.engram/protocol-mode.json"
  printf 'ENGRAM_BACKUP_REPOS="%s"\n' "$repos" >"$home/.config/restic/engram.env"
  printf '%s\n' "$home"
}

# backup HOME [ARGS...]: run engram-backup in the sandbox; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
backup() {
  local home=$1
  shift
  LAST_OUTPUT=$(env -u RESTIC_REPOSITORY -u RESTIC_PASSWORD -u RESTIC_PASSWORD_FILE \
    -u ENGRAM_BACKUP_REPOS -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
    HOME="$home" ENGRAM_DATA_DIR="$home/.engram" RESTIC_CACHE_DIR="$home/.cache/restic" \
    bash "$SCRIPT" "$@" 2>&1)
  LAST_EXIT=$?
}

# snapshots HOME REPO: number of snapshots in REPO.
snapshots() {
  RESTIC_PASSWORD_FILE="$1/.config/restic/engram.pass" RESTIC_CACHE_DIR="$1/.cache/restic" \
    restic -r "$2" snapshots --json 2>/dev/null | jq 'length'
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

says() { [[ $LAST_OUTPUT == *"$1"* ]]; }
same() { [[ $1 == "$2" ]]; }

echo "== init =="

home=$(sandbox init)
backup "$home" --init
assert 'init succeeds' test "$LAST_EXIT" -eq 0
assert 'init creates the password file' test -s "$home/.config/restic/engram.pass"
assert 'password file is private' same "$(stat -c %a "$home/.config/restic/engram.pass")" 600
assert 'init creates both repositories' test -f "$home/repo-a/config" -a -f "$home/repo-b/config"
assert 'init tells the user to save the password' says 'password manager'
password=$(<"$home/.config/restic/engram.pass")
backup "$home" --init
assert 'second init succeeds' test "$LAST_EXIT" -eq 0
assert 'second init keeps the password' same "$(<"$home/.config/restic/engram.pass")" "$password"

# restic init costs ~3 s per repository (key derivation), so the cases below
# reuse these two empty, initialized repositories instead of creating new ones.
template=$home

# ready NAME: a sandbox holding copies of the template's repositories and password.
ready() {
  local home
  home=$(sandbox "$1")
  cp -a "$template/repo-a" "$template/repo-b" "$home/"
  cp -a "$template/.config/restic/engram.pass" "$home/.config/restic/"
  printf '%s\n' "$home"
}

echo "== backup =="

home=$(ready run)
backup "$home"
assert 'backup succeeds' test "$LAST_EXIT" -eq 0
assert 'first repository has a snapshot' same "$(snapshots "$home" "$home/repo-a")" 1
assert 'second repository has a snapshot' same "$(snapshots "$home" "$home/repo-b")" 1
backup "$home"
assert 'unchanged database adds no snapshot' same "$(snapshots "$home" "$home/repo-a")" 1
sqlite3 "$home/.engram/engram.db" "INSERT INTO observations VALUES ('new');"
backup "$home"
assert 'changed database adds a snapshot' same "$(snapshots "$home" "$home/repo-a")" 2

echo "== verify =="

backup "$home" --verify
assert 'verify succeeds' test "$LAST_EXIT" -eq 0
assert 'verify checks database integrity' says 'integrity ok'
assert 'verify reads the restored data' says '2 observation'

echo "== failures =="

home=$(ready partial)
printf 'ENGRAM_BACKUP_REPOS="%s %s"\n' "$home/repo-a" "$home/missing-repo" \
  >"$home/.config/restic/engram.env"
backup "$home"
assert 'a failing repository fails the run' test "$LAST_EXIT" -ne 0
assert 'the failing repository is named' says 'missing-repo'
assert 'the healthy repository is still backed up' same "$(snapshots "$home" "$home/repo-a")" 1

home=$(sandbox nodb)
rm "$home/.engram/engram.db"
backup "$home"
assert 'missing database fails' test "$LAST_EXIT" -ne 0
assert 'missing database is reported' says 'engram.db not found'

home=$(sandbox noconfig)
rm "$home/.config/restic/engram.env"
backup "$home"
assert 'missing config fails' test "$LAST_EXIT" -ne 0
assert 'missing config explains the fix' says 'engram.env'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
