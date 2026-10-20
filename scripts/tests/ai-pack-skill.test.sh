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

# curl stub: serves $FAKE_CURL/<basename of the URL>; a missing file exits 6.
mkdir -p "$TMP_ROOT/stubs" "$TMP_ROOT/served"
cat >"$TMP_ROOT/stubs/curl" <<'STUB'
#!/usr/bin/env bash
echo called >>"$CURL_LOG"
out=""
while [[ $# -gt 1 ]]; do
  [[ $1 == -o ]] && out=$2
  shift
done
src="$FAKE_CURL/$(basename "$1")"
[[ -f $src ]] || exit 6
cp "$src" "$out"
STUB
chmod +x "$TMP_ROOT/stubs/curl"
export PATH="$TMP_ROOT/stubs:$PATH" FAKE_CURL="$TMP_ROOT/served" CURL_LOG="$TMP_ROOT/curl.log"

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
lacks() { [[ $LAST_OUTPUT != *"$1"* ]]; }
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
  # tpl: a template tool; its rules are fetched. expect/tpl is the rendered result.
  mkdir -p "$FIX/vendor/tpl" "$TMP_ROOT/expect/tpl"
  printf 'head\n{{FETCHED:rules}}\ntail\n' >"$FIX/vendor/tpl/SKILL.md"
  printf 'rule one\nrule two\n' >"$FAKE_CURL/rules.md"
  printf 'head\nrule one\nrule two\ntail\n' >"$TMP_ROOT/expect/tpl/SKILL.md"
  # A fifo makes hashing the staged copy block, so a run can be signaled mid-flight.
  mkdir -p "$FIX/vendor/slow"
  [[ -p $FIX/vendor/slow/p ]] || mkfifo "$FIX/vendor/slow/p"
}
mk_manifest() {
  local ha hb ht sr
  ha=$(bash "$SCRIPT" hash "$FIX/vendor/alpha")
  hb=$(bash "$SCRIPT" hash "$FIX/vendor/beta")
  ht=$(bash "$SCRIPT" hash "$TMP_ROOT/expect/tpl")
  sr=$(sha256sum "$FAKE_CURL/rules.md" | cut -d' ' -f1)
  jq -n --arg ha "$ha" --arg hb "$hb" --arg ht "$ht" --arg sr "$sr" '
    def tool($v; $h; $r): {kind: "skill", layers: ["project"], requires: $r,
      source: {type: "vendored", tag: "v1"},
      project_dirs: {(".claude/skills/" + $v[0]): {from: ("vendor:" + $v[1]), hash: $h}}};
    def fetched($sha; $file): {kind: "skill", layers: ["project"], requires: [],
      source: {type: "fetched", name: "rules", url: ("https://example.invalid/pins/" + $file), sha256: $sha},
      project_dirs: {".claude/skills/tpl": {from: "vendor:tpl", template: "SKILL.md", hash: $ht}}};
    {schema_version: 1,
     packs: {fetchy: {tools: ["tpl"], detect: {}},
             fetchbad: {tools: ["alpha", "tplbad"], detect: {}},
             fetchmiss: {tools: ["alpha", "tplmiss"], detect: {}},
             duo: {tools: ["alpha", "beta"], detect: {}},
             needy: {tools: ["alpha", "gamma"], detect: {}},
             broken: {tools: ["alpha", "bad"], detect: {}},
             hang: {tools: ["alpha", "slow"], detect: {}}},
     tools: {tpl: fetched($sr; "rules.md"), tplbad: fetched("0"; "rules.md"),
             tplmiss: fetched($sr; "missing.md"),
             alpha: tool(["alpha", "alpha"]; $ha; []),
             beta: tool(["beta", "beta"]; $hb; []),
             gamma: tool(["gamma", "beta"]; $hb; [{cmd: "no-such-cmd-xyz", hint: "sudo pacman -S foo"}]),
             bad: tool(["bad", "beta"]; "sha256:00"; []),
             slow: tool(["slow", "slow"]; "sha256:00"; [])}}
    | .tools.alpha.leftovers = [".claude/skills/alpha/out"]
    | .packs.alone = {tools: ["alpha"], detect: {}}' >"$FIX/packs.json"
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
assert 'skill-only add does not ask for a restart' lacks 'restart Claude in this project'
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
assert 'rollback leaves no stage' test -z "$(find "$P/.claude" -maxdepth 1 -name '.ai-pack-stage-*' 2>/dev/null)"
assert 'rollback removes the dirs it created' absent "$P/.claude"
new_proj rollsync
pack add alpha --cwd "$P"
mk_vendor 4
mk_manifest
pack add broken --cwd "$P"
assert 'replaced dir swapped back on failure' test "$(cat "$P/.claude/skills/alpha/SKILL.md")" = 'alpha 3'
new_proj extra
pack add alpha --cwd "$P"
printf 'mine\n' >"$P/.claude/skills/alpha/notes.md"
pack add alpha --cwd "$P"
assert 'extra file warns on same-version re-add' says 'edited by hand'
assert 'extra file kept on same-version re-add' test "$(cat "$P/.claude/skills/alpha/notes.md")" = mine
mk_vendor 5
mk_manifest
pack add alpha --cwd "$P"
assert 'extra file warns on version bump' says 'edited by hand'
assert 'extra file kept on version bump' test "$(cat "$P/.claude/skills/alpha/notes.md")" = mine
assert 'version bump skipped the dir' test "$(cat "$P/.claude/skills/alpha/SKILL.md")" != 'alpha 5'
echo "== signal =="
new_proj term
setsid bash "$SCRIPT" add hang --cwd "$P" >"$TMP_ROOT/term.out" 2>&1 &
pid=$!
for _ in $(seq 100); do
  [[ -d $P/.claude/skills/alpha && -n $(find "$P/.claude" -maxdepth 1 -name '.ai-pack-stage-*') ]] && break
  sleep 0.1
done
kill -TERM -- "-$pid"
wait "$pid"
assert 'TERM exits non-zero' test $? -ne 0
assert 'TERM rolled back the moved dir' absent "$P/.claude"
assert 'TERM wrote no state' absent "$STATE/projects.json"
new_proj stale
mkdir -p "$P/.claude/.ai-pack-stage-old"
printf 'x\n' >"$P/.claude/.ai-pack-stage-old/f"
pack add beta --cwd "$P"
assert 'stale stage deleted' absent "$P/.claude/.ai-pack-stage-old"

echo "== fetched and templated =="
new_proj fetch
pack add fetchy --cwd "$P"
assert 'fetched add succeeds' exit_is 0
assert 'rules templated into SKILL.md' cmp -s "$P/.claude/skills/tpl/SKILL.md" "$TMP_ROOT/expect/tpl/SKILL.md"
P1=$P
new_proj fetch2
pack add fetchy --cwd "$P"
assert 'template is deterministic across projects' cmp -s "$P/.claude/skills/tpl/SKILL.md" "$P1/.claude/skills/tpl/SKILL.md"
new_proj badsum
pack add fetchbad --cwd "$P"
assert 'checksum mismatch fails' exit_is 1
assert 'checksum mismatch says so' says 'sha256 mismatch'
assert 'checksum mismatch writes no project dir' absent "$P/.claude"
assert 'checksum mismatch writes no state' absent "$STATE/projects.json"
new_proj netfail
pack add fetchmiss --cwd "$P"
assert 'network error fails' exit_is 1
assert 'network error writes no project dir' absent "$P/.claude"
assert 'network error writes no state' absent "$STATE/projects.json"

echo "== fetch protocol =="
for u in http://example.invalid/pins/rules.md file:///etc/hostname; do
  jq --arg u "$u" '.tools.tpl.source.url = $u' "$FIX/packs.json" >"$FIX/p3.json"
  new_proj proto
  : >"$CURL_LOG"
  AI_PACK_MANIFEST="$FIX/p3.json" pack add fetchy --cwd "$P"
  assert "non-https url refused: $u" exit_is 1
  assert "refusal mentions https: $u" says 'https'
  assert "curl was not called: $u" test ! -s "$CURL_LOG"
  assert "refusal writes nothing: $u" absent "$P/.claude"
done

echo "== shadow =="
SK="$HOME/.claude/skills/synced/id1/alpha"
mkdir -p "$SK" "$HOME/.claude/skills/synced/id2/other" "$HOME/.claude/plugins/cache/mk/pl/1.0/skills/tpl"
printf 'x\n' >"$SK/SKILL.md"
printf -- '---\nname: "beta"\n---\n' >"$HOME/.claude/skills/synced/id2/other/SKILL.md"
printf 'y\n' >"$HOME/.claude/plugins/cache/mk/pl/1.0/skills/tpl/SKILL.md"
new_proj shadow
pack add duo --cwd "$P"
assert 'add still succeeds when shadowed' exit_is 0
assert 'nested personal skill shadows by dir name' says 'alpha is shadowed by ~/.claude/skills/synced/id1/alpha'
assert 'frontmatter name shadows' says 'beta is shadowed by ~/.claude/skills/synced/id2/other'
pack add fetchy --cwd "$P"
assert 'depth-6 plugin cache skill shadows' says 'tpl is shadowed by ~/.claude/plugins/cache/mk/pl/1.0/skills/tpl'

echo "== list =="
rm -rf "$HOME/.claude"
new_proj list
pack list --cwd "$P"
assert 'list works without any state' exit_is 0
assert 'list writes no state dir' absent "$STATE"
mkdir -p "$STATE"
printf '{"schema_version":0}\n' >"$STATE/projects.json"
old_sum=$(sha256sum "$STATE/projects.json")
pack list --cwd "$P"
assert 'list with an older-schema state file succeeds' exit_is 0
assert 'older-schema list uses defaults (tool shown as not added)' says 'not added'
assert 'older-schema list leaves the file alone' test "$(sha256sum "$STATE/projects.json")" = "$old_sum"
assert 'older-schema list writes nothing else' test "$(find "$STATE" -type f | wc -l)" -eq 1
rm -rf "$STATE"
assert 'inactive tool is shown' says 'alpha   '
assert 'pack row lists its tools' says 'duo'
pack add duo --cwd "$P"
snap() { find "$STATE" -type f -printf '%p %T@ %s\n' | LC_ALL=C sort; }
before=$(snap)
pack list --cwd "$P"
assert 'list marks active with via' says '(via duo)'
assert 'list shows the journal version' says 'v1'
assert 'a pack with every tool active is marked ✔' says ' duo       ✔  '
assert 'a partly active pack is marked ◐' says ' needy     ◐  '
assert 'a pack with no active tool is marked ·' says ' fetchy    ·  '
assert 'list changes no state file' test "$(snap)" = "$before"
jq '.tools.alpha.source.tag = "v2"' "$FIX/packs.json" >"$FIX/p2.json"
AI_PACK_MANIFEST="$FIX/p2.json" pack list --cwd "$P"
assert 'list shows drift' says 'v1 -> v2 available'
jq '.tools.alpha.source = {type: "vendored", commit: "4ecfb9fb8d1d3b7009674869b3aaee2f904042e1"}' \
  "$FIX/packs.json" >"$FIX/pc.json"
AI_PACK_MANIFEST="$FIX/pc.json" pack list --cwd "$P"
assert 'a commit-pinned source shows its short commit' says 'v1 -> 4ecfb9f available'
printf '{"schema_version":1,"tools":{"alpha":{"current":"v9"}}}\n' >"$STATE/machine.json"
pack list --cwd "$P"
assert 'list shows machine version' says '(machine v9)'
jq --arg d "$TMP_ROOT/gone-root" '.projects[$d] = {tools: {alpha: {version: "v1", dirs: [], files: []}}}' \
  "$STATE/projects.json" >"$STATE/p.tmp" && mv "$STATE/p.tmp" "$STATE/projects.json"
before=$(snap)
pack list --cwd "$P"
assert 'dead roots are not listed' lacks gone-root
assert 'dead roots are not dropped by list' test "$(snap)" = "$before"
rm -rf "$P/.claude/skills/beta"
pack list --cwd "$P"
assert 'dir removed by hand is reported' says 'missing'
new_proj adoptable
mkdir -p "$P/.claude/skills"
cp -a "$FIX/vendor/alpha" "$P/.claude/skills/alpha"
pack list --cwd "$P"
assert 'unjournaled matching dir is adoptable' says 'adoptable'
assert 'adoptable view writes no state' absent "$STATE"
mkdir -p "$HOME/.claude/skills/synced/$(printf 'long%.0s' {1..20})/alpha"
printf 'x\n' >"$HOME/.claude/skills/synced/$(printf 'long%.0s' {1..20})/alpha/SKILL.md"
pack list --cwd "$P"
assert 'shadow shown by list' says 'shadowed by ~/.claude/skills/synced/long'
maxlen() { LC_ALL=C.UTF-8 awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' <<<"$LAST_OUTPUT"; }
assert 'no line exceeds 70 columns' test "$(maxlen)" -le 70
rm -rf "$HOME/.claude/skills/synced"
valid_utf8() { iconv -f UTF-8 -t UTF-8 <<<"$LAST_OUTPUT" >/dev/null 2>&1; }
U8="$HOME/.claude/skills/synced/xy$(printf 'é%.0s' {1..80})"
mkdir -p "$U8/alpha"
printf 'x\n' >"$U8/alpha/SKILL.md"
for loc in C default; do
  if [[ $loc == C ]]; then LC_ALL=C pack list --cwd "$P"; else pack list --cwd "$P"; fi
  assert "truncated output is valid UTF-8 ($loc)" valid_utf8
  assert "truncated output is <= 70 characters ($loc)" test "$(maxlen)" -le 70
done
jq '.tools["a-very-long-tool-name"] = .tools.beta' "$FIX/packs.json" >"$FIX/p4.json"
AI_PACK_MANIFEST="$FIX/p4.json" pack list --cwd "$P"
assert 'long tool names keep the columns aligned' test "$(awk '/-- tools --/ { f = 1; next }
  f && /^ [^ ]/ { match($0, / (✔|·) /); print RSTART }' <<<"$LAST_OUTPUT" | sort -u | wc -l)" -eq 1

echo "== remove =="
nostage() { test -z "$(find "$P/.claude" -maxdepth 1 -name '.ai-pack-stage-*' 2>/dev/null)"; }
new_proj rm
pack add duo --cwd "$P"
mkdir -p "$P/.claude/.ai-pack-stage-old"
pack remove duo --cwd "$P"
assert 'remove succeeds' exit_is 0
assert 'remove deletes the first dir' absent "$P/.claude/skills/alpha"
assert 'remove deletes the second dir' absent "$P/.claude/skills/beta"
assert 'remove leaves no journal entry' test "$(journal --arg k "$P" '.projects[$k] // "none"')" = none
assert 'remove cleans stale stages' nostage
pack remove nope --cwd "$P"
assert 'remove of an unknown name fails' exit_is 1
new_proj rmedit
pack add duo --cwd "$P"
printf 'edited\n' >"$P/.claude/skills/alpha/SKILL.md"
pack remove duo --cwd "$P"
assert 'edited file: remove succeeds' exit_is 0
assert 'edited file warns' says 'SKILL.md was changed by hand'
assert 'edited file: tells how to re-add' says 'delete .claude/skills/alpha to re-add'
assert 'edited file keeps the dir untouched' test "$(cat "$P/.claude/skills/alpha/sub/a")" = a
assert 'edited file keeps the edit' test "$(cat "$P/.claude/skills/alpha/SKILL.md")" = edited
assert 'other tool is still removed' absent "$P/.claude/skills/beta"
assert 'edited tool loses its journal entry' test "$(journal --arg k "$P" '.projects[$k] // "none"')" = none
new_proj rmextra
pack add alpha --cwd "$P"
printf 'mine\n' >"$P/.claude/skills/alpha/notes.md"
pack remove alpha --cwd "$P"
assert 'added file warns' says 'notes.md was changed by hand'
assert 'added file is kept' test "$(cat "$P/.claude/skills/alpha/notes.md")" = mine
assert 'added file keeps journaled files too' test -f "$P/.claude/skills/alpha/SKILL.md"
new_proj rmleft
pack add alpha --cwd "$P"
mkdir -p "$P/.claude/skills/alpha/out"
printf 'log\n' >"$P/.claude/skills/alpha/out/log"
pack remove alpha --cwd "$P"
assert 'leftover: journaled file removed' absent "$P/.claude/skills/alpha/SKILL.md"
assert 'leftover: journaled subdir removed' absent "$P/.claude/skills/alpha/sub"
assert 'leftover is kept' test "$(cat "$P/.claude/skills/alpha/out/log")" = log
assert 'leftover keeps .gitignore so it stays ignored' has_line '*' "$P/.claude/skills/alpha/.gitignore"
assert 'leftover is printed' says '.claude/skills/alpha/out'
assert 'leftover does not warn' lacks 'warning'
assert 'leftover stays out of git status' test -z "$(git -C "$P" status --porcelain)"
new_proj rmhand
pack add duo --cwd "$P"
rm -rf "$P/.claude/skills/alpha"
rm "$P/.claude/skills/beta/SKILL.md"
pack remove duo --cwd "$P"
assert 'hand-removed dir: remove succeeds' exit_is 0
assert 'hand-removed dir: no warning' lacks 'warning'
assert 'hand-removed file: dir is removed' absent "$P/.claude/skills/beta"
assert 'hand-removed dir: no journal entry' test "$(journal --arg k "$P" '.projects[$k] // "none"')" = none

echo "== remove shared tools =="
new_proj shared
pack add duo --cwd "$P"
pack add alone --cwd "$P"
pack remove duo --cwd "$P"
assert 'shared tool stays when another pack needs it' test -f "$P/.claude/skills/alpha/SKILL.md"
assert 'shared tool says who needs it' says 'alpha is still needed by alone'
assert 'shared tool via drops the removed pack' test "$(journal --arg k "$P" '.projects[$k].tools.alpha.via | join(",")')" = alone
assert 'unshared tool is removed' absent "$P/.claude/skills/beta"
pack remove alone --cwd "$P"
assert 'last pack removes the shared tool' absent "$P/.claude/skills/alpha"
new_proj byname
pack add duo --cwd "$P"
pack remove alpha --cwd "$P"
assert 'tool by name kept while a pack needs it' test -f "$P/.claude/skills/alpha/SKILL.md"
assert 'tool by name says which pack' says 'alpha is still needed by duo'
pack add alpha --cwd "$P"
pack remove duo --cwd "$P"
assert 'pack removal keeps a directly added tool' test -f "$P/.claude/skills/alpha/SKILL.md"
assert 'direct add is named' says 'alpha is still needed by direct'
pack remove alpha --cwd "$P"
assert 'tool by name removes the last reason' absent "$P/.claude/skills/alpha"

echo "== purge =="
mk_machine() {
  mkdir -p "$STATE"
  jq -n --arg a "$1" --arg b "$2" --arg c "$3" \
    '{schema_version: 1, tools: {alpha: {current: "v1", projects: [$a, $b, $c]}, beta: {current: "v1", projects: [$a]}}}' >"$STATE/machine.json"
}
mach() { jq -r "$@" "$STATE/machine.json"; }
new_proj purge
Q="$TMP_ROOT/other-live"
D="$TMP_ROOT/dead-root"
mkdir -p "$Q"
mk_machine "$P" "$Q" "$D"
pack add alpha --cwd "$P"
exec 8>"$STATE/lock"
flock -n 8
AI_PACK_LOCK_WAIT=1 pack remove --purge alpha --cwd "$P"
exec 8>&-
assert 'purge needs the lock first' says 'holds the lock'
assert 'locked purge touches nothing' test "$(mach '.tools.alpha.projects | length')" -eq 3
pack remove --purge alpha --cwd "$P"
assert 'purge refuses while another project uses the tool' exit_is 1
assert 'refusal lists the project' says "still used by $Q; nothing removed"
assert 'dead root is shown' says "$D"
assert 'dead root is dropped before the refusal' test "$(mach '.tools.alpha.projects | index($d)' --arg d "$D")" = null
assert 'refused purge keeps the files' test -f "$P/.claude/skills/alpha/SKILL.md"
assert 'refused purge keeps the journal' test "$(journal --arg k "$P" '.projects[$k].tools.alpha.version')" = v1
rm -rf "$Q"
pack remove --purge alpha --cwd "$P"
assert 'purge succeeds once the other root is gone' exit_is 0
assert 'second dead root is shown' says "$Q"
assert 'purge removes the project dir' absent "$P/.claude/skills/alpha"
assert 'purge drops the machine entry' test "$(mach '.tools.alpha // "none"')" = none
assert 'purge leaves other machine tools' test "$(mach '.tools.beta.current')" = v1
new_proj purge2
pack add duo --cwd "$P"
mk_machine "$P" "$TMP_ROOT/none-a" "$TMP_ROOT/none-b"
pack remove --purge alpha --cwd "$P"
assert 'purge refuses when another pack here still needs it' exit_is 1
assert 'that refusal names this project' says "still used by $P; nothing removed"
assert 'that refusal removed nothing' test -f "$P/.claude/skills/beta/SKILL.md"
pack remove duo --cwd "$P"
assert 'plain remove leaves the machine entry' test "$(mach '.tools.alpha.current')" = v1
assert 'plain remove drops this project from the refcount' test "$(mach '.tools.alpha.projects | index($p)' --arg p "$P")" = null

echo "== remove path safety =="
OUT="$TMP_ROOT/outside"
mkdir -p "$OUT"
tamper() {
  jq "$@" "$STATE/projects.json" >"$STATE/p.new" && mv "$STATE/p.new" "$STATE/projects.json"
}
new_proj pathb
pack add alpha --cwd "$P"
printf 'victim\n' >"$OUT/b"
tamper --arg k "$P" --arg h "$(sha256sum "$OUT/b" | cut -d' ' -f1)" \
  '.projects[$k].tools.alpha.files += [{path: ".claude/skills/alpha/../../../../outside/b", sha256: $h}]'
pack remove alpha --cwd "$P"
assert 'dotdot file path never deletes outside the project' test "$(cat "$OUT/b")" = victim
assert 'dotdot file path keeps the dir' test -f "$P/.claude/skills/alpha/SKILL.md"
for d in "" . "../outside" "/etc" ".claude/skills/../.."; do
  new_proj pathc
  pack add alpha --cwd "$P"
  mkdir -p "$P/emptyuserdir"
  printf 'x\n' >"$P/userfile"
  tamper --arg k "$P" --arg d "$d" '.projects[$k].tools.alpha.dirs += [$d]'
  pack remove alpha --cwd "$P"
  assert "bogus journal dir [$d] keeps user dirs" test -d "$P/emptyuserdir" -a -d "$P/.git" -a -f "$P/userfile"
  assert "bogus journal dir [$d] still removes the real one" absent "$P/.claude/skills/alpha"
done
new_proj symdir
pack add alpha --cwd "$P"
mkdir -p "$OUT/eskills"
cp -a "$P/.claude/skills/alpha" "$OUT/eskills/"
rm -rf "$P/.claude/skills"
ln -s "$OUT/eskills" "$P/.claude/skills"
pack remove alpha --cwd "$P"
assert 'symlinked skills dir: outside copy kept' test -f "$OUT/eskills/alpha/SKILL.md"
assert 'symlinked skills dir: warns' says 'outside the project'
new_proj symsub
pack add alpha --cwd "$P"
cp -a "$P/.claude/skills/alpha/sub" "$OUT/jsub"
rm -rf "$P/.claude/skills/alpha/sub"
ln -s "$OUT/jsub" "$P/.claude/skills/alpha/sub"
pack remove alpha --cwd "$P"
assert 'symlinked subdir: outside copy kept' test -f "$OUT/jsub/a"
new_proj gitig
pack add alpha --cwd "$P"
printf '*\n# my note\n' >"$P/.claude/skills/alpha/.gitignore"
pack remove alpha --cwd "$P"
assert 'edited .gitignore is kept' test -f "$P/.claude/skills/alpha/.gitignore"
assert 'edited .gitignore warns' says '.gitignore was changed by hand'
assert 'edited .gitignore keeps the other files' test -f "$P/.claude/skills/alpha/SKILL.md"

echo "== created parents =="
new_proj parents
pack add alpha --cwd "$P"
pack remove alpha --cwd "$P"
assert 'dirs add created are removed when empty' absent "$P/.claude"
new_proj preexist
mkdir -p "$P/.claude/skills/mine"
pack add alpha --cwd "$P"
pack remove alpha --cwd "$P"
assert 'pre-existing dirs are kept' test -d "$P/.claude/skills/mine"
new_proj partial
pack add alpha --cwd "$P"
mkdir -p "$P/.claude/skills/mine"
pack remove alpha --cwd "$P"
assert 'created dir kept when the user put something in it' test -d "$P/.claude/skills/mine"

echo "== add path safety =="
new_proj addsym
mkdir -p "$OUT/claude-target"
ln -s "$OUT/claude-target" "$P/.claude"
pack add alpha --cwd "$P"
assert 'add refuses a .claude symlink to outside' exit_is 1
assert 'add says why' says 'outside the project'
assert 'nothing was written through the symlink' test -z "$(find "$OUT/claude-target" -mindepth 1)"
assert 'no state written' absent "$STATE/projects.json"
new_proj addsym2
mkdir -p "$P/.claude"
ln -s "$OUT/claude-target" "$P/.claude/skills"
pack add alpha --cwd "$P"
assert 'add refuses a skills symlink to outside' exit_is 1
assert 'nothing written through the skills symlink' test -z "$(find "$OUT/claude-target" -mindepth 1)"

if [[ $failures -gt 0 ]]; then
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
echo "all passed"
