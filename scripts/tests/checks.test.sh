#!/usr/bin/env bash
# Tests for the scripts/check-*.sh verification steps. Run: bash scripts/tests/checks.test.sh
set -u

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SCRIPTS/.." && pwd)"
failures=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# fixture NAME: build a minimal valid repo that passes every check; print its path.
fixture() {
  local root="$TMP_ROOT/$1"
  mkdir -p "$root"/{claude,.claude-plugin,plugins/p/.claude-plugin,plugins/p/hooks,plugins/p/skills/s}
  git -C "$root" init -q
  cp "$REPO/claude/settings.json" "$root/claude/settings.json"
  printf '# Rules\n' >"$root/claude/CLAUDE.md"
  printf '{"plugins":[{"name":"p","source":"./plugins/p"}]}\n' >"$root/.claude-plugin/marketplace.json"
  printf '{"name":"p","version":"0.1.0","description":"d"}\n' >"$root/plugins/p/.claude-plugin/plugin.json"
  # shellcheck disable=SC2016 # literal ${CLAUDE_PLUGIN_ROOT}, resolved by the check.
  printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"\\"${CLAUDE_PLUGIN_ROOT}\\"/hooks/h.sh"}]}]}}\n' \
    >"$root/plugins/p/hooks/hooks.json"
  printf '#!/usr/bin/env bash\necho ok\n' >"$root/plugins/p/hooks/h.sh"
  chmod +x "$root/plugins/p/hooks/h.sh"
  printf -- '---\nname: s\ndescription: "Does s."\n---\n# S\n' >"$root/plugins/p/skills/s/SKILL.md"
  printf '#!/usr/bin/env bash\nset -eu\necho install\n' >"$root/install.sh"
  printf '%s\n' "$root"
}

# expect EXPECTED_EXIT LABEL SCRIPT ROOT: run scripts/SCRIPT against ROOT.
# Combined output is kept in $LAST_OUT for content assertions.
LAST_OUT=""
expect() {
  local expected=$1 label=$2 script=$3 root=$4 actual
  LAST_OUT=$(bash "$SCRIPTS/$script" "$root" 2>&1)
  actual=$?
  if [[ $actual -eq $expected ]]; then
    printf 'PASS  [exit %d] %s\n' "$actual" "$label"
  else
    printf 'FAIL  [want %d, got %d] %s\n%s\n' "$expected" "$actual" "$label" "$LAST_OUT"
    failures=$((failures + 1))
  fi
}

# output_has LABEL PATTERN: assert $LAST_OUT matches PATTERN.
output_has() {
  if grep -q -- "$2" <<<"$LAST_OUT"; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s (no "%s" in output)\n%s\n' "$1" "$2" "$LAST_OUT"
    failures=$((failures + 1))
  fi
}

echo "== baseline =="
for s in check-shell.sh check-json.sh check-structure.sh check-settings.sh check-skills.sh run-tests.sh; do
  expect 0 "valid fixture passes $s" "$s" "$(fixture "ok-$s")"
done

echo "== check-shell =="
root=$(fixture shell-syntax)
printf '#!/usr/bin/env bash\necho "unterminated\n' >"$root/plugins/p/hooks/bad.sh"
expect 1 'shell syntax error fails' check-shell.sh "$root"
output_has 'names the failing file' 'plugins/p/hooks/bad.sh'

root=$(fixture shell-shebang)
mkdir -p "$root/git-hooks"
printf '#!/usr/bin/env bash\ncd somewhere\n' >"$root/git-hooks/pre-commit"
expect 1 'extensionless script with bash shebang is linted' check-shell.sh "$root"

root=$(fixture shell-symlink)
mkdir -p "$root/git-hooks"
printf '#!/usr/bin/env bash\necho ok\n' >"$root/git-hooks/_dispatch"
ln -s _dispatch "$root/git-hooks/pre-push"
expect 0 'symlinked hook is skipped, target linted once' check-shell.sh "$root"

