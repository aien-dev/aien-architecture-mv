#!/bin/sh
# go.sh OUTDIR CYCLES TRIALS: wait for the next free spark-window (retry every 60 s), run run.sh inside it, close it.
set -u
H=$(cd "$(dirname "$0")" && pwd)
OUT=$1; shift
until id=$(spark-window open l118-core-split --ledger L118 --lease 75 2>>"$OUT.open.log"); do sleep 60; done
echo "window $id $(date -u +%FT%TZ)" >> "$OUT.open.log"
spark-window run "$H/run.sh" "$OUT" "$@"; rc=$?
spark-window close "$id" >> "$OUT.open.log" 2>&1
echo "run.sh rc=$rc closed $(date -u +%FT%TZ)" >> "$OUT.open.log"
[ $rc -eq 0 ] && "$H/analyze.sh" "$OUT/trials.tsv" > "$OUT/analysis.txt" 2>&1
exit $rc
