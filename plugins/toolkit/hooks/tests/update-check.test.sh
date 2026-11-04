#!/usr/bin/env bash
# Tests for update-check.sh. Run: bash plugins/toolkit/hooks/tests/update-check.test.sh
set -u

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/update-check.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
unset SKIP_UPDATE_CHECK

# fixture NAME INSTALLED AVAILABLE ENGRAM LATEST: build an isolated environment
# with one installed plugin (demo@mkt) and stub `engram`/`curl` binaries.
# LATEST "fail" makes curl fail. Prints the fixture dir.
fixture() {
  local dir="$TMP_ROOT/$1" installed=$2 available=$3 engram=$4 latest=$5
  mkdir -p "$dir/plugins" "$dir/mkt/.claude-plugin" "$dir/bin"
  jq -n --arg v "$installed" '{plugins: {"demo@mkt": [{version: $v}]}}' \
    >"$dir/plugins/installed_plugins.json"
  jq -n --arg loc "$dir/mkt" '{mkt: {installLocation: $loc}}' \
    >"$dir/plugins/known_marketplaces.json"
  jq -n --arg v "$available" '{plugins: [{name: "demo", version: $v}]}' \
    >"$dir/mkt/.claude-plugin/marketplace.json"
  printf '#!/usr/bin/env bash\necho "engram %s"\n' "$engram" >"$dir/bin/engram"
  if [[ $latest == fail ]]; then
    printf '#!/usr/bin/env bash\ntouch "%s/curl-called"\nexit 22\n' "$dir" >"$dir/bin/curl"
  else
    printf '#!/usr/bin/env bash\ntouch "%s/curl-called"\necho %s\n' \
      "$dir" "'{\"tag_name\": \"v$latest\"}'" >"$dir/bin/curl"
  fi
  chmod +x "$dir/bin/engram" "$dir/bin/curl"
  printf '%s\n' "$dir"
}

