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
for s in check-shell.sh check-json.sh check-structure.sh check-settings.sh check-skills.sh check-workflows.sh run-tests.sh; do
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

root=$(fixture shell-vendor)
mkdir -p "$root/packs/vendor/x/scripts" "$root/packs/lib"
printf '#!/usr/bin/env bash\ncd somewhere\n' >"$root/packs/vendor/x/scripts/bad.sh"
printf '#!/usr/bin/env bash\necho "unterminated\n' >"$root/packs/vendor/x/scripts/syntax.sh"
expect 0 'failing script under packs/vendor/ is skipped' check-shell.sh "$root"
printf '#!/usr/bin/env bash\ncd somewhere\n' >"$root/packs/lib/bad.sh"
expect 1 'failing script under packs/lib/ is still linted' check-shell.sh "$root"
output_has 'names the packs/lib file' 'packs/lib/bad.sh'

root=$(fixture shell-many)
mkdir -p "$root/many"
for i in 1 2 3 4 5; do printf '#!/usr/bin/env bash\necho %s\n' "$i" >"$root/many/good$i.sh"; done
printf '#!/usr/bin/env bash\ncd somewhere\n' >"$root/many/bad.sh"
expect 1 'one bad script among many sane ones fails the step' check-shell.sh "$root"
output_has 'names the bad script among many' 'ERROR shellcheck many/bad.sh'
good_count=$(grep -c '^ok    shellcheck ' <<<"$LAST_OUT")
if [[ $good_count -eq 7 ]]; then
  printf 'PASS  every sane script is reported ok (7)\n'
else
  printf 'FAIL  every sane script is reported ok: want 7, got %s\n%s\n' "$good_count" "$LAST_OUT"
  failures=$((failures + 1))
fi

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

# The credential denies of audit-fixes story 02: restic key, gh token, git
# credentials and every .env.* file.
for rule in 'Read(~/.config/restic/**)' 'Read(~/.config/gh/**)' 'Read(~/.git-credentials)' 'Read(//**/.env.*)'; do
  root=$(fixture settings-drop-credential)
  jq --arg r "$rule" '.permissions.deny -= [$r]' "$REPO/claude/settings.json" >"$root/claude/settings.json"
  expect 1 "dropping $rule fails" check-settings.sh "$root"
  output_has "names $rule" "missing deny rule ${rule//\*/\\*}"
done

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

root=$(fixture tests-failure-output)
mkdir -p "$root/scripts"
printf '#!/usr/bin/env bash\necho "why-it-failed"\nexit 1\n' >"$root/scripts/loud.test.sh"
expect 1 'a failing test file still fails' run-tests.sh "$root"
output_has 'shows the failing test output' 'why-it-failed'

# A failure reported early in a long output is still shown (CI hid look's).
root=$(fixture tests-early-failure)
mkdir -p "$root/scripts"
printf '#!/usr/bin/env bash\necho "FAIL  early bash case"\necho "(fail) early bun case [5000.00ms]"\nseq 60\nexit 1\n' >"$root/scripts/long.test.sh"
expect 1 'a failing file with a long output still fails' run-tests.sh "$root"
output_has 'shows a FAIL line printed before the last 40 lines' 'FAIL  early bash case'
output_has 'shows a (fail) line printed before the last 40 lines' '(fail) early bun case'

root=$(fixture tests-parallel)
mkdir -p "$root/scripts"
for n in 1 2 3; do
  printf '#!/usr/bin/env bash\nsleep 2\n' >"$root/scripts/slow$n.test.sh"
done
start=$SECONDS
expect 0 'three slow test files pass' run-tests.sh "$root"
elapsed=$((SECONDS - start))
if ((elapsed < 5)); then
  printf 'PASS  test files run in parallel (%ds for 3 x 2s)\n' "$elapsed"
else
  printf 'FAIL  test files run in parallel (%ds for 3 x 2s)\n' "$elapsed"
  failures=$((failures + 1))
fi
output_has 'results are reported in file order' 'slow1.test.sh'

