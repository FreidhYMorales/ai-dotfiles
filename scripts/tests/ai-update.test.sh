#!/usr/bin/env bash
# Tests for bin/ai-update. Run: bash scripts/tests/ai-update.test.sh
# Each case runs against a throwaway HOME with stub `curl` (serving files from
# a local "remote" tree), `claude` and `engram` binaries.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/ai-update"
REPO=Gentleman-Programming/engram
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# fake_engram FILE VERSION: an engram stub that reports VERSION.
fake_engram() {
  cat >"$1" <<EOF
#!/usr/bin/env bash
case \$1 in
  version) echo "engram $2" ;;
  doctor) echo "doctor: ok" ;;
  serve)
    # Starting while the old server is still dying would lose its port.
    [[ \$(ps -o stat= -p "\$(cat "\$FAKE_STATE/serve-pid" 2>/dev/null)" 2>/dev/null) != [^Z]* ]] || echo overlap >>"\$FAKE_STATE/serve-calls"
    echo "$2" >>"\$FAKE_STATE/serve-calls"
    ;;
esac
EOF
  chmod +x "$1"
}

# publish HOME TAG [REPORTED]: publish release TAG on the fake remote; its
# binary reports REPORTED (default: TAG).
publish() {
  local home=$1 tag=$2 reported=${3:-$2} rel build
  rel="$home/remote/github.com/$REPO/releases/download/v$tag"
  build="$home/build-$tag"
  mkdir -p "$rel" "$build" "$home/remote/api.github.com/repos/$REPO/releases"
  fake_engram "$build/engram" "$reported"
  tar -czf "$rel/engram_${tag}_linux_amd64.tar.gz" -C "$build" engram
  (cd "$rel" && sha256sum "engram_${tag}_linux_amd64.tar.gz" >checksums.txt)
  jq -n --arg t "v$tag" '{tag_name: $t}' >"$home/remote/api.github.com/repos/$REPO/releases/latest"
}

# sandbox NAME CURRENT LATEST [PLUGIN_INSTALLED PLUGIN_AVAILABLE]: print the HOME.
sandbox() {
  local home="$TMP_ROOT/$1" current=$2 latest=$3 installed=${4:-1.0.0} available=${5:-1.0.0}
  mkdir -p "$home/bin" "$home/local/bin" "$home/.engram" "$home/plugins" "$home/mkt/.claude-plugin" "$home/state"
  fake_engram "$home/local/bin/engram" "$current"
  sqlite3 "$home/.engram/engram.db" "CREATE TABLE obs(t TEXT); INSERT INTO obs VALUES ('kept');"
  [[ $latest == none ]] || publish "$home" "$latest"
  jq -n --arg v "$installed" '{plugins: {"demo@mkt": [{version: $v}]}}' >"$home/plugins/installed_plugins.json"
  jq -n --arg loc "$home/mkt" '{mkt: {installLocation: $loc}}' >"$home/plugins/known_marketplaces.json"
  jq -n --arg v "$available" '{plugins: [{name: "demo", version: $v}]}' >"$home/mkt/.claude-plugin/marketplace.json"
  cat >"$home/bin/curl" <<'EOF'
#!/usr/bin/env bash
# Serve http(s) URLs from $FAKE_REMOTE/<host>/<path>; -o writes to a file.
out="" url=""
while (($#)); do
  case $1 in
    -o) out=$2 && shift ;;
    http*) url=$1 ;;
  esac
  shift
done
file="$FAKE_REMOTE/${url#*://}"
[[ -f $file ]] || exit 22
if [[ -n $out ]]; then cp "$file" "$out"; else cat "$file"; fi
EOF
  cat >"$home/bin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_STATE/claude-calls"
# A refresh may publish a newer version, as a real marketplace update does.
if [[ "$*" == "plugin marketplace update mkt" && -n ${FAKE_MKT_BUMP:-} ]]; then
  jq --arg v "$FAKE_MKT_BUMP" '.plugins[0].version = $v' "$FAKE_STATE/../mkt/.claude-plugin/marketplace.json" >"$FAKE_STATE/mkt.tmp" &&
    mv "$FAKE_STATE/mkt.tmp" "$FAKE_STATE/../mkt/.claude-plugin/marketplace.json"
fi
EOF
  # Never the real pgrep: a match here is killed, and it must not be the host's
  # engram serve. It answers for one fake process, by the command line under test.
  cat >"$home/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
pid=$(cat "$FAKE_STATE/serve-pid" 2>/dev/null)
[[ -n ${FAKE_SERVE_CMDLINE:-} && -n $pid && $(ps -o stat= -p "$pid" 2>/dev/null) == [^Z]* ]] || exit 1
printf '%s\n' "$FAKE_SERVE_CMDLINE" | rg -qx -- "${!#}" || exit 1
echo "$pid"
EOF
  chmod +x "$home/bin/curl" "$home/bin/claude" "$home/bin/pgrep"
  # A stand-in repo: its install.sh records the call and copies `source` into
  # the build, so a changed source means a changed build.
  mkdir -p "$home/repo"
  echo v1 >"$home/repo/source"
  cat >"$home/repo/install.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_STATE/install-calls"
if [[ -n ${FAKE_INSTALL_FAIL:-} ]]; then
  echo "error: scripts/gen-agents/gen.sh failed; the previous build is kept" >&2
  exit 1
fi
repo=$(dirname "$0")
mkdir -p "$repo/build/agents" && cp "$repo/source" "$repo/build/agents/out"
EOF
  mkdir -p "$home/.cache/ai-dotfiles" && echo "$current" >"$home/.cache/ai-dotfiles/engram-latest"
  printf '%s\n' "$home"
}

