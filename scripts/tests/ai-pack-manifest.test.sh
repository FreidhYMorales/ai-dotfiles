#!/usr/bin/env bash
# Tests for the real packs/packs.json: schema, names, pack membership, requires,
# detect rules, pins equal `ai-pack hash` of the vendored dirs, upstream pins.
# Run: bash scripts/tests/ai-pack-manifest.test.sh. Offline: nothing is fetched.
# jq filters are single-quoted on purpose: $t and $r are jq variables.
# shellcheck disable=SC2016
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/ai-pack"
M="$ROOT/packs/packs.json"
V="$ROOT/packs/vendor"
failures=0
TMP_ROOT=$(realpath "$(mktemp -d)")
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/home"
export HOME="$TMP_ROOT/home" AI_PACK_STATE="$TMP_ROOT/state"

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

# q FILTER [ARGS...]: jq -e against the manifest, silent.
q() { jq -e "$@" "$M" >/dev/null 2>&1; }
hash_of() { bash "$SCRIPT" hash "$1" 2>/dev/null; }

echo "== schema and names =="
assert 'manifest exists and is valid JSON' q .
assert 'schema_version is 1' q '.schema_version == 1'
assert 'pack and tool names are unique in one namespace' \
  q '([.packs, .tools] | map(keys[]) | length) == ([.packs, .tools] | map(keys[]) | unique | length)'
assert 'every pack tool is defined' q '[.packs[].tools[] as $t | .tools | has($t)] | all'
assert 'every tool belongs to a pack' q '. as $m | [.tools | keys[] as $t | [$m.packs[].tools[]] | index($t) != null] | all'
assert 'every tool has kind, layers and project_dirs' \
  q '[.tools[] | (.kind | IN("skill", "npm")) and (.layers | type == "array") and (.project_dirs | type == "object")] | all'
assert 'project dir keys are relative, without .., under .claude/skills or .playwright' \
  q '[.tools[].project_dirs | keys[] | (startswith("/") or contains("..") | not) and (startswith(".claude/skills/") or . == ".playwright")] | all'
assert 'every pin is sha256:<64 hex>' \
  q '[.tools[].project_dirs[].hash | test("^sha256:[0-9a-f]{64}$")] | all'

echo "== packs =="
assert 'web has playwright, web-design-guidelines, taste' \
  q '.packs.web.tools == ["playwright", "web-design-guidelines", "taste"]'
assert 'diagrams has archify' q '.packs.diagrams.tools == ["archify"]'
assert 'web detects vite, react, vue, svelte, next, astro in package.json' \
  q '.packs.web.detect.package_deps_any == ["vite", "react", "vue", "svelte", "next", "astro"]'
assert 'web detects index.html' q '.packs.web.detect.files_any == ["index.html"]'
assert 'diagrams has no detect rules' q '.packs.diagrams.detect == {}'

echo "== requires =="
assert 'playwright needs node >= 22, npm and chromium with the pacman hint' \
  q '.tools.playwright.requires | (map(select(.cmd == "node"))[0].min == "22") and (map(.cmd) | index("npm") != null)
     and (map(select(.cmd == "chromium"))[0].hint == "sudo pacman -S chromium")'
assert 'taste needs node >= 22 and chromium with the pacman hint' \
  q '.tools.taste.requires | (map(select(.cmd == "node"))[0].min == "22")
     and (map(select(.cmd == "chromium"))[0].hint == "sudo pacman -S chromium")'
assert 'archify needs node >= 18' q '.tools.archify.requires | map(select(.cmd == "node"))[0].min == "18"'
assert 'every requires entry has a hint' q '[.tools[].requires[]? | .hint | type == "string"] | all'

echo "== sources =="
assert 'playwright is npm @playwright/cli 0.1.22 with a sha512 integrity and the playwright-cli bin' \
  q '.tools.playwright | .kind == "npm" and .source.package == "@playwright/cli" and .source.version == "0.1.22"
     and (.source.integrity | test("^sha512-[A-Za-z0-9+/]{86}==$")) and .bins == ["playwright-cli"]'
assert 'playwright copies its skill from the npm package' \
  q '.tools.playwright.project_dirs[".claude/skills/playwright-cli"].from == "npm:skills/playwright-cli"'
assert 'playwright config dir is vendored and its output is a leftover' \
  q '.tools.playwright.project_dirs[".playwright"].from == "vendor:playwright" and (.tools.playwright.leftovers | index(".playwright/output") != null)'
assert 'taste is vendored v2.1.2 into a dir named after its frontmatter name' \
  q '.tools.taste | .source == {type: "vendored", tag: "v2.1.2"} and .project_dirs[".claude/skills/design-taste-frontend"].from == "vendor:taste-skill"'