echo "== check-workflows =="
# workflow ROOT CONTENT: write .github/workflows/ci.yml in ROOT.
workflow() {
  mkdir -p "$1/.github/workflows"
  printf '%s\n' "$2" >"$1/.github/workflows/ci.yml"
}
good_workflow='on: push
jobs:
  check:
    runs-on: ubuntu-24.04
    steps:
      - run: echo ok'
# shellcheck disable=SC2016 # ${{ }} is GitHub expression syntax, not shell.
bad_workflow='on: push
jobs:
  check:
    runs-on: ubuntu-24.04
    steps:
      - run: echo "${{ github.nope }}"'

root=$(fixture wf-none)
expect 0 'no workflows passes' check-workflows.sh "$root"

root=$(fixture wf-skip)
workflow "$root" "$bad_workflow"
export ACTIONLINT=no-such-actionlint
expect 0 'missing actionlint skips' check-workflows.sh "$root"
output_has 'skip is reported' 'actionlint not installed'
unset ACTIONLINT

if command -v actionlint >/dev/null 2>&1; then
  root=$(fixture wf-good)
  workflow "$root" "$good_workflow"
  expect 0 'valid workflow passes' check-workflows.sh "$root"

  root=$(fixture wf-bad)
  workflow "$root" "$bad_workflow"
  expect 1 'invalid workflow fails' check-workflows.sh "$root"
  output_has 'names the bad property' 'nope'
else
  echo 'SKIP  actionlint not installed; lint cases not run'
fi

echo "== check (aggregate) =="
expect 0 'valid fixture passes all steps' check.sh "$(fixture agg-ok)"
output_has 'prints a passing summary' 'All checks passed'

root=$(fixture agg-fail)
printf 'nope' >"$root/plugins/p/broken.json"
seq 1 60 >"$root/claude/CLAUDE.md"
expect 1 'any failing step fails the aggregate' check.sh "$root"
output_has 'summary lists json step' 'FAILED: json'
output_has 'summary lists skills step' 'FAILED: skills'

echo "== make check-fast (this repo) =="
# The fast tier the Stop hook runs: the six static steps, never tests or bench.
fast_recipe=$(make -C "$REPO" -n check-fast 2>&1)
for s in check-shell.sh check-json.sh check-structure.sh check-settings.sh check-skills.sh check-workflows.sh; do
  if grep -qF "scripts/$s" <<<"$fast_recipe"; then
    printf 'PASS  check-fast runs %s\n' "$s"
  else
    printf 'FAIL  check-fast runs %s\n%s\n' "$s" "$fast_recipe"
    failures=$((failures + 1))
  fi
done
for s in run-tests.sh check-bench.sh check.sh; do
  if grep -qF "scripts/$s" <<<"$fast_recipe"; then
    printf 'FAIL  check-fast does not run %s\n%s\n' "$s" "$fast_recipe"
    failures=$((failures + 1))
  else
    printf 'PASS  check-fast does not run %s\n' "$s"
  fi
done

echo "== check-shell, changed-files mode =="
# changed_fixture NAME: a fixture with one commit holding a script shellcheck
# rejects (old/bad.sh), and origin/main pointing at that commit.
changed_fixture() {
  local root
  root=$(fixture "$1")
  mkdir -p "$root/old"
  printf '#!/usr/bin/env bash\ncd somewhere\n' >"$root/old/bad.sh"
  git -C "$root" add -A
  git -C "$root" -c user.name=t -c user.email=t@example.com commit -q -m base
  git -C "$root" update-ref refs/remotes/origin/main HEAD
  printf '%s\n' "$root"
}

root=$(changed_fixture changed-only)
printf '#!/usr/bin/env bash\necho new\n' >"$root/new.sh"
CHECK_SHELL_CHANGED=1 expect 0 'changed mode lints only the changed script' check-shell.sh "$root"
output_has 'changed mode reports the changed script' 'ok    shellcheck new.sh'

root=$(changed_fixture changed-error)
printf '#!/usr/bin/env bash\ncd somewhere\n' >"$root/plugins/p/hooks/h.sh"
CHECK_SHELL_CHANGED=1 expect 1 'changed mode fails on a lint error in a changed script' check-shell.sh "$root"
output_has 'changed mode names the failing changed script' 'ERROR shellcheck plugins/p/hooks/h.sh'

