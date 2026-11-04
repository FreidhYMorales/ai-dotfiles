#!/usr/bin/env bash
# Print the packages docs/recovery.md step 1 installs, one per line, so the CI
# recovery drill installs exactly what the doc tells a person to install.
# Fails when the doc no longer has exactly one `sudo pacman -S --needed` line.
# Usage: scripts/recovery-packages.sh [RECOVERY_MD]
set -euo pipefail

doc=${1:-"$(cd "$(dirname "$0")/.." && pwd)/docs/recovery.md"}
# grep, not rg: a clean machine has no ripgrep until these are installed.
lines=$(grep '^sudo pacman -S --needed ' "$doc" || true)
if [[ -z $lines || $(wc -l <<<"$lines") -ne 1 ]]; then
  echo "recovery-packages: expected one 'sudo pacman -S --needed' line in $doc" >&2
  exit 1
fi
read -ra words <<<"${lines#sudo pacman -S --needed }"
printf '%s\n' "${words[@]}"
