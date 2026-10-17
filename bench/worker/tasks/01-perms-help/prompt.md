Add a `--help` option to `bin/claude-perms-audit`: it prints the usage block from
the header comment (the lines describing Flags and Usage) and exits 0 without
scanning anything. Add a test case for it in
`scripts/tests/claude-perms-audit.test.sh`, following the style of the existing
cases. Then run `make check` and make sure it ends with "All checks passed".
Change only those two files.
