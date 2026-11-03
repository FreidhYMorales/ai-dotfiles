#!/usr/bin/env bash
# Behaviour tests for git-hooks/_dispatch, the global hook dispatcher: real
# `git commit` calls in throwaway repos whose core.hooksPath points at this
# repo's git-hooks/. Run: bash scripts/tests/gitleaks-hook.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS="$ROOT/git-hooks"
failures=0

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
# Keep the host's global git config (and its own hooksPath) out of the tests.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset SKIP_GITLEAKS

# A GitHub token gitleaks detects, built at runtime so this file holds no secret.
FAKE_SECRET="gh""p_$(printf 'aZ3kQ9vL2mX7pR4tW8yB1nC6dF0gH5jK2sE9')"

pass() { echo "PASS  $1"; }
fail() {
  echo "FAIL  $1"
  [[ -n ${2:-} ]] && printf '%s\n' "$2" | while IFS= read -r line; do echo "      $line"; done
  failures=$((failures + 1))
}

# new_repo NAME: a repo using the dispatcher, with one initial commit.
new_repo() {
  local repo="$TMP_ROOT/$1"
  git init -q "$repo"
  git -C "$repo" config user.name test
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config core.hooksPath "$HOOKS"
  printf 'hello\n' >"$repo/README"
  git -C "$repo" add README
  SKIP_GITLEAKS=1 git -C "$repo" commit -q -m init
  printf '%s\n' "$repo"
}

# try_commit REPO [ENV...]: commit what is staged; sets LAST_EXIT, LAST_OUTPUT.
LAST_OUTPUT=""
LAST_EXIT=0
try_commit() {
  local repo=$1
  shift
  LAST_OUTPUT=$(cd "$repo" && env "$@" git commit -q -m change 2>&1)
  LAST_EXIT=$?
}

commit_count() { git -C "$1" rev-list --count HEAD; }

if command -v gitleaks >/dev/null 2>&1; then
  echo "== gitleaks block =="
  repo=$(new_repo block)
  printf 'token = "%s"\n' "$FAKE_SECRET" >"$repo/config.ini"
  git -C "$repo" add config.ini
  try_commit "$repo"
  if [[ $LAST_EXIT -ne 0 && $LAST_OUTPUT == *"Commit blocked"* && $(commit_count "$repo") == 1 ]]; then
    pass 'a staged secret blocks the commit'
  else
    fail 'a staged secret blocks the commit' "exit=$LAST_EXIT commits=$(commit_count "$repo")
$LAST_OUTPUT"
  fi
else
  echo "SKIP  gitleaks not installed; block, bypass and chaining tests not run"
fi

[[ $failures -eq 0 ]] || {
  echo "$failures failure(s)"
  exit 1
}
echo "all passed"
