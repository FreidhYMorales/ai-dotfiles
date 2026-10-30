#!/usr/bin/env bash
# Check the generator output against the committed goldens and for Claude-only
# forms the rewrite missed. Runs from `make check` via
# scripts/tests/gen-agents.test.sh. GEN_SOURCE passes through to gen.sh.
# Regenerate the goldens after a source change:
#   rm -rf scripts/gen-agents/golden && GEN_REPO_PATH="/repo path" scripts/gen-agents/gen.sh scripts/gen-agents/golden
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GOLDEN="$HERE/golden"
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
status=0

GEN_REPO_PATH="/repo path" bash "$HERE/gen.sh" "$out" || exit 1

# Every file missing on either side or differing. The repo path has a space,
# so files are listed relative to each tree, never parsed from diff output.
while IFS= read -r rel; do
  cmp -s "$GOLDEN/$rel" "$out/$rel" && continue
  echo "stale golden: $rel (regenerate the goldens)"
  status=1
done < <({ (cd "$GOLDEN" && find . -type f) && (cd "$out" && find . -type f); } | cut -c3- | sort -u)

# Claude-only forms that must never reach a target.
forms='(^|[^A-Za-z0-9_-])(flow|toolkit):[a-z]|\.\./\.\./|\$\{CLAUDE_PLUGIN_ROOT\}|mcp__engram__'
while IFS= read -r hit; do
  echo "Claude-only form: $hit"
  status=1
done < <(cd "$out" && grep -rnE "$forms" . | cut -c3-)

exit "$status"
