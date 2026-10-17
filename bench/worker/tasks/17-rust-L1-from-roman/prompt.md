Add the inverse of `to_roman` to `src/lib.rs`:
`pub fn from_roman(s: &str) -> Option<u32>`. It returns the number for a
standard Roman numeral in the range 1..=3999, written in uppercase exactly as
`to_roman` would write it (so `from_roman(&to_roman(n).unwrap()) == Some(n)`
for every valid `n`), and `None` for anything else: the empty string,
lowercase, spaces, non-canonical forms such as `IIII`, `VV`, `IC` or `XM`,
and numbers above 3999.

Add tests for it to `tests/roman.rs`, then run `cargo test --offline` and make
sure every test passes. Change only those two files.
