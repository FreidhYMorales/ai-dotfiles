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

finish_cases
