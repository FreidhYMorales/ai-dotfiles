#!/usr/bin/env bash
# Install AI dotfiles for Claude Code and OpenCode.
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
#     - Uses a generated build (scripts/gen-agents/gen.sh into build/agents; a
#       failed generation keeps the previous build).
#     - Symlinks the generated AGENTS.md into ~/.config/opencode/AGENTS.md.
#     - Symlinks the generated flow-x/toolkit-x skills, commands and agents into
#       ~/.config/opencode/{skills,commands,agents}/.
#     - Symlinks the toolkit.ts hooks plugin into ~/.config/opencode/plugins/.
#     - Warns when engram is not registered in opencode.json.
#   - Details: docs/multi-agent.md.
#
#   - --uninstall removes the links, timers, git hooksPath and plugins this
#     installer put in place; everything else stays.
#
# Usage: ./install.sh [--dry-run] [--uninstall] [--target claude|opencode|all]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
OPENCODE_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
MARKETPLACE="ai-dotfiles"
PLUGINS=(flow toolkit look)
# Plugins this marketplace no longer ships: uninstalled when found.
RETIRED_PLUGINS=(sdd)
# Claude-only skills: judgment-day relies on Claude Code agents, so
# link_skills keeps it out of OpenCode until v2.
CLAUDE_ONLY_SKILLS="judgment-day"
# Skills scripts/gen-agents/gen.sh generates for OpenCode: their raw copies
# are never linked there.
PORTED_SKILLS="plan-review backlog story pair work-unit-commits plan fill-gaps research handoff \
next idea split integrate foundation bootstrap ship chained-pr cli-tools cognitive-doc-design \
comment-writer delegate-local go-testing skill-creator skill-improver"
# Generated OpenCode files (gitignored): a symlink to the
# latest generation, swapped in one rename.
BUILD_DIR="${AI_BUILD_DIR:-$REPO_DIR/build/agents}"

DRY_RUN=0
UNINSTALL=0
TARGET_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --target)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "--target needs a value: claude|opencode|all" >&2
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
      echo "Usage: ./install.sh [--dry-run] [--uninstall] [--target claude|opencode|all]"
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