echo "== check-json =="
root=$(fixture json-bad)
printf '{"a": 1,}\n' >"$root/plugins/p/broken.json"
expect 1 'invalid JSON fails' check-json.sh "$root"
output_has 'names the invalid file' 'plugins/p/broken.json'

echo "== check-structure =="
root=$(fixture struct-version)
printf '{"name":"p","description":"d"}\n' >"$root/plugins/p/.claude-plugin/plugin.json"
expect 1 'plugin.json without version fails' check-structure.sh "$root"
output_has 'names the missing field' 'version'

root=$(fixture struct-marketplace)
printf '{"plugins":[{"name":"q","source":"./plugins/q"}]}\n' >"$root/.claude-plugin/marketplace.json"
expect 1 'marketplace source to missing dir fails' check-structure.sh "$root"

root=$(fixture struct-hook-missing)
rm "$root/plugins/p/hooks/h.sh"
expect 1 'missing hook command fails' check-structure.sh "$root"

root=$(fixture struct-hook-exec)
chmod -x "$root/plugins/p/hooks/h.sh"
expect 1 'non-executable hook command fails' check-structure.sh "$root"

echo "== check-settings =="
root=$(fixture settings-drop)
jq '.permissions.deny -= ["Read(~/.ssh/**)"]' "$REPO/claude/settings.json" >"$root/claude/settings.json"
expect 1 'dropping a secret deny rule fails' check-settings.sh "$root"
output_has 'names the dropped rule' 'Read(~/.ssh/\*\*)'

root=$(fixture settings-missing)
rm "$root/claude/settings.json"
expect 1 'missing settings.json fails' check-settings.sh "$root"

echo "== check-skills =="
root=$(fixture skill-nodesc)
printf -- '---\nname: s\n---\n# S\n' >"$root/plugins/p/skills/s/SKILL.md"
expect 1 'skill without description fails' check-skills.sh "$root"

root=$(fixture skill-emptyname)
printf -- '---\nname: \ndescription: "d"\n---\n' >"$root/plugins/p/skills/s/SKILL.md"
expect 1 'skill with empty name fails' check-skills.sh "$root"

root=$(fixture skill-nofront)
printf '# S\nname: s\ndescription: d\n' >"$root/plugins/p/skills/s/SKILL.md"
expect 1 'skill without frontmatter fails' check-skills.sh "$root"

root=$(fixture skill-long)
seq 1 501 >>"$root/plugins/p/skills/s/SKILL.md"
expect 0 'skill over 500 lines only warns' check-skills.sh "$root"
output_has 'prints a warning' 'WARN'

root=$(fixture claude-md-long)
seq 1 60 >"$root/claude/CLAUDE.md"
expect 1 'CLAUDE.md with 60 lines fails' check-skills.sh "$root"

root=$(fixture claude-md-ok)
seq 1 59 >"$root/claude/CLAUDE.md"
expect 0 'CLAUDE.md with 59 lines passes' check-skills.sh "$root"

echo "== run-tests =="
root=$(fixture tests-mixed)
mkdir -p "$root/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' >"$root/scripts/good.test.sh"
printf '#!/usr/bin/env bash\nexit 1\n' >"$root/plugins/p/hooks/bad.test.sh"
expect 1 'a failing test file fails' run-tests.sh "$root"
output_has 'names the failing test file' 'plugins/p/hooks/bad.test.sh'

echo "== check (aggregate) =="
expect 0 'valid fixture passes all steps' check.sh "$(fixture agg-ok)"
output_has 'prints a passing summary' 'All checks passed'

root=$(fixture agg-fail)
printf 'nope' >"$root/plugins/p/broken.json"
seq 1 60 >"$root/claude/CLAUDE.md"
expect 1 'any failing step fails the aggregate' check.sh "$root"
output_has 'summary lists json step' 'FAILED: json'
output_has 'summary lists skills step' 'FAILED: skills'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
