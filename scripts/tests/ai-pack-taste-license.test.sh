#!/usr/bin/env bash
# Tests that `ai-pack add taste`, with the real manifest and vendor dir, gives a
# project the upstream MIT LICENSE. Offline; node and chromium are stubs, since
# only the requirement check needs them.
# Run: bash scripts/tests/ai-pack-taste-license.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/ai-pack"
SKILL=.claude/skills/design-taste-frontend
# sha256 of LICENSE in the taste-skill v2.1.2 tag tarball.
UPSTREAM_LICENSE=4575a543ab88dad12ccea7d97e563d0bce5b448b06072e65d3264497dad326df
failures=0
TMP_ROOT=$(realpath "$(mktemp -d)")
trap 'chmod -R u+rwx "$TMP_ROOT" 2>/dev/null; rm -rf "$TMP_ROOT"' EXIT

# Isolate git from the user's config and hooks.
mkdir -p "$TMP_ROOT/home" "$TMP_ROOT/stubs"
export HOME="$TMP_ROOT/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$TMP_ROOT/home/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.name t
git config --file "$GIT_CONFIG_GLOBAL" user.email t@t
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false

printf '#!/usr/bin/env bash\necho v22.0.0\n' >"$TMP_ROOT/stubs/node"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_ROOT/stubs/chromium"
chmod +x "$TMP_ROOT/stubs/node" "$TMP_ROOT/stubs/chromium"
export PATH="$TMP_ROOT/stubs:$PATH" AI_PACK_STATE="$TMP_ROOT/state"

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

LAST_EXIT=0
# pack [ARGS...]: run ai-pack; status in $LAST_EXIT, output shown on failure.
pack() {
  local out
  out=$(bash "$SCRIPT" "$@" 2>&1)
  LAST_EXIT=$?
  ((LAST_EXIT == 0)) || printf '%s\n' "$out"
}
exit_is() { [[ $LAST_EXIT == "$1" ]]; }

new_proj() {
  P="$TMP_ROOT/proj-$1"
  mkdir -p "$P"
  git init -q "$P" && git -C "$P" commit -q --allow-empty -m init
  rm -rf "$AI_PACK_STATE"
}

license_sha() { sha256sum "$P/$SKILL/LICENSE" 2>/dev/null | cut -d' ' -f1; }
# other_files: path and sha256 of every skill file except LICENSE.
other_files() {
  (cd "$P/$SKILL" && find . -type f ! -name LICENSE ! -name .gitignore -print0 |
    LC_ALL=C sort -z | xargs -0 sha256sum)
}

echo "== a new project =="
new_proj fresh
pack add taste --cwd "$P"
assert 'add succeeds' exit_is 0
assert 'the LICENSE holds the upstream bytes' test "$(license_sha)" = "$UPSTREAM_LICENSE"

echo "== an earlier, unedited copy =="
# The earlier release: the vendored skill with no LICENSE, under its own pin.
FIX="$TMP_ROOT/fix"
mkdir -p "$FIX/vendor"
cp -a "$ROOT/packs/vendor/taste-skill" "$FIX/vendor/taste-skill"
rm -f "$FIX/vendor/taste-skill/LICENSE"
jq --arg d "$SKILL" --arg h "$(bash "$SCRIPT" hash "$FIX/vendor/taste-skill")" \
  '.tools.taste.project_dirs[$d].hash = $h' "$ROOT/packs/packs.json" >"$FIX/packs.json"

new_proj earlier
AI_PACK_MANIFEST="$FIX/packs.json" pack add taste --cwd "$P"
assert 'the earlier copy installs' exit_is 0
assert 'the earlier copy has no LICENSE' test ! -e "$P/$SKILL/LICENSE"
before=$(other_files)
assert 'the earlier copy has other files' test -n "$before"
pack add taste --cwd "$P"
assert 'adding again succeeds' exit_is 0
assert 'the copy gains the upstream LICENSE' test "$(license_sha)" = "$UPSTREAM_LICENSE"
assert 'its other files stay the same' test "$(other_files)" = "$before"

if ((failures > 0)); then
  printf '%d case(s) failed\n' "$failures"
  exit 1
fi
echo 'All cases passed'
