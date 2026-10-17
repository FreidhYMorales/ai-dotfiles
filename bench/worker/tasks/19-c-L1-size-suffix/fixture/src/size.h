#ifndef SIZE_H
#define SIZE_H

/*
 * parse_size: parse a byte count such as "4096" into *out.
 * Returns 0 on success, -1 on invalid input or overflow (then *out is left
 * unchanged).
 */
int parse_size(const char *s, unsigned long long *out);

#endif