assert 'taste declares the .taste-skill leftover' q '.tools.taste.leftovers | index(".taste-skill") != null'
assert 'archify is vendored v3.2.0' \
  q '.tools.archify | .source == {type: "vendored", tag: "v3.2.0"} and .project_dirs[".claude/skills/archify"].from == "vendor:archify"'
assert 'web-design-guidelines fetches rules from a 40-hex commit over https with a sha256' \
  q '.tools["web-design-guidelines"].source | .type == "fetched" and .name == "rules"
     and (.url | test("^https://raw\\.githubusercontent\\.com/vercel-labs/web-interface-guidelines/[0-9a-f]{40}/command\\.md$"))
     and (.sha256 | test("^[0-9a-f]{64}$"))'
assert 'web-design-guidelines renders vendor:web-design-guidelines/SKILL.md' \
  q '.tools["web-design-guidelines"].project_dirs[".claude/skills/web-design-guidelines"] | .from == "vendor:web-design-guidelines" and .template == "SKILL.md"'

echo "== pins match the vendored trees =="
while IFS=$'\t' read -r tool rel from pin; do
  [[ $from == vendor:* ]] || continue
  name=${from#vendor:}
  is_tpl=$(jq -r --arg t "$tool" --arg r "$rel" '.tools[$t].project_dirs[$r].template // empty' "$M")
  [[ -z $is_tpl ]] || continue # rendered with fetched bytes; checked below
  assert "$tool $rel pin equals ai-pack hash of vendor/$name" test "$(hash_of "$V/$name")" = "$pin"
done < <(jq -r '.tools | to_entries[] | .key as $t | .value.project_dirs | to_entries[]
  | [$t, .key, .value.from, .value.hash] | @tsv' "$M")

echo "== web-design-guidelines template =="
tpl="$V/web-design-guidelines"
assert 'vendor dir holds only SKILL.md (rules are never committed)' \
  test "$(find "$tpl" -type f | wc -l)" -eq 1 -a -f "$tpl/SKILL.md"
assert 'template has exactly one {{FETCHED:rules}} marker line' \
  test "$(grep -cx '{{FETCHED:rules}}' "$tpl/SKILL.md")" -eq 1
assert 'template frontmatter names the skill' test "$(sed -n 's/^name: //p' "$tpl/SKILL.md")" = web-design-guidelines
assert 'no rules text is committed anywhere in packs/' \
  test -z "$(grep -rlF 'Icon-only buttons need' "$ROOT/packs" 2>/dev/null)"

echo "== vendored trees =="
assert 'taste SKILL.md name matches the project dir' \
  test "$(sed -n 's/^name: *//p' "$V/taste-skill/SKILL.md" | head -n1)" = design-taste-frontend
assert 'archify update check is patched off (check-update.mjs)' \
  grep -q 'ai-dotfiles vendor patch' "$V/archify/scripts/check-update.mjs"
assert 'archify update check is patched off (delivery-update.mjs)' \
  grep -q 'ai-dotfiles vendor patch' "$V/archify/bin/delivery-update.mjs"
assert 'vendor README documents both tags' \
  test "$(grep -c -e 'v3\.2\.0' -e 'v2\.1\.2' "$V/README.md")" -ge 2
assert 'vendor README names the archive checksums' test "$(grep -c 'sha256' "$V/README.md")" -ge 2

echo "== upstreams.json =="
up_has() { jq -e --arg r "$1" '.upstreams | any(.repo == $r)' "$ROOT/upstreams.json" >/dev/null; }
for r in tt-a1i/archify Leonxlnx/taste-skill vercel-labs/web-interface-guidelines microsoft/playwright-cli; do
  assert "upstreams watches $r" up_has "$r"
done
up_reviewed() { jq -r --arg r "$1" '.upstreams[] | select(.repo == $r) | .reviewed' "$ROOT/upstreams.json"; }
assert 'upstreams pins archify v3.2.0' test "$(up_reviewed tt-a1i/archify)" = v3.2.0
assert 'upstreams pins taste-skill v2.1.2' test "$(up_reviewed Leonxlnx/taste-skill)" = v2.1.2
assert 'upstreams pins playwright-cli v0.1.22' test "$(up_reviewed microsoft/playwright-cli)" = v0.1.22
assert 'upstreams pins the guidelines at a commit' \
  test "$(up_reviewed vercel-labs/web-interface-guidelines | grep -cE '^[0-9a-f]{40}$')" -eq 1

echo
if [[ $failures -gt 0 ]]; then
  printf '%d failure(s)\n' "$failures"
  exit 1
fi
echo "all passed"
