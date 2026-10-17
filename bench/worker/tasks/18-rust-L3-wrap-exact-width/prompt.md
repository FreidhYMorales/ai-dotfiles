Bug report for the `wrap` crate (see README.md):

Our `--help` text uses `fill(text, 80, "  ")`, but many lines end several
columns short of the limit: a word that would end exactly at the last allowed
column is always pushed to the next line, so paragraphs come out with more
lines than needed. Lines shorter than the limit are otherwise fine, and long
words still behave as documented.

Find the cause and fix it, keeping the documented behavior. Add a test that
reproduces the problem to `tests/wrap.rs`, then run `cargo test --offline` and
make sure every test passes. Change only `src/lib.rs` and `tests/wrap.rs`.
