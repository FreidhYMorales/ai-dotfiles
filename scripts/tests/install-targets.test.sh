#!/usr/bin/env bash
# install.sh tests: which targets it accepts and resolves. Antigravity is no
# longer a target (retire-antigravity story 01).
# Run: bash scripts/tests/install-targets.test.sh
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

echo "== --target antigravity is rejected =="

home=$(sandbox target-antigravity)
install "$home" --target antigravity
assert 'it exits non-zero' test "$LAST_EXIT" -ne 0
assert 'it names the unknown target' rg -qxF 'unknown target: antigravity' <<<"$LAST_OUTPUT"
assert 'it installs nothing for Claude' test ! -e "$home/.claude"
assert 'it installs nothing under ~/.gemini' test ! -e "$home/.gemini"

echo "== --target all means Claude Code and OpenCode =="

home=$(sandbox target-all)
install "$home" --target all
assert 'it exits 0' test "$LAST_EXIT" -eq 0
assert 'it installs exactly claude and opencode' \
  rg -qxF 'done. Active targets: claude opencode.' <<<"$LAST_OUTPUT"

# agy_home NAME: a sandbox with an `agy` on PATH and an existing ~/.gemini
# (the Antigravity dir and a hooks.json carrying the old toolkit key).
agy_home() {
  local home
  home=$(sandbox "$1")
  printf '#!/usr/bin/env bash\nexit 0\n' >"$home/bin/agy"
  chmod +x "$home/bin/agy"
  mkdir -p "$home/.gemini/antigravity-cli/skills" "$home/.gemini/config"
  printf '{"toolkit":{"Stop":[]},"mine":{}}\n' >"$home/.gemini/config/hooks.json"
  printf '%s\n' "$home"
}
# gemini_state HOME: every path under ~/.gemini with its content hash.
gemini_state() {
  local path
  while IFS= read -r path; do
    if [[ -f $path ]]; then
      printf '%s %s\n' "${path#"$1"}" "$(sha256sum <"$path" | cut -d' ' -f1)"
    else
      printf '%s\n' "${path#"$1"}"
    fi
  done < <(find "$1/.gemini" | sort)
}
# done_line: the installer's final "done." line.
done_line() { rg '^done\.' <<<"$LAST_OUTPUT"; }
no_antigravity() { ! rg -q antigravity <<<"$(done_line)"; }

echo "== auto-detection never picks Antigravity =="

home=$(agy_home detect-install)
before=$(gemini_state "$home")
install "$home"
assert 'the install exits 0' test "$LAST_EXIT" -eq 0
assert 'the install reaches its done line' rg -q '^done\. Active targets:' <<<"$LAST_OUTPUT"
assert 'the done line names no antigravity target' no_antigravity
assert 'the ~/.gemini tree is left exactly as it was' same "$(gemini_state "$home")" "$before"

echo "== --uninstall with no target leaves ~/.gemini alone =="

home=$(agy_home detect-uninstall)
before=$(gemini_state "$home")
install "$home" --uninstall
assert 'the uninstall exits 0' test "$LAST_EXIT" -eq 0
assert 'the uninstall reaches its done line' rg -q '^done\. Uninstalled targets:' <<<"$LAST_OUTPUT"
assert 'the uninstall done line names no antigravity target' no_antigravity
assert 'the old toolkit key stays in hooks.json' \
  json_true "$home/.gemini/config/hooks.json" '.toolkit != null'
assert 'the ~/.gemini tree is left exactly as it was after the uninstall' \
  same "$(gemini_state "$home")" "$before"

finish_cases
