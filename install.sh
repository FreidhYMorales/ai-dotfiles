#!/usr/bin/env bash
# Install AI dotfiles for Claude Code.
#   - Symlinks claude/CLAUDE.md into ~/.claude (existing file is backed up).
#   - Merges claude/settings.json into ~/.claude/settings.json (Claude Code
#     rewrites that file itself, so it is merged, never symlinked).
#   - Registers this repo as a plugin marketplace and installs the `flow` plugin.
#
# Usage: ./install.sh [--dry-run]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MARKETPLACE="ai-dotfiles"
PLUGIN="flow"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run() {
  if (( DRY_RUN )); then echo "[dry-run] $*"; else "$@"; fi
}

require() {
  command -v "$1" >/dev/null || { echo "missing dependency: $1" >&2; exit 1; }
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
  [[ -f "$target" ]] || { run cp "$fragment" "$target"; return; }
  local merged
  merged="$(jq -s '.[0] * .[1]' "$target" "$fragment")"
  if [[ "$merged" == "$(jq . "$target")" ]]; then
    echo "ok: $target"
    return
  fi
  run cp "$target" "$target.bak-$(date +%Y%m%d-%H%M%S)"
  if (( DRY_RUN )); then
    echo "[dry-run] would merge into $target:"; jq . "$fragment"
  else
    printf '%s\n' "$merged" > "$target"
    echo "merged: $target"
  fi
}

install_plugin() {
  if claude plugin marketplace list 2>/dev/null | rg -q "$MARKETPLACE"; then
    echo "ok: marketplace $MARKETPLACE"
  else
    run claude plugin marketplace add "$REPO_DIR"
  fi
  if claude plugin list 2>/dev/null | rg -q "$PLUGIN@$MARKETPLACE"; then
    run claude plugin update "$PLUGIN@$MARKETPLACE"
  else
    run claude plugin install "$PLUGIN@$MARKETPLACE"
  fi
}

main() {
  require jq
  require rg
  require claude
  link_file "$REPO_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  merge_settings
  install_plugin
  echo "done. Restart Claude Code to apply."
}

main
