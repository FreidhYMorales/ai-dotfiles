# shellcheck shell=bash
# Shared helpers for toolkit hooks. Source it right after `set -u`.

# hook_off: exit 0 silently when AI_HOOKS_OFF names this hook (comma-separated
# list of hook names, spaces allowed) or is "all". The hook name is its file
# name without .sh. Per-hook SKIP_* variables keep working too.
hook_off() {
  local name list
  name=$(basename "${BASH_SOURCE[1]}" .sh)
  list=",${AI_HOOKS_OFF:-},"
  list=${list// /}
  [[ $list == ",all," || $list == *",$name,"* ]] && exit 0
  return 0
}
