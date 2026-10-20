# core-split

Tests whether builds kept on the Cortex-A725 cores (0-4,10-14) disturb timings kept on the Cortex-X925 cores
(5-9,15-19). `go.sh OUT CYCLES TRIALS` waits for the next spark-window, runs `run.sh` inside it and closes it;
`analyze.sh trials.tsv` applies the pass rule written in `evidence/core-split-20261020/PREDICTION.md`.
`cpuspin.c` is the register-only processor test. Result of the first run: `evidence/core-split-20261020/RESULT.md`
(inconclusive: the box was too busy for the test to see even an unpinned build).
