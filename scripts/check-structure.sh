#!/usr/bin/env bash
# Validate plugin structure: plugin.json fields, marketplace sources and
# hooks.json command paths (${CLAUDE_PLUGIN_ROOT} resolved to the plugin dir).
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for manifest in "$ROOT"/plugins/*/.claude-plugin/plugin.json; do
  [[ -f $manifest ]] || continue
  rel=${manifest#"$ROOT"/}
  for field in name version description; do
    if jq -e --arg f "$field" '.[$f] | strings | length > 0' "$manifest" >/dev/null 2>&1; then
      :
    else
      err "$rel: missing or empty \"$field\""
    fi
  done
  ok "$rel"
done

marketplace="$ROOT/.claude-plugin/marketplace.json"
if [[ -f $marketplace ]]; then
  while IFS=$'\t' read -r name source; do
    if [[ -d $ROOT/$source ]]; then
      ok "marketplace: $name -> $source"
    else
      err "marketplace: plugin \"$name\" source \"$source\" is not a directory"
    fi
  done < <(jq -r '.plugins[]? | [.name, (.source | strings)] | @tsv' "$marketplace")
fi

for hooks in "$ROOT"/plugins/*/hooks/hooks.json; do
  [[ -f $hooks ]] || continue
  plugin_dir=${hooks%/hooks/hooks.json}
  rel=${hooks#"$ROOT"/}
  while IFS= read -r command; do
    # The command's first word is the executable; strip quotes, resolve the root.
    exe=${command%% *}
    exe=${exe//\"/}
    exe=${exe//\$\{CLAUDE_PLUGIN_ROOT\}/$plugin_dir}
    if [[ ! -e $exe ]]; then
      err "$rel: command not found: $exe"
    elif [[ ! -x $exe ]]; then
      err "$rel: command not executable: $exe"
    else
      ok "$rel: ${exe#"$ROOT"/}"
    fi
  done < <(jq -r '.. | objects | select(.type? == "command") | .command' "$hooks")
done
finish structure
