#include "../src/url.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;

static void check(const char *name, char *(*fn)(const char *), const char *in, const char *want)
{
	char *got = fn(in);
	if (got == NULL || strcmp(got, want) != 0) {
		printf("FAIL %s(\"%s\"): got \"%s\", want \"%s\"\n", name, in, got ? got : "(null)", want);
		failures++;
	}
	free(got);
}

int main(void)
{
	check("url_encode", url_encode, "a b&c=d", "a+b%26c%3Dd");
	check("url_encode", url_encode, "safe-_.~", "safe-_.~");
	check("url_decode", url_decode, "a+b%26c%3Dd", "a b&c=d");
	check("url_decode", url_decode, "%e2%82%ac", "\xe2\x82\xac");
	check("url_decode", url_decode, "plain", "plain");
	check("url_decode", url_decode, "", "");
	if (url_decode(NULL) != NULL || url_encode(NULL) != NULL) {
		printf("FAIL NULL input should give NULL\n");
		failures++;
	}
	if (failures) {
		printf("%d failure(s)\n", failures);
		return 1;
	}
	printf("all tests passed\n");
	return 0;
}
