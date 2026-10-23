# The Spark job queue (spark-broker): built, measured, not installed

Ledger L118, 2026-10-19/20. Brief: Drake, "we're getting jams too much". Rule: the
choice is made by measurement, not opinion.

**Result in one line:** the queue works, and it passed every safety test, but it lost
the measured comparison against the lock wrappers we already run (4 of 6 numbers to 2).
So the lock wrappers stay installed. The queue is kept in the repository as the
alternative, ready to install with one command if a future comparison favours it.

## 1. The jam, as it looked tonight

The Spark has two scarce things: the GB10 chip, and "quiet time" (nothing heavy
running, so a timing is honest). Agents took turns with two lock files. The fault:
an agent waited for one thing while holding the other.

Seen live at 23:50Z (evidence `docs/ops/spark-broker-evidence/live-jam-2350Z.txt`,
`ps-waiters-2350Z.txt`):
- A timing (cascade suite C) took the quiet lock at 23:07:53, then waited 33 minutes
  for the chip, which someone else held. For those 33 minutes no build could start.
- About 20 builds were queued; the oldest had waited 1 hour 48 minutes. They were
  started before the 20-minute rule went in at 23:43Z, so they still run the old logic:
  they wait until no timing at all is waiting, and timings arrived back to back.
- Between 22:25Z and 22:35Z, and again 23:10Z to 23:20Z, the chip did no work at all
  while up to 9 processes held or waited on its lock (sensor log). UNVERIFIED cause:
  likely two jobs taking the two locks in opposite orders, or a holder stuck (the
  qwen38 gate self-deadlock, L116, fits the second window).

## 2. What was built

`tools/ops/spark-broker/` (C, no Python):
- **spark-broker**: one small always-running program that keeps one line (queue).
  Agents never wait inside a lock; they wait in the line, holding nothing.
- **spark-job**: how an agent joins the line: `spark-job build CMD`, `spark-job chip CMD`,
  `spark-job measure NAME CMD`, `spark-job status` (who is waiting and for how long),
  `spark-job wait ID`. The first call starts the broker if none is running, so no new
  start-at-boot entry is needed.
- **quiet-build / quiet-measure shims**: the old commands, rewired to the queue, so no
  agent brief needs to change. If the broker is not running they fall back to the old
  wrappers (kept as `quiet-build.locks`, `quiet-measure.locks`).

The rules it follows:
- **Builds** run whenever no timing is actually running (a timing that is only waiting
  in line does not stop them), at nice 5, at most 6 at once, and only while the
  1-minute load is under 32 (the Spark has 20 cores; tonight's load ran 5 to 50).
- **Chip runs** go one at a time. The broker never changes how the 27B server uses the
  chip lock: when a chip job's turn comes, the job takes the same lock file as before.
- **Timings** go one at a time, in this order: first the chip (builds keep running while
  the timing waits for it), then running builds are allowed to finish (at most
  10 minutes; after that they are pushed to the lowest priority and let go of the quiet
  lock), then the measurement window opens (L113's `spark-window` and `spark-receipt`,
  so window ids and receipts stay the same), the job runs, the window closes.
- **No starving:** a build that has waited 10 minutes goes before the next timing
  starts. Why 10: half of the 20-minute bar, so a build that becomes urgent while a
  short timing runs still starts inside 20 minutes. A build cannot jump into a timing
  that is already running, so its worst case is 10 minutes plus that timing's length.

Safety, tested for real with several callers at once (`make test`, sandboxed lock
files, 17 of 17 checks pass): two builds run together; a timing waits for running
builds and then runs alone; a timing waiting for the chip does not hold builds back;
two timings never overlap, two chip runs never overlap, no chip run during a timing;
a caller killed while waiting or while running gives its turn back at once; a build
started inside a timing runs at once (no deadlock); the 10-minute rule and the drain
cap work; the status shows every waiter with its age; with no broker, jobs fall back
to the old wrappers. Two bugs were found and fixed by these tests before the replay
(a timing that needs no chip never got its start signal; the drain cap could not work
while builds still held the old shared lock).

## 3. How the choice was made

Tonight's job mix was rebuilt from what is on disk (`trace-20261019.tsv`): 38 builds
and 11 timings between 21:30Z and 23:55Z, arrival times from process start times,
agent transcripts and measurement receipts; timing lengths from the receipts; one
33-minute outside hold on the chip, from the cascade suite's measured wait. Not known,
so ASSUMED and labelled: build lengths (the four build times seen tonight, 35, 63, 81
and 100 s, in rotation) and the lengths of three timings still running at capture.

Both systems replayed the same mix with stand-in jobs that only sleep, at 60 times
speed, in a sandbox with their own lock files (no real chip time, the real locks never
touched): **A** = the wrappers as installed (with the 20-minute rule), **B** = the broker.
The predicted numbers and the rule for picking the winner were written and pushed
before any replay ran (`PREDICTION.md`, commit 051d5e4).

## 4. The numbers

Minutes of waiting, in the replayed evening (`RESULTS.txt`). Base run, with its repeat in brackets.

| | A: lock wrappers (installed) | B: broker |
|---|---|---|
| build wait, median | 19.3 (19.4) | **11.7 (5.9)** |
| build wait, worst | **20.0 (20.0)** | 39.3 (39.3) |
| timing wait, median | **1.1 (1.1)** | 6.8 (7.5) |
| timing wait, worst | **38.3 (38.3)** | 46.1 (46.3) |
| jobs that waited over 20 min | **4 (4)** | 11 (10) |
| builds running during timings | 21% of timing time (20%) | **0% (0%)** |

By the rule fixed in advance (a win needs a real margin; most wins decides; a tie keeps
A): **A wins 4, B wins 2. A stays installed.**

Other runs, reported, not used to decide:
- Builds 4 times longer: A lets builds run during 66% of timing time; B keeps timings
  clean but timings wait far longer (median 34.6, worst 107 minutes).
- A stand-in 27B server taking the chip 20 s of every 60 s (pattern UNVERIFIED): same
  picture as the base run.
- The wrappers before the 20-minute rule (A0): worst build wait 2 hours 14 minutes, 31
  jobs over 20 minutes. The 20-minute rule removed most of tonight's jam on its own.
- After the result, one labelled exploration: B with a 20-minute age rule instead of 10.
  Builds got worse (worst 56.6 minutes, 21 jobs over 20 minutes); timings were no better
  (median 6.7). So the broker's extra timing wait does not come from the age rule.

Where my predictions were wrong: I expected A's builds to land just over 20 minutes (they
land just under, so A has far fewer "over 20" jobs than predicted), and I expected the
broker's timing waits to stay near 1 to 2 minutes (they were near 7).

