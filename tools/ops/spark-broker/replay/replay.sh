#!/bin/sh
# replay.sh SYSTEM TRACE OUTDIR [SCALE] [BUILDX] [SERVER]
# Replays a job trace (arrival times and run lengths) with stand-in jobs that
# only sleep, so no real chip or CPU time is used, against one system:
#   A   the lock wrappers as installed on 2026-10-19 23:43Z (20-minute rule)
#   A0  the wrappers before that bandage (no 20-minute rule)
#   B   spark-broker with the quiet-build/quiet-measure shims
# Everything runs in a sandbox (own lock files, own socket); the Spark's real
# /tmp/aien-*.lock files are never touched. Time is compressed SCALE times
# (default 60: one trace minute = one real second). BUILDX multiplies build
# run lengths (default 1). SERVER=1 adds a stand-in 27B server that takes the
# chip lock 20 s out of every 60 s (pattern UNVERIFIED, used as a stress case).
# Writes OUTDIR/jobs.log (arrive/start/end per job, ms) and OUTDIR/metrics.txt.
set -u
SYS=$1 TRACE=$2 OUT=$3 SCALE=${4:-60} BX=${5:-1} SRV=${6:-0}
H=$(cd "$(dirname "$0")/.." && pwd)
S=$(mktemp -d /tmp/l118-replay.XXXXXX)
mkdir -p "$OUT" "$S/bin"
L=$OUT/jobs.log; : > "$L"
Q=$S/q.lock G=$S/g.lock W=$S/want.d
P=$(awk -v s="$SCALE" 'BEGIN{printf "%.3f", 5/s}')          # the wrappers' 5 s poll, scaled
CAP=$(( 1200 / SCALE ))                                         # the 20-minute rule, scaled
sand() { sed -e "s|/tmp/aien-quiet.want.d|$W|g" -e "s|/tmp/aien-quiet.lock|$Q|g" -e "s|sleep 5|sleep $P|g" \
             -e "s|QUIET_BUILD_CAP:-1200|QUIET_BUILD_CAP:-$CAP|" -e "s|LOG=\$HOME/.local/state/quiet/build-overrides.log|LOG=$S/overrides.log|" "$1" > "$2"; chmod +x "$2"; }
unset SPARK_JOB SPARK_WINDOW AIEN_GB10_LOCK_HELD
case $SYS in
A)  sand "$H/quiet-build.locks" "$S/bin/quiet-build"; sand "$H/quiet-measure.locks" "$S/bin/quiet-measure" ;;
A0) sand "$H/replay/quiet-build.pre-bandage" "$S/bin/quiet-build"; sand "$H/quiet-measure.locks" "$S/bin/quiet-measure" ;;
B)  for f in quiet-build quiet-measure quiet-build.locks quiet-measure.locks spark-job; do ln -s "$H/$f" "$S/bin/$f"; done
    N=$(( 600000 / SCALE )) D=$(( 600000 / SCALE ))
    ( "$H/spark-broker" -s "$S/sock" -l "$OUT/broker-events.log" -t 20 -b 6 -L 100000 -N $N -D $D 2>"$S/broker.err" & echo $! > "$S/bp" )
    export SPARK_BROKER_SOCK=$S/sock SPARK_QUIET_LOCK=$Q SPARK_GB10_LOCK=$G SPARK_JOB_WINDOW=0 SPARK_JOB_LEGACY_DIR=$S/bin
    sleep 0.3 ;;
*)  echo "SYSTEM must be A, A0 or B" >&2; exit 2 ;;
esac
export PATH=$S/bin:$H/replay:$PATH
ms() { date +%s%3N; }
t0=$(ms)
if [ "$SRV" = 1 ]; then
  end=$(awk -F'\t' '!/^#/ {e=$1+$3; if (e>m) m=e} END{print m}' "$TRACE")
  ( i=0; while [ $(( ($(ms) - t0) * SCALE / 1000 )) -lt "$end" ]; do
      flock "$G" sleep "$(awk -v s="$SCALE" 'BEGIN{printf "%.3f", 20/s}')"
      sleep "$(awk -v s="$SCALE" 'BEGIN{printf "%.3f", 40/s}')"; i=$((i+1)); done ) &
  echo $! > "$S/srv"
fi
pids=""
while IFS="$(printf '\t')" read -r off cls run name src; do
  case $off in \#*|"") continue ;; esac
  [ "$cls" = build ] && run=$(( run * BX ))
  now=$(ms); wait_ms=$(( t0 + off * 1000 / SCALE - now ))
  [ "$wait_ms" -gt 0 ] && sleep "$(awk -v w="$wait_ms" 'BEGIN{printf "%.3f", w/1000}')"
  d=$(awk -v r="$run" -v s="$SCALE" 'BEGIN{printf "%.3f", r/s}')
  printf 'arrive %s %s %s\n' "$name" "$cls" "$(ms)" >> "$L"
  case $cls in
  build)    quiet-build fakejob "$L" "$name" B "$d" 2>>"$S/jobs.err" & ;;
  measure)  quiet-measure flock "$G" fakejob "$L" "$name" M "$d" 2>>"$S/jobs.err" & ;;
  chiphold) flock "$G" fakejob "$L" "$name" H "$d" 2>>"$S/jobs.err" & ;;
  esac
  pids="$pids $!"
done < "$TRACE"
for p in $pids; do wait "$p"; done
[ -f "$S/srv" ] && kill "$(cat "$S/srv")" 2>/dev/null
[ -f "$S/bp" ] && kill "$(cat "$S/bp")" 2>/dev/null
cp "$S/overrides.log" "$OUT/" 2>/dev/null
printf 'system=%s scale=%s buildx=%s server=%s trace=%s sandbox=%s\n' "$SYS" "$SCALE" "$BX" "$SRV" "$TRACE" "$S" > "$OUT/run.txt"
sh "$H/replay/metrics.sh" "$L" "$SCALE" | tee "$OUT/metrics.txt"
