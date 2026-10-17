#!/usr/bin/env bash
# Worker benchmark: local models solve real tasks from this repo through pi
# inside pi-box; hidden checks the model never sees decide the result.
#
# Usage: bench/worker/run.sh [MODEL...]   (default: gpt-oss:20b qwen3-coder:30b)
#   Resumable: finished tasks are skipped, so after a suspend or Ctrl+C just
#   run it again. Delete ~/.local/state/worker-bench to start over.
#
# Per task: fresh clone at the pinned BASE commit without bench/ (the model
# cannot read the checks), pi gets prompt.md, then the runner records:
#   hidden  the task's check.sh passes
#   make    `make check` passes (lint, format, every test)
#   scope   only the files in `allowed` changed
# plus time and changed lines. Results and diffs: ~/.local/state/worker-bench.
set -u

BENCH=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$BENCH/../.." && pwd)
BASE=$(<"$BENCH/BASE")
OUT=${WORKER_BENCH_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/worker-bench}
TIMEOUT=${WORKER_BENCH_TIMEOUT:-1200}
models=("$@")
((${#models[@]})) || models=(gpt-oss:20b qwen3-coder:30b)

for tool in pi-box pi ollama jq git make; do
  command -v "$tool" >/dev/null || {
    echo "missing: $tool" >&2
    exit 1
  }
done

secs() {
  local t=${EPOCHREALTIME/./}
  echo $((t / 1000000))
}

for model in "${models[@]}"; do
  # One model on the GPU at a time, so timings are comparable.
  ollama ps 2>/dev/null | awk 'NR > 1 {print $1}' | while read -r loaded; do
    [[ $loaded == "$model" ]] || ollama stop "$loaded" >/dev/null 2>&1
  done
  for task_dir in "$BENCH"/tasks/*/; do
    task=$(basename "$task_dir")
    dir="$OUT/${model//[:\/]/_}/$task"
    if [[ -f $dir/result.json ]]; then
      echo "== $model / $task: done, skipping"
      continue
    fi
    echo "== $model / $task"
    rm -rf "$dir" && mkdir -p "$dir"
    git clone -q --no-hardlinks "$REPO" "$dir/repo" && git -C "$dir/repo" checkout -q "$BASE"
    rm -rf "$dir/repo/bench"
    git -C "$dir/repo" -c user.name=bench -c user.email=bench@local -c core.hooksPath=/dev/null \
      commit -q -am "bench: hide checks" >/dev/null 2>&1

    start=$(secs)
    (cd "$dir/repo" && timeout "$TIMEOUT" pi-box --provider ollama --model "$model" --no-session \
      -p "$(<"$task_dir/prompt.md")") >"$dir/pi.log" 2>&1
    worker_exit=$?
    seconds=$(($(secs) - start))

    git -C "$dir/repo" add -A
    git -C "$dir/repo" diff --cached >"$dir/diff.patch"
    mapfile -t changed < <(git -C "$dir/repo" diff --cached --name-only)
    lines=$(git -C "$dir/repo" diff --cached --numstat | awk '{n += $1 + $2} END {print n + 0}')
    scope=true
    for f in "${changed[@]}"; do
      rg -qxF "$f" "$task_dir/allowed" || scope=false
    done
    (cd "$dir/repo" && bash "$task_dir/check.sh") >"$dir/hidden.log" 2>&1 && hidden=true || hidden=false
    (cd "$dir/repo" && make check) >"$dir/make.log" 2>&1 && make_ok=true || make_ok=false

    jq -n --arg model "$model" --arg task "$task" --argjson seconds "$seconds" \
      --argjson worker_exit "$worker_exit" --argjson hidden "$hidden" --argjson make "$make_ok" \
      --argjson scope "$scope" --argjson lines "$lines" \
      --argjson files "$(printf '%s\n' "${changed[@]}" | jq -R . | jq -sc 'map(select(length > 0))')" \
      '{model: $model, task: $task, seconds: $seconds, worker_exit: $worker_exit, hidden: $hidden,
        make: $make, scope: $scope, lines: $lines, files: $files}' >"$dir/result.json"
    jq -r '"   hidden=\(.hidden) make=\(.make) scope=\(.scope) lines=\(.lines) \(.seconds)s"' "$dir/result.json"
    rm -rf "$dir/repo"
  done
done

echo
echo "== summary (pass = hidden + make + scope)"
fd -g result.json "$OUT" -x bat -p {} 2>/dev/null | jq -s -r '
  group_by(.model)[] |
  "\(.[0].model): \(map(select(.hidden and .make and .scope)) | length)/\(length) pass, " +
  "hidden \(map(select(.hidden)) | length), make \(map(select(.make)) | length), " +
  "scope \(map(select(.scope)) | length), avg \((map(.seconds) | add / length) | floor)s, " +
  "avg \((map(.lines) | add / length) | floor) lines"'
