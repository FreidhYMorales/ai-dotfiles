#include "size.h"

#include <stdio.h>

static int failures;

static void ok(const char *s, unsigned long long want)
{
	unsigned long long got = 0;
	if (parse_size(s, &got) != 0 || got != want) {
		printf("FAIL parse_size(\"%s\"): got %llu, want %llu\n", s, got, want);
		failures++;
	}
}

static void bad(const char *s)
{
	unsigned long long got = 777;
	if (parse_size(s, &got) != -1 || got != 777) {
		printf("FAIL parse_size(\"%s\") should fail and leave *out alone\n", s);
		failures++;
	}
}

int main(void)
{
	ok("4096", 4096);
	ok("0", 0);
	ok("0K", 0);
	ok("1K", 1024);
	ok("4k", 4096);
	ok("2M", 2097152);
	ok("2m", 2097152);
	ok("3G", 3221225472ULL);
	ok("1T", 1099511627776ULL);
	ok("1t", 1099511627776ULL);
	ok("16777215T", 18446742974197923840ULL);
	ok("17179869183G", 18446744072635809792ULL);
	ok("18446744073709551615", 18446744073709551615ULL);
	bad("");
	bad("K");
	bad("k");
	bad("1KB");
	bad("1KK");
	bad("1.5K");
	bad("1 K");
	bad(" 1K");
	bad("1K ");
	bad("1P");
	bad("1B");
	bad("-1K");
	bad("16777216T");
	bad("17179869184G");
	bad("18014398509481984K");
	bad("18446744073709551616");
	bad("99999999999999999999K");
	if (failures) {
		printf("%d failure(s)\n", failures);
		return 1;
	}
	printf("ok\n");
	return 0;
}
