#!/usr/bin/env bash
# Worker benchmark: local models solve coding tasks through pi inside pi-box;
# hidden checks the model never sees decide the result.
#
# Usage: bench/worker/run.sh [MODEL...]   (default: gpt-oss:20b qwen3-coder:30b)
#   Resumable: finished tasks are skipped, so after a suspend or Ctrl+C just
#   run it again. Delete ~/.local/state/worker-bench to start over.
#   Env: WORKER_BENCH_DIR (results), WORKER_BENCH_TIMEOUT (seconds per task),
#        WORKER_BENCH_TASKS (glob on task names, e.g. "1[12]-*").
#
# Per task: a fresh repo built from the task's `source` (see lib.sh; checks,
# reference patches and metadata never reach it), pi gets prompt.md, then the
# runner records:
#   hidden  the task's check.sh passes
#   gate    the task's gate passes (`make check` for this repo's own tasks)
#   scope   only the files in `allowed` changed
# plus lang, level, time and changed lines. Results and diffs:
# ~/.local/state/worker-bench. Validate the tasks without a model:
# bench/worker/validate.sh.
set -u

# Keep the machine awake for the whole run (released when it ends); a suspend
# would stall the model mid-task. Set WORKER_BENCH_ALLOW_SLEEP=1 to skip.
if [[ -z ${WORKER_BENCH_INHIBITED:-} && ${WORKER_BENCH_ALLOW_SLEEP:-} != 1 ]] && command -v systemd-inhibit >/dev/null; then
  WORKER_BENCH_INHIBITED=1 exec systemd-inhibit --what=sleep:idle --who=worker-bench \
    --why="local model benchmark running" "$0" "$@"
fi

