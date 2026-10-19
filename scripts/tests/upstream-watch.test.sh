#!/usr/bin/env bash
# Tests for bin/upstream-watch. Run: bash scripts/tests/upstream-watch.test.sh
# A stub `gh` answers from fixture files, so no network is used.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/upstream-watch"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# Stub gh: `gh api <path>` prints $FAKE_GH/<path with / and ? as _>, or fails.
mkdir -p "$TMP_ROOT/bin"
cat >"$TMP_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ $1 == api ]] || exit 1
key=${2//\//_}
key=${key//\?/_}
[[ -f $FAKE_GH/$key ]] || exit 1
cat "$FAKE_GH/$key"
EOF
chmod +x "$TMP_ROOT/bin/gh"

# fixture NAME: a fake GitHub with two watched repos. Prints the dir.
fixture() {
  local d="$TMP_ROOT/$1"
  mkdir -p "$d/gh" "$d/state"
  jq -n '{upstreams: [
    {repo: "acme/tool", watch: "releases", reviewed: "v1.0.0", why: "harness we use"},
    {repo: "acme/skills", watch: "commits", reviewed: "aaa111", why: "skills we adapted"}
  ]}' >"$d/upstreams.json"
  printf '{"tag_name":"v1.2.0","html_url":"https://github.com/acme/tool/releases/tag/v1.2.0"}' \
    >"$d/gh/repos_acme_tool_releases_latest"
  printf '[{"sha":"bbb222"}]' >"$d/gh/repos_acme_skills_commits_per_page=1"
  printf '{"total_commits":7,"html_url":"https://github.com/acme/skills/compare/aaa111...bbb222"}' \
    >"$d/gh/repos_acme_skills_compare_aaa111...bbb222"
  printf '%s\n' "$d"
}

# watch DIR [ARGS...]: run upstream-watch on fixture DIR; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
watch() {
  local d=$1
  shift
  LAST_OUTPUT=$(env PATH="$TMP_ROOT/bin:$PATH" FAKE_GH="$d/gh" UPSTREAMS_FILE="$d/upstreams.json" \
    UPSTREAM_WATCH_STATE="$d/state/state.json" bash "$SCRIPT" "$@" 2>&1)
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
lacks() { [[ $LAST_OUTPUT != *"$1"* ]]; }
json_ok() { jq -e "$2" "$1" >/dev/null 2>&1; }

echo "== report =="

d=$(fixture report)
watch "$d"
assert 'exits 0' test "$LAST_EXIT" -eq 0
assert 'reports a new release' says 'acme/tool: v1.0.0 -> v1.2.0'
assert 'reports new commits with a count' says 'acme/skills: 7 new commit(s)'
assert 'links to what changed' says 'compare/aaa111...bbb222'
assert 'says why the repo is watched' says 'harness we use'
assert 'writes the state for the hook' json_ok "$d/state/state.json" '.changed | map(.repo) == ["acme/tool", "acme/skills"]'

echo "== up to date and failures =="

d=$(fixture current)
jq '.upstreams[0].reviewed = "v1.2.0" | .upstreams[1].reviewed = "bbb222"' "$d/upstreams.json" >"$d/u" && mv "$d/u" "$d/upstreams.json"
watch "$d"
assert 'nothing new says so' says 'all upstreams reviewed'
assert 'nothing new leaves an empty state' json_ok "$d/state/state.json" '.changed == []'

d=$(fixture offline)
rm "$d/gh/repos_acme_tool_releases_latest"
watch "$d"
assert 'an unreachable repo is a warning' says 'acme/tool: could not check'
assert 'other repos are still checked' says 'acme/skills: 7 new commit(s)'
assert 'an unreachable repo is not reported as changed' json_ok "$d/state/state.json" '.changed | map(.repo) == ["acme/skills"]'

echo "== --mark =="

d=$(fixture mark)
watch "$d" --mark acme/tool
assert 'mark exits 0' test "$LAST_EXIT" -eq 0
assert 'mark records the latest release' json_ok "$d/upstreams.json" '.upstreams[0].reviewed == "v1.2.0"'
assert 'mark leaves other repos alone' json_ok "$d/upstreams.json" '.upstreams[1].reviewed == "aaa111"'
watch "$d" --mark all
assert 'mark all records every repo' json_ok "$d/upstreams.json" '.upstreams[1].reviewed == "bbb222"'
watch "$d"
assert 'after marking all nothing is new' says 'all upstreams reviewed'
watch "$d" --mark nope/missing
assert 'marking an unknown repo fails' test "$LAST_EXIT" -ne 0

echo "== --refresh =="

d=$(fixture refresh)
watch "$d" --refresh
assert 'refresh prints nothing' test -z "$LAST_OUTPUT"
assert 'refresh still writes the state' json_ok "$d/state/state.json" '.changed | length == 2'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
