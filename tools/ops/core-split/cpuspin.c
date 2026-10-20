/* cpuspin: fixed single-thread integer work (a dependent xorshift/multiply chain that fits in
 * registers, so it measures core speed and scheduling, not memory). Prints one line:
 *   cpuspin iters=N ns=T cpu_start=C cpu_end=C sink=S
 * The CPU numbers are the camera: they show the run stayed on the cores it was pinned to. */
#define _GNU_SOURCE
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static uint64_t ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (uint64_t)t.tv_sec * 1000000000u + t.tv_nsec; }
int main(int argc, char **argv) {
    uint64_t n = argc > 1 ? strtoull(argv[1], 0, 10) : 300000000u, x = 88172645463325252u;
    int c0 = sched_getcpu(); uint64_t t0 = ns();
    for (uint64_t i = 0; i < n; i++) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; x *= 0x9E3779B97F4A7C15u; }
    uint64_t t1 = ns(); int c1 = sched_getcpu();
    printf("cpuspin iters=%llu ns=%llu cpu_start=%d cpu_end=%d sink=%llu\n", (unsigned long long)n,
           (unsigned long long)(t1 - t0), c0, c1, (unsigned long long)x);
    return 0;
}
