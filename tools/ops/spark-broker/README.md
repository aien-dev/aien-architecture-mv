# spark-broker: one queue for the Spark's chip and quiet time

The Spark is shared by many agents. Two things on it are scarce: the GB10 chip, and
"quiet time" (a box with nothing else heavy running, needed for honest timings).
Until now each agent waited for these inside lock files, and an agent waiting for
one thing could block everyone waiting for the other. spark-broker replaces the
waiting with one queue: agents say what kind of job they have and wait their turn
in line, without holding anything.

- `spark-job build CMD` : builds and tests; run whenever no timing is running.
- `spark-job chip CMD` : correctness runs on the chip, one at a time.
- `spark-job measure NAME CMD` : timings, one at a time: chip first, then builds drained,
  then a measurement window (spark-window) and a receipt (spark-receipt).
- `spark-job status` shows the line and how long each job has waited.
- `quiet-build` and `quiet-measure` keep working: they now hand jobs to the broker.
  With no broker running they fall back to the old lock wrappers (`*.locks`).

Shown on the real Spark: the concurrency tests (`make test`, sandboxed lock files) and
the replay of the 2026-10-19 evening's job mix. Full write-up and the measured comparison:
`docs/ops/BROKER.md`. Build: `make`; install: `make install`.

Status (2026-10-20): built and tested, NOT installed. It lost the measured comparison
against the lock wrappers already in use (4 of 6 numbers to 2), so those stay; see BROKER.md.
