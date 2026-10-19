#!/usr/bin/env bash
# Tests for `ai-pack` with kind npm: pack integrity, staging prefix, bin links,
# machine.json, machine-wide upgrade, purge. Run: bash scripts/tests/ai-pack-npm.test.sh
# Uses an npm stub and a fixture package; nothing touches the real npm or packs.
# jq filters are single-quoted on purpose: $k and $t are jq variables.
# shellcheck disable=SC2016
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/ai-pack"
failures=0
TMP_ROOT=$(realpath "$(mktemp -d)")
trap 'chmod -R u+rwx "$TMP_ROOT" 2>/dev/null; rm -rf "$TMP_ROOT"' EXIT

# Isolate git and the user's dirs.
mkdir -p "$TMP_ROOT/home"
export HOME="$TMP_ROOT/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$TMP_ROOT/home/gitconfig"
unset XDG_BIN_HOME XDG_DATA_HOME
git config --file "$GIT_CONFIG_GLOBAL" user.name t
git config --file "$GIT_CONFIG_GLOBAL" user.email t@t
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false

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

# Stubs: curl (never reached), node, fix-chromium, npm. The npm stub packs a text
# file "<name> <ver>"; install lays out node_modules/<name>/skill and .bin/fixcli.
S="$TMP_ROOT/stubs"
mkdir -p "$S"
printf '#!/usr/bin/env bash\nexit 6\n' >"$S/curl"
printf '#!/usr/bin/env bash\necho v22.1.0\n' >"$S/node"
printf '#!/usr/bin/env bash\necho Chromium 1\n' >"$S/fix-chromium"
cat >"$S/npm" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$NPM_LOG"
cmd=$1
shift
case $cmd in
  pack)
    spec=$1 dest=""
    [[ $2 == --pack-destination ]] && dest=$3
    name=${spec%@*} ver=${spec##*@}
    file=${name#@}
    file=${file//\//-}-$ver.tgz
    printf '%s %s\n' "$name" "$ver" >"$dest/$file"
    echo "$file"
    ;;
  install)
    prefix="" tar=""
    while [[ $# -gt 0 ]]; do
      [[ $1 == --prefix ]] && prefix=$2
      tar=$1
      shift
    done
    mkdir -p "$prefix/node_modules/.bin"
    [[ ${FAKE_NPM_FAIL:-} != install ]] || exit 1
    read -r name ver <"$tar"
    mkdir -p "$prefix/node_modules/$name/skill"
    printf 'skill %s\n' "$ver" >"$prefix/node_modules/$name/skill/SKILL.md"
    printf '#!/bin/sh\necho %s\n' "$ver" >"$prefix/node_modules/.bin/fixcli"
    chmod +x "$prefix/node_modules/.bin/fixcli"
    ;;
esac
STUB
chmod +x "$S"/*
export PATH="$S:$PATH" NPM_LOG="$TMP_ROOT/npm.log"

FIX="$TMP_ROOT/fix"
STATE="$TMP_ROOT/state"
NPMROOT="$HOME/.local/share/ai-pack/npm"
BIN="$HOME/.local/bin"
export AI_PACK_MANIFEST="$FIX/packs.json" AI_PACK_STATE="$STATE"
LAST_OUTPUT=""
LAST_EXIT=0
pack() {
  LAST_OUTPUT=$(bash "$SCRIPT" "$@" 2>&1)
  LAST_EXIT=$?
}
says() { [[ $LAST_OUTPUT == *"$1"* ]]; }
lacks() { [[ $LAST_OUTPUT != *"$1"* ]]; }
exit_is() { [[ $LAST_EXIT -eq $1 ]]; }
absent() { [[ ! -e $1 && ! -L $1 ]]; }
mach() { jq -r "$@" "$STATE/machine.json" 2>/dev/null; }
calls() { grep -c "^$1 " "$NPM_LOG" 2>/dev/null || true; }
link_is() { [[ $(readlink "$BIN/fixcli") == "$NPMROOT/fixweb@$1/node_modules/.bin/fixcli" ]]; }

# mk_manifest VERSION [JQ FILTER]: fixture npm tool pinned to what the stub packs.
mk_manifest() {
  local ver=$1 sk hc integ
  rm -rf "$FIX/pkg"
  mkdir -p "$FIX/pkg/skill" "$FIX/vendor/fixcfg"
  printf 'skill %s\n' "$ver" >"$FIX/pkg/skill/SKILL.md"
  printf '{}\n' >"$FIX/vendor/fixcfg/cli.config.json"
  sk=$(bash "$SCRIPT" hash "$FIX/pkg/skill")
  hc=$(bash "$SCRIPT" hash "$FIX/vendor/fixcfg")
  integ="sha512-$(printf '@fix/cli %s\n' "$ver" | openssl dgst -sha512 -binary | base64 -w0)"
  jq -n --arg v "$ver" --arg i "$integ" --arg sk "$sk" --arg hc "$hc" '
    {schema_version: 1, packs: {webx: {tools: ["fixweb"], detect: {}}},
     tools: {fixweb: {kind: "npm", layers: ["machine", "project"],
       source: {type: "npm", package: "@fix/cli", version: $v, integrity: $i},
       bins: ["fixcli"],
       requires: [{cmd: "node", min: "22", hint: "sudo pacman -S nodejs"},
                  {cmd: "npm", hint: "sudo pacman -S npm"},
                  {cmd: "fix-chromium", hint: "sudo pacman -S chromium"}],
       project_dirs: {".claude/skills/fixcli": {from: "npm:skill", hash: $sk},
                      ".fixcli": {from: "vendor:fixcfg", hash: $hc}},
       leftovers: [".fixcli/output"]}}}' | jq "${2:-.}" >"$FIX/packs.json"
}
new_proj() {
  P="$TMP_ROOT/proj-$1"
  mkdir -p "$P"
  git init -q "$P" && git -C "$P" commit -q --allow-empty -m init
}
reset_machine() { rm -rf "$STATE" "$HOME/.local"; : >"$NPM_LOG"; }

echo "== add =="
mk_manifest 0.1.22
reset_machine
new_proj a
pack add webx --cwd "$P"
assert 'add succeeds' exit_is 0
assert 'prefix installed' test -x "$NPMROOT/fixweb@0.1.22/node_modules/.bin/fixcli"
assert 'staging gone' absent "$NPMROOT/fixweb@0.1.22.staging"
assert 'bin link points into the prefix' link_is 0.1.22
assert 'npm install used --ignore-scripts' grep -q -- '--ignore-scripts' "$NPM_LOG"
assert 'machine current recorded' test "$(mach '.tools.fixweb.current')" = 0.1.22
assert 'machine prefix recorded' test "$(mach '.tools.fixweb.versions["0.1.22"].prefix')" = "$NPMROOT/fixweb@0.1.22"
assert 'machine bin recorded' test "$(mach '.tools.fixweb.bins.fixcli')" = "$NPMROOT/fixweb@0.1.22/node_modules/.bin/fixcli"
assert 'machine refcount has the project' test "$(mach --arg k "$P" '.tools.fixweb.projects | index($k)')" = 0
assert 'skill copied from the installed package' test "$(<"$P/.claude/skills/fixcli/SKILL.md")" = 'skill 0.1.22'
assert 'vendored config copied' test -f "$P/.fixcli/cli.config.json"
assert 'first install needs no restart notice' lacks 'restart your Claude sessions'
before=$(calls install)
pack add webx --cwd "$P"
assert 're-add succeeds' exit_is 0
assert 're-add installs nothing' test "$(calls install)" = "$before"

echo "== integrity mismatch =="
mk_manifest 0.1.22 '.tools.fixweb.source.integrity = "sha512-AAAA"'
reset_machine
new_proj mismatch
pack add webx --cwd "$P"
assert 'mismatch fails' exit_is 1
assert 'mismatch says so' says 'integrity mismatch'
assert 'npm install never ran' test "$(calls install)" = 0
assert 'no prefix or staging' absent "$NPMROOT/fixweb@0.1.22"
assert 'no link' absent "$BIN/fixcli"
assert 'no machine.json' absent "$STATE/machine.json"
assert 'no project files' absent "$P/.claude"

echo "== install failure =="
mk_manifest 0.1.22
reset_machine
new_proj fail
FAKE_NPM_FAIL=install pack add webx --cwd "$P"
assert 'failed install exits 1' exit_is 1
assert 'staging removed' absent "$NPMROOT/fixweb@0.1.22.staging"
assert 'prefix absent' absent "$NPMROOT/fixweb@0.1.22"
assert 'machine.json absent' absent "$STATE/machine.json"
assert 'no link after a failed install' absent "$BIN/fixcli"
pack add webx --cwd "$P"
mk_manifest 0.1.23
cp "$STATE/machine.json" "$TMP_ROOT/machine.before"
FAKE_NPM_FAIL=install pack add webx --cwd "$P"
assert 'failed upgrade exits 1' exit_is 1
assert 'machine.json untouched by the failed upgrade' cmp -s "$STATE/machine.json" "$TMP_ROOT/machine.before"
assert 'old link kept' link_is 0.1.22
assert 'new staging removed' absent "$NPMROOT/fixweb@0.1.23.staging"

echo "== rollback after the machine layer =="
mk_manifest 0.1.22 '.tools.fixweb.project_dirs[".claude/skills/fixcli"].hash = "sha256:00"'
reset_machine
new_proj rollback
pack add webx --cwd "$P"
assert 'bad pin fails the run' exit_is 1
assert 'prefix rolled back' absent "$NPMROOT/fixweb@0.1.22"
assert 'link rolled back' absent "$BIN/fixcli"
assert 'machine.json absent' absent "$STATE/machine.json"

echo "== bin collision =="
mk_manifest 0.1.22
reset_machine
new_proj collide
mkdir -p "$BIN"
printf 'mine\n' >"$BIN/fixcli"
pack add webx --cwd "$P"
assert 'foreign file refused' exit_is 1
assert 'foreign file intact' test "$(<"$BIN/fixcli")" = mine
assert 'nothing else written' absent "$NPMROOT/fixweb@0.1.22"
assert 'no machine.json' absent "$STATE/machine.json"
assert 'no project files' absent "$P/.claude"
rm -f "$BIN/fixcli"
ln -s /bin/true "$BIN/fixcli"
pack add webx --cwd "$P"
assert 'foreign symlink refused' exit_is 1
assert 'foreign symlink intact' test "$(readlink "$BIN/fixcli")" = /bin/true

echo "== requires =="
reset_machine
new_proj req
mk_manifest 0.1.22 '.tools.fixweb.requires[2].cmd = "no-such-chromium"'
pack add webx --cwd "$P"
assert 'missing chromium exits 1' exit_is 1
assert 'prints the pacman line' says 'sudo pacman -S chromium'
assert 'says nothing was written' says 'nothing was written'
assert 'no prefix' absent "$NPMROOT/fixweb@0.1.22"
# A PATH without npm: the implicit npm requirement fires even if the manifest omits it.
mk_manifest 0.1.22 '.tools.fixweb.requires |= map(select(.cmd != "npm"))'
NN="$TMP_ROOT/nonpm"
mkdir -p "$NN"
for c in bash env jq flock curl sha256sum sha512sum basenc base64 tr cut mktemp mv ln rm mkdir find sort dirname \
  realpath readlink stat cp chmod awk date git head iconv rmdir cat tail uniq openssl node fix-chromium; do
  p=$(PATH="$S:/usr/bin" command -v "$c") && ln -sf "$p" "$NN/$c"
done
LAST_OUTPUT=$(PATH="$NN" bash "$SCRIPT" add webx --cwd "$P" 2>&1)
LAST_EXIT=$?
assert 'implicit npm requirement fails' exit_is 1
assert 'implicit npm hint' says 'sudo pacman -S npm'

echo "== machine-wide upgrade =="
mk_manifest 0.1.22
reset_machine
new_proj up-a
A=$P
new_proj up-b
B=$P
pack add webx --cwd "$A"
pack add webx --cwd "$B"
mk_manifest 0.1.23
pack add webx --cwd "$A"
assert 'upgrade succeeds' exit_is 0
assert 'upgrade prints the restart notice' says 'restart your Claude sessions'
assert 'link switched' link_is 0.1.23
assert 'old prefix kept' test -d "$NPMROOT/fixweb@0.1.22"
assert 'machine current bumped' test "$(mach '.tools.fixweb.current')" = 0.1.23
assert 'skill re-synced in A' test "$(<"$A/.claude/skills/fixcli/SKILL.md")" = 'skill 0.1.23'
pack list --cwd "$B"
assert 'list in B shows the machine version' says '(machine 0.1.23)'

echo "== purge =="
pack remove --purge webx --cwd "$A"
assert 'purge refuses while B uses it' exit_is 1
assert 'refusal names B' says "$B"
assert 'nothing removed' test -d "$NPMROOT/fixweb@0.1.23"
pack remove webx --cwd "$A"
pack remove --purge webx --cwd "$B"
assert 'purge succeeds' exit_is 0
assert 'all prefixes removed' absent "$NPMROOT/fixweb@0.1.22"
assert 'current prefix removed' absent "$NPMROOT/fixweb@0.1.23"
assert 'bin link removed' absent "$BIN/fixcli"
assert 'machine entry dropped' test "$(mach '.tools.fixweb // "none"')" = none

echo "== purge keeps what is not ours =="
mk_manifest 0.1.22
reset_machine
new_proj keep
pack add webx --cwd "$P"
mkdir -p "$NPMROOT/fixweb@9.9.9"
rm -f "$BIN/fixcli"
ln -s /bin/true "$BIN/fixcli"
pack remove --purge webx --cwd "$P"
assert 'purge succeeds' exit_is 0
assert 'own prefix removed' absent "$NPMROOT/fixweb@0.1.22"
assert 'unrecorded prefix kept' test -d "$NPMROOT/fixweb@9.9.9"
assert 'relinked bin kept' test "$(readlink "$BIN/fixcli")" = /bin/true

if [[ $failures -gt 0 ]]; then
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
echo "all passed"
