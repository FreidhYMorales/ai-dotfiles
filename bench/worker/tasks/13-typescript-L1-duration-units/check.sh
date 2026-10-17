#!/usr/bin/env bash
# Hidden check: parseDuration understands d and ms without breaking m and s.
set -u
exec node --test --test-reporter=spec "$(dirname "${BASH_SOURCE[0]}")/hidden/duration.hidden.test.ts"
