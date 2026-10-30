#!/usr/bin/env bash
# Generate the OpenCode and Antigravity versions of the ported skills and
# agents from the Claude Code plugin sources.
# Usage: scripts/gen-agents/gen.sh OUT_DIR
# Writes OUT_DIR/opencode/ and OUT_DIR/antigravity/. GEN_REPO_PATH sets the
# repo path written into the output (default: this repo).
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${1:?usage: gen.sh OUT_DIR}
REPO_PATH=${GEN_REPO_PATH:-$REPO_DIR}
# The repo path as a sed replacement ('#' is the delimiter below).
REPO_SED=$(printf '%s' "$REPO_PATH" | sed -e 's/[\\&#]/\\&/g')

# rename: the name map, flow:x -> flow-x and toolkit:x -> toolkit-x.
rename() { sed -E 's/(^|[^A-Za-z0-9_-])(flow|toolkit):([a-z])/\1\2-\3/g'; }

# opencode_words PLUGIN: plugin-relative paths become absolute and quoted
# (OpenCode does not resolve them), Claude names become OpenCode names.
opencode_words() {
  # Backticks are literal markdown.
  # shellcheck disable=SC2016
  sed -E \
    -e "s#\`\\.\\./\\.\\./([^\`]+)\`#\`\"$REPO_SED/plugins/$1/\\1\"\`#g" \
    -e "s#the plugin's \`([^\`]+)\`#\`\"$REPO_SED/plugins/$1/\\1\"\`#g" \
    -e 's/`general-purpose`/`general`/g' \
    -e 's/mcp__engram__/engram_/g'
}

# field FILE KEY: a frontmatter value.
field() { awk -v key="$2" 'NR > 1 && /^---$/ { exit } index($0, key ": ") == 1 { print substr($0, length(key) + 3) }' "$1"; }

# body FILE: everything after the frontmatter.
body() { awk 'f >= 2 { print } /^---$/ { f++ }' "$1"; }

# opencode_agent SRC NAME: a read-only subagent; tools Claude does not list
# are denied.
opencode_agent() {
  local src=$1 dst="$OUT/opencode/agents/$2.md"
  mkdir -p "$(dirname "$dst")"
  {
    printf -- '---\ndescription: %s\nmode: subagent\npermission:\n' "$(field "$src" description)"
    printf '  edit: deny\n  webfetch: deny\n  task: deny\n---\n'
    body "$src"
  } | rename >"$dst"
}

# opencode_skill PLUGIN SKILL: the skill as <plugin>-<skill>, plus a command
# of the same name that loads it.
opencode_skill() {
  local src="$REPO_DIR/plugins/$1/skills/$2/SKILL.md" name="$1-$2"
  mkdir -p "$OUT/opencode/skills/$name" "$OUT/opencode/commands"
  sed "s/^name: $2\$/name: $name/" "$src" | rename | opencode_words "$1" >"$OUT/opencode/skills/$name/SKILL.md"
  # Backticks and $ARGUMENTS are literal.
  # shellcheck disable=SC2016
  {
    printf -- '---\ndescription: %s\n---\n\n' "$(field "$src" description)"
    printf 'Load the `%s` skill and follow it. $ARGUMENTS\n' "$name"
  } | rename >"$OUT/opencode/commands/$name.md"
}

opencode_agent "$REPO_DIR/plugins/flow/agents/plan-reviewer.md" flow-plan-reviewer
opencode_skill flow plan-review
