#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): block commands that name a credential file.
# Exit 0 = allow, exit 2 = block (stderr is shown to Claude).
set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0

# A protected name starts after a non-word character (so process.env.X is not
# a file) and, for the fixed names, ends before one (so .config/ghostty is not
# .config/gh). ~, $HOME and absolute spellings all contain these names.
before='(^|[^A-Za-z0-9_])'
after='([^A-Za-z0-9_.-]|$)'
patterns=(
  "$before(\\.config/(gh|restic))$after"
  "$before(\\.git-credentials)$after"
  "$before(\\.env\\.[A-Za-z0-9_-][A-Za-z0-9_.-]*)"
)
for re in "${patterns[@]}"; do
  if [[ $cmd =~ $re ]]; then
    echo "Blocked: the command names a protected credential path (${BASH_REMATCH[2]})." >&2
    exit 2
  fi
done
exit 0
