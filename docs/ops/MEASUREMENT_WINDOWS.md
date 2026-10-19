# Measurement windows and the shared base

Several agents measure on the one Spark at the same time. When three of them timed things in parallel
on 2026-10-19, two of the three verdicts came back INCONCLUSIVE only because the box was loaded by the
others. Drake's rule: build once, measure the shared parts once per window, and then each agent measures
only its own difference, one after another.

The shared base is four small shell tools in `~/.local/bin` (copies in [`tools/ops/`](../../tools/ops/README.md)):

| Tool | What it does |
|---|---|
| `spark-build-once` | Builds a source tree once. A second caller with the same source gets the stored result in seconds. |
| `spark-window` | Opens one measurement window at a time, keeps the box quiet while it is open, records the box state at open and close. |
| `spark-calibrate` | The one calibration of a window: CPU memory bandwidth and idle power at the wall. |
| `spark-baseline 27b` | The one 27B baseline of a window: a fixed 64-token reply, tokens per second and joules per token. |

`spark-receipt` (the energy receipt every measurement already uses) now stamps the window id and the
window's calibration file into each receipt. It is shell and awk now; the keys, file name and output
are the same as before, plus the two new keys.

## The run order

1. One window at a time. `spark-window open` refuses when a window is already open or waiting, and
   shows whose it is.
2. If you are refused, queue with a ledger note and try again after it closes:
   `ledger note <your id> "measure: waiting for window <their window id>"`.
3. Inside your window: calibrate once, take the 27B baseline once (if your work involves the 27B),
   then run only your own measurements. Every receipt carries the window id, so a reader can match it
   to the calibration and the baseline taken under the same conditions.
4. Close the window as soon as your timings are done. A window that is forgotten closes itself when
   its lease runs out (90 minutes unless you ask for another length).

Builds are not measurements: do them before you open the window, through `spark-build-once` or
`quiet-build`. While a window is open, builds wait.

## Exact commands

Open a window (waits its turn; prints the window id when it holds the box):

```sh
id=$(spark-window open my-measurement --ledger L109 --lease 60)
```

Calibrate and take the baseline inside it:

```sh
spark-window run spark-calibrate
spark-window run spark-baseline 27b
```

Run your own measurement inside it (any command; `spark-receipt` inside picks up the window id):

```sh
spark-window run spark-receipt my-run --idle 30 -- ./my-benchmark args
```

Close it:

```sh
spark-window close
```

See what is open and who holds or waits on the locks:

```sh
spark-window status
spark-window locks
```

Build once (from inside a git worktree; name every result you need with `--out`):

```sh
spark-build-once --out build/dagsim -- make build/dagsim
```

## What lands on disk

Everything for one window sits in `~/yardsticks/windows/<window id>/`:

| File | Contents |
|---|---|
| `open.json`, `close.json` | Box state at open and close: load, free memory, GPU use and power, who holds the GPU and quiet locks, who waits, the latest sensor row |
| `calibration.json` | Memory bandwidth (median, lowest and highest of 10 copies, with 1 and 8 threads) and idle power at the wall over 30 s |
| `calibration/` | The raw probe output and the idle receipt |
| `baseline-27b.json` | Tokens per second, joules per token at the wall and above idle, the reply's fingerprint, the server build |
| `baseline-27b/` | The exact request, the reply, the receipt, the GPU lock samples taken during the request |

Receipts still go to `~/yardsticks/receipts/<date>-<name>.json` and now carry `window_id` and
`calibration` (both `null` outside a window). The build cache lives in `~/.cache/spark-build-once/`
and its log in `~/yardsticks/build-once.log`.

## How it works, in plain words

- **The quiet lock.** The hive already had one rule for keeping the box quiet: builds share
  `/tmp/aien-quiet.lock` through `quiet-build`, a measurement takes it alone through `quiet-measure`.
  A window is a long-running `quiet-measure`: a small holder process takes the lock alone and keeps it
  until you close the window or the lease runs out. Inside the window `quiet-measure` sees its own
  window and runs your command straight away instead of waiting on its own lock.
- **The GPU lock.** `/tmp/aien-gb10.lock` is separate. The calibration holds it for its minute of
  probing and idling so the GPU stays idle. The baseline does not hold it, because the 27B server takes
  that lock itself for every reply; holding it would make the server wait on us forever. The baseline
  waits until nobody holds or waits on the GPU lock, sends the request, samples the lock table while it
  runs, and marks the baseline not ok if anyone else used the GPU meanwhile.
- **The build cache key** is the source tree as it is on disk (the committed tree, plus uncommitted
  changes, plus new files that git does not ignore), the folder you run from, the exact command, the
  `--out` list and the `PHYSICS_DIR` / `AIENOS_LOCK_REPO` settings. Any change gives a new key, so a
  stored build is only reused for identical sources. Two callers with the same key at the same moment:
  one builds, the other waits on a per-key lock and then takes the stored result. Results are stored
  by an atomic rename, so a half-written entry is never visible.

## Limits, said plainly

- Wall power is the whole UPS output in 10 W steps about every 2 s, not the Spark alone. A 64-token
  reply lasts a few seconds, so its joules per token rest on a few samples: read it as coarse.
- Tokens per second in the baseline is the whole request time, including the short prompt's prefill.
- Programs that take only the GPU lock and not the quiet lock can still run during a window. The
  window records them (lock holders at open and close; the baseline samples the lock during its
  request), it does not stop them.
- The memory probe is the one research/583 used (omega `research/cost-sim-583@3bd56731`,
  `tools/dagsim/memcpy_probe.c`), built with `cc -O2 -pthread`; 583 did not record its compiler
  flags, so its numbers and ours are comparable in method, not guaranteed bit for bit.

## Receipt format: what changed

Same keys, same order, same file name, same output as before; two keys added at the end. Run side by
side on the same 8-second command, the old and new receipts differed only in timing jitter
(`start`, `seconds`, `wall_J` within 0.02 %) and these lines:

```diff
  "note": "wall W = UPS ups.load x 10 (CP1500PFCLCD, 1 percent steps, ~2 s); whole UPS output, not the Spark alone",
+ "window_id": "20261019T232138Z-103d00",
+ "calibration": "/home/drakestapleton/yardsticks/windows/20261019T232138Z-103d00/calibration.json"
```

Outside a window both are `null`. Numbers still print with a decimal point (`180.0`), as before.
