#!/usr/bin/env bash
# Tests for bin/pi-box: try to escape the sandbox and check that every attempt
# fails. Run: bash scripts/tests/pi-box.test.sh
# Box commands are single-quoted on purpose: $HOME and friends must expand
# inside the sandbox, not here.
# shellcheck disable=SC2016
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/pi-box"
failures=0

if ! command -v bwrap >/dev/null 2>&1 || ! bwrap --ro-bind / / true 2>/dev/null; then
  echo "SKIP  bubblewrap unavailable (or user namespaces disabled); pi-box tests not run"
  exit 0
fi

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# A fake HOME with secrets next to the project, and a pi install to protect.
home="$TMP_ROOT/home"
project="$home/work/proj"
mkdir -p "$home/.ssh" "$home/.config/gh" "$home/.pi/agent" "$project/src" "$home/work/other"
printf 'PRIVATE KEY\n' >"$home/.ssh/id_test"
printf 'oauth_token: gho_x\n' >"$home/.config/gh/hosts.yml"
printf '{}\n' >"$home/.pi/agent/models.json"
printf 'neighbour\n' >"$home/work/other/notes.txt"
git -C "$project" init -q

# box DIR CMD: run CMD (a bash -c string) through pi-box from DIR.
LAST_OUTPUT=""
LAST_EXIT=0
box() {
  local dir=$1
  shift
  LAST_OUTPUT=$(cd "$dir" && env -u XDG_STATE_HOME HOME="$home" PI_BOX_NETWORK="${PI_BOX_NETWORK:-host}" bash "$SCRIPT" -- bash -c "$1" 2>&1)
  LAST_EXIT=$?
}

# assert LABEL CONDITION...: run a test command and record PASS/FAIL.
assert() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    failures=$((failures + 1))
  fi
}

says() { [[ $LAST_OUTPUT == *"$1"* ]]; }
lacks() { [[ $LAST_OUTPUT != *"$1"* ]]; }

echo "== the project is writable =="

box "$project" 'echo ok >src/new.txt && pwd'
assert 'writes inside the project succeed' test -f "$project/src/new.txt"
assert 'the sandbox starts in the same directory' says "$project"

box "$project/src" 'echo ok >../from-subdir.txt'
assert 'a subdirectory opens the whole git project' test -f "$project/from-subdir.txt"

echo "== escapes fail =="

box "$project" 'echo pwned >"$HOME/escaped.txt"; echo pwned >../../escaped.txt; true'
assert 'writes to HOME never reach the host' test ! -e "$home/escaped.txt"
assert 'writes next to the project never reach the host' test ! -e "$home/work/escaped.txt"

box "$project" 'cat "$HOME/.ssh/id_test" "$HOME/.config/gh/hosts.yml" ../other/notes.txt 2>&1; true'
assert 'ssh keys are invisible' lacks 'PRIVATE KEY'
assert 'the GitHub token is invisible' lacks 'gho_x'
assert 'sibling projects are invisible' lacks 'neighbour'

box "$project" 'echo tampered >"$HOME/.pi/agent/models.json"; true'
assert 'pi config changes never reach the host' test "$(cat "$home/.pi/agent/models.json")" == '{}'
box "$project" 'cat "$HOME/.pi/agent/models.json"'
assert 'the pi config is readable' says '{}'

box "$project" 'echo x >/tmp/box-tmp-probe; ls /tmp'
assert '/tmp is private to the sandbox' test ! -e /tmp/box-tmp-probe

box "$project" 'echo x >/usr/box-probe 2>&1; echo "exit=$?"'
assert 'the system is read-only' says 'exit=1'

echo "== git metadata cannot be planted =="

# delegate-local runs git on the host inside the worker clone, so a config key
# like core.fsmonitor or a hook written from the box would run unsandboxed.
box "$project" 'git config core.fsmonitor "touch /tmp/pwned"; true'
assert 'git config changes never reach the host' \
  test -z "$(git -C "$project" config --get core.fsmonitor)"
box "$project" 'printf "#!/bin/sh\necho pwned\n" >.git/hooks/pre-commit; true'
assert 'git hooks cannot be added' test ! -e "$project/.git/hooks/pre-commit"
box "$project" 'mv .git .git-old && mkdir .git; true'
assert 'the git dir cannot be swapped' test ! -e "$project/.git-old"

