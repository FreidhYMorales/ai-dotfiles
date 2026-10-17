#ifndef URL_H
#define URL_H

/*
 * Query-string encoding (application/x-www-form-urlencoded).
 * Both functions return a new malloc'd string the caller frees, or NULL when
 * s is NULL or memory runs out.
 */

/* url_encode: keep A-Z a-z 0-9 - _ . ~, turn space into '+', %XX the rest. */
char *url_encode(const char *s);

/*
 * url_decode: '+' becomes a space and %XX (two hex digits, any case) becomes
 * that byte. A '%' that is not followed by two hex digits is kept literally.
 */
char *url_decode(const char *s);

#endif
