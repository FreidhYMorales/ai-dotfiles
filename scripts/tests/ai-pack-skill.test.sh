#!/usr/bin/env bash
# Tests for `ai-pack add` with vendored skills: staging, classification,
# adoption, re-sync, rollback. Run: bash scripts/tests/ai-pack-skill.test.sh
# Uses a fixture manifest and tiny vendor dirs; nothing touches the real packs.
# jq filters are single-quoted on purpose: $k and $t are jq variables.
# shellcheck disable=SC2016
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/ai-pack"
failures=0
TMP_ROOT=$(realpath "$(mktemp -d)")
trap 'chmod -R u+rwx "$TMP_ROOT" 2>/dev/null; rm -rf "$TMP_ROOT"' EXIT

# Isolate git from the user's config and hooks.
mkdir -p "$TMP_ROOT/home"
export HOME="$TMP_ROOT/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$TMP_ROOT/home/gitconfig"
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

FIX="$TMP_ROOT/fix"
STATE="$TMP_ROOT/state"
export AI_PACK_MANIFEST="$FIX/packs.json" AI_PACK_STATE="$STATE"
LAST_OUTPUT=""
LAST_EXIT=0
# pack [ARGS...]: run ai-pack; output in $LAST_OUTPUT, status in $LAST_EXIT.
pack() {
  LAST_OUTPUT=$(bash "$SCRIPT" "$@" 2>&1)
  LAST_EXIT=$?
}
says() { [[ $LAST_OUTPUT == *"$1"* ]]; }
exit_is() { [[ $LAST_EXIT -eq $1 ]]; }
absent() { [[ ! -e $1 && ! -L $1 ]]; }
has_line() { [[ $(<"$2") == "$1" ]]; }
journal() { jq -r "$@" "$STATE/projects.json" 2>/dev/null; }

# Fixture: vendor dirs alpha and beta; packs duo, needy (missing command),
# broken (second tool has a wrong pin). mk_manifest re-pins from the vendor dirs.
mk_vendor() {
  mkdir -p "$FIX/vendor/alpha/sub" "$FIX/vendor/beta"
  printf 'alpha %s\n' "$1" >"$FIX/vendor/alpha/SKILL.md"
  printf 'a\n' >"$FIX/vendor/alpha/sub/a"
  printf 'beta\n' >"$FIX/vendor/beta/SKILL.md"
}
mk_manifest() {
  local ha hb
  ha=$(bash "$SCRIPT" hash "$FIX/vendor/alpha")
  hb=$(bash "$SCRIPT" hash "$FIX/vendor/beta")
  jq -n --arg ha "$ha" --arg hb "$hb" '
    def tool($v; $h; $r): {kind: "skill", layers: ["project"], requires: $r,
      source: {type: "vendored", tag: "v1"},
      project_dirs: {(".claude/skills/" + $v[0]): {from: ("vendor:" + $v[1]), hash: $h}}};
    {schema_version: 1,
     packs: {duo: {tools: ["alpha", "beta"], detect: {}},
             needy: {tools: ["alpha", "gamma"], detect: {}},
             broken: {tools: ["alpha", "bad"], detect: {}}},
     tools: {alpha: tool(["alpha", "alpha"]; $ha; []),
             beta: tool(["beta", "beta"]; $hb; []),
             gamma: tool(["gamma", "beta"]; $hb; [{cmd: "no-such-cmd-xyz", hint: "sudo pacman -S foo"}]),
             bad: tool(["bad", "beta"]; "sha256:00"; [])}}' >"$FIX/packs.json"
}
new_proj() {
  P="$TMP_ROOT/proj-$1"
  mkdir -p "$P"
  git init -q "$P" && git -C "$P" commit -q --allow-empty -m init
  rm -rf "$STATE"
}

mk_vendor 1
mk_manifest

echo "== add new =="
new_proj new
pack add duo --cwd "$P"
assert 'add duo succeeds' exit_is 0
assert 'skill files copied' test "$(cat "$P/.claude/skills/alpha/sub/a")" = a
assert 'dir is self-ignoring' has_line '*' "$P/.claude/skills/alpha/.gitignore"
assert 'journal lists files with sha256' test \
  "$(journal --arg k "$P" '.projects[$k].tools.alpha.files | map(.path) | sort | join(",")')" = \
  ".claude/skills/alpha/SKILL.md,.claude/skills/alpha/sub/a"
