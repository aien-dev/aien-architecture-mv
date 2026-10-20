# L118 core split: rule and prediction, written before any run (2026-10-20)

Question: with builds pinned to the Cortex-A725 cores (0-4,10-14, nice 19, idle IO, make -j10) and timings
pinned to the Cortex-X925 cores (5-9,15-19), do the timings stay as steady as with no build running?

Metrics (all pinned with taskset -c 5-9,15-19, the same pin quiet-measure now uses):
1. gpu_ns: chip median of the q38gu decode slice, one token row (34816 x 5120 weights, memory bound),
   gpu_tcgemm_test-00659ce6 --tv --rows 1 --tiles 1:4:4 --reps 11. GPU memory-bound.
2. m1_GBps: memcpy_probe 1 GB, 1 thread, median of 10 reps (the spark-calibrate probe). CPU memory.
3. m8_GBps: same, 8 threads. CPU memory bandwidth under contention: the metric most exposed to builds.
4. spin_ns: cpuspin, 3e8 dependent integer steps, register only. CPU core speed.

Design: CYCLES cycles, each runs Q (no build of ours), P (pinned build loop), U (unpinned make -j20 build
loop, negative control) in rotating order, TRIALS trials each, inside one spark-window, holding the GB10
lock for the whole timing part. Order rotates so drift in the box load hits all three alike.

Gate, per metric: P passes when median(P) lies inside [min(Q), max(Q)] AND range(P) <= 1.5 x range(Q)
(the 1.5 allows for sampling noise of a range at small N). Verdict PASS only if all 4 metrics pass.
Negative control: U must fail at least one metric; if U passes everything the test is blind and the verdict
is INCONCLUSIVE, whatever P did.

Prediction: spin_ns and gpu_ns PASS (separate cores; the GPU slice reads from DRAM far faster than a
build writes). m8_GBps is the risk: the X925 and A725 share the memory controller and each L3 cluster
(CPUs 0-9 and 10-19 each share one L3), so a build may cut multi-thread memcpy bandwidth by a few percent.
If m8 alone fails, that tells us CPU memory-bandwidth timings still need the quiet window and everything
else does not.