# prune_backups DST: before a new DST.bak-<stamp> is made, remove all but the 2
# newest existing ones, so 3 remain. Only the exact name the installer writes
# matches; the stamp sorts as text, so the glob lists them oldest first.
prune_backups() {
  local old=() f i
  for f in "$1".bak-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]; do
    [[ -e $f || -L $f ]] && old+=("$f")
  done
  for ((i = 0; i < ${#old[@]} - 2; i++)); do
    run rm -rf "${old[i]}"
    ((DRY_RUN)) || echo "pruned old backup: ${old[i]}"
  done
}

link_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "ok: $dst"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    prune_backups "$dst"
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
  prune_backups "$target"
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

# prune_links DIR: remove links in DIR that point into this repo or the build
# dir (which AI_BUILD_DIR may put outside the repo) but no longer resolve (e.g.
# a retired plugin's skills). Other links and files are the user's.
prune_links() {
  local dir="$1" dst target repo_real
  [[ -d "$dir" ]] || return 0
  repo_real=$(readlink -f "$REPO_DIR")
  for dst in "$dir"/*; do
    [[ -L "$dst" && ! -e "$dst" ]] || continue
    target=$(readlink "$dst")
    [[ $target == "$REPO_DIR"/* || $target == "$repo_real"/* || $target == "$BUILD_DIR"/* ]] || continue
    run rm "$dst"
    ((DRY_RUN)) || echo "pruned broken link: $dst"
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
    [[ " $CLAUDE_ONLY_SKILLS $PORTED_SKILLS " == *" $name "* ]] && continue
    link_file "$skill" "$target_skills_dir/$name"
  done
  # Remove Claude-only and raw ported links an earlier run left behind, but
  # only our own symlinks: real directories and links pointing elsewhere are
  # the user's.
  repo_real=$(readlink -f "$REPO_DIR")
  for name in $CLAUDE_ONLY_SKILLS $PORTED_SKILLS; do
    dst="$target_skills_dir/$name"
    [[ -L "$dst" ]] || continue
    target=$(readlink "$dst")
    [[ $target == "$REPO_DIR"/* || $target == "$repo_real"/* ]] || continue
    run rm "$dst"
    if [[ " $PORTED_SKILLS " == *" $name "* ]]; then
      echo "removed raw skill (now generated): $dst"
    else
      echo "removed Claude-only skill: $dst"
    fi
  done
}

# build_agents: generate the OpenCode files once per run into
# a new dir, then point BUILD_DIR at it with one rename, so a reader never sees
# half a build; the previous generation is removed after the swap.
# A dry run generates into a throwaway dir instead (GEN_DIR), removed on
# exit, so it can list the real links without leaving anything behind.
BUILT=0
GEN_DIR=$BUILD_DIR
build_agents() {
  ((BUILT)) && return 0
  BUILT=1
  if ((DRY_RUN)); then
    GEN_DIR=$(mktemp -d)
    trap 'rm -rf "$GEN_DIR"' EXIT
    bash "$REPO_DIR/scripts/gen-agents/gen.sh" "$GEN_DIR" >/dev/null || {
      echo "error: scripts/gen-agents/gen.sh failed" >&2
      exit 1
    }
    return 0
  fi
  local new old
  new="$BUILD_DIR.$(date +%Y%m%d%H%M%S).$$"
  old=$(readlink "$BUILD_DIR" 2>/dev/null || true)
  run mkdir -p "$(dirname "$BUILD_DIR")"
  if ! run bash "$REPO_DIR/scripts/gen-agents/gen.sh" "$new"; then
    run rm -rf "$new"
    echo "error: scripts/gen-agents/gen.sh failed; the previous build is kept" >&2
    exit 1
  fi
  run ln -s "$(basename "$new")" "$new.link"
  run mv -T "$new.link" "$BUILD_DIR"
  # Only a generation this function made, never anything else.
  if [[ $old == "$(basename "$BUILD_DIR")".* ]]; then
    run rm -rf "$(dirname "$BUILD_DIR")/$old"
  fi
}

# link_generated TARGET KIND DIR: link each generated TARGET/KIND entry into
# DIR through BUILD_DIR, so the links survive the next swap.
link_generated() {
  local dir=$3 src
  build_agents
  prune_links "$dir"
  for src in "$GEN_DIR/$1/$2"/*; do
    [[ -e $src ]] || continue
    link_file "$BUILD_DIR/$1/$2/$(basename "$src")" "$dir/$(basename "$src")"
  done
}

# link_rules TARGET DST: link TARGET's generated AGENTS.md at DST. An earlier
# run's raw rules link is ours, so it goes without a backup; anything else
# at DST is moved aside by link_file.
link_rules() {
  local dst=$2
  build_agents
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$REPO_DIR/AGENTS.md")" ]]; then
    run rm "$dst"
  fi
  link_file "$BUILD_DIR/$1/AGENTS.md" "$dst"
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
  # No user bus (ssh, sudo, container): the units stay linked, the rest of
  # the install goes on. Any other reload failure does too, with systemd's own
  # error. Only stderr is captured: a dry run's line still reaches stdout (fd 3).
  local reload_err
  if ! { reload_err=$(run systemctl --user daemon-reload 2>&1 >&3); } 3>&1; then
    if [[ $reload_err == *"Failed to connect to"*bus* ]]; then
      echo "no systemd user session: timers not enabled; re-run ./install.sh from a login session to enable them"
    else
      echo "warning: systemctl --user daemon-reload failed, timers not enabled: $reload_err"
    fi
    return 0
  fi
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
  current="$(git config --global --path --get core.hooksPath || true)"
  if [[ "$current" == "$dir" ]]; then
    echo "ok: core.hooksPath"
  elif [[ "$current" == /* && ! -d "$current" ]]; then
    # Points nowhere (e.g. the repo was moved): git runs no global hooks.
    run git config --global core.hooksPath "$dir"
    echo "set: replaced dangling core.hooksPath $current -> $dir"
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
  link_rules opencode "$OPENCODE_DIR/AGENTS.md"
  link_skills "$OPENCODE_DIR/skills"
  link_generated opencode skills "$OPENCODE_DIR/skills"
  link_generated opencode agents "$OPENCODE_DIR/agents"
  link_generated opencode commands "$OPENCODE_DIR/commands"
  link_file "$REPO_DIR/plugins/toolkit/opencode/toolkit.ts" "$OPENCODE_DIR/plugins/toolkit.ts"
  # Verify only: engram setup may rewrite the user's config, so it stays manual.
  if ! jq -e '.mcp.engram != null and .mcp.engram.enabled != false' "$OPENCODE_DIR/opencode.json" >/dev/null 2>&1; then
    echo "warning: engram is not registered in OpenCode; run: engram setup opencode"
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
          TARGETS=(claude opencode)
          return
          ;;
        claude | opencode)
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
    if [[ ${#TARGETS[@]} -eq 0 ]]; then
      TARGETS=(claude)
    fi
  fi
}

# remove_links DIR: remove the links in DIR that point into this repo or the
# build dir; other links and files are the user's.
remove_links() {
  local dir="$1" dst target repo_real
  [[ -d "$dir" ]] || return 0
  repo_real=$(readlink -f "$REPO_DIR")
  for dst in "$dir"/*; do
    [[ -L "$dst" ]] || continue
    target=$(readlink "$dst")
    [[ $target == "$REPO_DIR"/* || $target == "$repo_real"/* || $target == "$BUILD_DIR"/* ]] || continue
    run rm "$dst"
    ((DRY_RUN)) || echo "removed: $dst"
  done
}

# uninstall_plugins: remove this marketplace's plugins (current and retired)
# and the marketplace; plugins from other marketplaces stay.
uninstall_plugins() {
  local installed plugin
  installed="$(claude plugin list 2>/dev/null || true)"
  for plugin in "${PLUGINS[@]}" "${RETIRED_PLUGINS[@]}"; do
    rg -qF "$plugin@$MARKETPLACE" <<<"$installed" || continue
    run claude plugin uninstall "$plugin@$MARKETPLACE"
    ((DRY_RUN)) || echo "uninstalled plugin: $plugin@$MARKETPLACE"
  done
  if claude plugin marketplace list 2>/dev/null | rg -q "$MARKETPLACE"; then
    run claude plugin marketplace remove "$MARKETPLACE"
    ((DRY_RUN)) || echo "removed marketplace: $MARKETPLACE"
  fi
}

uninstall() {
  remove_links "$BIN_DIR"
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" src
  # Disable before the unit links go, while systemd can still find the units.
  if command -v systemctl >/dev/null; then
    for src in "$REPO_DIR"/systemd/*.timer; do
      [[ -e "$src" ]] || continue
      if run systemctl --user disable --now "$(basename "$src")" 2>/dev/null; then
        ((DRY_RUN)) || echo "disabled: $(basename "$src")"
      else
        echo "skip: could not disable $(basename "$src") (no systemd user session?)"
      fi
    done
  fi
  remove_links "$unit_dir"
  if command -v systemctl >/dev/null; then
    run systemctl --user daemon-reload 2>/dev/null || true
  fi
  # Only our own hooksPath; one the user set elsewhere stays.
  if [[ "$(git config --global --path --get core.hooksPath || true)" == "$REPO_DIR/git-hooks" ]]; then
    run git config --global --unset core.hooksPath
    ((DRY_RUN)) || echo "unset: core.hooksPath $REPO_DIR/git-hooks"
  fi
  local target dir
  for target in "${TARGETS[@]}"; do
    case "$target" in
      claude)
        for dir in "$CLAUDE_DIR" "$CLAUDE_DIR/output-styles"; do remove_links "$dir"; done
        uninstall_plugins
        # The merge unioned arrays with local entries: ours cannot be told apart.
        [[ -f "$CLAUDE_DIR/settings.json" ]] &&
          echo "note: $CLAUDE_DIR/settings.json keeps the merged entries; clean it by hand (fragment: $REPO_DIR/claude/settings.json)"
        ;;
      opencode)
        for dir in "$OPENCODE_DIR" "$OPENCODE_DIR"/{skills,agents,commands,plugins}; do remove_links "$dir"; done
        ;;
    esac
  done
  echo "done. Uninstalled targets: ${TARGETS[*]}."
}

TARGETS=()

main() {
  resolve_targets "$TARGET_ARG"
  if ((UNINSTALL)); then
    uninstall
    return
  fi

  require jq
  require rg
  # Other parts of the setup use these; the install itself does not.
  local tool
  for tool in make shellcheck zellij bwrap socat; do
    command -v "$tool" >/dev/null || echo "warning: $tool not found; install the packages in docs/recovery.md step 1"
  done

  link_bin
  install_units
  install_git_hooks

  local target
  for target in "${TARGETS[@]}"; do
    case "$target" in
      claude) install_claude ;;
      opencode) install_opencode ;;
    esac
  done

  echo "done. Active targets: ${TARGETS[*]}."
}

main
