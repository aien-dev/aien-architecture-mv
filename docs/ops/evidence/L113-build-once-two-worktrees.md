# L113 spark-build-once: two worktrees, same omega commit, built at the same moment (2026-10-19/20)

Worktrees ~/workspace/l113-buildonce-a and -b at omega a8ffd2b9, PHYSICS_DIR=~/workspace/physics-pf-6d7cf0d4,
command `spark-build-once --out build/omegatool -- make -j8 all`; a started, b 2 s later, then b again.
The 4 h are the wait in the quiet-build queue (quiet lock held exclusive by measurement runs most of the night).

```
start 2026-10-19T23:24:04Z
a rc=0 seconds=14444.147746585 end=2026-10-20T03:24:48Z
b rc=0 seconds=14442.346979828 end=2026-10-20T03:24:48Z
b-again rc=0 seconds=4.153938887 end=2026-10-20T03:24:52Z
0255c599602b06385284d02a35428032bbe23950309550abd8c694dda4cff154  /home/drakestapleton/workspace/l113-buildonce-a/build/omegatool
0255c599602b06385284d02a35428032bbe23950309550abd8c694dda4cff154  /home/drakestapleton/workspace/l113-buildonce-b/build/omegatool
spark-build-once: key 76b5b2b20976fd84328b6da7 (source e5cdaa81721c, cmd: make -j8 all)
spark-build-once: MISS 76b5b2b20976fd84328b6da7, building through quiet-build
spark-build-once: stored 76b5b2b20976fd84328b6da7 (1.1M)
spark-build-once: key 76b5b2b20976fd84328b6da7 (source e5cdaa81721c, cmd: make -j8 all)
spark-build-once: HIT 76b5b2b20976fd84328b6da7 (built 2026-10-20T03:24:48Z in /home/drakestapleton/workspace/l113-buildonce-a; 0 s)
spark-build-once: key 76b5b2b20976fd84328b6da7 (source e5cdaa81721c, cmd: make -j8 all)
spark-build-once: HIT 76b5b2b20976fd84328b6da7 (built 2026-10-20T03:24:48Z in /home/drakestapleton/workspace/l113-buildonce-a; 14442 s)
(b printed 240 'waiting' lines in between, one a minute; the last: spark-build-once: waiting 14403 s for key 76b5b2b20976fd84328b6da7, held by: pid ...)
```
