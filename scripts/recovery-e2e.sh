#!/usr/bin/env bash
# End-to-end recovery drill: lose a machine, rebuild it from the dotfiles plus
# the two things that survive a disaster (the restic backup repo and its
# password), and check that the engram memory comes back intact.
# Meant for a clean Arch container (CI job `recovery`); safe anywhere because it
# only touches temp dirs. Usage: scripts/recovery-e2e.sh [REPO_DIR]
set -euo pipefail

SRC=$(cd "${1:-$(dirname "$0")/..}" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_STATE_HOME CLAUDE_CONFIG_DIR

step() { printf '\n== %s\n' "$*"; }
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Stubs: `claude` (no real CLI in the container) and `systemctl` (the real one
# talks to the caller's session manager, not to the fake HOME).
mkdir -p "$WORK/stub"
for tool in claude systemctl; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$WORK/stub/$tool"
  chmod +x "$WORK/stub/$tool"
done

# machine NAME: a fresh HOME with the dotfiles cloned and installed.
machine() {
  local home="$WORK/$1"
  mkdir -p "$home"
  # Copy the working tree (not a clone) so the drill tests what is on disk.
  cp -a "$SRC" "$home/dotfiles"
  (cd "$home/dotfiles" && HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" PATH="$WORK/stub:$PATH" \
    ./install.sh >"$home/install.log" 2>&1) ||
    {
      cat "$home/install.log" >&2
      fail "install.sh failed on $1"
    }
  [[ -L $home/.claude/CLAUDE.md ]] || fail "CLAUDE.md not linked on $1"
  [[ -x $home/.local/bin/engram-backup ]] || fail "engram-backup not linked on $1"
  printf '%s\n' "$home"
}

backups="$WORK/backup-drive/restic-engram"

step "old machine: install the dotfiles and back up a memory"
old=$(machine old)
mkdir -p "$old/.engram" "$old/.config/restic"
sqlite3 "$old/.engram/engram.db" \
  "CREATE TABLE observations(title TEXT); INSERT INTO observations VALUES ('decision'), ('bugfix'), ('pattern');"
printf 'ENGRAM_BACKUP_REPOS="%s"\n' "$backups" >"$old/.config/restic/engram.env"
HOME="$old" "$old/.local/bin/engram-backup" --init >/dev/null
HOME="$old" "$old/.local/bin/engram-backup"
cp "$old/.config/restic/engram.pass" "$WORK/password-manager.txt"

step "disaster: the old machine is gone; only the backup drive and the password survive"
rm -rf "$old"

step "new machine: install the dotfiles and restore the memory"
new=$(machine new)
mkdir -p "$new/.config/restic"
printf 'ENGRAM_BACKUP_REPOS="%s"\n' "$backups" >"$new/.config/restic/engram.env"
install -m 600 "$WORK/password-manager.txt" "$new/.config/restic/engram.pass"
HOME="$new" ENGRAM_BACKUP_ALLOW_RUNNING=1 "$new/.local/bin/engram-backup" --restore

count=$(sqlite3 "$new/.engram/engram.db" 'SELECT count(*) FROM observations;')
[[ $count == 3 ]] || fail "expected 3 observations after restore, got $count"
[[ $(sqlite3 "$new/.engram/engram.db" 'PRAGMA integrity_check;') == ok ]] || fail "restored database is corrupt"
HOME="$new" "$new/.local/bin/engram-backup" --verify >/dev/null || fail "verify failed on the new machine"

step "recovery drill passed: 3/3 observations restored and verified"