## 5. Why the broker lost, in plain words

Keeping a timing truly quiet means the timing must wait for the builds already running
to finish. Tonight's timings came back to back, so those small waits added up along the
whole chain. The current wrappers do the opposite: builds wait for timings, and after
20 minutes they run anyway at the lowest priority, during the timings. That costs
measurement quality (builds were running during a fifth of all timing time, two thirds
with longer builds) but keeps everybody's wait at 20 minutes or less.

So with tonight's demand, no line-keeping rule gives both short waits and clean timings.
The box is simply oversubscribed: 11 timings needed about 2 hours of quiet time out of
2 hours 25 minutes, and one outside holder kept the chip for 33 minutes. The jam is a
demand problem first.

## 6. What reduces the need for box time (each already has a ledger line)

- **Test only the changed unit** (L088, repo agents + change board): fewer and smaller
  builds and timings.
- **Community Sparks as extra judges** (aien-dev/spark-connector, L119-L121): correctness
  runs move off this box.
- **Build once by source hash** (L113, `spark-build-once`, installed): a build whose
  sources did not change is not rebuilt at all.
- Seen in tonight's data: one cascade suite held quiet time for 38 minutes, and the chip
  sat idle for two 10-minute stretches while its lock was held. Shorter timings and
  finding those idle holders would cut the worst waits in both systems.

How the broker would feed them, if installed later: its event log
(`~/.local/state/spark-broker/events.log`) records every job's class, wait and run time,
which is the cost record L088 needs to price "full run vs changed unit"; `chip` jobs are
the class a community Spark would take over (a chip job whose wait passes a limit could
be sent to a remote judge, which then returns a receipt); and `spark-job build` is the
natural place to ask `spark-build-once` first, so a cached build skips the line entirely.

## 7. How to install it later, and undo it

From `tools/ops/spark-broker`: `make test`, then `sh install.sh`. It puts `spark-broker`
and `spark-job` in `~/.local/bin`, replaces `quiet-build` and `quiet-measure` with the
shims, and keeps the replaced files as `*.pre-broker-<date>` and as the fallback
`*.locks`. Undo: `sh install.sh --uninstall`. Re-run the comparison on a new evening:
`replay/replay.sh A|B TRACE OUTDIR`, then compare `metrics.txt`, with predictions written first.

## 8. Limits

One evening's trace; build lengths and three timing lengths assumed; stand-in jobs only
sleep, so "builds running during timings" counts builds, not measured CPU load; the
broker's load ceiling was switched off in the replay (stand-in jobs make no load); the
27B server's real chip pattern is not recorded anywhere, so it is a stress case only.
