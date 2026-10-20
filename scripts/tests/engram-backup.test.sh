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
# Isolate git from the user's config and global hooks (core.hooksPath).
: >"$TMP_ROOT/gitconfig"
export GIT_CONFIG_GLOBAL="$TMP_ROOT/gitconfig" GIT_CONFIG_NOSYSTEM=1

# sandbox NAME [REPO...]: HOME with an engram DB and a config listing REPOs
# (default: two local repos). Prints the HOME.
sandbox() {
  local home="$TMP_ROOT/$1" repos
  shift
  repos=${*:-"$home/repo-a $home/repo-b"}
  mkdir -p "$home/.engram" "$home/.config/restic" "$home/tmp"
  sqlite3 "$home/.engram/engram.db" \
    "CREATE TABLE observations(id INTEGER PRIMARY KEY, title TEXT); INSERT INTO observations(title) VALUES ('kept');"
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
    -u GITLEAKS_CONFIG -u GITLEAKS_CONFIG_TOML TMPDIR="$home/tmp" \
    ENGRAM_BACKUP_ALLOW_RUNNING=1 HOME="$home" ENGRAM_DATA_DIR="$home/.engram" RESTIC_CACHE_DIR="$home/.cache/restic" \
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
json_ok() { jq -e "$2" "$1" >/dev/null 2>&1; }
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
sqlite3 "$home/.engram/engram.db" "INSERT INTO observations(title) VALUES ('new');"
backup "$home"
assert 'changed database adds a snapshot' same "$(snapshots "$home" "$home/repo-a")" 2
status_file="$home/.local/state/engram-backup/backup.json"
assert 'a successful backup records its status' json_ok "$status_file" '.ok == true and .mode == "backup" and (.failed | length) == 0'
assert 'the status records when it ran' json_ok "$status_file" '(.time | fromdateiso8601) > (now - 300)'

echo "== verify =="

backup "$home" --verify
assert 'verify succeeds' test "$LAST_EXIT" -eq 0
assert 'verify checks database integrity' says 'integrity ok'
assert 'verify reads the restored data' says '2 observation'
assert 'verify records its own status' \
  json_ok "$home/.local/state/engram-backup/verify.json" '.ok == true and .mode == "verify"'

echo "== restore =="

# A new machine: the same repos and password, but no engram data at all.
fresh=$(ready restore-fresh)
backup "$home" --init
rm -rf "$fresh/repo-a" "$fresh/repo-b"
cp -a "$home/repo-a" "$home/repo-b" "$fresh/"
cp -a "$home/.config/restic/engram.pass" "$fresh/.config/restic/"
rm -rf "$fresh/.engram"
backup "$fresh" --restore
assert 'restore on a new machine succeeds' test "$LAST_EXIT" -eq 0
assert 'restore brings the database back' \
  test "$(sqlite3 "$fresh/.engram/engram.db" 'SELECT count(*) FROM observations' 2>/dev/null)" == 2
assert 'restore brings protocol-mode.json back' test -f "$fresh/.engram/protocol-mode.json"
assert 'restore reports where it came from' says 'restored'

echo "existing" >"$fresh/.engram/marker"
sqlite3 "$fresh/.engram/engram.db" "INSERT INTO observations(title) VALUES ('local only');"
backup "$fresh" --restore
assert 'restore refuses to overwrite existing data' test "$LAST_EXIT" -ne 0
assert 'the refusal points to --force' says '--force'
assert 'refused restore leaves the data alone' \
  test "$(sqlite3 "$fresh/.engram/engram.db" 'SELECT count(*) FROM observations')" == 3

backup "$fresh" --restore --force
assert 'forced restore succeeds' test "$LAST_EXIT" -eq 0
assert 'forced restore replaces the database' \
  test "$(sqlite3 "$fresh/.engram/engram.db" 'SELECT count(*) FROM observations')" == 2
assert 'forced restore keeps the old data aside' test -n "$(compgen -G "$fresh/.engram.before-restore-*")"

# A running engram (stub pgrep) must block a restore.
mkdir -p "$TMP_ROOT/running-bin"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_ROOT/running-bin/pgrep"
chmod +x "$TMP_ROOT/running-bin/pgrep"
rm -rf "$fresh/.engram"
LAST_OUTPUT=$(env -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME PATH="$TMP_ROOT/running-bin:$PATH" \
  HOME="$fresh" ENGRAM_DATA_DIR="$fresh/.engram" RESTIC_CACHE_DIR="$fresh/.cache/restic" \
  bash "$SCRIPT" --restore 2>&1)
LAST_EXIT=$?
assert 'restore refuses while engram is running' test "$LAST_EXIT" -ne 0
assert 'the refusal says to close Claude Code' says 'close every Claude Code session'
assert 'nothing is restored while engram runs' test ! -e "$fresh/.engram/engram.db"

echo "== failures =="

home=$(ready partial)
printf 'ENGRAM_BACKUP_REPOS="%s %s"\n' "$home/repo-a" "$home/missing-repo" \
  >"$home/.config/restic/engram.env"
backup "$home"
assert 'a failing repository fails the run' test "$LAST_EXIT" -ne 0
assert 'the failing repository is named' says 'missing-repo'
assert 'the healthy repository is still backed up' same "$(snapshots "$home" "$home/repo-a")" 1
assert 'a failed backup records the failing repository' \
  json_ok "$home/.local/state/engram-backup/backup.json" '.ok == false and (.failed | any(test("missing-repo")))'

home=$(sandbox nodb)
rm "$home/.engram/engram.db"
backup "$home"
assert 'missing database fails' test "$LAST_EXIT" -ne 0
assert 'missing database is reported' says 'engram.db not found'
assert 'missing database is recorded as a failure' \
  json_ok "$home/.local/state/engram-backup/backup.json" '.ok == false and (.failed | any(test("engram.db")))'

home=$(sandbox noconfig)
rm "$home/.config/restic/engram.env"
backup "$home"
assert 'missing config fails' test "$LAST_EXIT" -ne 0
assert 'missing config explains the fix' says 'engram.env'

echo "== init an off-site git repo =="

home=$(sandbox init-offsite)
cp -a "$template/.config/restic/engram.pass" "$home/.config/restic/"
git init -q --bare "$home/remote.git"
git clone -q "$home/remote.git" "$home/clone" 2>/dev/null
printf 'ENGRAM_BACKUP_REPOS="%s"\n' "$home/clone" >"$home/.config/restic/engram.env"
backup "$home" --init
assert 'init of an empty clone succeeds' test "$LAST_EXIT" -eq 0
assert 'init creates the restic repo in the clone' test -f "$home/clone/config"
assert 'init ignores restic locks' rg -qx 'locks/' "$home/clone/.gitignore"
assert 'init commits the new repo' \
  same "$(git --git-dir="$home/remote.git" log --format=%s --all 2>/dev/null)" 'init restic repository'
assert 'init pushes to the remote' \
  same "$(git --git-dir="$home/remote.git" ls-tree --name-only -r HEAD 2>/dev/null | rg -c '^(config|\.gitignore|keys/)')" 3
backup "$home" --init
assert 'second init of the clone succeeds' test "$LAST_EXIT" -eq 0
assert 'second init makes no commit' same "$(git -C "$home/clone" rev-list --count HEAD)" 1

echo "== secret scan =="

# A realistic fake GitHub token, built at runtime so this file holds no literal secret.
SECRET="ghp_$(printf 'Zq8rT2vKx9LmN4bW7cYd1PfHs6Ja3EgU0iRo')"
# leak HOME: store SECRET in a new observation.
leak() { sqlite3 "$1/.engram/engram.db" "INSERT INTO observations(title) VALUES ('token $SECRET');"; }
no_secret() { [[ $LAST_OUTPUT != *"$SECRET"* ]]; }
tmp_empty() { [[ -z $(compgen -G "$1/tmp/*") ]]; }

if command -v gitleaks >/dev/null 2>&1; then
  home=$(sandbox scan)
  backup "$home" --scan
  assert 'scan of a clean database succeeds' test "$LAST_EXIT" -eq 0
  assert 'clean scan records its status' \
    json_ok "$home/.local/state/engram-backup/scan.json" '.mode == "scan" and .ok == true and .findings == 0'
  assert 'clean scan removes its temp dump' tmp_empty "$home"
  leak "$home"
  backup "$home" --scan
  assert 'scan with a secret fails' test "$LAST_EXIT" -eq 1
  assert 'scan records the findings' \
    json_ok "$home/.local/state/engram-backup/scan.json" '.ok == false and .findings == 1 and (.time | fromdateiso8601) > (now - 300)'
  assert 'scan names the rule' says 'github-pat'
  assert 'scan points to the observation' says 'observations id=2'
  assert 'scan never prints the secret' no_secret
  assert 'scan with findings removes its temp dump' tmp_empty "$home"
  ENGRAM_BACKUP_GITLEAKS=no-such-gitleaks backup "$home" --scan
  assert 'scan without gitleaks fails' test "$LAST_EXIT" -ne 0
  assert 'scan without gitleaks says so' says 'gitleaks not installed'

  echo "== deleted data stays out of the backup =="

  home=$(ready freepages)
  sqlite3 "$home/.engram/engram.db" "PRAGMA secure_delete=OFF; INSERT INTO observations(title) VALUES ('token $SECRET');
    DELETE FROM observations WHERE title LIKE 'token %';" >/dev/null
  has_secret() { rg -a -q -F "$SECRET" "$1"; }
  lacks_secret() { ! rg -a -q -F "$SECRET" "$1"; }
  assert 'the deleted secret is still in the free pages' has_secret "$home/.engram/engram.db"
  backup "$home"
  assert 'backup of a database with free pages succeeds' test "$LAST_EXIT" -eq 0
  RESTIC_PASSWORD_FILE="$home/.config/restic/engram.pass" RESTIC_CACHE_DIR="$home/.cache/restic" \
    restic -r "$home/repo-a" restore latest --target "$home/restored" --quiet >/dev/null 2>&1
  restored_db="$home/restored$home/.cache/engram-backup/snapshot/engram.db"
  assert 'the snapshot holds a database' test -f "$restored_db"
  assert 'the snapshot leaves deleted data out' lacks_secret "$restored_db"
  assert 'the snapshot database is intact' same "$(sqlite3 "$restored_db" 'PRAGMA integrity_check;' 2>/dev/null)" ok

  echo "== off-site git repo =="

  # offsite HOME NAME: a clone (HOME/NAME) of a local bare repo standing in for
  # GitHub (HOME/NAME-remote.git), holding a copy of the template's restic repo.
  offsite() {
    git init -q --bare "$1/$2-remote.git"
    git clone -q "$1/$2-remote.git" "$1/$2" 2>/dev/null
    cp -a "$template/repo-a/." "$1/$2/"
    printf '%s\n' "$1/$2"
  }
  repos() { printf 'ENGRAM_BACKUP_REPOS="%s"\n' "${*:2}" >"$1/.config/restic/engram.env"; }
  commits() { git -C "$1" rev-list --count HEAD 2>/dev/null || echo 0; }
  pushed() { git --git-dir="$1" rev-list --count --all 2>/dev/null || echo 0; }
  failed_with() { json_ok "$1/.local/state/engram-backup/backup.json" ".ok == false and (.failed | any(contains(\"$2\")))"; }

  home=$(ready offsite)
  clone=$(offsite "$home" git)
  remote="$home/git-remote.git"
  repos "$home" "$home/repo-a" "$clone"
  backup "$home"
  assert 'backup to an off-site git repo succeeds' test "$LAST_EXIT" -eq 0
  assert 'the off-site repo is pushed' same "$(pushed "$remote")" 1
  assert 'the push is reported' says "pushed: $clone"
  assert 'the off-site repo ignores restic locks' rg -qx 'locks/' "$clone/.gitignore"
  assert 'the local repo is backed up too' same "$(snapshots "$home" "$home/repo-a")" 1
  git clone -q "$remote" "$home/check-clone" 2>/dev/null
  assert 'a fresh clone of the remote holds the snapshot' same "$(snapshots "$home" "$home/check-clone")" 1

  backup "$home"
  assert 'unchanged database makes no commit' same "$(commits "$clone")" 1
  assert 'unchanged database pushes nothing' same "$(pushed "$remote")" 1

  sqlite3 "$home/.engram/engram.db" "INSERT INTO observations(title) VALUES ('more');"
  backup "$home"
  assert 'changed database is committed and pushed' same "$(pushed "$remote")" 2

  leak "$home"
  backup "$home"
  assert 'a secret in the database fails the run' test "$LAST_EXIT" -ne 0
  assert 'the local repo is still backed up' says "backed up: $home/repo-a"
  assert 'the off-site repo is not backed up' same "$(snapshots "$home" "$clone")" 2
  assert 'nothing is pushed while secrets are found' same "$(pushed "$remote")" 2
  assert 'the block is recorded' failed_with "$home" "$clone (blocked: secrets found, see engram-backup --scan)"
  assert 'the blocked run never prints the secret' no_secret
  assert 'the blocked run removes its temp dump' tmp_empty "$home"

  sqlite3 "$home/.engram/engram.db" "DELETE FROM observations WHERE title LIKE 'token %';"
  backup "$home"
  assert 'removing the secret unblocks the off-site repo' same "$(pushed "$remote")" 3

  mv "$remote" "$home/away.git"
  sqlite3 "$home/.engram/engram.db" "INSERT INTO observations(title) VALUES ('offline');"
  backup "$home"
  assert 'a failed push fails the run' test "$LAST_EXIT" -ne 0
  assert 'the failed push is recorded' failed_with "$home" "$clone"
  assert 'the local commit is kept' same "$(commits "$clone")" 4
  mv "$home/away.git" "$remote"
  backup "$home"
  assert 'the next run succeeds' test "$LAST_EXIT" -eq 0
  assert 'the next run pushes the kept commit' same "$(pushed "$remote")" 4

  sqlite3 "$home/.engram/engram.db" "INSERT INTO observations(title) VALUES ('no scanner');"
  ENGRAM_BACKUP_GITLEAKS=no-such-gitleaks backup "$home"
  assert 'without gitleaks the run fails' test "$LAST_EXIT" -ne 0
  assert 'without gitleaks the user is warned' says 'gitleaks not installed'
  assert 'without gitleaks the off-site repo is blocked' failed_with "$home" "$clone (blocked"
  assert 'without gitleaks nothing is pushed' same "$(pushed "$remote")" 4
  assert 'without gitleaks the local repo is backed up' says "backed up: $home/repo-a"

  echo "== off-site commit failures =="

  hooked=$(ready hooked)
  hclone=$(offsite "$hooked" git)
  repos "$hooked" "$hclone"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$hclone/.git/hooks/pre-commit"
  chmod +x "$hclone/.git/hooks/pre-commit"
  backup "$hooked"
  assert 'a failed commit fails the run' test "$LAST_EXIT" -ne 0
  assert 'a failed commit is reported as such' failed_with "$hooked" "$hclone (commit failed)"
  assert 'a failed commit pushes nothing' same "$(pushed "$hooked/git-remote.git")" 0
  rm "$hclone/.git/hooks/pre-commit"
  backup "$hooked"
  assert 'after a failed commit the next run succeeds' test "$LAST_EXIT" -eq 0
  assert 'the next run commits and pushes the unchanged data' same "$(pushed "$hooked/git-remote.git")" 1
  assert 'the next run leaves a clean work tree' same "$(git -C "$hclone" status --porcelain)" ""

  echo "== restore from a clone =="

  fresh=$(sandbox clone-restore)
  rm -rf "$fresh/.engram"
  cp -a "$home/.config/restic/engram.pass" "$fresh/.config/restic/"
  git clone -q "$remote" "$fresh/clone" 2>/dev/null
  repos "$fresh" "$fresh/clone"
  backup "$fresh" --restore
  assert 'restore from a fresh clone succeeds' test "$LAST_EXIT" -eq 0
  assert 'restore from a clone brings the data back' \
    test "$(sqlite3 "$fresh/.engram/engram.db" 'SELECT count(*) FROM observations' 2>/dev/null)" == 3
  backup "$fresh" --verify
  assert 'verify works on a clone' test "$LAST_EXIT" -eq 0

  echo "== plain directories stay plain =="

  home=$(ready plain)
  git init -q "$home/repo-b"
  git init -q --bare "$home/outer-remote.git"
  git init -q "$home"
  git -C "$home" remote add origin "$home/outer-remote.git"
  backup "$home"
  assert 'git dirs without a remote, or inside another tree, back up as before' test "$LAST_EXIT" -eq 0
  assert 'no .gitignore is added to plain repos' test ! -e "$home/repo-a/.gitignore" -a ! -e "$home/repo-b/.gitignore"
  assert 'nothing is committed in plain repos' same "$(commits "$home/repo-b")$(commits "$home")" 00
  assert 'no scan runs without off-site repos' test ! -e "$home/.local/state/engram-backup/scan.json"
else
  echo "SKIP  gitleaks not installed; secret scan and off-site cases not run"
fi

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
