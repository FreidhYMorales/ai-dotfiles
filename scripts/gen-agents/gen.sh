#!/usr/bin/env bash
# Generate the OpenCode and Antigravity versions of the ported skills and
# agents from the Claude Code plugin sources.
# Usage: scripts/gen-agents/gen.sh OUT_DIR
# Writes OUT_DIR/opencode/ and OUT_DIR/antigravity/. GEN_REPO_PATH sets the
# repo path written into the output and GEN_SOURCE the repo the sources
# are read from (both default to this repo). GEN_MODELS sets the role model
# map (default: models.json next to this script).
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${1:?usage: gen.sh OUT_DIR}
SRC_DIR=${GEN_SOURCE:-$REPO_DIR}
REPO_PATH=${GEN_REPO_PATH:-$REPO_DIR}
MODELS=${GEN_MODELS:-$REPO_DIR/scripts/gen-agents/models.json}
# The repo path as a sed replacement ('#' is the delimiter below).
REPO_SED=$(printf '%s' "$REPO_PATH" | sed -e 's/[\\&#]/\\&/g')

# rename: the name map, flow:x -> flow-x and toolkit:x -> toolkit-x.
rename() { sed -E 's/(^|[^A-Za-z0-9_-])(flow|toolkit):([a-z])/\1\2-\3/g'; }

# plugin_paths PLUGIN: plugin-relative paths become absolute and quoted;
# neither target resolves them.
plugin_paths() {
  sed -E \
    -e "s#\`\\.\\./\\.\\./([^\`]+)\`#\`\"$REPO_SED/plugins/$1/\\1\"\`#g" \
    -e "s#the plugin's \`([^\`]+)\`#\`\"$REPO_SED/plugins/$1/\\1\"\`#g" \
    -e "s#\`\\\$\\{CLAUDE_PLUGIN_ROOT\\}/([^\`]+)\`#\`\"$REPO_SED/plugins/$1/\\1\"\`#g"
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
    # A sibling's file named from the skills dir (`pair/references/x.md`).
    re=$(printf '%s' "$path" | sed -e 's/[].[\*^$#]/\\&/g')
    script+=(-e "s#\`$re\`#$to#g")
  done < <(cd "$SRC_DIR/plugins/$1/skills" && find . -type f -regextype posix-extended \
    -regex '\./[^/]+/(references|templates|cheatsheets|assets)/.+' | cut -c3- | sort)
  sed "${script[@]}" -e ''
}

# Backticks in the sed scripts below are literal markdown.
# shellcheck disable=SC2016
{
  # claude_only: skills that are never generated are marked as such; the
  # references become absolute paths, so pair's base-directory note goes.
  # make eval runs Claude, so pair's Done step closes a skill story with the
  # eval pending; the next skill lists it (story 29).
  claude_only() {
    sed -e 's#`/toolkit-judgment-day`#& (Claude Code only)#g' \
      -e "s/ (this skill's base directory)//" \
      -e '/^7\. \*\*Done\.\*\*.*the `make eval` result/ s/$/ Outside Claude `make eval` cannot run: for a skill story write `make eval pending (needs Claude)` in the story log in place of its result and close the story; the `next` skill lists it until the eval runs in Claude./'
  }

  # opencode_words: Claude names become OpenCode names. OpenCode 2.2.2 reads
  # disable-model-invocation as "the model may not load this skill", which
  # stops its own command from loading it; the description still says
  # "explicit use only".
  opencode_words() {
    sed -e 's/`general-purpose`/`general`/g' -e 's/mcp__engram__/engram_/g' \
      -e '/^disable-model-invocation: /d'
  }

  # agy_words: subagents are launched through invoke_subagent; engram tools
  # go by their own names. pair's verifier step ends in NEEDS DECISION while
  # agy has no shell tool (story 17).
  agy_words() {
    sed -E \
      -e '/invoke the `flow-verifier` agent/ s/$/ In Antigravity the `flow-verifier` subagent has no shell tool to run the `Test command:`, so a high-risk story ends in NEEDS DECISION: stop, say so and finish the story in Claude or OpenCode; never verify inline./' \
      -e 's/invoke the `flow-verifier` agent on the story diff[^;]*; if it is not available, say so and recommend `\/toolkit-judgment-day` \(Claude Code only\)\./stop with NEEDS DECISION, do not run the `flow-verifier` agent and leave the story open; when the story moves to Claude Code and its verifier is not available, recommend `\/toolkit-judgment-day` (Claude Code only)./' \
      -e 's/(launch a fresh `[^`]+`) subagent/\1 subagent through `invoke_subagent`/g' \
      -e 's/(Launch the `[^`]+`) agent/\1 subagent through `invoke_subagent`/g' \
      -e 's/Launch `general-purpose`/Launch the default subagent through `invoke_subagent`/g' \
      -e 's/mcp__engram__//g'
  }
}

