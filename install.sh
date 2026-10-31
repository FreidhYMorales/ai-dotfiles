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
# Claude-only skills: judgment-day relies on Claude Code agents, so
# link_skills keeps it out of OpenCode and Antigravity until v2.
CLAUDE_ONLY_SKILLS="judgment-day"
# Skills scripts/gen-agents/gen.sh generates for OpenCode and Antigravity:
# their raw copies are never linked there.
PORTED_SKILLS="plan-review backlog story pair work-unit-commits plan fill-gaps research handoff \
next idea split integrate foundation bootstrap ship chained-pr cli-tools cognitive-doc-design \
comment-writer delegate-local go-testing skill-creator skill-improver"
# Generated OpenCode and Antigravity files (gitignored): a symlink to the
# latest generation, swapped in one rename.
BUILD_DIR="${AI_BUILD_DIR:-$REPO_DIR/build/agents}"

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

# build_agents: generate the OpenCode and Antigravity files once per run into
# a new dir, then point BUILD_DIR at it with one rename, so a reader never sees
# half a build; the previous generation is removed after the swap.
BUILT=0
build_agents() {
  ((BUILT)) && return 0
  BUILT=1
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
  local src_dir="$BUILD_DIR/$1/$2" dir=$3 src
  build_agents
  prune_links "$dir"
  for src in "$src_dir"/*; do
    [[ -e $src ]] || continue
    link_file "$src" "$dir/$(basename "$src")"
  done
}

# move_to_backup SRC LABEL: move SRC into agy's skills-backup/, outside skill
# discovery; never deleted. A taken name gets a numeric suffix, so no backup
# is ever overwritten.
move_to_backup() {
  local backup_dir="$ANTIGRAVITY_DIR/skills-backup" new n=1
  new="$backup_dir/$(basename "$1")"
  while [[ -e "$new" || -L "$new" ]]; do
    new="$backup_dir/$(basename "$1").$n"
    n=$((n + 1))
  done
  run mkdir -p "$backup_dir"
  run mv "$1" "$new"
  echo "moved $2: $1 -> $new"
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

# agy reads every top-level key of hooks.json as a named hook set; herdr owns
# its own key there, so only the "toolkit" key is ever written. A hooks.json
# jq cannot parse stops the install instead of being overwritten.
merge_agy_hooks() {
  local target="$GEMINI_CONFIG_DIR/hooks.json" current='{}' merged
  [[ -f "$target" ]] && current=$(<"$target")
  # Stop's 330 s timeout covers require-check's 300 s make check; SessionStart's
  # 15 s covers its three hooks' 5 + 2 + 5 s.
  merged=$(jq --arg pre "bash '$REPO_DIR/plugins/toolkit/hooks/agy/prefer-modern-cli.sh'" \
    --arg stop "bash '$REPO_DIR/plugins/toolkit/hooks/agy/require-check.sh'" \
    --arg start "bash '$REPO_DIR/plugins/toolkit/hooks/agy/session-start.sh'" \
    '.toolkit = {PreToolUse: [{matcher: "run_command", hooks: [{type: "command", command: $pre}]}],
      Stop: [{type: "command", command: $stop, timeout: 330}],
      SessionStart: [{type: "command", command: $start, timeout: 15}]}' <<<"$current")
  if [[ "$merged" == "$current" ]]; then
    echo "ok: $target"
    return
  fi
  if ((DRY_RUN)); then
    echo "[dry-run] would set the toolkit key in $target"
    return
  fi
  mkdir -p "$GEMINI_CONFIG_DIR"
  # A temp file of its own beside the target: two installs never share one.
  local tmp
  tmp=$(mktemp "$target.tmp.XXXXXX")
  printf '%s\n' "$merged" >"$tmp"
  # mktemp makes the file 0600: keep the target's mode, 0644 for a new file.
  if [[ -f "$target" ]]; then chmod --reference="$target" "$tmp"; else chmod 644 "$tmp"; fi
  mv "$tmp" "$target"
  echo "merged toolkit hooks: $target"
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
    link_rules antigravity "$GEMINI_CONFIG_DIR/AGENTS.md"
    merge_agy_hooks
  fi
  link_skills "$ANTIGRAVITY_DIR/skills"
  link_generated antigravity skills "$ANTIGRAVITY_DIR/skills"
  # The global subagents dir agy reads (story 16).
  link_generated antigravity agents "$GEMINI_CONFIG_DIR/agents"
  # agy discovers a skill in a *.bak-* dir of any of its three skills dirs by its name: and can let it shadow
  # ours; skills-backup/ is outside discovery. Moved, never deleted. Runs after
  # the link step, which itself renames a clashing user dir to *.bak-*.
  local old dir name
  for dir in "$HOME/.gemini/skills" "$GEMINI_CONFIG_DIR/skills" "$ANTIGRAVITY_DIR/skills"; do
    for old in "$dir"/*.bak-*; do
      [[ -e "$old" || -L "$old" ]] || continue
      move_to_backup "$old" "skill backup"
    done
  done
  # gentle-ai's copies named like a repo skill and the skills of a retired
  # plugin (named <plugin>-*) load beside the prefixed repo skills in every
  # agy discovery dir (story 32). Real dirs only: links are the installer's
  # or the user's.
  local retired keep
  for dir in "$HOME/.gemini/skills" "$GEMINI_CONFIG_DIR/skills" "$ANTIGRAVITY_DIR/skills"; do
    for old in "$dir"/*; do
      [[ -d "$old" && ! -L "$old" ]] || continue
      name=$(basename "$old")
      keep=1
      for retired in "${RETIRED_PLUGINS[@]}"; do
        [[ $name == "$retired"-* ]] && keep=0
      done
      compgen -G "$REPO_DIR/plugins/*/skills/$name/SKILL.md" >/dev/null && keep=0
      ((keep)) && continue
      move_to_backup "$old" "gentle-ai skill"
    done
  done
  # Ask agy, not its files: two mcp_config.json exist and only one is read.
  if ! command -v agy >/dev/null; then
    echo "warning: engram cannot be checked in Antigravity (agy not found); if missing, run: engram setup antigravity-cli"
  elif ! agy mcp list 2>/dev/null | rg -q '^engram\s'; then
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
