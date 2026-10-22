# Lock policy on the Spark: correctness work never waits behind a timing lock

Status: in force since 2026-10-22 (ledger L405). Drake, 2026-10-22: "we really need to look at that chip lock
and stop chip locking." The tools live in `~/.local/bin` on the Spark: `spark-window`, `quiet-build`,
`quiet-measure`, `q36-extra`, `lock-long-holds`. Measurement windows themselves are described in
`docs/ops/MEASUREMENT_WINDOWS.md` (branch `ops/measurement-windows`).

## Why

On 2026-10-21 one measurement window (L371, quiet lock exclusive, 180 minute lease) held the machine from
21:59Z to 00:58Z to time a single 117,770-token prompt read. The line of builds and tests waiting behind it
grew from 3 (at +11 min) to 29 (at +171 min) while the machine sat at load 3.5. When the lease ran out, the
load went to 62 in one minute. Separately, a test model server held the chip lock for 6.9 hours.

## The five rules

1. **Correctness work never waits behind a timing lock for long.** Builds, host tests, QEMU, crumb checks and
   gates that compare values (tokens, routes, outputs) take no exclusive lock. `quiet-build` caps all its
   waiting at 25 minutes. After that the job runs anyway at nice 19, without the lock. The overrun is written
   to the open window, whose timings are then labelled "shared machine". A measurement waiting in line
   pauses new builds for at most 1 minute (it was 10).
2. **Exclusive locks are for timing receipts only, and they are short.** `spark-window open` refuses an
   exclusive lease (chip or quiet) over 20 minutes; the default is 20. A window that runs past its lease is
   let go, writes `NO VERDICT` for its timings and posts on the board. A long measurement is split into
   windows of 20 minutes or less, or runs on the shared machine with its receipt labelled "shared machine".
3. **Timing windows open when the machine is quiet anyway.** A window that takes the quiet lock first waits,
   holding nothing, until at most 3 jobs hold or wait on the quiet lock and the 1-minute load is at most 10.
   It then drains the quiet lock for at most 5 minutes. If the lock has not drained by then, it lets go and
   waits again. After 45 minutes of waiting it gives up (exit 4) and says why.
4. **Test model servers use their own chip lock.** `q36-extra` starts every job with
   `AIEN_SERVE_GPU_LOCK=/tmp/aien-serve-<port>.lock`, the same way the live server on 18091 runs. A test
   that needs a quiet chip for timing opens a short window like everyone else.
5. **Watchdog.** `lock-long-holds` (cron, every 5 minutes) times every exclusive hold. A hold over 20 minutes
   is posted once on `~/handoffs/BOARD.md` with its holder. A window past its own lease is closed through
   `spark-window close` and marked `NO VERDICT`. The watchdog never kills a job.

## The numbers and where they come from

| Number | Value | Source |
|---|---|---|
| Exclusive lease cap | 20 min | Drake's order via Hermes, 2026-10-22 |
| N, jobs allowed on the quiet lock when a window opens | 3 | Incident line growth: 26 jobs in 160 min, which is 3.25 jobs per 20-minute window (aien-calc `calc:691a9354`) |
| Drain cap | 5 min | Bounds the time new jobs sit behind a raised gate |
| M, longest a build waits behind any timing lock | 25 min | Drain cap (5 min) plus lease cap (20 min), so a window that keeps the rules is never interrupted |
| Load ceiling for opening | 10 | Half the 20 cores. Builds run on the A725 cores and timing runs on the 10 X925 cores. The incident window held at load 3.5 |
| Idle wait before giving up | 45 min | Gives up rather than holding the window slot all night |

## How to take a timing window now

```
spark-window open <name> --ledger <id> --wait      # 20 min max, opens when the machine is quiet
spark-window run <command>
spark-window close                                  # prints the verdict: quiet machine / shared machine / NO VERDICT
```

Value checks need no exclusive lock: use `--gb10 shared --quiet none`, or no window at all.

## Proof

Sandbox harness `test/policy.sh` in the L405 work folder uses its own lock files, sleep jobs and no model.

| Scenario | Old tools | New tools |
|---|---|---|
| pileup: L371-style window (180 min) then 30 builds | FAIL, 0 of 30 done in 20 s | PASS, window refused, 30 of 30 done |
| longhold: measurement holding the quiet lock 600 s, 30 builds | FAIL, 0 of 30 | PASS, 30 of 30 ran past it with every overrun logged |
| overrun: window lease runs out | FAIL, still held | PASS, let go, NO VERDICT, one board line |
| idle: window asks to open while 5 builds run | FAIL, a new build waited 305.9 s | PASS, the new build ran at once; the window opened once the machine was quiet |
| q36: test server on port 18098 | FAIL, no lock of its own | PASS, `/tmp/aien-serve-18098.lock` |
| watch: long raw holder plus a window past its lease | FAIL, nothing posted | PASS, one post each, window closed with NO VERDICT, raw holder left running |
| flag: a measurement waiting in line | FAIL | PASS, a new build ran after the 1-minute flag wait (2 s in the test) |
| control short: real 20-unit timing window | | PASS, chip exclusive, build held back until close, "quiet machine" |
| control refuse: lease 21 exclusive, lease 90 shared | | PASS, refused and opened |
| control measure: 4 s `quiet-measure` | | PASS, a build waited for it and then ran under the lock |
