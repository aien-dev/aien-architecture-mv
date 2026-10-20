#!/bin/sh
# core-split experiment (L118): do builds pinned to the A725 cores disturb timings pinned to the X925 cores?
#   spark-window run tools/ops/core-split/run.sh OUTDIR CYCLES TRIALS
# Each cycle runs three conditions in rotating order, TRIALS trials each:
#   Q  no build loop of ours (other agents' quiet-build jobs may run; counted per trial)
#   P  build loop pinned like quiet-build: taskset -c 0-4,10-14 nice 19 ionice idle make -j10
#   U  negative control: the same build loop unpinned, make -j20 (the old nice-19 override path)
# A trial = GPU decode slice (q38gu, one token row, memory bound), CPU memcpy 1 thread, CPU memcpy
# 8 threads, cpuspin; every one pinned like quiet-measure (taskset -c 5-9,15-19).
# Then, with the GPU lock released: 3 timed builds each on A725 only, X925 only, all cores.
set -u
OUT=$1; CYC=${2:-6}; TR=${3:-2}
[ -n "${SPARK_WINDOW:-}" ] || { echo "run inside spark-window run" >&2; exit 2; }
WR=${SPARK_WINDOWS_ROOT:-$HOME/yardsticks/windows}
[ "$(cat "$WR/OPEN" 2>/dev/null)" = "$SPARK_WINDOW" ] && [ -f "$WR/$SPARK_WINDOW/held" ] || { echo "window $SPARK_WINDOW not open+held" >&2; exit 2; }
G=$HOME/workspace/targets/cascade/bin/gpu_tcgemm_test-00659ce6
M=$HOME/.cache/spark-shared/memcpy_probe-a4234222ecc4
C=${CPUSPIN:-/tmp/l118-build/cpuspin}
SRC=${BUILD_SRC:-/tmp/l118-build/omega}; PHY=${BUILD_PHY:-/tmp/l118-build/physics}
MEAS="taskset -c 5-9,15-19"
mkdir -p "$OUT/raw"; T=$OUT/trials.tsv; B=$OUT/builds.tsv
{ echo "window=$SPARK_WINDOW start=$(date -u +%FT%TZ) cycles=$CYC trials=$TR"
  sha256sum "$G" "$M" "$C"; echo "omega_src=$(cat "$SRC/.l118-commit" 2>/dev/null) physics_pin=6d7cf0d4"
  cat /proc/loadavg; grep MemAvailable /proc/meminfo; nvidia-smi --query-gpu=utilization.gpu,power.draw,clocks.sm,clocks.mem --format=csv,noheader; } > "$OUT/start.txt" 2>&1
printf 'cond\tcycle\ttrial\tutc\tload1\tother_builds\tgpu_ns\tgpu_gbps\tgpu_wall_s\tm1_GBps\tm8_GBps\tspin_ns\tspin_cpus\n' > "$T"
printf 'cond\tstart\tend\tdur_s\trc\n' > "$B"

loop_pid=""
start_loop() {  # $1 = P or U
  rm -f "$OUT/stop"
  if [ "$1" = P ]; then pfx="taskset -c 0-4,10-14 nice -n 19 ionice -c3"; j=10; else pfx="nice -n 19 ionice -c3"; j=20; fi
  setsid sh -c "cd '$SRC'; while [ ! -f '$OUT/stop' ]; do make clean >/dev/null 2>&1; t0=\$(date +%s.%N); $pfx make -j$j PHYSICS_DIR='$PHY' PHYSICS_LOCK_CHECK=0 all >/dev/null 2>&1; rc=\$?; t1=\$(date +%s.%N); printf '%s\t%s\t%s\t%s\t%s\n' $1 \$t0 \$t1 \$(echo \"\$t1 - \$t0\" | bc) \$rc >> '$B'; done" &
  loop_pid=$!; sleep 2
}
stop_loop() { [ -n "$loop_pid" ] || return 0; touch "$OUT/stop"; kill -TERM -- "-$loop_pid" 2>/dev/null; wait "$loop_pid" 2>/dev/null; loop_pid=""; sleep 1; }
trap 'stop_loop' EXIT INT TERM

