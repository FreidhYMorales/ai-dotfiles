#!/usr/bin/env bash
# Structural test for the retired sdd workflow: docs, skills and config name
# only the backlog -> story -> pair loop.
# Run: bash scripts/tests/no-sdd.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

# no_sdd FILE: FILE exists and has no case-insensitive whole-word "sdd".
no_sdd() { [[ -f $1 ]] && ! grep -qiw 'sdd' "$1"; }

echo "== docs name only the loop =="
assert 'README names no sdd' no_sdd "$ROOT/README.md"
assert 'multi-agent doc names no sdd' no_sdd "$ROOT/docs/multi-agent.md"
assert 'upstream list names no sdd' no_sdd "$ROOT/upstreams.json"

# at_least MIN VERSION: true when VERSION is MIN or newer (the retirement bump happened).
at_least() { [[ -n $2 && $(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1) == "$1" ]]; }

echo "== flow names no sdd and counts no files =="
FLOW="$ROOT/plugins/flow"
assert 'high-risk list names no sdd' no_sdd "$FLOW/skills/pair/references/high-risk.md"
for skill in plan research foundation; do
  assert "$skill delegates by understanding, not 4+ files" test -f "$FLOW/skills/$skill/SKILL.md" -a -z "$(grep -F '4+ files' "$FLOW/skills/$skill/SKILL.md")"
done
assert 'flow plugin is at least 0.11.0' at_least 0.11.0 "$(jq -r .version "$FLOW/.claude-plugin/plugin.json")"
assert 'marketplace lists flow at least 0.11.0' \
  at_least 0.11.0 "$(jq -r '.plugins[] | select(.name == "flow") | .version' "$ROOT/.claude-plugin/marketplace.json")"
# Story tiered-checks/05: the regression round ships in flow 0.12.0.
assert 'flow plugin is at least 0.12.0' at_least 0.12.0 "$(jq -r .version "$FLOW/.claude-plugin/plugin.json")"
assert 'marketplace lists flow at least 0.12.0' \
  at_least 0.12.0 "$(jq -r '.plugins[] | select(.name == "flow") | .version' "$ROOT/.claude-plugin/marketplace.json")"
# Story tiered-checks/07: new repos get both check targets in flow 0.13.0.
assert 'flow plugin is at least 0.13.0' at_least 0.13.0 "$(jq -r .version "$FLOW/.claude-plugin/plugin.json")"
assert 'marketplace lists flow at least 0.13.0' \
  at_least 0.13.0 "$(jq -r '.plugins[] | select(.name == "flow") | .version' "$ROOT/.claude-plugin/marketplace.json")"

echo "== toolkit skills name no sdd =="
TOOLKIT="$ROOT/plugins/toolkit"
assert 'work-unit-commits names no sdd' no_sdd "$TOOLKIT/skills/work-unit-commits/SKILL.md"
assert 'chained-pr names no sdd' no_sdd "$TOOLKIT/skills/chained-pr/SKILL.md"
assert 'toolkit plugin is at least 0.14.0' at_least 0.14.0 "$(jq -r .version "$TOOLKIT/.claude-plugin/plugin.json")"
assert 'marketplace lists toolkit at least 0.14.0' \
  at_least 0.14.0 "$(jq -r '.plugins[] | select(.name == "toolkit") | .version' "$ROOT/.claude-plugin/marketplace.json")"
# Story tiered-checks/06: ship's run-once rule ships in toolkit 0.19.0.
assert 'toolkit plugin is at least 0.19.0' at_least 0.19.0 "$(jq -r .version "$TOOLKIT/.claude-plugin/plugin.json")"
assert 'marketplace lists toolkit at least 0.19.0' \
  at_least 0.19.0 "$(jq -r '.plugins[] | select(.name == "toolkit") | .version' "$ROOT/.claude-plugin/marketplace.json")"
# Story tiered-checks/09: delegate-local's focused test ships in toolkit 0.20.0.
assert 'toolkit plugin is at least 0.20.0' at_least 0.20.0 "$(jq -r .version "$TOOLKIT/.claude-plugin/plugin.json")"
assert 'marketplace lists toolkit at least 0.20.0' \
  at_least 0.20.0 "$(jq -r '.plugins[] | select(.name == "toolkit") | .version' "$ROOT/.claude-plugin/marketplace.json")"
# Story tiered-checks/12: ship's CI skip ships in toolkit 0.21.0.
assert 'toolkit plugin is at least 0.21.0' at_least 0.21.0 "$(jq -r .version "$TOOLKIT/.claude-plugin/plugin.json")"
assert 'marketplace lists toolkit at least 0.21.0' \
  at_least 0.21.0 "$(jq -r '.plugins[] | select(.name == "toolkit") | .version' "$ROOT/.claude-plugin/marketplace.json")"
# Story retire-antigravity/03: the Antigravity hook adapters are gone.
assert 'toolkit hooks/agy does not exist' test -d "$TOOLKIT/hooks" -a ! -e "$TOOLKIT/hooks/agy"
assert 'toolkit plugin is at least 0.22.0' at_least 0.22.0 "$(jq -r .version "$TOOLKIT/.claude-plugin/plugin.json")"
assert 'marketplace lists toolkit at least 0.22.0' \
  at_least 0.22.0 "$(jq -r '.plugins[] | select(.name == "toolkit") | .version' "$ROOT/.claude-plugin/marketplace.json")"

echo "== no sdd outside history and retirement files =="
# History stays as written; these files name sdd only to retire, reject or
# ignore it.
allow=(
  -g '!docs/plans/**' -g '!docs/upstream/**' -g '!docs/ideas.md'
  -g '!packs/vendor/**'
  -g '!plugins/flow/evals/handoff-solo-to-backlog/**'
  -g '!scripts/tests/install*.test.sh' -g '!scripts/tests/plugins.test.sh' -g '!scripts/tests/no-sdd.test.sh'
  -g '!scripts/tests/flow-handoff.test.sh' -g '!scripts/tests/flow-pair.test.sh' -g '!scripts/tests/flow-rules.test.sh'
  -g '!scripts/tests/multi-agent-plan.test.sh'
)
# Backticks in the pattern are literal markdown.
# shellcheck disable=SC2016
allowed_lines='^(install\.sh:[0-9]+:RETIRED_PLUGINS=\(sdd\)|(plugins/flow/skills|scripts/gen-agents/golden/[a-z]+/skills)/[a-z-]+/SKILL\.md:[0-9]+:- Ignore old engram topics `sdd/\*` and `sdd-init/\*`\.)$'
hits=$(cd "$ROOT" && rg -n -iw 'sdd' --hidden -g '!.git' "${allow[@]}")
stray=$(rg -v "$allowed_lines" <<<"$hits")
# Guard against a scan that finds nothing at all: the retirement line must show up.
assert 'the scan sees the retirement line' rg -q '^install\.sh:[0-9]+:RETIRED_PLUGINS=\(sdd\)$' <<<"$hits"
assert 'no sdd outside the allowlist' test -z "$stray"
[[ -n $stray ]] && printf '%s\n' "$stray"

if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
