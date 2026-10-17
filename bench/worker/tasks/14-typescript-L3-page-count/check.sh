#!/usr/bin/env bash
# Hidden check: exact multiples of perPage have no extra empty page, in both
# paginate and pageLinks; empty lists keep one page.
set -u
exec node --test --test-reporter=spec "$(dirname "${BASH_SOURCE[0]}")/hidden/paginate.hidden.test.ts"
