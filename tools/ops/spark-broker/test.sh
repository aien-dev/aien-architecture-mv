#!/bin/sh
# test.sh: real concurrency tests for spark-broker (several callers at once).
# Runs in a sandbox: its own socket and its own lock files under /tmp, so the
# Spark's real /tmp/aien-*.lock files are never touched. Prints PASS/FAIL per check.
set -u
H=$(cd "$(dirname "$0")" && pwd)
S=$(mktemp -d /tmp/l118-test.XXXXXX)
export SPARK_BROKER_AUTOSTART=0 SPARK_BROKER_SOCK=$S/sock SPARK_QUIET_LOCK=$S/q.lock SPARK_GB10_LOCK=$S/g.lock SPARK_JOB_WINDOW=0 SPARK_JOB_LEGACY_DIR=$H
export PATH=$H:$H/replay:$PATH
unset SPARK_JOB SPARK_WINDOW AIEN_GB10_LOCK_HELD
L=$S/jobs.log; : > "$L"
fails=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
# t ID FIELD: start/end time (ms) of a fake job from the log
t() { awk -v i="$2" -v k="$1" '$1==k && $2==i {print $4}' "$L"; }
# B ARGS: start the broker (age rule and drain cap in ms, small for the test)
B() { ( "$H/spark-broker" -s "$S/sock" -l "$S/events.log" -t 50 -L 1000 "$@" 2>>"$S/broker.err" & echo $! > "$S/bp" ); BP=$(cat "$S/bp"); sleep 0.3; }
stopb() { kill "$BP" 2>/dev/null; sleep 0.2; }

# 1. two builds at once both run together; a measure arriving meanwhile waits for both (drain), runs alone
B -N 60000 -D 60000
quiet-build fakejob "$L" b1 B 1.0 & quiet-build fakejob "$L" b2 B 1.0 &
sleep 0.2
quiet-measure flock "$SPARK_GB10_LOCK" fakejob "$L" m1 M 1.0 &
sleep 0.2
quiet-build fakejob "$L" b3 B 0.3 &
wait
s1=$(t start b1) s2=$(t start b2) e1=$(t end b1) e2=$(t end b2) ms=$(t start m1) me=$(t end m1) b3s=$(t start b3)
[ $((s1 > s2 ? s1 - s2 : s2 - s1)) -lt 300 ] && ok "1a two builds submitted together run together" || bad "1a builds did not run together ($s1 $s2)"
[ "$ms" -ge "$e1" ] && [ "$ms" -ge "$e2" ] && ok "1b measurement started only after running builds finished" || bad "1b measurement overlapped builds"
[ "$b3s" -ge "$me" ] && ok "1c build submitted during the measurement waited for it" || bad "1c build ran during the measurement ($b3s < $me)"
stopb

# 2. a measurement waiting for the chip does not hold builds back
: > "$L"; B -N 60000 -D 60000
flock "$SPARK_GB10_LOCK" sleep 2 & HOLD=$!          # an unconverted chip user (like the 27B server) holds the chip
sleep 0.2
quiet-measure flock "$SPARK_GB10_LOCK" fakejob "$L" m2 M 0.5 &
sleep 0.3
quiet-build fakejob "$L" b4 B 0.5 &
wait
b4s=$(t start b4) m2s=$(t start m2) b4e=$(t end b4)
[ "$b4e" -lt "$m2s" ] && ok "2a build ran and finished while the measurement waited for the chip" || bad "2a build blocked by a measurement waiting for the chip ($b4s $b4e $m2s)"
grep -q "state id=1 class=M word=lockwait" "$S/events.log" && ok "2b measurement reported it was waiting on the chip lock" || bad "2b no lockwait state"
stopb

# 3. two measurements at once never overlap; two chip jobs at once never overlap
: > "$L"; B -N 60000 -D 60000
quiet-measure fakejob "$L" m3 M 0.6 & quiet-measure fakejob "$L" m4 M 0.6 &
spark-job chip fakejob "$L" c1 C 0.6 & spark-job chip fakejob "$L" c2 C 0.6 &
wait
ov() { a0=$(t start "$1") a1=$(t end "$1") b0=$(t start "$2") b1=$(t end "$2"); [ "$a1" -le "$b0" ] || [ "$b1" -le "$a0" ]; }
ov m3 m4 && ok "3a two measurements at once ran one after the other" || bad "3a measurements overlapped"
ov c1 c2 && ok "3b two chip jobs at once ran one after the other" || bad "3b chip jobs overlapped"
ov m3 c1 && ov m3 c2 && ov m4 c1 && ov m4 c2 && ok "3c no chip job ran during a measurement" || bad "3c chip job overlapped a measurement"
stopb