# A core.hooksPath inside the project (the dotfiles repo sets its git-hooks/
# globally) would let the box plant a hook every host repo runs.
mkdir -p "$project/git-hooks"
GIT_CONFIG_GLOBAL="$TMP_ROOT/hooks.gitconfig"
git config --global core.hooksPath "$project/git-hooks"
box "$project/src" 'printf "#!/bin/sh\necho pwned\n" >../git-hooks/pre-commit; true'
GIT_CONFIG_GLOBAL=/dev/null
assert 'a hooksPath inside the project cannot be written' \
  test ! -e "$project/git-hooks/pre-commit"

# A hooksPath inside the project that does not exist yet could be created
# from the box, so pi-box refuses to open the project.
GIT_CONFIG_GLOBAL="$TMP_ROOT/missing-hooks.gitconfig"
git config --global core.hooksPath "$project/new-hooks"
box "$project" 'mkdir new-hooks && printf "#!/bin/sh\necho pwned\n" >new-hooks/pre-commit; true'
GIT_CONFIG_GLOBAL=/dev/null
assert 'a missing hooksPath inside the project is refused' test "$LAST_EXIT" -ne 0
assert 'the missing hooksPath refusal explains why' says 'refusing'
assert 'a missing hooksPath is never created' test ! -e "$project/new-hooks"

# A nested hooksPath: renaming its parent and rebuilding it must fail too.
mkdir -p "$project/tools/hooks"
GIT_CONFIG_GLOBAL="$TMP_ROOT/nested-hooks.gitconfig"
git config --global core.hooksPath "$project/tools/hooks"
box "$project" 'mv tools tools.old && mkdir -p tools/hooks && printf "#!/bin/sh\necho pwned\n" >tools/hooks/pre-commit; true'
GIT_CONFIG_GLOBAL=/dev/null
assert 'a nested hooksPath cannot be rebuilt' test ! -e "$project/tools/hooks/pre-commit"
assert 'the parent of a nested hooksPath cannot be moved' test ! -e "$project/tools.old"

# A global git config symlinked into the project (a dotfiles repo) runs in
# every host repo: both ~/.gitconfig and the XDG location stay read-only.
mkdir -p "$project/conf" "$home/.config/git"
printf '[user]\n\tname = t\n' >"$project/conf/gitconfig"
printf '[user]\n\tname = t\n' >"$project/conf/xdg-config"
ln -s "$project/conf/gitconfig" "$home/.gitconfig"
ln -s "$project/conf/xdg-config" "$home/.config/git/config"
saved_xdg_config=${XDG_CONFIG_HOME-}
unset GIT_CONFIG_GLOBAL XDG_CONFIG_HOME
box "$project" 'printf "[core]\n\tfsmonitor = x\n" >>conf/gitconfig; printf "[core]\n\tfsmonitor = x\n" >>conf/xdg-config; true'
export GIT_CONFIG_GLOBAL=/dev/null
[[ -n $saved_xdg_config ]] && export XDG_CONFIG_HOME=$saved_xdg_config
rm "$home/.gitconfig" "$home/.config/git/config"
assert 'a ~/.gitconfig inside the project cannot be written' \
  test "$(cat "$project/conf/gitconfig")" == $'[user]\n\tname = t'
assert 'an XDG git config inside the project cannot be written' \
  test "$(cat "$project/conf/xdg-config")" == $'[user]\n\tname = t'

# A .git file pointing to a git dir inside the project (bare + worktree
# layout): that git dir's config must stay read-only, also when a hooksPath
# elsewhere means the hooks check never looks at it.
bareproj="$home/work/bareproj"
mkdir -p "$bareproj" "$TMP_ROOT/elsewhere-hooks"
git init -q --bare "$bareproj/.bare"
printf 'gitdir: ./.bare\n' >"$bareproj/.git"
GIT_CONFIG_GLOBAL="$TMP_ROOT/elsewhere.gitconfig"
git config --global core.hooksPath "$TMP_ROOT/elsewhere-hooks"
box "$bareproj" 'git config core.fsmonitor "touch /tmp/pwned"; true'
GIT_CONFIG_GLOBAL=/dev/null
assert 'a git dir behind a .git file cannot be configured' \
  test -z "$(git -C "$bareproj" config --get core.fsmonitor)"

