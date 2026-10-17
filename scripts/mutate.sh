#!/usr/bin/env bash
# Mutation testing for shell scripts: does the test suite notice a bug?
# Each mutant flips one operator on one line (== to !=, && to ||, exit 0 to
# exit 1...) in a throwaway copy of the repo and runs the test command there.
# A failing test kills the mutant; a passing one lets it survive, which points
# at logic no test protects. The real files are never touched.
#
# Usage: scripts/mutate.sh FILE [--min PERCENT] TEST_COMMAND...
#   FILE           script to mutate, relative to the repo root
#   --min PERCENT  exit 1 when the kill rate is below PERCENT
# Exit: 0 ok, 1 below --min, 2 the test command fails before any mutation.
set -u

usage() {
  sed -n '2,13p' "$0" | cut -c3- >&2
  exit 2
}

[[ $# -ge 2 ]] || usage
target=$1
shift
min=0
if [[ $1 == --min ]]; then
  min=$2
  shift 2
fi
[[ $# -ge 1 ]] || usage
TIMEOUT=${MUTATE_TIMEOUT:-120}

# Operator pairs: each occurrence on a line yields one mutant (first match).
FROM=('==' '!=' '-eq' '-ne' '-gt' '-lt' '-ge' '-le' '&&' '||' '[[ -z ' '[[ -n ' '[[ -f ' '[[ -d ' 'exit 0' 'exit 1' 'exit 2' 'return 0' 'return 1')
TO=('!=' '==' '-ne' '-eq' '-le' '-ge' '-lt' '-gt' '||' '&&' '[[ -n ' '[[ -z ' '[[ ! -f ' '[[ ! -d ' 'exit 1' 'exit 0' 'exit 0' 'return 1' 'return 0')

root=$(git rev-parse --show-toplevel) || exit 2
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(cd "$root" && git ls-files -co --exclude-standard -z | xargs -0 cp --parents -t "$work")
file="$work/$target"
[[ -f $file ]] || {
  echo "not found: $target" >&2
  exit 2
}

run_tests() { (cd "$work" && timeout "$TIMEOUT" "$@" >/dev/null 2>&1); }

if ! run_tests "$@"; then
  echo "error: the test command fails on the unmutated baseline; fix it first" >&2
  exit 2
fi

mapfile -t lines <"$file"
total=0
killed=0
for i in "${!lines[@]}"; do
  line=${lines[i]}
  [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
  for k in "${!FROM[@]}"; do
    [[ $line == *"${FROM[k]}"* ]] || continue
    mutated=${line/"${FROM[k]}"/"${TO[k]}"}
    mutant=("${lines[@]}")
    mutant[i]=$mutated
    printf '%s\n' "${mutant[@]}" >"$file"
    total=$((total + 1))
    if run_tests "$@"; then
      printf 'SURVIVED line %d: %s\n' "$((i + 1))" "${mutated#"${mutated%%[![:space:]]*}"}"
    else
      killed=$((killed + 1))
    fi
  done
done
printf '%s\n' "${lines[@]}" >"$file"

pct=100
((total > 0)) && pct=$((killed * 100 / total))
printf 'score: %d/%d killed (%d%%)\n' "$killed" "$total" "$pct"
((pct >= min)) || exit 1
