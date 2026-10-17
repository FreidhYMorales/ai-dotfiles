Add a `--list` option to `scripts/mutate.sh`: `scripts/mutate.sh --list FILE`
prints every mutant it would create, one per line as `line N: <mutated line>`
(the same format as the SURVIVED lines), without copying the repo and without
running any test command, then exits 0. Update the usage comment. Add a test
case for it in `scripts/tests/mutate.test.sh`. Then run `make check` and make
sure it ends with "All checks passed". Change only those two files.
