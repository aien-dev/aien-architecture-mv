#!/bin/sh
# test-spark-window-starve.sh [SCRIPT]: L189 regression test for spark-window _hold.
# A window must open even while the quiet lock is held shared by one holder after another
# (builds and tests in turn) and while the chip lock is free. Uses only temp lock files and a
# temp window root; never touches /tmp/aien-quiet.lock or /tmp/aien-gb10.lock.
#   case 1 (no contention): opens fast.
#   case 2 (shared quiet holders back to back, short gaps): opens within LIMIT seconds.
# Exit 0 = all pass. Pass an older script path to see it fail (red).
set -u
S=${1:-$(dirname "$0")/spark-window}; LIMIT=${LIMIT:-60}
T=$(mktemp -d /tmp/spark-window-starve.XXXXXX)
export SPARK_WINDOWS_ROOT=$T/win SPARK_QUIET_LOCK=$T/quiet.lock SPARK_GB10_LOCK=$T/gb10.lock
: > "$SPARK_QUIET_LOCK"; : > "$SPARK_GB10_LOCK"
pids=""
cleanup() { for p in $pids; do kill "$p" 2>/dev/null; done; for h in "$T"/win/*/holder.pid; do [ -f "$h" ] && kill -- -"$(cat "$h")" 2>/dev/null; done; sleep 0.5; rm -rf "$T"; }
trap cleanup EXIT
fail=0
opens_within() {  # NAME SECONDS: run open, true if it prints a window id in time
  ( "$S" open "$1" --lease 5 > "$T/open.out" 2> "$T/open.err" ) & op=$!
  i=0; while [ $i -lt $(( $2 * 5 )) ]; do
    [ -f "$SPARK_WINDOWS_ROOT/OPEN" ] && [ -f "$SPARK_WINDOWS_ROOT/$(cat "$SPARK_WINDOWS_ROOT/OPEN")/held" ] && { wait $op; return 0; }
    sleep 0.2; i=$((i + 1)); done
  return 1
}
close_it() { "$S" close "$(cat "$SPARK_WINDOWS_ROOT/OPEN" 2>/dev/null)" > /dev/null 2>&1; }

if opens_within plain 10; then echo "PASS case 1: no contention opens"; close_it; else echo "FAIL case 1: no contention did not open"; fail=1; close_it; fi

# Shared quiet holders back to back, like builds and tests in turn. A waiting exclusive lock can only
# be won in a gap; the old _hold let it go again at once and almost never won it a second time.
stream() {  # SECONDS GAP: one shared holder after another, forever
  ( while :; do flock -s "$SPARK_QUIET_LOCK" sleep "$1"; sleep "$2"; done ) & pids="$pids $!"
}
stop_streams() { for p in $pids; do kill "$p" 2>/dev/null; done; pids=""; sleep 1.2; }
case_run() {  # LABEL: open under the running streams
  if opens_within "$1" "$LIMIT"; then echo "PASS $1: opened under shared quiet holders (tries $(cat "$SPARK_WINDOWS_ROOT/$(cat "$SPARK_WINDOWS_ROOT/OPEN")/tries" 2>/dev/null))"
  else echo "FAIL $1: no window in $LIMIT s under shared quiet holders back to back"; fail=1; fi
  close_it; stop_streams
}
stream 1.0 0
case_run "case 2 one holder, no pause between holders"
stream 0.9 0; stream 0.6 0
case_run "case 3 two holders, no pause between holders"
# chip busy too: the window must wait for the chip, then open once it is free (no deadlock, no early open)
stream 1.0 0
( flock -x "$SPARK_GB10_LOCK" sleep 6 ) & pids="$pids $!"; sleep 0.5; t0=$(date +%s)
# the open time comes from the window's own held file, not from when this loop noticed it (the poll is slow on a loaded box)
if opens_within "case 4 chip busy 6 s" "$LIMIT"; then
  dt=$(( $(stat -c %Y "$SPARK_WINDOWS_ROOT/$(cat "$SPARK_WINDOWS_ROOT/OPEN")/held") - t0 ))
  if [ $dt -ge 4 ]; then echo "PASS case 4 chip busy 6 s: opened only after the chip was free (window opened $dt s after the start)"
  else echo "FAIL case 4 chip busy 6 s: opened while the chip was held ($dt s)"; fail=1; fi
else echo "FAIL case 4 chip busy 6 s: no window in $LIMIT s"; fail=1; fi
close_it; stop_streams
exit $fail
