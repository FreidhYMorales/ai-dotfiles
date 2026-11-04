#!/usr/bin/env bash
# install.sh tests: a fresh machine (no systemd user bus, dry run before any
# build, missing optional tools). Run: bash scripts/tests/install-fresh.test.sh
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

echo "== no systemd user bus =="

# A systemctl that behaves like the real one with no user session (ssh, sudo, container).
home=$(sandbox no-bus)
cat >"$home/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_CLAUDE_STATE/systemctl"
echo 'Failed to connect to user scope bus via local transport: $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined' >&2
exit 1
EOF
install "$home"
assert 'install succeeds without a user bus' test "$LAST_EXIT" -eq 0
assert 'install reaches the end' rg -q '^done\. Active targets:' <<<"$LAST_OUTPUT"
assert 'git hooks are installed' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" "$ROOT/git-hooks"
assert 'the Claude step runs' same "$(readlink "$home/.claude/CLAUDE.md")" "$ROOT/claude/CLAUDE.md"
assert 'it says the timers were not enabled' rg -q 'timers not enabled' <<<"$LAST_OUTPUT"
assert 'it says how to enable them later' rg -q 're-run \./install\.sh from a login session' <<<"$LAST_OUTPUT"

echo "== a real daemon-reload failure =="

# The bus is there, but the reload itself fails.
home=$(sandbox reload-fails)
cat >"$home/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_CLAUDE_STATE/systemctl"
echo 'Failed to reload daemon: Access denied' >&2
exit 1
EOF
install "$home"
assert 'install succeeds after a failed reload' test "$LAST_EXIT" -eq 0
assert 'install reaches the end after a failed reload' rg -q '^done\. Active targets:' <<<"$LAST_OUTPUT"
assert 'it shows the error from systemd' rg -qF 'Failed to reload daemon: Access denied' <<<"$LAST_OUTPUT"
assert 'it says the timers were not enabled after a failed reload' rg -q 'timers not enabled' <<<"$LAST_OUTPUT"
assert 'it does not blame the user session' test -z "$(rg -F 'no systemd user session' <<<"$LAST_OUTPUT")"
assert 'no timer is enabled after a failed reload' test -z "$(rg -F 'enable' "$home/state/systemctl")"
assert 'git hooks are installed after a failed reload' \
  same "$(git config --file "$home/.gitconfig" core.hooksPath)" "$ROOT/git-hooks"

echo "== both wordings of a missing bus keep the session hint =="

wording=0
for message in 'Failed to connect to user scope bus via local transport: No such file or directory' \
  'Failed to connect to bus: No medium found'; do
  wording=$((wording + 1))
  home=$(sandbox "bus-wording-$wording")
  cat >"$home/bin/systemctl" <<EOF
#!/usr/bin/env bash
echo '$message' >&2
exit 1
EOF
  install "$home"
  assert "wording $wording: it says there is no user session" rg -qF 'no systemd user session' <<<"$LAST_OUTPUT"
  assert "wording $wording: it gives no reload warning" test -z "$(rg -F 'daemon-reload failed' <<<"$LAST_OUTPUT")"
  assert "wording $wording: install reaches the end" rg -q '^done\. Active targets:' <<<"$LAST_OUTPUT"
done

echo "== dry run before any build =="

home=$(sandbox dry-fresh)
install "$home" --dry-run --target all
assert 'dry run succeeds' test "$LAST_EXIT" -eq 0
# would_link DST: the dry run prints the link it would make at DST.
would_link() { rg -q "^\[dry-run\] ln -s .+ $1\$" <<<"$LAST_OUTPUT"; }
assert 'it lists the generated OpenCode agent links' would_link "$home/\.config/opencode/agents/flow-verifier\.md"
assert 'it lists the generated OpenCode skill links' would_link "$home/\.config/opencode/skills/flow-backlog"
assert 'it lists the generated Antigravity agent links' would_link "$home/\.gemini/config/agents/flow-plan-reviewer\.md"
assert 'it lists the generated Antigravity skill links' would_link "$home/\.gemini/antigravity-cli/skills/flow-backlog"

# Everything in the sandbox but its own stubs (bin/) and their state (state/).
# BUILD_DIR lives in the sandbox here (AI_BUILD_DIR), so this also covers the
# repo's build dir.
home=$(sandbox dry-clean)
mkdir -p "$home/tmp"
TMPDIR="$home/tmp" install "$home" --dry-run --target all
assert 'the dry run leaves nothing in the home' \
  test -z "$(find "$home" -mindepth 1 -not -path "$home/bin*" -not -path "$home/state*" -not -path "$home/tmp")"
assert 'the dry run leaves no temp build behind' test -z "$(find "$home/tmp" -mindepth 1)"

echo "== missing tools the install does not need =="

# install_without TOOL: install into a fresh sandbox whose PATH holds every
# /usr/bin command but TOOL.
install_without() {
  local bin="$TMP_ROOT/usr-bin-no-$1"
  mkdir -p "$bin"
  ln -s /usr/bin/* "$bin/"
  rm -f "$bin/$1"
  home=$(sandbox "no-$1")
  PATH="$bin" install "$home" --target claude
}

for tool in zellij bwrap; do
  install_without "$tool"
  assert "install without $tool succeeds" test "$LAST_EXIT" -eq 0
  assert "install without $tool reaches the end" rg -q '^done\. Active targets:' <<<"$LAST_OUTPUT"
  assert "install warns that $tool is missing" rg -q "^warning: $tool not found" <<<"$LAST_OUTPUT"
done
home=$(sandbox all-tools)
install "$home" --target claude
assert 'with every tool present nothing is reported missing' test -z "$(rg '^warning: \S+ not found' <<<"$LAST_OUTPUT")"

finish_cases