med5() { grep -E '^[0-9]' "$1" | cut -d, -f5 | sort -n | awk '{v[NR]=$1} END{if(!NR){print "NA";exit} print (NR%2)?v[(NR+1)/2]:(v[NR/2]+v[NR/2+1])/2}'; }
trial() {  # cond cycle k
  tag=$1-$2-$3; ob=$(ls /tmp/aien-build.active.d 2>/dev/null | wc -l)
  g0=$(date +%s.%N)
  $MEAS "$G" --tv --shape q38gu --rows 1 --emu-rows 1 --reps 11 --tiles 1:4:4 --out "$OUT/raw/g-$tag.json" > "$OUT/raw/g-$tag.log" 2>&1
  g1=$(date +%s.%N)
  gl=$(grep '"rows":1,' "$OUT/raw/g-$tag.json" 2>/dev/null | grep -v xform | head -1)
  gns=$(echo "$gl" | sed -n 's/.*"chip_median_ns":\([0-9]*\).*/\1/p'); gbw=$(echo "$gl" | sed -n 's/.*"weights_gbps":\([0-9.]*\).*/\1/p')
  $MEAS "$M" 1 1 10 > "$OUT/raw/m1-$tag.csv" 2>&1
  $MEAS "$M" 1 8 10 > "$OUT/raw/m8-$tag.csv" 2>&1
  s=$($MEAS "$C" 300000000)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(date -u +%FT%TZ)" "$(cut -d' ' -f1 /proc/loadavg)" "$ob" \
    "${gns:-NA}" "${gbw:-NA}" "$(echo "$g1 - $g0" | bc)" "$(med5 "$OUT/raw/m1-$tag.csv")" "$(med5 "$OUT/raw/m8-$tag.csv")" \
    "$(echo "$s" | sed -n 's/.*ns=\([0-9]*\).*/\1/p')" "$(echo "$s" | sed -n 's/.*cpu_start=\([0-9]*\) cpu_end=\([0-9]*\).*/\1-\2/p')" >> "$T"
}

exec 9>/tmp/aien-gb10.lock; w0=$(date +%s); flock 9; echo "gb10_lock_wait_s=$(( $(date +%s) - w0 )) at $(date -u +%FT%TZ)" >> "$OUT/start.txt"
trial warm 0 0; trial warm 0 1          # warm-up, not analysed
c=1
while [ $c -le "$CYC" ]; do
  case $(( c % 3 )) in 1) ord="Q P U";; 2) ord="P U Q";; 0) ord="U Q P";; esac
  for cond in $ord; do
    [ "$cond" = Q ] || start_loop "$cond"
    k=1; while [ $k -le "$TR" ]; do trial "$cond" "$c" "$k"; k=$((k + 1)); done
    stop_loop
  done
  c=$((c + 1))
done
flock -u 9; exec 9>&-
echo "gpu_part_end=$(date -u +%FT%TZ)" >> "$OUT/start.txt"

# build timing alone (no measurement running), 3 each
for kind in A725 X925 ALL A725 X925 ALL A725 X925 ALL; do
  case $kind in A725) pfx="taskset -c 0-4,10-14"; j=10;; X925) pfx="taskset -c 5-9,15-19"; j=10;; ALL) pfx=""; j=20;; esac
  (cd "$SRC" && make clean >/dev/null 2>&1; t0=$(date +%s.%N); $pfx nice -n 19 make -j$j PHYSICS_DIR="$PHY" PHYSICS_LOCK_CHECK=0 all >/dev/null 2>&1; rc=$?; t1=$(date +%s.%N)
   printf 'alone-%s\t%s\t%s\t%s\t%s\n' $kind $t0 $t1 $(echo "$t1 - $t0" | bc) $rc >> "$B")
done
{ echo "end=$(date -u +%FT%TZ)"; cat /proc/loadavg; } >> "$OUT/start.txt"
echo "done: $T $B"
