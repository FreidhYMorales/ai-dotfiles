#!/usr/bin/env bash
# Regression guard: claude/settings.json must keep every secret-protecting
# permissions.deny rule. Adding rules is fine; removing one fails.
set -u
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

required=(
  'Read(//**/.env)'
  'Read(//**/.env.local)'
  'Read(//**/.env.*.local)'
  'Read(//**/.env.development)'
  'Read(//**/.env.production)'
  'Read(//**/.env.staging)'
  'Read(//**/.env.test)'
  'Read(//**/*.pem)'
  'Read(//**/*.key)'
  'Read(//**/*.p12)'
  'Read(//**/*.pfx)'
  'Read(//**/id_rsa*)'
  'Read(//**/id_ed25519*)'
  'Read(//**/*serviceAccount*.json)'
  'Read(//**/*service-account*.json)'
  'Read(//**/*credentials*.json)'
  'Read(//**/.netrc)'
  'Read(//**/.npmrc)'
  'Read(//**/.pypirc)'
  'Read(~/.ssh/**)'
  'Read(~/.aws/**)'
  'Read(~/.gnupg/**)'
  'Read(~/.config/gcloud/**)'
  'Read(~/.docker/config.json)'
  'Read(~/.claude.json)'
)

settings="$ROOT/claude/settings.json"
if [[ ! -f $settings ]]; then
  err "claude/settings.json not found"
  finish settings
fi

for rule in "${required[@]}"; do
  if jq -e --arg r "$rule" '.permissions.deny // [] | index($r) != null' "$settings" >/dev/null 2>&1; then
    :
  else
    err "claude/settings.json: missing deny rule $rule"
  fi
done
[[ $errors -eq 0 ]] && ok "all ${#required[@]} secret deny rules present"
finish settings
