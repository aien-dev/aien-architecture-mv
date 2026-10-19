# tools/ops: the Spark's shared measurement base

Shell tools installed in `~/.local/bin` on the Spark. These are the committed copies; install by copying
each file over the old one (copy to a temporary name, then rename, so running jobs keep the old file).
How and when to use them: [docs/ops/MEASUREMENT_WINDOWS.md](../../docs/ops/MEASUREMENT_WINDOWS.md).

| File | Purpose |
|---|---|
| `spark-build-once` | Build cache keyed by the source tree, command and env knobs; concurrent callers build once |
| `spark-window` | One measurement window at a time; holds the quiet lock exclusive; box state at open and close |
| `spark-calibrate` | Per-window calibration: memcpy bandwidth (omega#583 probe) and 30 s idle power at the wall |
| `spark-baseline` | Per-window 27B baseline: fixed 64-token reply on 127.0.0.1:18091, tok/s and J/token |
| `spark-receipt` | Energy receipt for any command; now stamps `window_id` and `calibration` |
| `quiet-measure` | Exclusive quiet lock for a measurement; runs directly inside its own open window |
| `quiet-build` | Shared quiet lock for builds (unchanged, kept here so the pair is in one place) |

Shown on the Spark so far (2026-10-19): two callers on one source built once in a scratch repo (the second
reused the stored result), two windows opened at the same moment (one refused), lease expiry; the real
window and the real two-worktree build are recorded in the shared-base handoff once they ran.
