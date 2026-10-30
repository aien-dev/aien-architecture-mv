#!/bin/sh
# Offline test: a bare `spark-window close` must not close a window it does not own (L162).
# Uses a scratch windows folder and scratch lock files; never touches the live windows.
# Usage: tools/ops/test_spark_window_close.sh [path/to/spark-window]
set -u
here=$(cd "$(dirname "$0")" && pwd)
SW=${1:-$here/spark-window}
T=$(mktemp -d /tmp/spark-window-close-test.XXXXXX)
SPARK_WINDOWS_ROOT=$T/windows SPARK_QUIET_LOCK=$T/quiet.lock SPARK_GB10_LOCK=$T/gb10.lock
export SPARK_WINDOWS_ROOT SPARK_QUIET_LOCK SPARK_GB10_LOCK
# The L405 gate path, want dir and board are temp too, and the idle check ignores the host load:
# these temp locks have no other users, so the real machine load says nothing about them.
export SPARK_QUIET_GATE=$T/quiet.gate SPARK_QUIET_WANT=$T/want.d SPARK_BOARD=$T/BOARD.md SPARK_IDLE_LOAD=100000
unset SPARK_WINDOW
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
cleanup() {
  for h in "$T"/windows/*/holder.pid; do [ -f "$h" ] && kill -- -"$(cat "$h")" 2>/dev/null; done
  rm -rf "$T"
}
trap cleanup EXIT
waitfor() { i=0; while [ ! -e "$1" ] && [ $i -lt 100 ]; do sleep 0.2; i=$((i + 1)); done; [ -e "$1" ]; }
closed() { [ -f "$SPARK_WINDOWS_ROOT/$1/close.json" ]; }
holder_alive() { kill -0 "$(cat "$SPARK_WINDOWS_ROOT/$1/holder.pid")" 2>/dev/null; }

# Lane 1: its own script process. Opens inside $(...) like real lanes, waits for go1, then bare-closes.
cat > "$T/lane1.sh" <<EOF
id=\$("$SW" open lane1 --ledger L1 --gb10 none 2>/dev/null)
echo "\$id" > "$T/id1"
while [ ! -e "$T/go1" ]; do sleep 0.2; done
"$SW" close > "$T/lane1.out" 2>&1
echo \$? > "$T/lane1.rc"
EOF
sh "$T/lane1.sh" & lane1=$!
waitfor "$T/id1" && [ -n "$(cat "$T/id1")" ] || { bad "lane 1 opened a window"; exit 1; }
A=$(cat "$T/id1")
ok "lane 1 opened window $A"
check "window A is held" "$([ -f "$SPARK_WINDOWS_ROOT/$A/held" ] && echo yes)" yes

# 1. A stranger's bare close is refused (exit 3), names the holder, and changes nothing.
sh -c "\"$SW\" close" > "$T/stranger.out" 2>&1; rc=$?
check "stranger bare close exits 3" "$rc" 3
grep -q "$A" "$T/stranger.out" && grep -q 'owner=L1' "$T/stranger.out"; check "refusal prints the holder" "$?" 0
check "window A still held after the refusal" "$(closed "$A" && echo closed || echo held)" held
holder_alive "$A"; check "window A holder still alive" "$?" 0

# 2. Wrong SPARK_WINDOW does not count as ownership.
SPARK_WINDOW=20200101T000000Z-aaaaaa sh -c "\"$SW\" close" > /dev/null 2>&1; rc=$?
check "bare close with another window's SPARK_WINDOW exits 3" "$rc" 3
check "window A still held after wrong SPARK_WINDOW" "$(closed "$A" && echo closed || echo held)" held

# 3. close with a bogus or unknown id touches nothing.
sh -c "\"$SW\" close ../x" > /dev/null 2>&1; check "close ../x exits 2" "$?" 2
sh -c "\"$SW\" close 20200101T000000Z-bbbbbb" > /dev/null 2>&1; check "close of an unknown id exits 1" "$?" 1
check "window A still held after bad ids" "$(closed "$A" && echo closed || echo held)" held

# 4. The owner's own bare close (same script, different subshell from the open) works.
touch "$T/go1"; wait "$lane1"
check "owner bare close exits 0" "$(cat "$T/lane1.rc")" 0
check "window A closed by its owner" "$(closed "$A" && echo closed || echo held)" closed

# 5. Incident replay: lane 2 opens B; lane 1's stale bare close (a new process, as a finishing
#    script after its lease ran out) must not close B; close A (already closed) by id must not either.
B=$(sh -c "\"$SW\" open lane2 --ledger L2 --gb10 none 2>/dev/null"); [ -n "$B" ] || { bad "lane 2 opened a window"; exit 1; }
ok "lane 2 opened window $B"
sh "$T/lane1.sh" > /dev/null 2>&1 & stale=$!   # a second lane-1 run: its open is refused (B is open), id empty
sleep 1; touch "$T/go1"; wait "$stale"
check "stale lane-1 bare close exits 3" "$(cat "$T/lane1.rc")" 3
sh -c "\"$SW\" close" > /dev/null 2>&1; check "stale bare close exits 3" "$?" 3
sh -c "\"$SW\" close $A" > /dev/null 2>&1; check "close of the already closed A exits 1" "$?" 1
check "window B untouched" "$(closed "$B" && echo closed || echo held)" held
holder_alive "$B"; check "window B holder alive" "$?" 0

# 6. SPARK_WINDOW = the window id (what spark-window run sets) allows a bare close from anywhere.
SPARK_WINDOW=$B sh -c "\"$SW\" close" > /dev/null 2>&1; check "bare close with SPARK_WINDOW=B exits 0" "$?" 0
check "window B closed" "$(closed "$B" && echo closed || echo held)" closed

# 7. close with an explicit id closes exactly that window, from any process.
C=$(sh -c "\"$SW\" open lane3 --ledger L3 --gb10 none 2>/dev/null"); [ -n "$C" ] || { bad "lane 3 opened a window"; exit 1; }
sh -c "\"$SW\" close $C" > /dev/null 2>&1; check "close <ID> exits 0" "$?" 0
check "window C closed" "$(closed "$C" && echo closed || echo held)" closed

echo "pass $pass fail $fail"
[ "$fail" -eq 0 ]
