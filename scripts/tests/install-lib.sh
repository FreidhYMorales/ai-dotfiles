#!/usr/bin/env bash
# Shared setup for the install.sh tests (install-*.test.sh), sourced by each
# file so the parallel runner runs the areas side by side. Not a test file.
# LAST_OUTPUT, LAST_EXIT and REMAINING are read by the sourcing files.
# shellcheck disable=SC2034
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="$ROOT/install.sh"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# sandbox NAME: create an isolated HOME with a stateful `claude` stub; print its path.
sandbox() {
  local home="$TMP_ROOT/$1"
  mkdir -p "$home/bin" "$home/state"
  cat >"$home/bin/claude" <<'EOF'
#!/usr/bin/env bash
state=$FAKE_CLAUDE_STATE
printf '%s\n' "$*" >>"$state/calls"
case "$1 $2 ${3:-}" in
"plugin marketplace list") [[ -f $state/marketplace ]] && echo "  ❯ ai-dotfiles" ;;
"plugin marketplace add") touch "$state/marketplace" ;;
"plugin marketplace remove") rm -f "$state/marketplace" ;;
"plugin list "*) cat "$state/plugins" 2>/dev/null ;;
"plugin install "*) printf '%s\n' "$3" >>"$state/plugins" ;;
"plugin uninstall "*) rg -vxF "$3" "$state/plugins" >"$state/plugins.new"; mv "$state/plugins.new" "$state/plugins" ;;
esac
exit 0
EOF
  cat >"$home/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_CLAUDE_STATE/systemctl"
EOF
  # `agy mcp list` prints state/agy-mcp-list; engram is registered by default.
  printf 'NAME    TYPE   STATUS   COMMAND/URL\nengram  stdio  enabled  engram mcp --tools=agent\n' \
    >"$home/state/agy-mcp-list"
  # `agy --version` prints state/agy-version; the pinned 1.4.12 by default.
  printf '1.4.12\n' >"$home/state/agy-version"
  cat >"$home/bin/agy" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "mcp list" ]] && cat "$FAKE_CLAUDE_STATE/agy-mcp-list"
[[ "$*" == "--version" ]] && cat "$FAKE_CLAUDE_STATE/agy-version"
exit 0
EOF
  chmod +x "$home/bin/claude" "$home/bin/systemctl" "$home/bin/agy"
  printf '%s\n' "$home"
}

# install HOME [ARGS...]: run install.sh inside the sandbox; output in $LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
install() {
  local home=$1
  shift
  LAST_OUTPUT=$(env -u XDG_BIN_HOME -u XDG_CONFIG_HOME HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" \
    GIT_CONFIG_GLOBAL="$home/.gitconfig" GIT_CONFIG_NOSYSTEM=1 \
    FAKE_CLAUDE_STATE="$home/state" PATH="$home/bin:$PATH" AI_BUILD_DIR="$home/build/agents" \
    bash "$INSTALL" "$@" 2>&1)
  LAST_EXIT=$?
}

# snapshot HOME: every file under the sandbox's ~/.claude and ~/.gitconfig,
# with its type, link target and content hash.
snapshot() {
  local home=$1 path
  while IFS= read -r path; do
    if [[ -L $path ]]; then
      printf 'link %s -> %s\n' "${path#"$home"}" "$(readlink "$path")"
    else
      printf 'file %s %s\n' "${path#"$home"}" "$(sha256sum <"$path" | cut -d' ' -f1)"
    fi
  done < <(find "$home/.claude" "$home/.gitconfig" "$home/.local/bin" "$home/.config/systemd" \
    \( -type f -o -type l \) 2>/dev/null | sort)
}

# assert LABEL CONDITION...: run a test command and record PASS/FAIL.
assert() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    failures=$((failures + 1))
  fi
}

same() { [[ $1 == "$2" ]]; }
# json_true FILE [JQ_ARGS...] FILTER: FILTER evaluates to true on FILE.
json_true() {
  local file=$1
  shift
  jq -e "$@" "$file" >/dev/null 2>&1
}
backups() { find "$1/.claude" -name '*.bak-*' 2>/dev/null | wc -l; }
calls_since() { tail -n +"$(($2 + 1))" "$1/state/calls"; }
call_count() { wc -l <"$1/state/calls"; }

# Every other flow and toolkit skill but judgment-day (story 30).
REMAINING="flow-plan flow-research flow-fill-gaps flow-handoff flow-next flow-idea flow-split
  flow-integrate flow-foundation flow-bootstrap toolkit-ship toolkit-chained-pr toolkit-cli-tools
  toolkit-cognitive-doc-design toolkit-comment-writer toolkit-delegate-local toolkit-go-testing
  toolkit-skill-creator toolkit-skill-improver"

# finish_cases: print the summary and exit with the case status.
finish_cases() {
  echo
  if [[ $failures -gt 0 ]]; then
    echo "$failures case(s) failed"
    exit 1
  fi
  echo "All cases passed"
}