# The worker flow still works: edits made in the box show up in host git.
printf 'old\n' >"$project/tracked.txt"
git -C "$project" add tracked.txt
git -C "$project" -c user.name=t -c user.email=t@t commit -qm init
box "$project" 'printf "new\n" >tracked.txt && printf "x\n" >added.txt'
assert 'host git status shows box edits' \
  test "$(git -C "$project" status --short -- tracked.txt added.txt)" == $' M tracked.txt\n?? added.txt'
assert 'host git diff shows the box change' \
  test "$(git -C "$project" diff -- tracked.txt | tail -2)" == $'-old\n+new'

echo "== pi state =="

box "$project" 'echo "$PI_CODING_AGENT_SESSION_DIR"; echo s >"$PI_CODING_AGENT_SESSION_DIR/s.jsonl"'
assert 'sessions go to a writable pi-box state dir' \
  test -f "$home/.local/state/pi-box/sessions/s.jsonl"

echo "== outside git =="

plain="$home/plain"
mkdir -p "$plain"
box "$plain" 'echo ok >here.txt'
assert 'outside git the current folder is the project' test -f "$plain/here.txt"

echo "== network: only ollama is reachable =="

if command -v socat >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  # Two host services: a fake ollama (must be reachable) and any other local
  # service (must not be), each serving a marker file.
  www="$TMP_ROOT/www"
  mkdir -p "$www"
  printf 'from-ollama\n' >"$www/ollama.txt"
  printf 'from-other\n' >"$www/other.txt"
  free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
  ollama_port=$(free_port)
  other_port=$(free_port)
  python3 -m http.server "$ollama_port" --bind 127.0.0.1 --directory "$www" >/dev/null 2>&1 &
  ollama_pid=$!
  python3 -m http.server "$other_port" --bind 127.0.0.1 --directory "$www" >/dev/null 2>&1 &
  other_pid=$!
  for _ in $(seq 50); do
    curl -s "http://127.0.0.1:$other_port/other.txt" >/dev/null && curl -s "http://127.0.0.1:$ollama_port/ollama.txt" >/dev/null && break
    sleep 0.1
  done

  netbox() {
    LAST_OUTPUT=$(cd "$project" && env -u XDG_STATE_HOME HOME="$home" PI_BOX_OLLAMA="127.0.0.1:$ollama_port" "$@" \
      bash "$SCRIPT" -- bash -c "curl -s --max-time 3 http://127.0.0.1:11434/ollama.txt; curl -s --max-time 3 http://127.0.0.1:$other_port/other.txt; echo end" 2>&1)
  }

  netbox
  assert 'ollama is reachable inside as 127.0.0.1:11434' says 'from-ollama'
  assert 'other host services are unreachable' lacks 'from-other'
  netbox PI_BOX_NETWORK=host
  assert 'PI_BOX_NETWORK=host shares the host network' says 'from-other'
  assert 'no bridge socket is left behind' test -z "$(find "$home/.local/state/pi-box" -name '*.sock' 2>/dev/null)"

  # DNS is a data channel too: the host resolver must not be reachable.
  LAST_OUTPUT=$(cd "$project" && env -u XDG_STATE_HOME HOME="$home" PI_BOX_OLLAMA="127.0.0.1:$ollama_port" \
    bash "$SCRIPT" -- bash -c 'getent hosts github.com || echo no-dns' 2>&1)
  assert 'the host DNS resolver is unreachable' says 'no-dns'
  assert 'the bridge exits quietly' lacks 'exiting on signal'

  kill "$ollama_pid" "$other_pid" 2>/dev/null
else
  echo 'SKIP  socat or python3 missing; network cases not run'
fi

echo "== refuses projects that would expose HOME =="

box "$home" 'echo pwned >"$HOME/.ssh/id_test"; true'
assert 'running from HOME is refused' test "$LAST_EXIT" -ne 0
assert 'the refusal explains why' says 'refusing'
assert 'nothing in HOME was touched' test "$(cat "$home/.ssh/id_test")" == 'PRIVATE KEY'

box / 'true'
assert 'running from / is refused' test "$LAST_EXIT" -ne 0

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