# update HOME STDIN [ARGS...]: run ai-update in the sandbox; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
update() {
  local home=$1 answer=$2
  shift 2
  LAST_OUTPUT=$(printf '%s' "$answer" | env -u UPDATE_CHECK_CACHE -u ENGRAM_REPO \
    -u OPENCODE_CONFIG_DIR -u ANTIGRAVITY_CONFIG_DIR -u AI_BUILD_DIR AI_DOTFILES_DIR="$home/repo" \
    HOME="$home" XDG_CACHE_HOME="$home/.cache" PATH="$home/bin:$home/local/bin:$PATH" \
    FAKE_REMOTE="$home/remote" FAKE_STATE="$home/state" \
    ENGRAM_BIN="$home/local/bin/engram" ENGRAM_DATA_DIR="$home/.engram" \
    CLAUDE_PLUGINS_DIR="$home/plugins" AI_UPDATE_PLATFORM=linux_amd64 \
    AI_UPDATE_RESTART_SERVER="${FAKE_RESTART_SERVER:-0}" bash "$SCRIPT" "$@" 2>&1)
  LAST_EXIT=$?
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
engram_is() { [[ $("$1/local/bin/engram" version) == "engram $2" ]]; }
no_backup() { [[ -z $(compgen -G "$1/.engram-backup-*") && ! -e $1/local/bin/engram-$2.bak ]]; }
claude_called() { rg -qxF "$2" "$1/state/claude-calls" 2>/dev/null; }

echo "== --check only reports =="

home=$(sandbox check 3.4.0 3.5.0 0.3.0 0.3.1)
update "$home" '' --check
assert 'check exits 0' test "$LAST_EXIT" -eq 0
assert 'check lists the engram update' says 'engram 3.4.0 -> 3.5.0'
assert 'check lists the plugin update' says 'demo@mkt 0.3.0 -> 0.3.1'
assert 'check leaves engram alone' engram_is "$home" 3.4.0
assert 'check makes no backup' no_backup "$home" 3.4.0
assert 'check refreshes the marketplaces' claude_called "$home" 'plugin marketplace update mkt'
no_installs() { ! rg -q '^plugin (install|update)' "$1/state/claude-calls" 2>/dev/null; }
assert 'check installs no plugin' no_installs "$home"

# The catalog is read after the refresh, so a release published since the last
# refresh is reported (it was missed before: plugin engram 0.1.12 -> 0.1.14).
home=$(sandbox check-fresh 3.4.0 3.4.0 0.3.1 0.3.1)
FAKE_MKT_BUMP=0.3.2 update "$home" '' --check
assert 'check reports a plugin published since the last refresh' says 'demo@mkt 0.3.1 -> 0.3.2'

home=$(sandbox current 3.4.0 3.4.0)
update "$home" '' --check
assert 'nothing to do says so' says 'Everything is up to date'

home=$(sandbox offline 3.4.0 none 0.3.0 0.3.1)
update "$home" '' --check
assert 'unreachable GitHub is a warning' says 'could not check the latest engram release'
assert 'unreachable GitHub still reports plugins' says 'demo@mkt 0.3.0 -> 0.3.1'
assert 'unreachable GitHub exits 0' test "$LAST_EXIT" -eq 0

echo "== apply =="

home=$(sandbox apply 3.4.0 3.5.0 0.3.0 0.3.1)
# A deleted row stays in the free pages of the live file (engram's sqlite keeps
# them); the pre-update copy must not carry it.
sqlite3 "$home/.engram/engram.db" "PRAGMA secure_delete=OFF; INSERT INTO obs VALUES ('deleted-row-marker-7Qx'); DELETE FROM obs WHERE t LIKE 'deleted-row%';"
assert 'the deleted row is still in the live file (precondition)' rg -aq 'deleted-row-marker-7Qx' "$home/.engram/engram.db"
update "$home" '' --yes
assert 'apply exits 0' test "$LAST_EXIT" -eq 0
assert 'engram is upgraded' engram_is "$home" 3.5.0
assert 'old binary is kept as .bak' \
  test "$("$home/local/bin/engram-3.4.0.bak" version)" == 'engram 3.4.0'
backup=$(compgen -G "$home/.engram-backup-*" | head -n1)
assert 'database backup is consistent' \
  test "$(sqlite3 "$backup/engram.db" 'SELECT t FROM obs' 2>/dev/null)" == kept
lacks_bytes() { ! rg -aq "$1" "$2"; }
assert 'database backup drops deleted rows' lacks_bytes deleted-row-marker-7Qx "$backup/engram.db"
assert 'doctor runs after the upgrade' says 'doctor: ok'
assert 'update-check cache is refreshed' test ! -e "$home/.cache/ai-dotfiles/engram-latest"
assert 'marketplaces are refreshed' claude_called "$home" 'plugin marketplace update mkt'
assert 'outdated plugin is updated' claude_called "$home" 'plugin update demo@mkt'

home=$(sandbox decline 3.4.0 3.5.0)
update "$home" $'n\n'
assert 'declining changes nothing' engram_is "$home" 3.4.0
assert 'declining makes no backup' no_backup "$home" 3.4.0

home=$(sandbox accept 3.4.0 3.5.0)
update "$home" $'y\n'
assert 'accepting the prompt upgrades' engram_is "$home" 3.5.0

echo "== keeps the last two copies =="

# old_copies HOME VERSION...: three dated database copies and one binary per VERSION.
old_copies() {
  local home=$1 stamp version
  shift
  for stamp in 20260101-000000 20260201-000000 20260301-000000; do
    mkdir -p "$home/.engram-backup-$stamp"
    echo old >"$home/.engram-backup-$stamp/engram.db"
  done
  for version in "$@"; do echo old >"$home/local/bin/engram-$version.bak"; done
}
# binary_copies HOME: the versions of the binary copies, oldest first.
binary_copies() {
  local f names=()
  for f in "$1"/local/bin/engram-*.bak; do
    [[ -e $f ]] || continue
    f=${f##*/engram-}
    names+=("${f%.bak}")
  done
  ((${#names[@]})) && printf '%s\n' "${names[@]}" | sort -V | xargs
}
database_copies() { compgen -G "$1/.engram-backup-*" | wc -l; }

home=$(sandbox prune 3.12.0 3.13.0)
old_copies "$home" 3.2.0 3.9.0 3.10.0
update "$home" '' --yes
assert 'a healthy update exits 0' test "$LAST_EXIT" -eq 0
assert 'two database copies remain' test "$(database_copies "$home")" -eq 2
assert 'the newest older database copy is one of them' test -d "$home/.engram-backup-20260301-000000"
assert 'the older database copies are gone' test ! -e "$home/.engram-backup-20260201-000000"
assert 'the two newest binaries remain, by version' test "$(binary_copies "$home")" == '3.10.0 3.12.0'

# Names ai-update never made, sorting both before and after its own copies.
home=$(sandbox prune-lookalikes 3.12.0 3.13.0)
old_copies "$home" 3.9.0 3.10.0
mkdir -p "$home/.engram-backup-0-mine" "$home/.engram-backup-notes"
touch "$home/local/bin/engram-backup" "$home/local/bin/engram-0-mine.bak" "$home/local/bin/engram-notes.bak"
update "$home" '' --yes
assert 'engram-backup survives pruning' test -e "$home/local/bin/engram-backup"
assert 'a look-alike database dir sorting first survives' test -d "$home/.engram-backup-0-mine"
assert 'a look-alike database dir sorting last survives' test -d "$home/.engram-backup-notes"
assert 'a look-alike binary sorting first survives' test -e "$home/local/bin/engram-0-mine.bak"
assert 'a look-alike binary sorting last survives' test -e "$home/local/bin/engram-notes.bak"
assert 'look-alikes do not displace a database copy' test -d "$home/.engram-backup-20260301-000000"
assert 'look-alikes do not displace a binary copy' test -e "$home/local/bin/engram-3.10.0.bak"

# Look-alikes that carry a version number, and sort after the real copies.
home=$(sandbox prune-versioned 3.12.0 3.13.0)
old_copies "$home" 3.9.0 3.10.0
touch "$home/local/bin/engram-backup-1.2.3.bak" "$home/local/bin/engram-mine-1.2.3.bak"
update "$home" '' --yes
assert 'a versioned look-alike survives' test -e "$home/local/bin/engram-mine-1.2.3.bak"
assert 'a versioned engram-backup look-alike survives' test -e "$home/local/bin/engram-backup-1.2.3.bak"
assert 'a versioned look-alike does not displace the pre-update binary' test -e "$home/local/bin/engram-3.12.0.bak"
assert 'a versioned look-alike does not displace the older binary' test -e "$home/local/bin/engram-3.10.0.bak"

echo "== judges the doctor =="

# publish_doctor HOME TAG EXIT JSON: release TAG whose doctor writes a row (as a
# migration would), prints JSON with --json and exits EXIT.
publish_doctor() {
  local home=$1 tag=$2 code=$3 json=$4 build
  publish "$home" "$tag"
  build="$home/build-$tag"
  cat >"$build/engram" <<EOF
#!/usr/bin/env bash
case \$1 in
  version) echo "engram $tag" ;;
  doctor)
    sqlite3 "\$ENGRAM_DATA_DIR/engram.db" "INSERT INTO obs VALUES ('migrated');"
    [[ -z \${FAKE_DOCTOR_LOSE_COPY:-} ]] || rm -f "\$HOME"/.engram-backup-*/engram.db
    [[ -z \${FAKE_DOCTOR_CORRUPT_COPY:-} ]] || for f in "\$HOME"/.engram-backup-*/engram.db; do echo garbage >"\$f"; done
    [[ -z \${FAKE_DOCTOR_LEAVE_WAL:-} ]] || echo stale | tee "\$ENGRAM_DATA_DIR/engram.db-wal" "\$ENGRAM_DATA_DIR/engram.db-shm" >/dev/null
    if [[ \${2:-} == --json ]]; then printf '%s\n' '$json'; else echo 'doctor: report'; fi
    exit $code
    ;;
esac
EOF
  repack "$home" "$tag"
}
# publish_no_start HOME TAG: release TAG that writes a row, then dies on start.
publish_no_start() {
  local home=$1 tag=$2
  publish "$home" "$tag"
  cat >"$home/build-$tag/engram" <<'EOF'
#!/usr/bin/env bash
sqlite3 "$ENGRAM_DATA_DIR/engram.db" "INSERT INTO obs VALUES ('migrated');"
exit 1
EOF
  repack "$home" "$tag"
}
# repack HOME TAG: republish the edited build of release TAG.
repack() {
  local home=$1 tag=$2 rel
  rel="$home/remote/github.com/$REPO/releases/download/v$tag"
  chmod +x "$home/build-$tag/engram"
  tar -czf "$rel/engram_${tag}_linux_amd64.tar.gz" -C "$home/build-$tag" engram
  (cd "$rel" && sha256sum "engram_${tag}_linux_amd64.tar.gz" >checksums.txt)
}
has_row() { [[ $(sqlite3 "$1/.engram/engram.db" "SELECT count(*) FROM obs WHERE t = '$2'") -ge 1 ]]; }
lacks_row() { ! has_row "$1" "$2"; }

home=$(sandbox doctor-blocked 3.4.0 none)
old_copies "$home" 3.1.0 3.2.0
publish_doctor "$home" 3.5.0 0 '{"status":"blocked","summary":{"total":10,"ok":8,"warnings":1,"blocked":1,"errors":0}}'
update "$home" '' --yes
assert 'warnings and blocked checks exit 0' test "$LAST_EXIT" -eq 0
assert 'warnings and blocked checks keep the new binary' engram_is "$home" 3.5.0
assert 'warnings and blocked checks keep the database' has_row "$home" migrated
assert 'warnings and blocked checks still prune' test "$(database_copies "$home")" -eq 2

home=$(sandbox failed-doctor-keeps 3.4.0 none)
old_copies "$home" 3.1.0 3.2.0
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
update "$home" '' --yes
assert 'a failed doctor fails the update' test "$LAST_EXIT" -ne 0
assert 'a failed doctor removes no database copy' test "$(database_copies "$home")" -eq 4
assert 'a failed doctor removes no binary copy' test "$(binary_copies "$home")" == '3.1.0 3.2.0 3.4.0'

home=$(sandbox wrong-version-keeps 3.4.0 none)
old_copies "$home" 3.1.0 3.2.0
publish "$home" 3.5.0 3.4.9
update "$home" '' --yes
assert 'a binary that does not start removes no database copy' test "$(database_copies "$home")" -eq 4
assert 'a binary that does not start removes no binary copy' test "$(binary_copies "$home")" == '3.1.0 3.2.0 3.4.0'

echo "== never updates without a sound copy =="

# fake_vacuum HOME BODY: a sqlite3 whose VACUUM INTO runs BODY; the rest is real.
fake_vacuum() {
  cat >"$1/bin/sqlite3" <<EOF
#!/usr/bin/env bash
case \$2 in
  *'VACUUM INTO'*) $2 ;;
  *) exec $(command -v sqlite3) "\$@" ;;
esac
EOF
  chmod +x "$1/bin/sqlite3"
}
copies_kept_and_engram_alone() {
  [[ $(database_copies "$1") -eq 3 && $(binary_copies "$1") == '3.1.0 3.2.0' ]] && engram_is "$1" 3.4.0
}

home=$(sandbox copy-fails 3.4.0 3.5.0)
old_copies "$home" 3.1.0 3.2.0
fake_vacuum "$home" 'exit 1'
update "$home" '' --yes
assert 'a failed database copy fails the update' test "$LAST_EXIT" -ne 0
assert 'a failed database copy is reported' says 'could not back up the database'
assert 'a failed database copy stops before the swap and costs no copy' copies_kept_and_engram_alone "$home"

# The copy command reports success, but what it wrote is no database.
home=$(sandbox copy-corrupt 3.4.0 3.5.0)
old_copies "$home" 3.1.0 3.2.0
fake_vacuum "$home" "echo garbage >\"\$(printf %s \"\$2\" | rg -o \"/[^']*\")\""
update "$home" '' --yes
assert 'a corrupt database copy fails the update' test "$LAST_EXIT" -ne 0
assert 'a corrupt database copy is reported' says 'could not back up the database'
assert 'a corrupt database copy stops before the swap and costs no copy' copies_kept_and_engram_alone "$home"

echo "== restores on a yes =="

home=$(sandbox restore-doctor-exit 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
update "$home" $'y\n' --yes
assert 'a restore still fails the update' test "$LAST_EXIT" -ne 0
assert 'the previous binary is back' engram_is "$home" 3.4.0
assert 'the old memories are back' has_row "$home" kept
assert 'what the new version wrote is gone' lacks_row "$home" migrated
assert 'the question warns newer memories are lost' says 'are lost'
assert 'the restore is reported' says 'restored: engram 3.4.0 and the database'
assert 'open sessions are told to restart' says 'Restart Claude Code'

home=$(sandbox restore-no-start 3.4.0 none)
publish_no_start "$home" 3.5.0
update "$home" $'y\n' --yes
assert 'a restore after a dead binary fails the update' test "$LAST_EXIT" -ne 0
assert 'a restore after a dead binary brings the previous binary back' engram_is "$home" 3.4.0
assert 'a restore after a dead binary brings the old memories back' has_row "$home" kept
assert 'a restore after a dead binary drops what it wrote' lacks_row "$home" migrated
assert 'a restore after a dead binary is reported' says 'restored: engram 3.4.0 and the database'

# The database copy is gone by the time of the restore: all or nothing.
home=$(sandbox restore-impossible 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
FAKE_DOCTOR_LOSE_COPY=1 update "$home" $'y\n' --yes
no_restored_claim() { ! says 'restored:'; }
assert 'an impossible restore fails the update' test "$LAST_EXIT" -ne 0
assert 'an impossible restore is reported' says 'restore failed'
assert 'an impossible restore does not claim success' no_restored_claim
assert 'an impossible restore leaves the binary alone' engram_is "$home" 3.5.0
assert 'an impossible restore leaves the database alone' has_row "$home" migrated

# The copy was damaged after the update made it: it must not replace the database.
home=$(sandbox restore-corrupt 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
FAKE_DOCTOR_CORRUPT_COPY=1 update "$home" $'y\n' --yes
assert 'a corrupt copy is not restored' says 'restore failed'
assert 'a corrupt copy does not claim success' no_restored_claim
assert 'a corrupt copy leaves the binary alone' engram_is "$home" 3.5.0
assert 'a corrupt copy leaves the database alone' has_row "$home" migrated

# A leftover write-ahead log must not replay over the restored copy.
home=$(sandbox restore-wal 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
FAKE_DOCTOR_LEAVE_WAL=1 update "$home" $'y\n' --yes
assert 'the restore reports success with a stale log around' says 'restored: engram 3.4.0 and the database'
assert 'the stale write-ahead log is gone' test ! -e "$home/.engram/engram.db-wal"
assert 'the stale shared-memory file is gone' test ! -e "$home/.engram/engram.db-shm"

# fake_server HOME: a server that takes half a second to die, as a real one may.
fake_server() {
  (
    bash -c 'trap "sleep 0.5; exit 0" TERM; for _ in {1..300}; do sleep 0.1; done' >/dev/null 2>&1 &
    echo $! >"$1/state/serve-pid"
  )
}
server_gone() { [[ $(ps -o stat= -p "$(cat "$1/state/serve-pid")" 2>/dev/null) != [^Z]* ]]; }
# server_started_as HOME VERSION: VERSION started once, with the old server gone.
server_started_as() {
  local _
  for _ in {1..50}; do
    [[ -s $1/state/serve-calls ]] && break
    sleep 0.1
  done
  [[ $(cat "$1/state/serve-calls" 2>/dev/null) == "$2" ]]
}
stop_fake_server() { kill "$(cat "$1/state/serve-pid")" 2>/dev/null || true; }

home=$(sandbox restore-server 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
fake_server "$home"
FAKE_RESTART_SERVER=1 FAKE_SERVE_CMDLINE="$home/local/bin/engram serve" update "$home" $'y\n' --yes
assert 'a restore stops a server running under an absolute path' server_gone "$home"
assert 'a restore starts the previous binary once the old server is gone' server_started_as "$home" 3.4.0
stop_fake_server "$home"

home=$(sandbox update-server 3.4.0 3.5.0)
fake_server "$home"
FAKE_RESTART_SERVER=1 FAKE_SERVE_CMDLINE='engram serve' update "$home" '' --yes
assert 'an update stops a server started by bare name' server_gone "$home"
assert 'an update starts the new binary once the old server is gone' server_started_as "$home" 3.5.0
stop_fake_server "$home"

home=$(sandbox restore-no-server 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
FAKE_RESTART_SERVER=1 update "$home" $'y\n' --yes
assert 'a restore starts no server when none was running' test ! -e "$home/state/serve-calls"

# stuck_server HOME: a server that ignores the request to stop.
stuck_server() {
  (
    bash -c 'trap "" TERM; for _ in {1..300}; do sleep 0.1; done' >/dev/null 2>&1 &
    echo $! >"$1/state/serve-pid"
  )
}
kill_stuck_server() { kill -9 "$(cat "$1/state/serve-pid")" 2>/dev/null || true; }
# A server starts in the background: give a wrong one the time to show up.
no_server_started() {
  sleep 0.5
  [[ ! -e $1/state/serve-calls ]]
}

home=$(sandbox restore-stuck 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
stuck_server "$home"
FAKE_DOCTOR_LEAVE_WAL=1 FAKE_RESTART_SERVER=1 FAKE_SERVE_CMDLINE="$home/local/bin/engram serve" update "$home" $'y\n' --yes
kill_stuck_server "$home"
assert 'a stuck server fails the restore' test "$LAST_EXIT" -ne 0
assert 'a stuck server is reported' says 'engram serve did not stop'
assert 'a stuck server does not claim a restore' no_restored_claim
assert 'a stuck server keeps the write-ahead log' test -e "$home/.engram/engram.db-wal"
assert 'a stuck server keeps the database' has_row "$home" migrated
assert 'a stuck server keeps the binary' engram_is "$home" 3.5.0
assert 'a stuck server still gets the restore commands' says 'To restore by hand'
assert 'a stuck server gets no second server' no_server_started "$home"

home=$(sandbox update-stuck 3.4.0 3.5.0)
stuck_server "$home"
FAKE_RESTART_SERVER=1 FAKE_SERVE_CMDLINE='engram serve' update "$home" '' --yes
kill_stuck_server "$home"
assert 'a healthy update with a stuck server warns' says 'engram serve did not stop'
assert 'a healthy update with a stuck server starts no second one' no_server_started "$home"

# The doctor exits 0 and only its report says it failed.
home=$(sandbox restore-doctor-errors 3.4.0 none)
publish_doctor "$home" 3.5.0 0 '{"status":"error","summary":{"total":10,"ok":9,"errors":1}}'
update "$home" $'y\n' --yes
assert 'a report with errors fails the update' test "$LAST_EXIT" -ne 0
assert 'a report with errors brings the previous binary back' engram_is "$home" 3.4.0
assert 'a report with errors drops what the new version wrote' lacks_row "$home" migrated

# An unreadable report is no evidence of a failure: warn, never overwrite.
home=$(sandbox doctor-unreadable 3.4.0 none)
publish_doctor "$home" 3.5.0 0 'not json'
update "$home" '' --yes
assert 'an unreadable report keeps the update' test "$LAST_EXIT" -eq 0
assert 'an unreadable report keeps the database' has_row "$home" migrated
assert 'an unreadable report warns' says 'could not read the engram doctor report'

echo "== without a yes, the database stays =="

# printed_commands: the indented lines after the restore header in $LAST_OUTPUT.
printed_commands() { printf '%s\n' "$LAST_OUTPUT" | sed -n '/^To restore by hand/,$p' | rg '^  '; }

home=$(sandbox decline-doctor 3.4.0 none)
publish_doctor "$home" 3.5.0 1 '{"status":"error","summary":{"errors":1}}'
FAKE_DOCTOR_LEAVE_WAL=1 update "$home" '' --yes
assert 'no answer after a failed doctor fails the update' test "$LAST_EXIT" -ne 0
assert 'no answer keeps the new binary, which may have migrated the database' engram_is "$home" 3.5.0
# Look at the log before any query: opening the database makes sqlite discard it.
assert 'no answer leaves the write-ahead log alone' test -e "$home/.engram/engram.db-wal"
cp "$home/.engram/engram.db-wal" "$home/state/wal-before-query"
assert 'no answer leaves the database untouched' has_row "$home" migrated
assert 'no answer says to stop engram before the commands' says 'Stop engram serve and close Claude Code'
commands=$(printed_commands)
assert 'restore commands are printed' test -n "$commands"
cp "$home/state/wal-before-query" "$home/.engram/engram.db-wal"
bash -euc "$commands"
assert 'the printed commands drop the stale log' test ! -e "$home/.engram/engram.db-wal"
assert 'the printed commands bring the previous binary back' engram_is "$home" 3.4.0
assert 'the printed commands bring the old memories back' has_row "$home" kept
assert 'the printed commands drop what the new version wrote' lacks_row "$home" migrated

home=$(sandbox decline-no-start 3.4.0 none)
publish_no_start "$home" 3.5.0
update "$home" '' --yes
no_commands() { [[ -z $(printed_commands) ]]; }
assert 'no answer after a dead binary fails the update' test "$LAST_EXIT" -ne 0
assert 'no answer after a dead binary brings the previous binary back' engram_is "$home" 3.4.0
assert 'no answer after a dead binary leaves the database untouched' has_row "$home" migrated
assert 'no answer after a dead binary prints no restore commands' no_commands

echo "== major versions always ask =="

home=$(sandbox major-no 3.4.0 4.0.0)
update "$home" $'n\n' --yes
assert 'major bump is flagged' says 'MAJOR'
assert 'major bump ignores --yes and can be declined' engram_is "$home" 3.4.0

home=$(sandbox major-yes 3.4.0 4.0.0)
update "$home" $'y\n' --yes
assert 'major bump applies after confirmation' engram_is "$home" 4.0.0

echo "== regenerates the OpenCode and Antigravity build =="

installed_with() { rg -qxF -- "$2" "$1/state/install-calls" 2>/dev/null; }

home=$(sandbox regen-opencode 3.4.0 3.4.0)
mkdir -p "$home/.config/opencode"
update "$home" ''
assert 'regeneration with nothing to update exits 0' test "$LAST_EXIT" -eq 0
assert 'OpenCode installed: its build is regenerated' installed_with "$home" '--target opencode'
assert 'a changed build asks to restart OpenCode' says 'Restart OpenCode'
update "$home" ''
silent_restart() { ! says 'Restart OpenCode'; }
assert 'an unchanged build does not ask to restart' silent_restart
echo v2 >"$home/repo/source"
update "$home" ''
assert 'a pulled change asks to restart again' says 'Restart OpenCode'

home=$(sandbox regen-agy 3.4.0 3.4.0)
mkdir -p "$home/.gemini/antigravity-cli"
update "$home" ''
assert 'Antigravity installed: its build is regenerated' installed_with "$home" '--target antigravity'

home=$(sandbox regen-both 3.4.0 3.4.0)
mkdir -p "$home/.config/opencode" "$home/.gemini/antigravity-cli"
update "$home" ''
assert 'both installed: both builds are regenerated' installed_with "$home" '--target opencode,antigravity'

home=$(sandbox regen-fail 3.4.0 3.4.0)
mkdir -p "$home/.config/opencode"
FAKE_INSTALL_FAIL=1 update "$home" ''
assert 'a failed generation fails ai-update' test "$LAST_EXIT" -ne 0
assert 'a failed generation is reported' says 'gen.sh failed; the previous build is kept'

no_install() { [[ ! -e $1/state/install-calls ]]; }
home=$(sandbox regen-check 3.4.0 3.4.0)
mkdir -p "$home/.config/opencode" "$home/.gemini/antigravity-cli"
update "$home" '' --check
assert 'check leaves the build alone' no_install "$home"

home=$(sandbox regen-none 3.4.0 3.4.0)
update "$home" ''
assert 'no OpenCode or Antigravity: nothing is regenerated' no_install "$home"
assert 'no OpenCode or Antigravity: no restart line' silent_restart

echo "== failures leave engram intact =="

home=$(sandbox badsum 3.4.0 3.5.0)
printf '%064d  engram_3.5.0_linux_amd64.tar.gz\n' 0 \
  >"$home/remote/github.com/$REPO/releases/download/v3.5.0/checksums.txt"
update "$home" '' --yes
assert 'checksum mismatch fails' test "$LAST_EXIT" -ne 0
assert 'checksum mismatch is reported' says 'checksum mismatch'
assert 'checksum mismatch leaves engram alone' engram_is "$home" 3.4.0
assert 'checksum mismatch makes no backup' no_backup "$home" 3.4.0

home=$(sandbox wrongver 3.4.0 3.5.0)
publish "$home" 3.5.0 3.4.9
update "$home" '' --yes
assert 'wrong installed version fails' test "$LAST_EXIT" -ne 0
assert 'wrong installed version rolls back' engram_is "$home" 3.4.0
assert 'rollback is reported' says 'rolled back'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
