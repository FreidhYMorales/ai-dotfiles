#!/usr/bin/env bash
# Generate the OpenCode and Antigravity versions of the ported skills and
# agents from the Claude Code plugin sources.
# Usage: scripts/gen-agents/gen.sh OUT_DIR
# Writes OUT_DIR/opencode/ and OUT_DIR/antigravity/. GEN_REPO_PATH sets the
# repo path written into the output and GEN_SOURCE the repo the sources
# are read from (both default to this repo).
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${1:?usage: gen.sh OUT_DIR}
SRC_DIR=${GEN_SOURCE:-$REPO_DIR}
REPO_PATH=${GEN_REPO_PATH:-$REPO_DIR}
# The repo path as a sed replacement ('#' is the delimiter below).
REPO_SED=$(printf '%s' "$REPO_PATH" | sed -e 's/[\\&#]/\\&/g')

# rename: the name map, flow:x -> flow-x and toolkit:x -> toolkit-x.
rename() { sed -E 's/(^|[^A-Za-z0-9_-])(flow|toolkit):([a-z])/\1\2-\3/g'; }

# plugin_paths PLUGIN: plugin-relative paths become absolute and quoted;
# neither target resolves them.
plugin_paths() {
  sed -E \
    -e "s#\`\\.\\./\\.\\./([^\`]+)\`#\`\"$REPO_SED/plugins/$1/\\1\"\`#g" \
    -e "s#the plugin's \`([^\`]+)\`#\`\"$REPO_SED/plugins/$1/\\1\"\`#g"
}

# support_paths PLUGIN SKILL: bare references to support files, the skill's
# own (`references/x.md`) or a sibling's (`../pair/references/x.md`), become
# absolute and quoted. Only files that exist in the source are rewritten, so
# prose about a directory (skill-creator's `assets/`) stays.
support_paths() {
  local path rel re to script=()
  while IFS= read -r path; do
    rel=${path#*/}
    [[ ${path%%/*} == "$2" ]] || rel="../$path"
    re=$(printf '%s' "$rel" | sed -e 's/[].[\*^$#]/\\&/g')
    to=$(printf '%s' "$path" | sed -e 's/[\\&#]/\\&/g')
    to="\`\"$REPO_SED/plugins/$1/skills/$to\"\`"
    # A markdown link cannot hold the quoted path, so it becomes the path.
    script+=(-e "s#\\[$re\\]($re)#$to#g" -e "s#\`$re\`#$to#g")
  done < <(cd "$SRC_DIR/plugins/$1/skills" && find . -type f -regextype posix-extended \
    -regex '\./[^/]+/(references|templates|cheatsheets|assets)/.+' | cut -c3- | sort)
  sed "${script[@]}" -e ''
}

# Backticks in the sed scripts below are literal markdown.
# shellcheck disable=SC2016
{
  # opencode_words: Claude names become OpenCode names.
  opencode_words() { sed -e 's/`general-purpose`/`general`/g' -e 's/mcp__engram__/engram_/g'; }

  # agy_words: subagents are launched through invoke_subagent; engram tools
  # go by their own names.
  agy_words() {
    sed -E \
      -e 's/(launch a fresh `[^`]+`) subagent/\1 subagent through `invoke_subagent`/g' \
      -e 's/(Launch the `[^`]+`) agent/\1 subagent through `invoke_subagent`/g' \
      -e 's/Launch `general-purpose`/Launch the default subagent through `invoke_subagent`/g' \
      -e 's/mcp__engram__//g'
  }
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

# skill TARGET PLUGIN SKILL: the skill as <plugin>-<skill>, in TARGET's words.
skill() {
  local src="$SRC_DIR/plugins/$2/skills/$3/SKILL.md" dst="$OUT/$1/skills/$2-$3" words
  case $1 in
    opencode) words=opencode_words ;;
    antigravity) words=agy_words ;;
  esac
  mkdir -p "$dst"
  sed "s/^name: $3\$/name: $2-$3/" "$src" | rename | plugin_paths "$2" | support_paths "$2" "$3" | "$words" >"$dst/SKILL.md"
}

# opencode_skill PLUGIN SKILL: the skill plus a command of the same name that
# loads it.
opencode_skill() {
  local src="$SRC_DIR/plugins/$1/skills/$2/SKILL.md" name="$1-$2"
  skill opencode "$1" "$2"
  mkdir -p "$OUT/opencode/commands"
  # Backticks and $ARGUMENTS are literal.
  # shellcheck disable=SC2016
  {
    printf -- '---\ndescription: %s\n---\n\n' "$(field "$src" description)"
    printf 'Load the `%s` skill and follow it. $ARGUMENTS\n' "$name"
  } | rename >"$OUT/opencode/commands/$name.md"
}

# agy_tools TOOL: the agy registry names for a Claude tool. Only names agy
# 1.4.9 proved (story 16); Glob and Bash wait for a real run (story 17).
agy_tools() {
  case $1 in
    Read) echo read_file view_file ;;
    Grep) echo grep_search ;;
    Glob | Bash) ;;
    # Engram is declared under mcpServers: (agy_agent), never as a tool.
    mcp__engram__*) ;;
    *)
      echo "gen-agents: $2: no agy name for tool $1" >&2
      return 1
      ;;
  esac
}

# agy_agent SRC NAME: Claude tools mapped through agy_tools; opus -> pro.
# An unmapped tool stops the generator: agy never builds such a subagent and
# says nothing. An agent with an engram tool declares engram under
# mcpServers: (story 16).
agy_agent() {
  local src=$1 dst="$OUT/antigravity/agents/$2.md" tool mapped names=() engram=
  for tool in $(field "$src" tools | tr -d ','); do
    [[ $tool == mcp__engram__* ]] && engram=1
    mapped=$(agy_tools "$tool" "$src")
    # shellcheck disable=SC2206 # split the space-separated names
    names+=($mapped)
  done
  mkdir -p "$(dirname "$dst")"
  {
    printf -- '---\nname: %s\ndescription: %s\ntools:\n' "$2" "$(field "$src" description)"
    printf '  - %s\n' "${names[@]}"
    # No agy shell tool is proven yet (story 17), so no agent runs commands.
    printf 'model: pro\ncommandExecutionPolicy: off\n'
    [[ -z $engram ]] || printf 'mcpServers:\n  - name: engram\n    command: engram\n    args:\n      - mcp\n      - --tools=agent\n'
    printf -- '---\n'
    body "$src"
  } | rename >"$dst"
}

opencode_agent "$SRC_DIR/plugins/flow/agents/plan-reviewer.md" flow-plan-reviewer
agy_agent "$SRC_DIR/plugins/flow/agents/plan-reviewer.md" flow-plan-reviewer
opencode_skill flow plan-review
skill antigravity flow plan-review
