Bug report for the `url` library (see README.md):

Search queries that contain a literal percent sign come out wrong on the
server. `q=100%` and `q=50%off` arrive with garbage bytes where the `%` was,
and sometimes the rest of the value is cut off or other memory shows up in
it. `q=%zz` is broken too. Properly encoded input like `%26` works fine.

Find the cause and fix it so the documented behavior in `src/url.h` holds.
Add test cases that reproduce the problem to `tests/test_url.c`, then run
`make test` and make sure it passes with no compiler warnings. Change only
`src/url.c`, `src/url.h` or `tests/test_url.c`.
