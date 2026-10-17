Extend `parse_size` in `src/size.c` so a byte count may end with one unit
suffix: `K`, `M`, `G` or `T`, in upper or lower case, meaning 1024, 1024^2,
1024^3 and 1024^4 bytes (`4K` is 4096, `2m` is 2097152). Exactly one letter
is allowed and it must follow at least one digit; anything else (`K` alone,
`1KB`, `1.5K`, `1 K`, `1KK`) is invalid. A result that does not fit in an
`unsigned long long` is an overflow. Invalid input and overflow still return
-1 and leave `*out` unchanged. Update the comment in `src/size.h`.

Add test cases to `tests/test_size.c`, then run `make test` and make sure it
passes with no compiler warnings. Change only `src/size.c`, `src/size.h` and
`tests/test_size.c`.
