#!/usr/bin/env bash
# Shared helpers for bench/worker/run.sh and validate.sh. Source it; do not
# execute it. Builds a task's repo exactly the same way for both, so a task
# validated here behaves the same when a model runs it.
#
# Task metadata (one line each, in the task dir):
#   lang    bash, lua, qml, python, typescript, go, rust or c
#   level   L1 (one function/option), L2 (feature, 2-3 files), L3 (bug)
#   source  absent or "self": this repo at BASE, without bench/
#           "fixture": the task's fixture/ dir is the whole project
#           "<abs repo path> <commit>": that repo at that commit
#   gate    shell command run in the repo root after the worker
#           (default: `make check` for self, nothing otherwise); $BENCH
#           points at bench/worker, for shared gate scripts

# A git hook can export GIT_DIR and friends, and they outrank `git -C`: every
# command below would then rewrite the repo being checked, not the task's repo.
mapfile -t git_local_vars < <(git rev-parse --local-env-vars)
unset "${git_local_vars[@]}"

BENCH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$BENCH/../.." && pwd)
BASE=$(<"$BENCH/BASE")

# meta TASK_DIR NAME [DEFAULT]: first line of a metadata file, or DEFAULT.
meta() {
  local line
  if [[ -f $1/$2 ]]; then
    IFS= read -r line <"$1/$2"
    printf '%s' "$line"
  else
    printf '%s' "${3:-}"
  fi
}

# gate_cmd TASK_DIR: the task's gate command (may be empty).
gate_cmd() {
  local default=""
  [[ $(meta "$1" source self) == self ]] && default="make check"
  meta "$1" gate "$default"
}

git_bench() {
  git -c user.name=bench -c user.email=bench@local -c core.hooksPath=/dev/null \
    -c commit.gpgsign=false "$@"
}

# clone_at SRC COMMIT DEST: clone SRC and keep only the history up to COMMIT,
# so later commits (and anything they reveal) are not reachable in DEST.
clone_at() {
  local src=$1 commit=$2 dest=$3 ref
  git clone -q --no-hardlinks --no-checkout "$src" "$dest" || return 1
  git -C "$dest" checkout -q -B bench "$commit" || return 1
  git -C "$dest" remote remove origin
  while IFS= read -r ref; do
    [[ $ref == refs/heads/bench ]] || git -C "$dest" update-ref -d "$ref"
  done < <(git -C "$dest" for-each-ref --format='%(refname)')
  git -C "$dest" reflog expire --expire=now --all
  git -C "$dest" gc -q --prune=now
}

# build_repo TASK_DIR DEST: create the task's repo at DEST with everything
# committed; prints the base commit the worker's diff is measured against.
build_repo() {
  local task_dir=$1 dest=$2 source path commit
  source=$(meta "$task_dir" source self)
  case $source in
    self)
      clone_at "$REPO" "$BASE" "$dest" || return 1
      rm -rf "$dest/bench"
      git_bench -C "$dest" commit -q -am "bench: hide checks" >/dev/null 2>&1
      ;;
    fixture)
      [[ -d $task_dir/fixture ]] || return 1
      mkdir -p "$dest" && cp -a "$task_dir/fixture/." "$dest/" || return 1
      git -C "$dest" init -q -b main &&
        git -C "$dest" add -A &&
        git_bench -C "$dest" commit -q -m "initial commit" || return 1
      ;;
    /*)
      read -r path commit <<<"$source"
      [[ -n $commit ]] || return 1
      clone_at "$path" "$commit" "$dest" || return 1
      ;;
    *) return 1 ;;
  esac
  git -C "$dest" rev-parse HEAD
}

# changed_files REPO BASE_COMMIT: every path that differs from BASE_COMMIT,
# committed or not (stages everything, so untracked files count too).
changed_files() {
  git -C "$1" add -A
  git -C "$1" diff --cached --name-only "$2"
}

# in_scope TASK_DIR FILE...: true when every FILE is listed in `allowed`.
in_scope() {
  local task_dir=$1 f a ok
  shift
  local allowed=()
  mapfile -t allowed <"$task_dir/allowed"
  for f in "$@"; do
    ok=false
    for a in "${allowed[@]}"; do [[ $f == "$a" ]] && ok=true && break; done
    $ok || return 1
  done
}

# run_check TASK_DIR REPO LOG / run_gate TASK_DIR REPO LOG: true on pass.
# Build caches go to a per-task dir so neither the repo nor $HOME fills up.
tool_env() {
  local cache=$1
  export GOCACHE=$cache/go-cache GOPROXY=off GOTOOLCHAIN=local \
    CARGO_TARGET_DIR=$cache/cargo-target PYTHONDONTWRITEBYTECODE=1 DENO_DIR=$cache/deno
}
run_check() {
  (cd "$2" && tool_env "$2.cache" && timeout 600 bash "$1/check.sh") </dev/null >"$3" 2>&1
}
run_gate() {
  local gate
  gate=$(gate_cmd "$1")
  [[ -z $gate ]] && return 0
  (cd "$2" && tool_env "$2.cache" && BENCH=$BENCH timeout 900 bash -c "$gate") </dev/null >"$3" 2>&1
}

# format_changed REPO BASE: shfmt the shell files the worker changed. Format is
# the harness's job, not the model's (one run failed on formatting alone).
format_changed() {
  command -v shfmt >/dev/null || return 0
  local f
  while IFS= read -r f; do
    [[ -f $1/$f ]] || continue
    if [[ $f == *.sh ]] || head -n1 "$1/$f" | rg -q '^#!.*\b(ba)?sh\b'; then
      shfmt -w -i 2 -ci "$1/$f" 2>/dev/null || true
    fi
  done < <(changed_files "$1" "$2")
}
