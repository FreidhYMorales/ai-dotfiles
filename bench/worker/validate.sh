#!/usr/bin/env bash
# Validate benchmark tasks without any model: a task is only useful when its
# hidden check fails on the untouched repo and passes with a correct solution.
#
# Usage: bench/worker/validate.sh [TASK...]   (default: every task)
# Per task, on a repo built exactly as run.sh builds it:
#   base   check.sh must FAIL on the untouched repo
#   apply  reference.patch must apply
#   check  check.sh must pass with the patch
#   gate   the gate must pass with the patch
#   scope  every file the patch touches must be listed in `allowed`
# Prints one line per task; exits 1 when any task fails. A task whose source
# repo is not on this machine is skipped, not failed. KEEP=1 keeps the work dir
# for inspection.
set -u

# shellcheck source=bench/worker/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

tasks=("$@")
if ((${#tasks[@]} == 0)); then
  for d in "$BENCH"/tasks/*/; do
    d=${d%/}
    tasks+=("${d##*/}")
  done
fi

work=$(mktemp -d)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$work"' EXIT

# fail TASK STEP LOG: report a failed step with the end of its log.
fail() {
  printf 'FAIL  %-34s %s\n' "$1" "$2"
  [[ -f ${3:-} ]] && tail -n 15 "$3" | sed 's/^/      | /'
  failed=$((failed + 1))
}

failed=0
skipped=0
for task in "${tasks[@]}"; do
  task_dir=$BENCH/tasks/${task%/}
  task=${task_dir##*/}
  repo=$work/$task/repo
  logs=$work/$task
  mkdir -p "$logs"
  for f in prompt.md check.sh allowed lang level reference.patch; do
    [[ -f $task_dir/$f ]] || {
      fail "$task" "missing $f"
      continue 2
    }
  done
  # A task built from another repo can only run where that repo lives.
  source_repo=$(meta "$task_dir" source self)
  source_repo=${source_repo%% *}
  if [[ $source_repo == /* && ! -d $source_repo ]]; then
    printf 'SKIP  %-34s source repo not on this machine: %s\n' "$task" "$source_repo"
    skipped=$((skipped + 1))
    continue
  fi
  if ! base=$(build_repo "$task_dir" "$repo" 2>"$logs/setup.log"); then
    fail "$task" "setup" "$logs/setup.log"
    continue
  fi
  if run_check "$task_dir" "$repo" "$logs/base.log"; then
    fail "$task" "base: check passes without any change" "$logs/base.log"
    continue
  fi
  if ! git -C "$repo" apply --whitespace=nowarn "$task_dir/reference.patch" 2>"$logs/apply.log"; then
    fail "$task" "apply: reference.patch does not apply" "$logs/apply.log"
    continue
  fi
  mapfile -t changed < <(changed_files "$repo" "$base")
  if ! in_scope "$task_dir" "${changed[@]}"; then
    printf '%s\n' "${changed[@]}" >"$logs/scope.log"
    fail "$task" "scope: patch touches files outside allowed" "$logs/scope.log"
    continue
  fi
  if ! run_check "$task_dir" "$repo" "$logs/check.log"; then
    fail "$task" "check: fails with reference.patch" "$logs/check.log"
    continue
  fi
  if ! run_gate "$task_dir" "$repo" "$logs/gate.log"; then
    fail "$task" "gate: '$(gate_cmd "$task_dir")' fails with reference.patch" "$logs/gate.log"
    continue
  fi
  src=$(meta "$task_dir" source self)
  src=${src%% *}
  printf 'ok    %-34s %-10s %s %s\n' "$task" "$(meta "$task_dir" lang)" "$(meta "$task_dir" level)" "${src##*/}"
done

echo
if ((failed)); then
  echo "$failed of ${#tasks[@]} task(s) failed validation"
  exit 1
fi
if ((skipped)); then
  echo "All $((${#tasks[@]} - skipped)) task(s) valid, $skipped skipped"
else
  echo "All ${#tasks[@]} task(s) valid"
fi