# shellcheck source=bench/worker/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
OUT=${WORKER_BENCH_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/worker-bench}
TIMEOUT=${WORKER_BENCH_TIMEOUT:-1200}
# Variants (kept in separate result dirs so runs stay comparable):
#   WORKER_BENCH_ATTEMPTS=N  retry up to N times, feeding back the gate output
#   WORKER_BENCH_FORMAT=1    shfmt the changed shell files after each attempt
ATTEMPTS=${WORKER_BENCH_ATTEMPTS:-1}
FORMAT=${WORKER_BENCH_FORMAT:-0}
#   WORKER_BENCH_CHEATSHEETS=1  append the delegate-local cheat sheets (common + task language)
CHEATSHEETS=${WORKER_BENCH_CHEATSHEETS:-0}
CHEATSHEET_DIR="$REPO/plugins/toolkit/skills/delegate-local/cheatsheets"
VARIANT=""
((ATTEMPTS > 1)) && VARIANT+="+fb$ATTEMPTS"
((FORMAT)) && VARIANT+="+fmt"
((CHEATSHEETS)) && VARIANT+="+cs"
models=("$@")
((${#models[@]})) || models=(gpt-oss:20b qwen3-coder:30b)

for tool in pi-box pi ollama jq git make; do
  command -v "$tool" >/dev/null || {
    echo "missing: $tool" >&2
    exit 1
  }
done

# secs: monotonic seconds. Wall-clock time keeps running while the laptop is
# suspended (and timeout(1) does not), which once turned 5 minutes into 31.
secs() { python3 -c 'import time; print(int(time.monotonic()))'; }

for model in "${models[@]}"; do
  # One model on the GPU at a time, so timings are comparable.
  ollama ps 2>/dev/null | awk 'NR > 1 {print $1}' | while read -r loaded; do
    [[ $loaded == "$model" ]] || ollama stop "$loaded" >/dev/null 2>&1
  done
  for task_dir in "$BENCH"/tasks/*/; do
    task_dir=${task_dir%/}
    task=$(basename "$task_dir")
    # shellcheck disable=SC2053 # WORKER_BENCH_TASKS is a glob on purpose.
    [[ -z ${WORKER_BENCH_TASKS:-} || $task == $WORKER_BENCH_TASKS ]] || continue
    dir="$OUT/${model//[:\/]/_}$VARIANT/$task"
    if [[ -f $dir/result.json ]]; then
      echo "== $model / $task: done, skipping"
      continue
    fi
    echo "== $model / $task"
    rm -rf "$dir" && mkdir -p "$dir"
    if ! base=$(build_repo "$task_dir" "$dir/repo" 2>"$dir/setup.log"); then
      echo "   setup failed, see $dir/setup.log" >&2
      continue
    fi

    prompt=$(<"$task_dir/prompt.md")
    # Passed as text: files outside the project are invisible inside pi-box.
    extra=()
    if ((CHEATSHEETS)); then
      sheet=$(<"$CHEATSHEET_DIR/common.md")
      lang_sheet="$CHEATSHEET_DIR/$(meta "$task_dir" lang).md"
      [[ -f $lang_sheet ]] && sheet+=$'\n\n'$(<"$lang_sheet")
      extra=(--append-system-prompt "$sheet")
    fi
    attempt=0
    start=$(secs)
    while :; do
      attempt=$((attempt + 1))
      echo "--- attempt $attempt" >>"$dir/pi.log"
      (cd "$dir/repo" && timeout "$TIMEOUT" pi-box --provider ollama --model "$model" --no-session \
        "${extra[@]}" -p "$prompt") >>"$dir/pi.log" 2>&1
      worker_exit=$?
      ((FORMAT)) && format_changed "$dir/repo" "$base"
      ((attempt < ATTEMPTS)) || break
      # Feedback uses only the project's visible gate, never the hidden check.
      run_gate "$task_dir" "$dir/repo" "$dir/feedback$attempt.log" && break
      prompt="$(<"$task_dir/prompt.md")

Your previous attempt is already in this repository, but the project check still fails.
Output of \`$(gate_cmd "$task_dir")\` (last 60 lines):
$(tail -n 60 "$dir/feedback$attempt.log")

Fix the cause, stay within the files named above, and make that check pass."
    done
    seconds=$(($(secs) - start))

    mapfile -t changed < <(changed_files "$dir/repo" "$base")
    git -C "$dir/repo" diff --cached "$base" >"$dir/diff.patch"
    lines=$(git -C "$dir/repo" diff --cached --numstat "$base" | awk '{n += $1 + $2} END {print n + 0}')
    in_scope "$task_dir" "${changed[@]}" && scope=true || scope=false
    run_check "$task_dir" "$dir/repo" "$dir/hidden.log" && hidden=true || hidden=false
    run_gate "$task_dir" "$dir/repo" "$dir/gate.log" && gate=true || gate=false

    jq -n --arg model "$model" --arg task "$task" --arg lang "$(meta "$task_dir" lang)" \
      --arg level "$(meta "$task_dir" level)" --arg source "$(meta "$task_dir" source self)" \
      --argjson seconds "$seconds" --argjson worker_exit "$worker_exit" --argjson hidden "$hidden" \
      --argjson gate "$gate" --argjson scope "$scope" --argjson lines "$lines" \
      --argjson files "$(printf '%s\n' "${changed[@]}" | jq -R . | jq -sc 'map(select(length > 0))')" \
      --arg variant "$VARIANT" --argjson attempts "$attempt" \
      '{model: ($model + $variant), variant: $variant, attempts: $attempts, task: $task, lang: $lang, level: $level, source: $source,
        seconds: $seconds, worker_exit: $worker_exit, hidden: $hidden, gate: $gate,
        scope: $scope, lines: $lines, files: $files}' >"$dir/result.json"
    jq -r '"   hidden=\(.hidden) gate=\(.gate) scope=\(.scope) lines=\(.lines) \(.seconds)s"' "$dir/result.json"
    rm -rf "$dir/repo" "$dir/repo.cache"
  done
done

results=("$OUT"/*/*/result.json)
[[ -f ${results[0]} ]] || exit 0
echo
echo "== summary (pass = hidden + gate + scope; cells: passed/run)"
# Older results have `make` instead of `gate` and no lang/level: take those
# from the task's metadata.
meta_json=$(for d in "$BENCH"/tasks/*/; do
  d=${d%/}
  jq -n --arg t "${d##*/}" --arg lang "$(meta "$d" lang '?')" --arg level "$(meta "$d" level '?')" \
    '{($t): {lang: $lang, level: $level}}'
done | jq -s 'add // {}')
jq -s -r --argjson meta "$meta_json" '
  map(.gate //= .make | .lang //= ($meta[.task].lang // "?") | .level //= ($meta[.task].level // "?")) |
  (map(.level) | unique) as $levels |
  group_by(.model)[] |
  (map(.lang) | unique) as $langs | . as $rs |
  "\n\(.[0].model): \(map(select(.hidden and .gate and .scope)) | length)/\(length) pass, " +
    "avg \((map(.seconds) | add / length) | floor)s, avg \((map(.lines) | add / length) | floor) lines",
  (["lang"] + $levels + ["avg s"] | map(.[:10] | . + (" " * (11 - length))) | join("")),
  ($langs[] as $l | [$l] +
    ($levels | map(. as $v | $rs | map(select(.lang == $l and .level == $v)) |
      if length == 0 then "-" else "\(map(select(.hidden and .gate and .scope)) | length)/\(length)" end)) +
    [$rs | map(select(.lang == $l)) | (map(.seconds) | add / length) | floor | tostring] |
    map(.[:10] | . + (" " * (11 - length))) | join(""))
' "${results[@]}"
