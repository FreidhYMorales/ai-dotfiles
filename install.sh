#!/usr/bin/env bash
# Install AI dotfiles for Claude Code, OpenCode, and Antigravity.
#   - Common:
#     - Symlinks bin/* (e.g. ai-update, engram-backup) into ~/.local/bin.
#     - Symlinks systemd/* user units and enables the engram backup timer once
#       engram-backup is configured.
#     - Sets up global git hooks (gitleaks on pre-commit).
#   - Claude Code:
#     - Symlinks claude/CLAUDE.md and claude/statusline.sh into ~/.claude.
#     - Merges claude/settings.json into ~/.claude/settings.json.
#     - Symlinks claude/output-styles/*.md into ~/.claude/output-styles/.
#     - Registers this repo as a plugin marketplace and installs plugins.
#   - OpenCode:
#     - Symlinks AGENTS.md into ~/.config/opencode/AGENTS.md.
#     - Symlinks all skills into ~/.config/opencode/skills/.
#   - Antigravity:
#     - Symlinks AGENTS.md into ~/.gemini/config/ (the global rules path agy reads).
#     - Symlinks all skills into ~/.gemini/antigravity-cli/skills/.
#
# Usage: ./install.sh [--dry-run] [--target claude|opencode|antigravity|all]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
OPENCODE_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
ANTIGRAVITY_DIR="${ANTIGRAVITY_CONFIG_DIR:-$HOME/.gemini/antigravity-cli}"
GEMINI_CONFIG_DIR="${GEMINI_CONFIG_DIR:-$HOME/.gemini/config}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
MARKETPLACE="ai-dotfiles"
PLUGINS=(flow toolkit look)
# Plugins this marketplace no longer ships: uninstalled when found.
RETIRED_PLUGINS=(sdd)
# Claude-only skills: the daily loop (flow:backlog, flow:story, flow:pair) relies
# on Claude Code hooks and agents, so link_skills keeps it out of OpenCode and
# Antigravity until it is ported (multi-agent-port).
CLAUDE_ONLY_SKILLS="backlog story pair"

DRY_RUN=0
TARGET_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --target)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "--target needs a value: claude|opencode|antigravity|all" >&2
        exit 1
      fi
      TARGET_ARG="$2"
      shift 2
      ;;
    --target=*)
      TARGET_ARG="${1#*=}"
      shift
      ;;
    -h | --help)
      echo "Usage: ./install.sh [--dry-run] [--target claude|opencode|antigravity|all]"
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 1
      ;;
  esac
done

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

