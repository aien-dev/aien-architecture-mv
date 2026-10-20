#!/bin/sh
# analyze.sh trials.tsv : per metric and condition n/median/min/max/range, then the pre-registered gate
# (PREDICTION.md): P passes a metric when median(P) lies inside [min(Q), max(Q)] and range(P) <= 1.5 x range(Q).
# The negative control U must fail at least one metric, or the test is called blind (INCONCLUSIVE).
T=$1
awk -F'\t' 'NR>1 && $1!="warm" {
  split("7 9 10 11 12", c, " "); split("gpu_ns gpu_wall_s m1_GBps m8_GBps spin_ns", nm, " ")
  for (i = 1; i <= 5; i++) if ($(c[i]) != "NA" && $(c[i]) != "") { k = $1 SUBSEP nm[i]; n[k]++; v[k, n[k]] = $(c[i]) + 0 }
  if ($6 > 0) ob[$1]++; tot[$1]++
}
function sortk(k, m,  i, j, t) { for (i = 1; i <= m; i++) s[i] = v[k, i]; for (i = 2; i <= m; i++) { t = s[i]; for (j = i - 1; j >= 1 && s[j] > t; j--) s[j + 1] = s[j]; s[j + 1] = t } }
function stat(k,  m) { m = n[k]; if (!m) { md = mn = mx = "NA"; return 0 } sortk(k, m); md = (m % 2) ? s[(m + 1) / 2] : (s[m / 2] + s[m / 2 + 1]) / 2; mn = s[1]; mx = s[m]; return m }
END {
  split("gpu_ns m1_GBps m8_GBps spin_ns gpu_wall_s", nm, " ")
  printf "%-11s %-4s %3s %14s %14s %14s %10s %9s\n", "metric", "cond", "n", "median", "min", "max", "range%", "shift%"
  for (i = 1; i <= 5; i++) {
    stat("Q" SUBSEP nm[i]); qmd = md; qmn = mn; qmx = mx; qr = mx - mn
    for (cc = 1; cc <= 3; cc++) { cd = substr("QPU", cc, 1); m = stat(cd SUBSEP nm[i]); if (!m) continue
      printf "%-11s %-4s %3d %14.4f %14.4f %14.4f %10.2f %9.2f", nm[i], cd, m, md, mn, mx, 100 * (mx - mn) / qmd, 100 * (md - qmd) / qmd
      if (cd != "Q" && i <= 4) { ok = (md >= qmn && md <= qmx && (mx - mn) <= 1.5 * qr); printf "  %s", ok ? "PASS" : "FAIL"; if (!ok) fail[cd]++ }
      printf "\n" } }
  printf "\ntrials with other agents builds running: Q %d/%d  P %d/%d  U %d/%d\n", ob["Q"], tot["Q"], ob["P"], tot["P"], ob["U"], tot["U"]
  printf "GATE (P vs Q, 4 metrics): %s\n", fail["P"] ? "FAIL (" fail["P"] " metric(s))" : "PASS"
  printf "NEGATIVE CONTROL (U must fail >=1): %s\n", fail["U"] ? "OK, U failed " fail["U"] " metric(s)" : "BLIND, U passed all: INCONCLUSIVE"
}' "$T"
