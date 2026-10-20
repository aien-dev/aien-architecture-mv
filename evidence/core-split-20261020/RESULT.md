# L118 core split: result (run1, window 20261020T040951Z-ddf3d8, 2026-10-20 04:25-04:30Z)

## Verdict: INCONCLUSIVE by the pre-registered rule (PREDICTION.md)
The negative control (builds allowed on every core, make -j20) passed all four metrics, so the test was
blind: at this box load it could not tell an unpinned build from no build. A blind test cannot certify the
pinned case. The pinned case also failed one metric (below). So builds-on-A725 has no passing verdict.

Raw: run1/trials.tsv (36 trials + 2 warm-up), run1/builds.tsv, run1/raw/, run1/analysis.txt, run1/start.txt.

| metric (pinned to X925) | Q median | Q range | P shift | P range | P | U shift | U range | U |
|---|---|---|---|---|---|---|---|---|
| GPU decode slice, chip ns | 929016 | 10.72% | +2.75% | 24.49% | FAIL | -0.58% | 9.10% | PASS |
| memcpy 1 thread, GB/s | 44.08 | 35.51% | -7.94% | 42.88% | PASS | +4.14% | 35.28% | PASS |
| memcpy 8 threads, GB/s | 58.83 | 83.04% | -11.94% | 68.17% | PASS | -3.57% | 58.90% | PASS |
| cpuspin, ns | 392757802 | 8.56% | -0.41% | 8.43% | PASS | +0.84% | 8.36% | PASS |

The pinned-build GPU spread was 2.28x the no-build spread (calc:03ad09fa), over the 1.5x allowance; its
worst trial was 1141769 ns against a no-build worst of 1010520 ns.

## Why it was blind: the "quiet" box was not quiet [OBSERVED run1/start.txt, run1/box-after.txt]
- Load average 38-50 on 20 cores during the window.
- Other agents' quiet-build jobs ran in 12 of 12 no-build trials (2-3 markers in /tmp/aien-build.active.d),
  because quiet-build was already switched to never wait (02:21Z), so a window no longer stops builds.
  One marker was stale (pid 853039 dead): quiet-build has no trap to remove its marker if killed.
- Heavy CPU work that never goes through quiet-build: a 10-core qwen38_subbit.ref-build (1024% CPU, 43 min),
  the Spark test pipeline's rustc jobs (user aien-run), seen on X925 cores 8 and 17.
- Kernel thread nvidia-modeset/kthread_q has used one full core since boot: 41h52m CPU in 153519 s up,
  0.98 of a core (calc:23a1baf9), migrating over the X925 cores (seen on 15 and 17). Fixer L158.
So the extra build loop we added was small next to the background, and pinning quiet-build covers only the
part of the load that goes through quiet-build.

## Build times alone (no measurement running, same box load), omega engine origin/main a8ffd2b9, 82 C files
| cores | runs (s) | median |
|---|---|---|
| A725 only, -j10 | 6.03, 4.92, 5.83 | 5.83 s |
| X925 only, -j10 | 3.85, 3.19, 5.86 | 3.85 s |
| all 20, -j20 | 4.72, 4.09, 5.28 | 4.72 s |
Even on the slow cores a whole build is about 6 s, against the 1,202 s median wait measured earlier.

## Incident during the run [OBSERVED run1.open.log, start.txt]
spark-window began taking the GB10 lock itself (--gb10 exclusive default) while run1 was queued; run.sh then
waited 916 s on its own window's lock until its own flock was stopped. run.sh now skips its own flock when
the window holds gb10 exclusive (run.sh-as-launched is the copy that ran).

## Limits
One window, N=12 per condition, at a load the box rarely drops below today. The gate uses min/max ranges,
which are sensitive to single outliers. Nothing here measures the old regime (builds held off) at the same
load, so "the core split is worse than holding builds" is NOT shown either.

## What would decide it
A window where all CPU-heavy work is held for the no-build blocks: either the window pauses quiet-build
starts for its few minutes and the pipeline (aien-run) and other direct jobs are pinned to A725 too, or the
run waits for a load under 10. Then rerun run.sh unchanged. Until then, timings that matter for CPU memory
bandwidth are not reproducible on this box (memcpy 8-thread range 83% with no build of ours running).
