#!/usr/bin/env bash
# Hidden check: --help prints usage and exits 0 without scanning.
set -u
out=$(HOME=/nonexistent bash bin/claude-perms-audit --help 2>&1)
rc=$?
[[ $rc -eq 0 ]] || {
  echo "exit $rc"
  exit 1
}
[[ $out == *Usage:* ]] || {
  echo "no Usage: in output"
  exit 1
}
[[ $out != *"risky permission rules"* ]] || {
  echo "it scanned"
  exit 1
}
