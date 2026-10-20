# spark-broker (ledger L118). make; make test; make install (to ~/.local/bin)
CFLAGS ?= -O2 -Wall -Wextra -Wno-format-truncation
BIN = spark-broker spark-job
all: $(BIN)
spark-broker: spark-broker.c ; $(CC) $(CFLAGS) -o $@ $<
spark-job: spark-job.c ; $(CC) $(CFLAGS) -o $@ $<
test: all ; sh ./test.sh
install: all ; sh ./install.sh
clean: ; rm -f $(BIN)
.PHONY: all test install clean
