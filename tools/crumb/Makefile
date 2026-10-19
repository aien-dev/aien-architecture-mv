# crumb: reader for advisory crumbs (RFC-0003 Am2). Needs only a C11 compiler (and git at run time).
CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror

crumb: crumb.c
	$(CC) $(CFLAGS) -o $@ crumb.c

test: crumb
	sh test.sh ./crumb

clean:
	rm -f crumb
.PHONY: test clean