root=$(changed_fixture changed-committed)
printf '#!/usr/bin/env bash\ncd somewhere\n' >"$root/branch.sh"
git -C "$root" add branch.sh
git -C "$root" -c user.name=t -c user.email=t@example.com commit -q -m branch
CHECK_SHELL_CHANGED=1 expect 1 'changed mode lints a script committed on the branch only' check-shell.sh "$root"
output_has 'changed mode names the committed script' 'ERROR shellcheck branch.sh'

echo "== git's local variables, as a hook exports them =="
# git_fixture NAME: a fixture with one commit and no remote, holding a test that
# builds its own repo and commits there, as the real suite's tests do.
git_fixture() {
  local root
  root=$(fixture "$1")
  mkdir -p "$root/scripts/tests"
  cat >"$root/scripts/tests/builds-own-repo.test.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q
git -C "$tmp" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m own
test "$(git -C "$tmp" rev-list --count HEAD)" = 1
EOF
  git -C "$root" add -A
  git -C "$root" -c user.name=t -c user.email=t@example.com commit -q -m base
  printf '%s\n' "$root"
}

# repo_state ROOT: every ref, HEAD and the number of commits.
repo_state() {
  git -C "$1" for-each-ref
  git -C "$1" rev-parse HEAD
  git -C "$1" rev-list --all --count
}

# state_kept LABEL ROOT BEFORE: assert ROOT's state still equals BEFORE.
state_kept() {
  local after
  after=$(repo_state "$2")
  if [[ $after == "$3" ]]; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s\nbefore:\n%s\nafter:\n%s\n' "$1" "$3" "$after"
    failures=$((failures + 1))
  fi
}

root=$(git_fixture vars-state)
before=$(repo_state "$root")
LAST_OUT=$(GIT_DIR="$root/.git" bash "$SCRIPTS/check.sh" "$root" 2>&1)
state_kept 'check.sh leaves the checked repo as it was under GIT_DIR' "$root" "$before"

root=$(git_fixture vars-healthy)
GIT_DIR="$root/.git" GIT_WORK_TREE="$root" expect 0 'a healthy tree still passes under the variables' check.sh "$root"
output_has 'the healthy tree prints a passing summary' 'All checks passed'

root=$(git_fixture vars-broken)
printf 'nope' >"$root/plugins/p/broken.json"
GIT_DIR="$root/.git" GIT_WORK_TREE="$root" expect 1 'a broken tree still fails under the variables' check.sh "$root"
output_has 'the broken tree names the failed step' 'FAILED: json'
if grep -q 'FAILED: tests' <<<"$LAST_OUT"; then
  printf 'FAIL  no test fails because of the variables\n%s\n' "$LAST_OUT"
  failures=$((failures + 1))
else
  printf 'PASS  no test fails because of the variables\n'
fi

root=$(git_fixture vars-step)
before=$(repo_state "$root")
GIT_DIR="$root/.git" expect 0 'run-tests.sh alone passes under GIT_DIR' run-tests.sh "$root"
state_kept 'run-tests.sh alone leaves the checked repo as it was under GIT_DIR' "$root" "$before"

root=$(git_fixture vars-index)
cat >"$root/scripts/tests/stages-in-own-repo.test.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git -C "$tmp" init -q
touch "$tmp/own-file"
git -C "$tmp" add own-file
EOF
before=$(git -C "$root" ls-files --stage)
GIT_INDEX_FILE="$root/.git/index" expect 0 'run-tests.sh passes under GIT_INDEX_FILE' run-tests.sh "$root"
after=$(git -C "$root" ls-files --stage)
if [[ $after == "$before" ]]; then
  printf 'PASS  the checked repo index is untouched under GIT_INDEX_FILE\n'
else
  printf 'FAIL  the checked repo index is untouched under GIT_INDEX_FILE\n%s\n' "$after"
  failures=$((failures + 1))
fi

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
