#include "../src/size.h"

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
	unsigned long long got = 12345;
	if (parse_size(s, &got) != -1 || got != 12345) {
		printf("FAIL parse_size(\"%s\") should fail and leave *out alone\n", s);
		failures++;
	}
}

int main(void)
{
	ok("0", 0);
	ok("4096", 4096);
	ok("18446744073709551615", 18446744073709551615ULL);
	bad("");
	bad("abc");
	bad("12x");
	bad("-1");
	bad(" 1");
	bad("18446744073709551616");
	if (failures) {
		printf("%d failure(s)\n", failures);
		return 1;
	}
	printf("all tests passed\n");
	return 0;
}
