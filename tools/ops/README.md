# tools/ops: the Spark's shared measurement base

Shell tools installed in `~/.local/bin` on the Spark. These are the committed copies; install by copying
each file over the old one (copy to a temporary name, then rename, so running jobs keep the old file).
How and when to use them: [docs/ops/MEASUREMENT_WINDOWS.md](../../docs/ops/MEASUREMENT_WINDOWS.md).

| File | Purpose |
|---|---|
| `spark-build-once` | Build cache keyed by the source tree, command and env knobs; concurrent callers build once |
| `spark-window` | One measurement window at a time; holds the quiet lock exclusive; box state at open and close. A bare `close` only closes a window you opened (same shell tree, or `SPARK_WINDOW` set); otherwise refused with exit 3, use `close <ID>` |
| `test_spark_window_close.sh` | Offline test for the close rule above (scratch locks and folder, never the live windows) |
| `test-spark-window-starve.sh` | Offline L189 test: a window still opens while shared quiet holders run back to back, and it waits out a busy chip lock before opening. Scratch locks and window root only |
| `spark-calibrate` | Per-window calibration: memcpy bandwidth (omega#583 probe) and 30 s idle power at the wall |
| `spark-baseline` | Per-window 27B baseline: fixed 64-token streamed reply on 127.0.0.1:18091, decode tok/s and J/token |
| `spark-receipt` | Energy receipt for any command; now stamps `window_id` and `calibration` |
| `quiet-measure` | Exclusive quiet lock for a measurement; runs directly inside its own open window |
| `quiet-build` | CPU-heavy jobs. Waits for a live measurement flag (at most 1 min), then the quiet gate, then a shared quiet lock. The whole wait is capped at 25 min (`SPARK_BUILD_MAX_WAIT`, default 1500 s). If the lock is acquired in time, the command runs as given. Past the cap it runs at nice 19, with no lock and no core pinning, and the open window is marked shared machine (L405). Waits are logged |

`SHA256SUMS` in this directory is the sha256 of each script. From `tools/ops`: `sha256sum -c SHA256SUMS`.

Shown on the Spark (2026-10-19/20): two callers on one source built once in a scratch repo (the second
reused the stored result), two windows opened at the same moment (one refused), lease expiry, the
`--wait` line in a sandbox (turns in arrival order, a late open refused, a waiter that gave up dropped).
Real runs: two omega worktrees at one commit built once, identical output, a repeat in 4 s
(docs/ops/evidence/L113-build-once-two-worktrees.md); window 20261020T095626Z-bd2f56 with a calibration
and a passing 27B baseline (~/yardsticks/windows/20261020T095626Z-bd2f56/).
