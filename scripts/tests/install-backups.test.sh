#!/usr/bin/env bash
# install.sh tests: pruning of the installer's own *.bak-* copies (story 15). Run: bash scripts/tests/install-backups.test.sh
# Each case runs the real installer against a throwaway HOME with a stub
# `claude` CLI (setup in install-lib.sh).
set -u
# shellcheck source=scripts/tests/install-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-lib.sh"

# seed_backups FILE STAMP...: create FILE.bak-STAMP copies that look old.
seed_backups() {
  local file=$1 stamp
  shift
  for stamp in "$@"; do
    printf 'old copy %s\n' "$stamp" >"$file.bak-$stamp"
  done
}

echo "== keeps the 3 newest backups of a linked file =="

home=$(sandbox prune-keep-three)
mkdir -p "$home/.claude"
printf '# my own notes\n' >"$home/.claude/CLAUDE.md"
seed_backups "$home/.claude/CLAUDE.md" 20200101-000001 20200101-000002 20200101-000003 20200101-000004
install "$home"
md_backups=("$home"/.claude/CLAUDE.md.bak-*)
assert 'three CLAUDE.md backups remain' same "${#md_backups[@]}" 3
assert 'the oldest backup is removed' test ! -e "$home/.claude/CLAUDE.md.bak-20200101-000001"
assert 'the second oldest backup is removed' test ! -e "$home/.claude/CLAUDE.md.bak-20200101-000002"
assert 'the two newest old backups are kept' \
  test -f "$home/.claude/CLAUDE.md.bak-20200101-000003" -a -f "$home/.claude/CLAUDE.md.bak-20200101-000004"
assert 'the new backup keeps the replaced file' \
  rg -q '^# my own notes$' "$(find "$home/.claude" -name 'CLAUDE.md.bak-*' ! -name '*-2020*' | head -n1)"
assert 'output names the oldest removed copy' \
  rg -qxF "pruned old backup: $home/.claude/CLAUDE.md.bak-20200101-000001" <<<"$LAST_OUTPUT"
assert 'output names the second removed copy' \
  rg -qxF "pruned old backup: $home/.claude/CLAUDE.md.bak-20200101-000002" <<<"$LAST_OUTPUT"

finish_cases
