#!/bin/sh
# install.sh: put spark-broker, spark-job and the quiet-build/quiet-measure shims in
# ~/.local/bin. The old wrappers stay beside them as quiet-build.locks and
# quiet-measure.locks (the fallback when no broker runs), and the files replaced
# are kept as *.pre-broker-<date>. No autostart entry: the first spark-job call
# starts the broker when none is running. Undo: ./install.sh --uninstall
set -eu
H=$(cd "$(dirname "$0")" && pwd)
B=${SPARK_BIN:-$HOME/.local/bin}
stamp=$(date -u +%Y%m%dT%H%MZ)
if [ "${1:-}" = --uninstall ]; then
  for f in quiet-build quiet-measure; do
    last=$(ls -t "$B/$f".pre-broker-* 2>/dev/null | head -1)
    [ -n "$last" ] && cp -p "$last" "$B/$f" && echo "restored $B/$f from $last"
  done
  rm -f "$B/spark-job"
  echo "spark-job removed; stop the running broker with: kill \$(cat /tmp/spark-broker/sock.pid)"
  exit 0
fi
make -C "$H" -s all
for f in quiet-build quiet-measure; do
  if [ -f "$B/$f" ] && ! grep -q "shim, ledger L118" "$B/$f"; then cp -p "$B/$f" "$B/$f.pre-broker-$stamp"; fi
done
# fallback wrappers: the versions that were live when this was installed
[ -f "$B/quiet-build.pre-broker-$stamp" ] && cp -p "$B/quiet-build.pre-broker-$stamp" "$B/quiet-build.locks.new" || cp -p "$H/quiet-build.locks" "$B/quiet-build.locks.new"
[ -f "$B/quiet-measure.pre-broker-$stamp" ] && cp -p "$B/quiet-measure.pre-broker-$stamp" "$B/quiet-measure.locks.new" || cp -p "$H/quiet-measure.locks" "$B/quiet-measure.locks.new"
for f in spark-broker spark-job quiet-build quiet-measure; do cp -p "$H/$f" "$B/$f.new"; done
for f in quiet-build.locks quiet-measure.locks spark-broker spark-job quiet-build quiet-measure; do mv -f "$B/$f.new" "$B/$f"; done
echo "installed in $B: spark-broker spark-job quiet-build quiet-measure (+ quiet-build.locks quiet-measure.locks fallback)"
