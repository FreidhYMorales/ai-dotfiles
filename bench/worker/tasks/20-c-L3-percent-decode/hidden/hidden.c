#include "url.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;

/* heap_copy: copy into an exact-size heap buffer so ASan sees any overread. */
static char *heap_copy(const char *s)
{
	size_t n = strlen(s) + 1;
	char *d = malloc(n);
	memcpy(d, s, n);
	return d;
}

static void check(const char *name, char *(*fn)(const char *), const char *in, const char *want)
{
	char *arg = heap_copy(in);
	char *got = fn(arg);
	if (got == NULL || strcmp(got, want) != 0) {
		printf("FAIL %s(\"%s\"): got \"%s\", want \"%s\"\n", name, in, got ? got : "(null)", want);
		failures++;
	}
	free(got);
	free(arg);
}

int main(void)
{
	check("url_decode", url_decode, "100%", "100%");
	check("url_decode", url_decode, "%", "%");
	check("url_decode", url_decode, "%4", "%4");
	check("url_decode", url_decode, "50%off", "50%off");
	check("url_decode", url_decode, "%zz", "%zz");
	check("url_decode", url_decode, "%4g", "%4g");
	check("url_decode", url_decode, "%g4", "%g4");
	check("url_decode", url_decode, "%%41", "%A");
	check("url_decode", url_decode, "a%+b", "a% b");
	check("url_decode", url_decode, "%41%42", "AB");
	check("url_decode", url_decode, "%4a%4A", "JJ");
	check("url_decode", url_decode, "a+b%20c", "a b c");
	check("url_decode", url_decode, "x=1%26y%3D2", "x=1&y=2");
	check("url_decode", url_decode, "%25", "%");
	check("url_decode", url_decode, "", "");
	check("url_encode", url_encode, "100% sure", "100%25+sure");
	if (url_decode(NULL) != NULL) {
		printf("FAIL url_decode(NULL) should be NULL\n");
		failures++;
	}
	if (failures) {
		printf("%d failure(s)\n", failures);
		return 1;
	}
	printf("ok\n");
	return 0;
}
