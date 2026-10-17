#!/usr/bin/env bash
# Install AI dotfiles for Claude Code.
#   - Symlinks claude/CLAUDE.md into ~/.claude (existing file is backed up).
#   - Merges claude/settings.json into ~/.claude/settings.json (Claude Code
#     rewrites that file itself, so it is merged, never symlinked).
#   - Symlinks claude/output-styles/*.md into ~/.claude/output-styles/.
#   - Symlinks bin/* (e.g. ai-update, engram-backup) into ~/.local/bin.
#   - Symlinks systemd/* user units and enables the engram backup timer once
#     engram-backup is configured.
#   - Registers this repo as a plugin marketplace and installs the `flow`,
#     `sdd` and `toolkit` plugins.
#
# Usage: ./install.sh [--dry-run]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
MARKETPLACE="ai-dotfiles"
PLUGINS=(flow sdd toolkit)
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run() {
  if ((DRY_RUN)); then echo "[dry-run] $*"; else "$@"; fi
}

require() {
  command -v "$1" >/dev/null || {
    echo "missing dependency: $1" >&2
    exit 1
  }
}

link_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "ok: $dst"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    run mv "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"
  fi
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
  echo "linked: $dst -> $src"
}

merge_settings() {
  local fragment="$REPO_DIR/claude/settings.json" target="$CLAUDE_DIR/settings.json"
  [[ -f "$target" ]] || {
    run cp "$fragment" "$target"
    return
  }
  local merged
  # Deep merge; arrays (e.g. permissions.deny) are unioned so entries added
  # locally through Claude Code are kept. The union preserves order (no
  # `unique`, which sorts) so re-running over a merged file is a no-op.
  merged="$(jq -s '
    def union($a; $b): reduce $b[] as $x ($a; if any(.[]; . == $x) then . else . + [$x] end);
    def m($a; $b):
      reduce ($b | keys_unsorted[]) as $k ($a;
        .[$k] = (if ($a[$k] | type) == "object" and ($b[$k] | type) == "object" then m($a[$k]; $b[$k])
                 elif ($a[$k] | type) == "array" and ($b[$k] | type) == "array" then union($a[$k]; $b[$k])
                 else $b[$k] end));
    m(.[0]; .[1])' "$target" "$fragment")"
  if [[ "$merged" == "$(jq . "$target")" ]]; then
    echo "ok: $target"
    return
  fi
  run cp "$target" "$target.bak-$(date +%Y%m%d-%H%M%S)"
  if ((DRY_RUN)); then
    echo "[dry-run] would merge into $target:"
    jq . "$fragment"
  else
    # Write aside and rename into place (same directory, so mv is atomic): an
    # interrupted run leaves either the old or the new file, never a truncated one.
    local real tmp
    real="$(readlink -f "$target")"
    tmp="$(mktemp "$real.tmp.XXXXXX")"
    printf '%s\n' "$merged" >"$tmp"
    chmod --reference="$real" "$tmp"
    mv -f "$tmp" "$real"
    echo "merged: $target"
  fi
}

link_output_styles() {
  local src
  for src in "$REPO_DIR"/claude/output-styles/*.md; do
    [[ -e "$src" ]] || continue
    link_file "$src" "$CLAUDE_DIR/output-styles/$(basename "$src")"
  done
}

link_bin() {
  local src
  for src in "$REPO_DIR"/bin/*; do
    [[ -f "$src" && -x "$src" ]] || continue
    link_file "$src" "$BIN_DIR/$(basename "$src")"
  done
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "warning: $BIN_DIR is not on PATH; add it to run ai-update directly" >&2 ;;
  esac
}

# systemd user units (engram backup timer). The timer is enabled only once
# engram-backup is configured, so it never fails daily on a fresh machine.
install_units() {
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" src
  local backup_env="${XDG_CONFIG_HOME:-$HOME/.config}/restic/engram.env"
  for src in "$REPO_DIR"/systemd/*.{service,timer}; do
    [[ -e "$src" ]] || continue
    link_file "$src" "$unit_dir/$(basename "$src")"
  done
  command -v systemctl >/dev/null || return 0
  run systemctl --user daemon-reload
  if [[ -f "$backup_env" ]]; then
    run systemctl --user enable --now engram-backup.timer
  else
    echo "next: create $backup_env, run 'engram-backup --init', then re-run ./install.sh to enable the daily timer"
  fi
}

# Global git hooks: gitleaks on pre-commit, then chain to each repo's own hooks.
GIT_HOOKS=(pre-commit prepare-commit-msg commit-msg post-commit pre-rebase post-checkout post-merge pre-push)

install_git_hooks() {
  local dir="$REPO_DIR/git-hooks" hook current
  for hook in "${GIT_HOOKS[@]}"; do
    [[ -L "$dir/$hook" ]] || run ln -sf _dispatch "$dir/$hook"
  done
  current="$(git config --global --get core.hooksPath || true)"
  if [[ "$current" == "$dir" ]]; then
    echo "ok: core.hooksPath"
  elif [[ -n "$current" ]]; then
    echo "skip: global core.hooksPath already set to $current" >&2
  else
    run git config --global core.hooksPath "$dir"
    echo "set: git core.hooksPath -> $dir"
  fi
  command -v gitleaks >/dev/null || echo "warning: gitleaks not installed (sudo pacman -S gitleaks)" >&2
}

install_plugins() {
  if claude plugin marketplace list 2>/dev/null | rg -q "$MARKETPLACE"; then
    echo "ok: marketplace $MARKETPLACE"
  else
    run claude plugin marketplace add "$REPO_DIR"
  fi
  local installed plugin
  installed="$(claude plugin list 2>/dev/null || true)"
  for plugin in "${PLUGINS[@]}"; do
    if rg -qF "$plugin@$MARKETPLACE" <<<"$installed"; then
      run claude plugin update "$plugin@$MARKETPLACE"
    else
      run claude plugin install "$plugin@$MARKETPLACE"
    fi
  done
}

main() {
  require jq
  require rg
  require claude
  link_file "$REPO_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  link_output_styles
  link_bin
  install_units
  merge_settings
  install_git_hooks
  install_plugins
  echo "done. Restart Claude Code to apply."
}

main
