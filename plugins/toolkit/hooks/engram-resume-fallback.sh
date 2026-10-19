#!/usr/bin/env bash
# SessionStart hook: on resumed sessions, route engram writes through the CLI.
# engram <= 3.4.0 denies every MCP write after `claude --continue`/`--resume`
# ("host session ... already ended", upstream #1624, fixed in #1765 after the
# 3.4.0 release). The `engram save` CLI bypasses that PreToolUse gate.
# Silent on fixed versions, other sources, or when engram is not installed,
# so the hook retires itself once engram is updated.
set -u
# shellcheck source=plugins/toolkit/hooks/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" && hook_off

LAST_AFFECTED=3.4.0

input=$(cat)
[[ $(jq -r '.source // empty' <<<"$input" 2>/dev/null) == resume ]] || exit 0
command -v engram >/dev/null 2>&1 || exit 0

version=$(engram version 2>/dev/null | awk '{print $2}')
version=${version#v}
[[ -n $version ]] || exit 0
# Affected when version <= LAST_AFFECTED.
[[ $(printf '%s\n%s\n' "$version" "$LAST_AFFECTED" | sort -V | tail -n1) == "$LAST_AFFECTED" ]] || exit 0

context="Engram $version cannot persist MCP writes in resumed sessions (upstream bug #1624): mem_save, mem_update and mem_session_summary are denied with \"host session ... already ended\". For the rest of this session, do not call engram MCP write tools; save through Bash instead:
  engram save '<title>' '<content>' --type <type> --project '<project>' [--topic <topic_key>]
Use the same **What/Why/Where/Learned** content format. For the end-of-session summary use --type session_summary. Reads (mem_search, mem_context, mem_get_observation) still work over MCP."

jq -n --arg ctx "$context" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