# field FILE KEY: a frontmatter value.
field() { awk -v key="$2" 'NR > 1 && /^---$/ { exit } index($0, key ": ") == 1 { print substr($0, length(key) + 3) }' "$1"; }

# model_for ROLE TARGET: the model the role map gives ROLE in TARGET.
# A missing entry stops the generator; agy accepts inherit, pro or flash only.
model_for() {
  local model
  model=$(jq -r --arg r "$1" --arg t "$2" '.[$r][$t] // empty' "$MODELS")
  if [[ -z $model ]]; then
    echo "gen-agents: $MODELS: no model for role $1 in $2" >&2
    return 1
  fi
  if [[ $2 == antigravity && ! $model =~ ^(inherit|pro|flash)$ ]]; then
    echo "gen-agents: $MODELS: agy accepts inherit, pro or flash, not $model (role $1)" >&2
    return 1
  fi
  printf '%s\n' "$model"
}

# body FILE: everything after the frontmatter.
body() { awk 'f >= 2 { print } /^---$/ { f++ }' "$1"; }

# plugin_of AGENT_SRC: the plugin an agent file belongs to.
plugin_of() { basename "$(dirname "$(dirname "$1")")"; }

# opencode_agent SRC NAME [readonly-shell]: a read-only subagent; tools Claude
# does not list are denied. With readonly-shell its shell runs read-only git,
# rg and make check without asking and asks for anything else. The last
# matching rule wins, so the closing rules take back the options that run a
# program or write a file (rg --pre, git --output/--ext-diff) and ask on a
# redirection.
opencode_agent() {
  local src=$1 dst="$OUT/opencode/agents/$2.md" model
  model=$(model_for reviewer opencode)
  mkdir -p "$(dirname "$dst")"
  {
    printf -- '---\ndescription: %s\nmode: subagent\n' "$(field "$src" description)"
    # inherit: no model line, so the agent runs on the session model.
    [[ $model == inherit ]] || printf 'model: %s\n' "$model"
    printf 'permission:\n'
    printf '  edit: deny\n  webfetch: deny\n  task: deny\n'
    if [[ ${3:-} == readonly-shell ]]; then
      printf '  bash:\n'
      printf '    "%s": %s\n' '*' ask 'git log*' allow 'git diff*' allow 'git show*' allow \
        'rg *' allow 'make check' allow 'rg *--pre*' deny 'git *--output*' deny \
        'git *--ext-diff*' deny '*>*' ask
    fi
    printf -- '---\n'
    body "$src"
  } | rename | plugin_paths "$(plugin_of "$src")" >"$dst"
}

# skill TARGET PLUGIN SKILL: the skill as <plugin>-<skill>, in TARGET's words.
skill() {
  local src="$SRC_DIR/plugins/$2/skills/$3/SKILL.md" dst="$OUT/$1/skills/$2-$3" words
  case $1 in
    opencode) words=opencode_words ;;
    antigravity) words=agy_words ;;
  esac
  mkdir -p "$dst"
  sed "s/^name: $3\$/name: $2-$3/" "$src" | rename | plugin_paths "$2" | support_paths "$2" "$3" | claude_only | "$words" >"$dst/SKILL.md"
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

