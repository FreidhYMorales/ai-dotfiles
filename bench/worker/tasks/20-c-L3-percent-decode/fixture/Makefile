CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Werror -O1 -g

.PHONY: test clean

build/test_url: tests/test_url.c src/url.c src/url.h
	@mkdir -p build
	$(CC) $(CFLAGS) -o $@ tests/test_url.c src/url.c

test: build/test_url
	./build/test_url

clean:
	rm -rf build