# run DIR [SOURCE] [ENV...]: run the hook against fixture DIR; stdout in $LAST_STDOUT.
LAST_STDOUT=""
LAST_EXIT=0
run() {
  local dir=$1 source=${2:-startup}
  shift 2 2>/dev/null || shift
  LAST_STDOUT=$(jq -n --arg s "$source" '{hook_event_name: "SessionStart", source: $s}' |
    env PATH="$dir/bin:$PATH" CLAUDE_PLUGINS_DIR="$dir/plugins" \
      UPDATE_CHECK_CACHE="$dir/cache/engram-latest" UPSTREAM_WATCH_STATE="$dir/upstream-state.json" \
      "$@" bash "$HOOK" 2>/dev/null)
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

is_empty() { [[ -z $LAST_STDOUT ]]; }
message_has() { jq -e --arg s "$1" '.systemMessage | contains($s)' >/dev/null 2>&1 <<<"$LAST_STDOUT"; }
message_lacks() { ! message_has "$1"; }

echo "== reports available updates =="

dir=$(fixture outdated-plugin 0.3.0 0.3.1 3.4.0 3.4.0)
run "$dir"
assert 'outdated plugin is reported' message_has 'demo@mkt 0.3.0 -> 0.3.1'
assert 'report names the update command' message_has 'claude plugin update demo@mkt'
assert 'current engram is not reported' message_lacks 'engram'

dir=$(fixture outdated-engram 0.3.1 0.3.1 3.4.0 3.4.1)
run "$dir"
assert 'outdated engram is reported' message_has 'engram 3.4.0 -> 3.4.1'
assert 'current plugin is not reported' message_lacks 'demo@mkt'

dir=$(fixture numeric 0.9.0 0.10.0 3.4.0 3.10.0)
run "$dir"
assert 'plugin compare is numeric' message_has 'demo@mkt 0.9.0 -> 0.10.0'
assert 'engram compare is numeric' message_has 'engram 3.4.0 -> 3.10.0'

echo "== stays silent =="

dir=$(fixture current 0.3.1 0.3.1 3.4.0 3.4.0)
run "$dir"
assert 'everything current is silent' is_empty

dir=$(fixture newer-local 0.4.0 0.3.1 3.5.0 3.4.0)
run "$dir"
assert 'installed newer than available is silent' is_empty

dir=$(fixture offline 0.3.1 0.3.1 3.4.0 fail)
run "$dir"
assert 'failed release lookup is silent' is_empty
assert 'failed release lookup exits 0' test "$LAST_EXIT" -eq 0

dir=$(fixture resume 0.3.0 0.3.1 3.4.0 3.4.1)
run "$dir" resume
assert 'resume source is silent' is_empty
assert 'resume source exits 0' test "$LAST_EXIT" -eq 0

run "$dir" startup SKIP_UPDATE_CHECK=1
assert 'SKIP_UPDATE_CHECK=1 is silent' is_empty
assert 'SKIP_UPDATE_CHECK=1 exits 0' test "$LAST_EXIT" -eq 0

dir=$(fixture missing 0.3.1 0.3.1 3.4.0 3.4.0)
rm -rf "$dir/plugins" "$dir/bin/engram"
run "$dir"
assert 'missing plugin files and engram is silent' is_empty
assert 'missing plugin files and engram exits 0' test "$LAST_EXIT" -eq 0

echo "== upstream news (read from upstream-watch state, no network) =="

dir=$(fixture upstreams 0.3.1 0.3.1 3.4.0 3.4.0)
jq -n '{checked_at: "2026-10-19T00:00:00Z", changed: [{repo: "acme/tool"}, {repo: "acme/skills"}]}' \
  >"$dir/upstream-state.json"
run "$dir"
assert 'changed upstreams are reported' message_has 'upstreams with news: acme/tool, acme/skills'
assert 'the report says how to review' message_has 'upstream-watch'

jq -n '{checked_at: "2026-10-19T00:00:00Z", changed: []}' >"$dir/upstream-state.json"
run "$dir"
assert 'no upstream news is silent' is_empty
rm -f "$dir/upstream-state.json"
run "$dir"
assert 'a missing upstream state is silent' is_empty

echo "== caches the release lookup =="

dir=$(fixture cache 0.3.1 0.3.1 3.4.0 3.4.1)
run "$dir"
assert 'first run queries GitHub' test -e "$dir/curl-called"
rm -f "$dir/curl-called"
run "$dir"
assert 'second run within a day uses the cache' test ! -e "$dir/curl-called"
assert 'cached result is still reported' message_has 'engram 3.4.0 -> 3.4.1'
touch -d '2 days ago' "$dir/cache/engram-latest"
run "$dir"
assert 'stale cache queries GitHub again' test -e "$dir/curl-called"

# with_look DIR PIN CLAUDE: install look@mkt in fixture DIR with PIN as its
# pinned Claude Code version and stub `claude --version` to print CLAUDE.
# CLAUDE "fail" makes `claude` exit 1.
with_look() {
  local dir=$1 pin=$2 claude=$3
  mkdir -p "$dir/look/tests"
  printf '%s\n' "$pin" >"$dir/look/tests/claude-code.version"
  jq --arg p "$dir/look" '.plugins["look@mkt"] = [{version: "0.1.0", installPath: $p}]' \
    "$dir/plugins/installed_plugins.json" >"$dir/installed.tmp" &&
    mv "$dir/installed.tmp" "$dir/plugins/installed_plugins.json"
  if [[ $claude == fail ]]; then
    printf '#!/usr/bin/env bash\nexit 1\n' >"$dir/bin/claude"
  else
    printf '#!/usr/bin/env bash\necho "%s (Claude Code)"\n' "$claude" >"$dir/bin/claude"
  fi
  chmod +x "$dir/bin/claude"
}

echo "== look pin differs from the installed Claude Code =="

dir=$(fixture look-newer 0.3.1 0.3.1 3.4.0 3.4.0)
with_look "$dir" 2.1.305 2.1.318
run "$dir"
assert 'a newer Claude Code than the look pin is reported' \
  message_has 'look pin 2.1.305 != Claude Code 2.1.318'
assert 'the look note points to the bump procedure' message_has 'docs/look.md'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
