#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): block legacy CLI tools in favor of modern ones.
# Exit 0 = allow, exit 2 = block (stderr is shown to Claude).
# Fails open: missing jq, invalid input or a non-Bash tool always exits 0.

# shellcheck source=plugins/toolkit/hooks/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" && hook_off

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null) || exit 0
[[ $tool == "Bash" ]] || exit 0
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || exit 0
[[ -n $cmd ]] || exit 0

[[ $cmd == *"# legacy-cli"* ]] && exit 0

# Split on |, ||, && and ; but not on newlines, so heredoc bodies stay inside
# their segment. Two-char operators are replaced first.
sep=$'\x1f'
cmd=${cmd//&&/$sep}
cmd=${cmd//||/$sep}
cmd=${cmd//|/$sep}
cmd=${cmd//;/$sep}

declare -A seen=()
messages=()

report() {
  local tool=$1 replacement=$2
  [[ -n ${seen[$tool]:-} ]] && return
  seen[$tool]=1
  messages+=("Use $replacement instead of $tool. Append '# legacy-cli' if the legacy tool is truly required.")
}

mapfile -d "$sep" -t segments <<<"$cmd"
for segment in "${segments[@]}"; do
  rest=${segment#"${segment%%[![:space:]]*}"}

  # Drop leading VAR=value assignments, then a `command` or `\` prefix.
  while [[ $rest =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do
    rest=${BASH_REMATCH[1]}
  done
  [[ $rest == command[[:space:]]* ]] && rest=${rest#command} && rest=${rest#"${rest%%[![:space:]]*}"}
  rest=${rest#\\}

  word=${rest%%[[:space:]]*}
  word=${word##*/}

  case $word in
    grep | egrep | fgrep) report "$word" "rg" ;;
    find) report find "fd" ;;
    ls) report ls "eza" ;;
    sed) report sed "sd (or 'bat -r START:END' to print a line range)" ;;
    cat)
      # Heredocs and writing to files are legitimate uses of cat.
      [[ $segment == *"<<"* || $segment == *">"* ]] || report cat "'bat -p' or the Read tool"
      ;;
  esac
done

((${#messages[@]} == 0)) && exit 0
printf '%s\n' "${messages[@]}" >&2
exit 2
