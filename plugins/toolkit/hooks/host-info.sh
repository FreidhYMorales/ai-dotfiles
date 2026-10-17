#!/usr/bin/env bash
# SessionStart hook: tell Claude which machine it is running on (OS/distro,
# package managers, shell) so install commands and tool choices fit the host.
# The host is the dev machine only: never the project's target platform nor
# other contributors' machines. Runs on startup, clear and compact (resume
# keeps the earlier context). Opt out with SKIP_HOST_INFO=1.
set -u

[[ ${SKIP_HOST_INFO:-} == 1 ]] && exit 0

input=$(</dev/stdin)
case $(jq -r '.source // empty' <<<"$input" 2>/dev/null) in
  startup | clear | compact) ;;
  *) exit 0 ;;
esac

OS_RELEASE_FILE=${OS_RELEASE_FILE:-/etc/os-release}
PROC_VERSION_FILE=${PROC_VERSION_FILE:-/proc/version}

has() { command -v "$1" >/dev/null 2>&1; }

# os_release_name: PRETTY_NAME (or NAME) from os-release, without sourcing it.
os_release_name() {
  local key value name=""
  [[ -r $OS_RELEASE_FILE ]] || return 1
  while IFS='=' read -r key value; do
    value=${value%\"}
    value=${value#\"}
    case $key in
      PRETTY_NAME) name=$value && break ;;
      NAME) name=$value ;;
    esac
  done <"$OS_RELEASE_FILE"
  [[ -n $name ]] && printf '%s\n' "$name"
}

kernel=$(uname -s 2>/dev/null)
case $kernel in
  Linux)
    os=$(os_release_name) || os=Linux
    if [[ -r $PROC_VERSION_FILE ]] && [[ $(<"$PROC_VERSION_FILE") == *[Mm]icrosoft* ]]; then
      os+=" (WSL)"
    fi
    ;;
  Darwin) os="macOS $(sw_vers -productVersion 2>/dev/null)" ;;
  MINGW* | MSYS* | CYGWIN*) os="Windows (Git Bash/MSYS)" ;;
  *) os=${kernel:-unknown} ;;
esac
os=${os% }

managers=()
for pm in pacman apt dnf zypper apk nix brew winget scoop choco; do
  has "$pm" && managers+=("$pm")
done
packages=unknown
if ((${#managers[@]})); then
  packages=$(printf '%s, ' "${managers[@]}")
  packages=${packages%, }
fi
for helper in paru yay; do
  if has pacman && has "$helper"; then
    packages+=" (AUR: $helper)"
    break
  fi
done

# Curated, so the line stays short: only tools that change what Claude can do
# or which command it should pick. Order is the reported order.
TOOLS=(git gh glab docker podman kubectl act make just mise direnv
  node bun deno pnpm python3 uv go cargo java
  rg rga fd bat eza sd fzf jq yq sqlite3 psql hyperfine
  shellcheck shfmt actionlint gitleaks trivy osv-scanner
  ffmpeg yt-dlp magick pandoc typst restic ollama tmux zellij nvim code)
found=()
for tool in "${TOOLS[@]}"; do
  has "$tool" && found+=("$tool")
done
tools=none
if ((${#found[@]})); then
  tools=$(printf '%s, ' "${found[@]}")
  tools=${tools%, }
fi

context="Host (dev machine): $os · packages: $packages · shell: ${SHELL##*/} · tools: $tools. Give install commands for this package manager; prefer installed tools and say when a task needs one that is missing. This is the machine you run on, not the project target platform or other contributors' machines: for those, follow the project's docs (e.g. docs/development.md)."

jq -n --arg ctx "$context" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
