#include "url.h"

#include <stdlib.h>
#include <string.h>

static const char HEX[] = "0123456789ABCDEF";

static int unreserved(unsigned char c)
{
	return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
	       c == '-' || c == '_' || c == '.' || c == '~';
}

/* hexval: value of one hex digit, or -1. */
static int hexval(char c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	return -1;
}

char *url_encode(const char *s)
{
	if (s == NULL)
		return NULL;
	char *out = malloc(strlen(s) * 3 + 1);
	if (out == NULL)
		return NULL;
	char *o = out;
	for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
		if (unreserved(*p)) {
			*o++ = (char)*p;
		} else if (*p == ' ') {
			*o++ = '+';
		} else {
			*o++ = '%';
			*o++ = HEX[*p >> 4];
			*o++ = HEX[*p & 15];
		}
	}
	*o = '\0';
	return out;
}

char *url_decode(const char *s)
{
	if (s == NULL)
		return NULL;
	size_t len = strlen(s);
	char *out = malloc(len + 1);
	if (out == NULL)
		return NULL;
	char *o = out;
	for (size_t i = 0; i < len; i++) {
		if (s[i] == '+') {
			*o++ = ' ';
		} else if (s[i] == '%') {
			*o++ = (char)(hexval(s[i + 1]) * 16 + hexval(s[i + 2]));
			i += 2;
		} else {
			*o++ = s[i];
		}
	}
	*o = '\0';
	return out;
}
