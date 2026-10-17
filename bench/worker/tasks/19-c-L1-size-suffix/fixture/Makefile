CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Werror -O1 -g

.PHONY: test clean

build/test_size: tests/test_size.c src/size.c src/size.h
	@mkdir -p build
	$(CC) $(CFLAGS) -o $@ tests/test_size.c src/size.c

test: build/test_size
	./build/test_size

clean:
	rm -rf build
