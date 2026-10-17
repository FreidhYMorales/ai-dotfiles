#include "size.h"

#include <limits.h>
#include <stddef.h>

int parse_size(const char *s, unsigned long long *out)
{
	unsigned long long n = 0;
	const char *p = s;

	if (s == NULL || *s == '\0')
		return -1;
	for (; *p >= '0' && *p <= '9'; p++) {
		unsigned digit = (unsigned)(*p - '0');
		if (n > (ULLONG_MAX - digit) / 10)
			return -1;
		n = n * 10 + digit;
	}
	if (p == s || *p != '\0')
		return -1;
	*out = n;
	return 0;
}
