#!/usr/bin/env bash
# SessionStart hook: warn when the global core.hooksPath points to a missing
# directory (e.g. the dotfiles repo was moved): git then runs no global hooks,
# so gitleaks stops checking commits with no error. Silent otherwise.
set -u
# shellcheck source=plugins/toolkit/hooks/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh" && hook_off

IFS= read -r -d '' input || true
[[ $(jq -r '.source // empty' <<<"$input" 2>/dev/null) == startup ]] || exit 0

path=$(git config --global --path --get core.hooksPath 2>/dev/null) || exit 0
[[ -d $path ]] && exit 0

message="Git hooks attention: the global core.hooksPath $path does not exist, so gitleaks is not running on commits; re-run ./install.sh from the dotfiles repo to repair it."
jq -n --arg m "$message" '{systemMessage: $m}'