# agy_agent SRC NAME: Claude tools mapped through agy_tools; the model comes
# from the role map.
# An unmapped tool stops the generator: agy never builds such a subagent and
# says nothing. An agent with an engram tool declares engram under
# mcpServers: (story 16).
agy_agent() {
  local src=$1 dst="$OUT/antigravity/agents/$2.md" tool mapped names=() engram=
  local model
  model=$(model_for reviewer antigravity)
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
    printf 'model: %s\ncommandExecutionPolicy: off\n' "$model"
    [[ -z $engram ]] || printf 'mcpServers:\n  - name: engram\n    command: engram\n    args:\n      - mcp\n      - --tools=agent\n'
    printf -- '---\n'
    body "$src"
  } | rename | plugin_paths "$(plugin_of "$src")" >"$dst"
}

# Backticks in the rule lines are literal markdown.
# shellcheck disable=SC2016
{
  # support_names TARGET: support files are copied raw, so they keep Claude
  # names; written with <skill> so the Claude-only check passes.
  support_names() {
    printf -- '- A skill'"'"'s support files (`references/`, `templates/`) may still name `/flow:<skill>` or `/toolkit:<skill>`; in %s that is `/flow-<skill>` or `/toolkit-<skill>`.\n' "$1"
  }

  # rules TARGET HEADING LINES_FN: the shared rules plus the lines the
  # target's hooks do not cover (story 31).
  rules() {
    mkdir -p "$OUT/$1"
    {
      rename <"$SRC_DIR/claude/CLAUDE.md"
      printf '\n## %s\n\n' "$2"
      support_names "$2"
      "$3"
    } >"$OUT/$1/AGENTS.md"
  }

  # OpenCode has the pause hook (#20) but no Stop gate, so the gate is a rule
  # line that mirrors require-check.
  opencode_rules() {
    printf -- '- Before saying work is done, run `make check` from the git root when the root Makefile has a `check` target and the tree has uncommitted changes; fix any failure first. Skip it while the `/flow-pair` red marker (`git rev-parse --git-path flow-pair-red`) names the current branch on its first line and its commit, on the second, is in HEAD.\n'
  }

  # agy has the Stop gate (#06) but no prompt hook, so pause is a rule line
  # with pause.sh's protocol; the agent saves the checkpoint itself.
  agy_rules() {
    printf -- '- Pause: when a message starts with "pausa", "pausar" or "pause", first save a checkpoint to engram (`mem_save`, topic `checkpoint/pause`: branch, last commit, uncommitted files); then start no new work, make at most one more tool call and reply in at most 5 lines: what was in progress, anything still running and whether it is safe to stop it, uncommitted changes, and how to resume: `agy --continue` from the project.\n'
  }
}

rules opencode OpenCode opencode_rules
rules antigravity Antigravity agy_rules
opencode_agent "$SRC_DIR/plugins/flow/agents/plan-reviewer.md" flow-plan-reviewer
opencode_agent "$SRC_DIR/plugins/flow/agents/verifier.md" flow-verifier readonly-shell
agy_agent "$SRC_DIR/plugins/flow/agents/plan-reviewer.md" flow-plan-reviewer
agy_agent "$SRC_DIR/plugins/flow/agents/verifier.md" flow-verifier
opencode_skill flow plan-review
opencode_skill flow backlog
opencode_skill flow story
opencode_skill flow pair
skill opencode toolkit work-unit-commits
opencode_skill flow plan
opencode_skill flow fill-gaps
# The other skills (story 30); OpenCode commands for them wait for #14.
FLOW_REST="research handoff next idea split integrate foundation bootstrap"
TOOLKIT_REST="ship chained-pr cli-tools cognitive-doc-design comment-writer delegate-local
  go-testing skill-creator skill-improver"
for name in $FLOW_REST; do skill opencode flow "$name"; done
for name in $TOOLKIT_REST; do skill opencode toolkit "$name"; done
skill antigravity flow plan-review
skill antigravity flow backlog
skill antigravity flow story
skill antigravity flow pair
skill antigravity toolkit work-unit-commits
for name in plan fill-gaps $FLOW_REST; do skill antigravity flow "$name"; done
for name in $TOOLKIT_REST; do skill antigravity toolkit "$name"; done
