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

# not_in_output LINE...: no LINE appears in the last install output.
not_in_output() {
  local line
  for line in "$@"; do
    rg -qF -- "$line" <<<"$LAST_OUTPUT" && return 1
  done
  return 0
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

echo "== keeps the 3 newest backups of a merged settings.json =="

home=$(sandbox prune-settings)
mkdir -p "$home/.claude"
jq -n '{model: "opus"}' >"$home/.claude/settings.json"
seed_backups "$home/.claude/settings.json" 20200101-000001 20200101-000002 20200101-000003
install "$home"
settings_backups=("$home"/.claude/settings.json.bak-*)
assert 'three settings.json backups remain' same "${#settings_backups[@]}" 3
assert 'the oldest settings backup is removed' test ! -e "$home/.claude/settings.json.bak-20200101-000001"
assert 'the two newest old settings backups are kept' \
  test -f "$home/.claude/settings.json.bak-20200101-000002" -a -f "$home/.claude/settings.json.bak-20200101-000003"
assert 'output names the removed settings copy' \
  rg -qxF "pruned old backup: $home/.claude/settings.json.bak-20200101-000001" <<<"$LAST_OUTPUT"
assert 'output names no kept settings copy' \
  not_in_output "pruned old backup: $home/.claude/settings.json.bak-20200101-000002" \
  "pruned old backup: $home/.claude/settings.json.bak-20200101-000003"

echo "== a directory backup is removed whole =="

# The link step renames a clashing directory, so a backup can be a directory.
home=$(sandbox prune-dir-backup)
mkdir -p "$home/.claude"
printf '# my own notes\n' >"$home/.claude/CLAUDE.md"
for stamp in 20200101-000001 20200101-000002 20200101-000003; do
  mkdir -p "$home/.claude/CLAUDE.md.bak-$stamp/nested"
  printf 'old dir copy\n' >"$home/.claude/CLAUDE.md.bak-$stamp/nested/notes.md"
done
install "$home"
assert 'the oldest directory backup is gone with its content' \
  test ! -e "$home/.claude/CLAUDE.md.bak-20200101-000001"
assert 'the newer directory backups keep their content' \
  test -f "$home/.claude/CLAUDE.md.bak-20200101-000002/nested/notes.md" \
  -a -f "$home/.claude/CLAUDE.md.bak-20200101-000003/nested/notes.md"
assert 'output names the removed directory copy' \
  rg -qxF "pruned old backup: $home/.claude/CLAUDE.md.bak-20200101-000001" <<<"$LAST_OUTPUT"

echo "== dry-run names the copies it would remove =="

home=$(sandbox prune-dry)
mkdir -p "$home/.claude"
printf '# my own notes\n' >"$home/.claude/CLAUDE.md"
seed_backups "$home/.claude/CLAUDE.md" 20200101-000001 20200101-000002 20200101-000003 20200101-000004
install "$home" --dry-run
dry_backups=("$home"/.claude/CLAUDE.md.bak-*)
assert 'dry-run keeps all four backups' same "${#dry_backups[@]}" 4
assert 'dry-run keeps the oldest backup' test -f "$home/.claude/CLAUDE.md.bak-20200101-000001"
assert 'dry-run names the oldest copy' \
  rg -qF "$home/.claude/CLAUDE.md.bak-20200101-000001" <<<"$LAST_OUTPUT"
assert 'dry-run names the second oldest copy' \
  rg -qF "$home/.claude/CLAUDE.md.bak-20200101-000002" <<<"$LAST_OUTPUT"
assert 'dry-run names no kept copy' \
  not_in_output "$home/.claude/CLAUDE.md.bak-20200101-000003" "$home/.claude/CLAUDE.md.bak-20200101-000004"
assert 'dry-run does not claim a copy was pruned' not_in_output 'pruned old backup:'

finish_cases