assert 'journal records via' test "$(journal --arg k "$P" '.projects[$k].tools.beta.via | join(",")')" = duo
assert 'journal records version' test "$(journal --arg k "$P" '.projects[$k].tools.beta.version')" = v1
assert 'notice to reload plugins' says 'run /reload-plugins'
assert 'no stage left behind' test -z "$(find "$P/.claude" -maxdepth 1 -name '.ai-pack-stage-*')"
pack add duo --cwd "$P"
assert 'second add is a no-op that succeeds' exit_is 0

echo "== worktrees stay clean =="
new_proj wt
git -C "$P" worktree add -q "$TMP_ROOT/wt2" -b other
pack add alpha --cwd "$P"
assert 'git status clean in the project' test -z "$(git -C "$P" status --porcelain)"
assert 'git status clean in the other worktree' test -z "$(git -C "$TMP_ROOT/wt2" status --porcelain)"
assert 'other worktree has no pack file' absent "$TMP_ROOT/wt2/.claude"

echo "== preflight =="
new_proj pre
pack add needy --cwd "$P"
assert 'missing requirement fails' exit_is 1
assert 'prints the hint' says 'no-such-cmd-xyz not found; install it with: sudo pacman -S foo'
assert 'says nothing was written' says 'nothing was written'
assert 'no project dir written' absent "$P/.claude/skills/alpha"
assert 'no state written' absent "$STATE/projects.json"
pack add nope --cwd "$P"
assert 'unknown name fails' exit_is 1

echo "== foreign target and adoption =="
new_proj foreign
mkdir -p "$P/.claude/skills/alpha"
printf 'mine\n' >"$P/.claude/skills/alpha/own"
pack add alpha --cwd "$P"
assert 'foreign target refused' exit_is 1
assert 'foreign content untouched' test "$(cat "$P/.claude/skills/alpha/own")" = mine
assert 'refusal writes no state' absent "$STATE/projects.json"
new_proj adopt
mkdir -p "$P/.claude/skills"
cp -a "$FIX/vendor/alpha" "$P/.claude/skills/alpha"
printf '*\n' >"$P/.claude/skills/alpha/.gitignore"
pack add alpha --cwd "$P"
assert 'unjournaled matching dir adopted' exit_is 0
assert 'adoption is journaled' test "$(journal --arg k "$P" '.projects[$k].tools.alpha.dirs[0]')" = .claude/skills/alpha

echo "== re-sync =="
new_proj sync
pack add alpha --cwd "$P"
mk_vendor 2
mk_manifest
pack add alpha --cwd "$P"
assert 're-sync succeeds' exit_is 0
assert 're-sync replaced the content' test "$(cat "$P/.claude/skills/alpha/SKILL.md")" = 'alpha 2'
assert 're-sync does not nest' absent "$P/.claude/skills/alpha/alpha"
assert 're-sync leaves no stage' test -z "$(find "$P/.claude" -maxdepth 1 -name '.ai-pack-stage-*')"
assert 're-sync journal has the new hash' test \
  "$(journal --arg k "$P" '.projects[$k].tools.alpha.files[] | select(.path | endswith("SKILL.md")) | .sha256')" = \
  "$(sha256sum "$FIX/vendor/alpha/SKILL.md" | cut -d' ' -f1)"
printf 'edited\n' >"$P/.claude/skills/alpha/SKILL.md"
mk_vendor 3
mk_manifest
pack add alpha --cwd "$P"
assert 'edited copy warns' says 'edited by hand'
assert 'edited copy unchanged' test "$(cat "$P/.claude/skills/alpha/SKILL.md")" = edited

echo "== rollback and stale stages =="
new_proj roll
pack add broken --cwd "$P"
assert 'second tool failure exits non-zero' test "$LAST_EXIT" -ne 0
assert 'first tool dir rolled back' absent "$P/.claude/skills/alpha"
assert 'no journal after rollback' absent "$STATE/projects.json"
assert 'rollback leaves no stage' test -z "$(find "$P/.claude" -maxdepth 1 -name '.ai-pack-stage-*')"
new_proj rollsync
pack add alpha --cwd "$P"
mk_vendor 4
mk_manifest
pack add broken --cwd "$P"
assert 'replaced dir swapped back on failure' test "$(cat "$P/.claude/skills/alpha/SKILL.md")" = 'alpha 3'
new_proj stale
mkdir -p "$P/.claude/.ai-pack-stage-old"
printf 'x\n' >"$P/.claude/.ai-pack-stage-old/f"
pack add beta --cwd "$P"
assert 'stale stage deleted' absent "$P/.claude/.ai-pack-stage-old"

if [[ $failures -gt 0 ]]; then
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
echo "all passed"