# prune_links DIR: remove links in DIR that point into this repo but no longer
# resolve (e.g. a retired plugin's skills). Other links and files are the user's.
prune_links() {
  local dir="$1" dst target repo_real
  [[ -d "$dir" ]] || return 0
  repo_real=$(readlink -f "$REPO_DIR")
  for dst in "$dir"/*; do
    [[ -L "$dst" && ! -e "$dst" ]] || continue
    target=$(readlink "$dst")
    [[ $target == "$REPO_DIR"/* || $target == "$repo_real"/* ]] || continue
    run rm "$dst"
    echo "pruned broken link: $dst"
  done
}

link_output_styles() {
  local src
  prune_links "$CLAUDE_DIR/output-styles"
  for src in "$REPO_DIR"/claude/output-styles/*.md; do
    [[ -e "$src" ]] || continue
    link_file "$src" "$CLAUDE_DIR/output-styles/$(basename "$src")"
  done
}

link_bin() {
  local src
  prune_links "$BIN_DIR"
  for src in "$REPO_DIR"/bin/*; do
    [[ -f "$src" && -x "$src" ]] || continue
    link_file "$src" "$BIN_DIR/$(basename "$src")"
  done
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "warning: $BIN_DIR is not on PATH; add it to run ai-update directly" >&2 ;;
  esac
}

link_skills() {
  local target_skills_dir="$1"
  run mkdir -p "$target_skills_dir"
  prune_links "$target_skills_dir"
  local skill name dst target repo_real
  for skill in "$REPO_DIR"/plugins/*/skills/*; do
    [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
    name=$(basename "$skill")
    [[ " $CLAUDE_ONLY_SKILLS " == *" $name "* ]] && continue
    link_file "$skill" "$target_skills_dir/$name"
  done
  # Remove Claude-only links an earlier run left behind, but only our own
  # symlinks: real directories and links pointing elsewhere are the user's.
  repo_real=$(readlink -f "$REPO_DIR")
  for name in $CLAUDE_ONLY_SKILLS; do
    dst="$target_skills_dir/$name"
    [[ -L "$dst" ]] || continue
    target=$(readlink "$dst")
    [[ $target == "$REPO_DIR"/* || $target == "$repo_real"/* ]] || continue
    run rm "$dst"
    echo "removed Claude-only skill: $dst"
  done
}

# systemd user units (engram backup timer). The timer is enabled only once
# engram-backup is configured, so it never fails daily on a fresh machine.
install_units() {
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" src
  local backup_env="${XDG_CONFIG_HOME:-$HOME/.config}/restic/engram.env"
  prune_links "$unit_dir"
  for src in "$REPO_DIR"/systemd/*.{service,timer}; do
    [[ -e "$src" ]] || continue
    link_file "$src" "$unit_dir/$(basename "$src")"
  done
  command -v systemctl >/dev/null || return 0
  run systemctl --user daemon-reload
  run systemctl --user enable --now upstream-watch.timer
  if [[ -f "$backup_env" ]]; then
    run systemctl --user enable --now engram-backup.timer
    run systemctl --user enable --now engram-backup-verify.timer
  else
    echo "next: create $backup_env, run 'engram-backup --init', then re-run ./install.sh to enable the daily backup and weekly verify timers"
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
  for plugin in "${RETIRED_PLUGINS[@]}"; do
    rg -qF "$plugin@$MARKETPLACE" <<<"$installed" || continue
    run claude plugin uninstall "$plugin@$MARKETPLACE"
  done
}

install_claude() {
  require claude
  link_file "$REPO_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  link_file "$REPO_DIR/claude/statusline.sh" "$CLAUDE_DIR/statusline.sh"
  link_output_styles
  merge_settings
  install_plugins
}

install_opencode() {
  link_file "$REPO_DIR/AGENTS.md" "$OPENCODE_DIR/AGENTS.md"
  link_skills "$OPENCODE_DIR/skills"
  # Verify only: engram setup may rewrite the user's config, so it stays manual.
  if ! jq -e '.mcp.engram != null and .mcp.engram.enabled != false' "$OPENCODE_DIR/opencode.json" >/dev/null 2>&1; then
    echo "warning: engram is not registered in OpenCode; run: engram setup opencode"
  fi
}

install_antigravity() {
  # agy never reads antigravity-cli/AGENTS.md: drop the link an earlier run
  # made there, but only our own symlink; anything else is the user's.
  local dst="$ANTIGRAVITY_DIR/AGENTS.md" target repo_real
  repo_real=$(readlink -f "$REPO_DIR")
  if [[ -L "$dst" ]]; then
    target=$(readlink "$dst")
    if [[ $target == "$REPO_DIR"/* || $target == "$repo_real"/* ]]; then
      run rm "$dst"
      echo "removed unread rules link: $dst"
    fi
  fi
  # agy also loads ~/.gemini/GEMINI.md (gentle-ai) on top of these rules, so
  # move it aside; the backup is never deleted.
  local gemini_md="$HOME/.gemini/GEMINI.md" backup
  if [[ -e "$gemini_md" || -L "$gemini_md" ]]; then
    backup="$gemini_md.bak-$(date +%Y%m%d-%H%M%S)"
    run mv "$gemini_md" "$backup"
    echo "moved $gemini_md aside (agy loads it over these rules); restore: mv '$backup' '$gemini_md'"
  fi
  if [[ -d "$GEMINI_CONFIG_DIR" || -d "$HOME/.gemini" ]]; then
    link_file "$REPO_DIR/AGENTS.md" "$GEMINI_CONFIG_DIR/AGENTS.md"
  fi
  link_skills "$ANTIGRAVITY_DIR/skills"
  # agy discovers a skill in a *.bak-* dir by its name: and can let it shadow
  # ours; skills-backup/ is outside discovery. Moved, never deleted. Runs after
  # the link step, which itself renames a clashing user dir to *.bak-*.
  local old new n backup_dir="$ANTIGRAVITY_DIR/skills-backup"
  for old in "$ANTIGRAVITY_DIR"/skills/*.bak-*; do
    [[ -e "$old" || -L "$old" ]] || continue
    # A taken name gets a numeric suffix, so no backup is ever overwritten.
    new="$backup_dir/$(basename "$old")"
    n=1
    while [[ -e "$new" || -L "$new" ]]; do
      new="$backup_dir/$(basename "$old").$n"
      n=$((n + 1))
    done
    run mkdir -p "$backup_dir"
    run mv "$old" "$new"
    echo "moved skill backup: $old -> $new"
  done
  # Ask agy, not its files: two mcp_config.json exist and only one is read.
  if ! agy mcp list 2>/dev/null | rg -q '^engram\s'; then
    echo "warning: engram is not registered in Antigravity; run: engram setup antigravity-cli"
  fi
}

resolve_targets() {
  local raw="$1"
  if [[ -n "$raw" ]]; then
    local items
    IFS=',' read -ra items <<<"$raw"
    local item
    for item in "${items[@]}"; do
      case "$item" in
        all)
          TARGETS=(claude opencode antigravity)
          return
          ;;
        claude | opencode | antigravity)
          TARGETS+=("$item")
          ;;
        *)
          echo "unknown target: $item" >&2
          exit 1
          ;;
      esac
    done
  else
    # Auto-detect installed agents
    command -v claude >/dev/null && TARGETS+=(claude)
    command -v opencode >/dev/null && TARGETS+=(opencode)
    if command -v agy >/dev/null || command -v antigravity >/dev/null || [[ -d "$ANTIGRAVITY_DIR" ]]; then
      TARGETS+=(antigravity)
    fi
    if [[ ${#TARGETS[@]} -eq 0 ]]; then
      TARGETS=(claude)
    fi
  fi
}

TARGETS=()

main() {
  resolve_targets "$TARGET_ARG"

  require jq
  require rg

  link_bin
  install_units
  install_git_hooks

  local target
  for target in "${TARGETS[@]}"; do
    case "$target" in
      claude) install_claude ;;
      opencode) install_opencode ;;
      antigravity) install_antigravity ;;
    esac
  done

  echo "done. Active targets: ${TARGETS[*]}."
}

main
