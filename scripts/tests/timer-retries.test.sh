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

echo "== a real user manager honours the cap =="

# wait_until SECONDS CONDITION...: poll CONDITION until it holds or time is up.
wait_until() {
  local deadline=$((SECONDS + $1))
  shift
  until "$@"; do
    ((SECONDS < deadline)) || return 1
    sleep 0.2
  done
}

if ! command -v systemd-run >/dev/null || ! systemctl --user show-environment >/dev/null 2>&1; then
  echo "SKIP  no systemd user manager here: the cap was not exercised"
else
  # The real Restart and StartLimitBurst, with the waits scaled from minutes to
  # seconds, on a transient unit that always fails and is removed at the end.
  probe=timer-retries-test-$$.service
  runs=$(mktemp)
  trap 'systemctl --user stop "$probe" 2>/dev/null; systemctl --user reset-failed "$probe" 2>/dev/null; rm -f "$runs"' EXIT
  window=8

  run_count() { wc -l <"$runs"; }
  gave_up() { same "$(systemctl --user show -P Result "$probe")" start-limit-hit; }
  ran_again() { (($(run_count) > 4)); }

  systemd-run --user --quiet --no-block --unit="$probe" --service-type=oneshot \
    -p Restart="$(setting engram-backup.service Service Restart)" -p RestartSec=1 \
    -p StartLimitBurst="$(setting engram-backup.service Unit StartLimitBurst)" \
    -p StartLimitIntervalSec="$window" \
    bash -c 'echo run >>"$1"; exit 1' probe "$runs"
  started=$SECONDS

  assert 'the manager gives up on a unit that keeps failing' wait_until 20 gave_up
  assert 'a failing unit runs exactly 4 times' same "$(run_count)" 4

  # Stand-in for the next day's timer run: once the window is over, a start runs.
  sleep $((window + 1 - (SECONDS - started)))
  systemctl --user start --no-block "$probe"
  assert 'a start after the window runs again' wait_until 10 ran_again
fi

echo
if ((failures)); then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
