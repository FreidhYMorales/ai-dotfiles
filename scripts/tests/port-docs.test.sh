#!/usr/bin/env bash
# Structural test for the multi-agent port docs: the README, the install.sh
# header and docs/multi-agent.md describe how each agent is set up.
# Run: bash scripts/tests/port-docs.test.sh
# The docs name paths like `~/.config` in markdown backticks: a quoted `~` or
# backtick here is literal text.
# shellcheck disable=SC2088,SC2016
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README="$ROOT/README.md"
failures=0

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

# has TEXT FIXED: TEXT contains the fixed string.
has() { rg -qF -- "$2" <<<"$1"; }
lacks() { ! has "$@"; }

echo "== README names the rules paths each agent reads =="
# The layout row of the repo-root AGENTS.md.
row=$(rg -F '| `AGENTS.md` |' "$README")
assert 'the AGENTS.md row is found' test -n "$row"
assert 'README names the OpenCode rules path' has "$row" '~/.config/opencode/AGENTS.md'

echo "== README closes the port roadmap item =="
item=$(rg -F 'Port the Claude-only parts' "$README")
assert 'the port roadmap item is found once' test "$(wc -l <<<"$item")" -eq 1 -a -n "$item"
assert 'the port roadmap item is checked off' has "$item" '- [x] Port the Claude-only parts'
assert 'the port item leaves judgment-day for v2' rg -q 'judgment-day.*v2' <<<"$item"

echo "== install.sh header describes the OpenCode target =="
# The comment block before the first command, split at each target heading.
header=$(awk 'NR > 1 && !/^#/ { exit } NR > 1' "$ROOT/install.sh")
opencode=$(awk '/^#   - OpenCode:/ { on = 1; next } /^#   - / { on = 0 } on' <<<"$header")
assert 'the header has an OpenCode section' test -n "$opencode"
assert 'the header links no raw skills' lacks "$header" 'Symlinks all skills'
for piece in 'generated AGENTS.md' 'skills' 'commands' 'agents' 'toolkit.ts' 'engram'; do
  assert "OpenCode header names $piece" has "$opencode" "$piece"
done

echo "== docs/multi-agent.md holds the setup notes =="
doc=$(<"$ROOT/docs/multi-agent.md")
# The manual setup section, up to the next level-2 heading.
setup=$(awk '/^## Manual setup per machine/ { on = 1; next } /^## / { on = 0 } on' <<<"$doc")
assert 'the manual setup section is found' test -n "$setup"
assert 'setup names the extra plugin file hang on 2.2.2' rg -q 'extra file.*`plugins/`.*hang.*2\.2\.2|2\.2\.2.*extra file.*`plugins/`.*hang' <<<"$setup"
assert 'setup keeps probes inside toolkit.ts' rg -q 'probe.*inside `toolkit\.ts`' <<<"$setup"
assert 'the doc names OpenCode the secondary agent' rg -q 'OpenCode is the secondary agent' <<<"$doc"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
