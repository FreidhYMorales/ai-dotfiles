#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): block commands that name a credential file.
# Exit 0 = allow, exit 2 = block (stderr is shown to Claude).
set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0

# Match on a copy with // and /./ collapsed, so ~/.config//gh is .config/gh.
while [[ $cmd == *'/./'* || $cmd == *'//'* ]]; do
  cmd=${cmd//\/.\//\/}
  cmd=${cmd//\/\//\/}
done

# A protected name starts after a non-word character (so process.env.X is not
# a file) and, for the fixed names, ends before one (so .config/ghostty is not
# .config/gh). ~, $HOME and absolute spellings all contain these names.
before='(^|[^A-Za-z0-9_])'
after='([^A-Za-z0-9_.-]|$)'
patterns=(
  "$before(\\.config/(gh|restic))$after"
  "$before(\\.git-credentials)$after"
  # .env.<name>, or a glob or brace group that can expand to one
  # (.env.*, .env*, .env.[lp]*, .env.{local,prod}).
  "$before(\\.env(\\.[]A-Za-z0-9_*?[{-]|\\*)[]A-Za-z0-9_.*?[{},-]*)"
  # Shell expansion that can reach gh or restic: a glob or brace group in the
  # segment after .config/ (.config/{gh,restic}, .config/g?), or a .. under it.
  "$before(\\.config/[^/[:space:]\"']*[*?[{][^/[:space:]\"']*)"
  "$before(\\.config/([^[:space:]\"']*/)?\\.\\.)(/|[[:space:]\"']|$)"
  "$before(\\.git-cred[A-Za-z0-9_-]*[*?[{])"
)
for re in "${patterns[@]}"; do
  if [[ $cmd =~ $re ]]; then
    echo "Blocked: the command names a protected credential path (${BASH_REMATCH[2]})." >&2
    exit 2
  fi
done
exit 0
