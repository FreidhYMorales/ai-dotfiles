#!/usr/bin/env bash
# The timer services retry a failed run on their own, with a cap.
# Run: bash scripts/tests/timer-retries.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UNITS=$ROOT/systemd
failures=0

# setting UNIT SECTION KEY: print KEY's value from SECTION of a unit file.
setting() {
  awk -F= -v section="[$2]" -v key="$3" '
    /^\[/ { current = $0; next }
    current == section && $1 == key { print substr($0, length(key) + 2) }
  ' "$UNITS/$1"
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

same() { [[ $1 == "$2" ]]; }

echo "== retry settings =="

for unit in engram-backup.service upstream-watch.service; do
  assert "$unit retries a failed run" same "$(setting "$unit" Service Restart)" on-failure
  assert "$unit waits 10 minutes between runs" same "$(setting "$unit" Service RestartSec)" 10min
  assert "$unit runs at most 4 times in a window" same "$(setting "$unit" Unit StartLimitBurst)" 4
  # 3 waits of 10 min plus up to 10 min on engram-backup's lock per run fit in
  # 2 h, and the next day's timer run falls outside it.
  assert "$unit counts its runs over 2 hours" same "$(setting "$unit" Unit StartLimitIntervalSec)" 2h
done

assert 'engram-backup-verify.service does not retry' same "$(setting engram-backup-verify.service Service Restart)" ''

echo
if ((failures)); then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