# 4. a caller killed while queued, and one killed while running, give their turn back
: > "$L"; B -N 60000 -D 60000
quiet-measure fakejob "$L" m5 M 1.0 &
sleep 0.2
spark-job build fakejob "$L" bx B 5 & KQ=$!          # queued behind the measurement
sleep 0.2; kill -9 $KQ
spark-job chip sleep 30 & KR=$!                      # runs (holds the chip turn)
sleep 0.3; kill -9 $KR
spark-job chip fakejob "$L" c3 C 0.2 &
sleep 0.2; c3t0=$(date +%s%3N)
wait
c3s=$(t start c3)
[ -z "$(t start bx)" ] && ok "4a killed queued caller never ran" || bad "4a killed queued caller ran"
[ -n "$c3s" ] && ok "4b chip turn freed when its caller was killed (next chip job ran)" || bad "4b chip turn stuck after kill"
grep -q "why=caller gone" "$S/events.log" && ok "4c broker logged the dead callers" || bad "4c no caller-gone record"
stopb

# 5. nested: a quiet-build inside a measurement runs at once (no deadlock)
: > "$L"; B -N 60000 -D 60000
quiet-measure sh -c "quiet-build fakejob $L n1 B 0.2" &
NP=$!; ( sleep 10; kill $NP 2>/dev/null ) & W=$!
wait $NP; kill $W 2>/dev/null
[ -n "$(t end n1)" ] && ok "5a nested build inside a measurement ran at once" || bad "5a nested build deadlocked"
stopb

# 6. age rule: a build that waited N blocks the NEXT measurement until it has run
: > "$L"; B -N 800 -D 60000
quiet-measure fakejob "$L" m6 M 1.5 &
sleep 0.2
quiet-build fakejob "$L" b6 B 0.5 &
sleep 0.2
quiet-measure fakejob "$L" m7 M 0.5 &
wait
b6s=$(t start b6) m6e=$(t end m6) m7s=$(t start m7)
[ "$b6s" -ge "$m6e" ] && [ "$b6s" -lt "$m7s" ] && ok "6a aged build ran before the next measurement started" || bad "6a aged build starved ($b6s $m6e $m7s)"
stopb

# 7. drain cap: a measurement waits for a long build at most D, then the build is reniced to 19
: > "$L"; B -N 60000 -D 500
quiet-build sh -c "fakejob $L b7 B 2; :" &
sleep 0.3
quiet-measure fakejob "$L" m8 M 0.3 &
sleep 1.0
nice7=$(ps -eo ni=,args= | grep "[f]akejob $L b7" | awk '{print $1}' | sort -n | head -1)
wait
m8s=$(t start m8) b7e=$(t end b7)
[ "$m8s" -lt "$b7e" ] && ok "7a drain cap: measurement started after the cap, not after the long build" || bad "7a drain cap not applied"
[ "${nice7:-0}" -ge 19 ] && ok "7b leftover build pushed to nice 19" || bad "7b leftover build nice=$nice7"
stopb

# 8. status shows queued jobs with their ages while one runs
: > "$L"; B -N 60000 -D 60000
quiet-measure fakejob "$L" m9 M 1.5 &
sleep 0.3; quiet-build fakejob "$L" b9 B 0.1 &
sleep 1.1
st=$(SPARK_JOB_WINDOW=0 spark-job status)
wait
echo "$st" | grep -q "build   queued" && echo "$st" | grep -q "measure running" && ok "8a status lists the running measurement and the queued build with ages" || { bad "8a status"; echo "$st"; }
stopb

# 9. no broker: falls back to the old lock wrappers and still runs (stub wrapper here:
#    the real quiet-build.locks watches the real /tmp/aien-quiet.want.d)
: > "$L"; mkdir -p "$S/legacy"; printf "#!/bin/sh\nexec \"\$@\"\n" > "$S/legacy/quiet-build.locks"; chmod +x "$S/legacy/quiet-build.locks"
SPARK_JOB_LEGACY_DIR=$S/legacy quiet-build fakejob "$L" f1 B 0.1 2>"$S/fb.err"
[ -n "$(t end f1)" ] && grep -q "old lock wrappers" "$S/fb.err" && ok "9a with no broker, jobs fall back to the old wrappers" || bad "9a fallback"

echo "sandbox: $S"
[ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED"
exit $fails
