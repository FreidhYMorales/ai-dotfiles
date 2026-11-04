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
  # shellcheck disable=SC2016 # $1 belongs to the generated stub.
  printf '#!/usr/bin/env bash\ncase $1 in version) echo "engram %s" ;; doctor) echo "doctor: ok" ;; esac\n' \
    "$2" >"$1"
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
  chmod +x "$home/bin/curl" "$home/bin/claude"
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
    AI_UPDATE_RESTART_SERVER=0 bash "$SCRIPT" "$@" 2>&1)
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
