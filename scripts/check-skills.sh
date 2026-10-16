#!/usr/bin/env bash
# Lint skills and global instructions:
# - every plugins/*/skills/*/SKILL.md has frontmatter with non-empty name and
#   description (warn when the file exceeds 500 lines);
# - claude/CLAUDE.md stays under 60 lines.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MAX_SKILL_LINES=500
MAX_CLAUDE_MD_LINES=59

# frontmatter FILE: print the YAML block between the leading --- fences.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit 1; next }
       $0 == "---" { closed = 1; exit }
       { print }
       END { if (!closed) exit 1 }' "$1"
}

# field_value YAML KEY: print the trimmed scalar value of a top-level KEY.
field_value() {
  awk -v key="$2" 'index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      gsub(/^["\047]|["\047]$/, "", v)
      print v; exit
    }' <<<"$1"
}

for skill in "$ROOT"/plugins/*/skills/*/SKILL.md; do
  [[ -f $skill ]] || continue
  rel=${skill#"$ROOT"/}
  if ! yaml=$(frontmatter "$skill"); then
    err "$rel: missing YAML frontmatter"
    continue
  fi
  bad=0
  for key in name description; do
    if [[ -z $(field_value "$yaml" "$key") ]]; then
      err "$rel: frontmatter \"$key\" is missing or empty"
      bad=1
    fi
  done
  lines=$(wc -l <"$skill")
  [[ $lines -gt $MAX_SKILL_LINES ]] && warn "$rel: $lines lines (over $MAX_SKILL_LINES)"
  [[ $bad -eq 0 ]] && ok "$rel"
done

claude_md="$ROOT/claude/CLAUDE.md"
if [[ -f $claude_md ]]; then
  lines=$(wc -l <"$claude_md")
  if [[ $lines -gt $MAX_CLAUDE_MD_LINES ]]; then
    err "claude/CLAUDE.md: $lines lines (must stay under 60)"
  else
    ok "claude/CLAUDE.md: $lines lines"
  fi
fi
finish skills
