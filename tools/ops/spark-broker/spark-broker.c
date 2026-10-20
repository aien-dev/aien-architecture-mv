/* spark-broker: one queue for the Spark's two scarce things, the GB10 chip
 * and the quiet state used for timings (ledger L118, docs/ops/BROKER.md).
 *
 * Agents never wait inside a lock. They connect (spark-job), say what kind
 * of job they have, and wait in this queue until it is their turn. The
 * broker only decides turns; the caller runs its own command, so the
 * command keeps its own directory, environment, output and exit code.
 *
 *   build    runs whenever no measurement is draining or running, at most
 *            -b at once, and only while load1 is under -L (a build that has
 *            waited -N ms ignores the load ceiling).
 *   chip     a correctness run on the chip: one broker chip job at a time;
 *            the caller then takes /tmp/aien-gb10.lock itself, so the 27B
 *            server and anything unconverted keep using that lock as today.
 *   measure  one at a time. Order: get the chip turn (waiting here, builds
 *            keep running), the caller takes the GB10 lock, then the broker
 *            stops starting builds and waits for running builds to finish
 *            (at most -D ms), then the caller opens the quiet window and runs.
 *
 * Fairness: measurements go ahead of chip jobs; a chip job that has waited
 * -N ms goes ahead of the next measurement; while any build has waited -N
 * ms, no new measurement starts (so a build waits at most N plus the
 * measurement already running).
 *
 * Protocol (one line per message, text):
 *   client: SUB <class> <needchip 0|1> <parent id|0> <pid> <name>\t<cmd>
 *   broker: ID <id>          then later GO (build/chip: start; measure: take the chip)
 *                            and, for measure, QUIET (builds drained: open window, run)
 *   client: ST <word>        lockwait | chip | run | done <rc>   (status only)
 *   client: STATUS           broker prints the queue and closes
 *   client: WAIT <id>        broker answers DONE <rc> when that job ends
 * A job ends when its client closes the connection (normal end, crash or
 * kill), so a dead caller can never hold a turn.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#define MAXC 512
#define MAXDONE 256

enum { S_FREE, S_CTL, S_Q, S_GO, S_DRAIN, S_RUN };
static const char *SN[] = { "free", "ctl", "queued", "granted", "draining", "running" };

typedef struct {
  int fd, state, needchip, waitfor;
  char cls;                 /* 'B' build, 'C' chip, 'M' measure, 0 control */
  long id, parent, pid, rc;
  long long t_sub, t_go, t_drain, t_run;
  char word[16], name[64], cmd[400];
  char in[1024]; int inlen;
} job_t;

typedef struct { long id; long rc; char cls; long long t_sub, t_go, t_end; char name[64]; } done_t;

static job_t J[MAXC];
static done_t D[MAXDONE]; static int nd;
static long next_id = 1;
static long long N_ms = 600000, D_ms = 600000, tick_ms = 1000;
static int maxb = 6; static double loadcap = 32.0;
static const char *loadfile = "/proc/loadavg";
static FILE *logf;

static long long now_ms(void) {
  struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
  return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
static void logev(const char *fmt, ...) {
  if (!logf) return;
  long long t = now_ms(); time_t s = t / 1000; struct tm tm; gmtime_r(&s, &tm);
  char b[32]; strftime(b, sizeof b, "%Y-%m-%dT%H:%M:%S", &tm);
  fprintf(logf, "%s.%03lldZ %lld ", b, t % 1000, t);
  va_list ap; va_start(ap, fmt); vfprintf(logf, fmt, ap); va_end(ap);
  fputc('\n', logf); fflush(logf);
}
static void say(job_t *j, const char *fmt, ...) {
  char b[512]; va_list ap; va_start(ap, fmt); int n = vsnprintf(b, sizeof b, fmt, ap); va_end(ap);
  if (n > 0 && j->fd >= 0) (void)!send(j->fd, b, (size_t)n < sizeof b ? (size_t)n : sizeof b - 1, MSG_NOSIGNAL);
}
static double load1(void) {
  FILE *f = fopen(loadfile, "r"); double l = 0;
  if (f) { if (fscanf(f, "%lf", &l) != 1) l = 0; fclose(f); }
  return l;
}
/* renice a caller and every process below it (used only when the drain cap runs out) */
static void renice_tree(long root, int prio) {
  long pids[4096], ppids[4096]; int n = 0;
  FILE *ls = popen("ps -e -o pid=,ppid=", "r");
  if (!ls) return;
  while (n < 4096 && fscanf(ls, "%ld %ld", &pids[n], &ppids[n]) == 2) n++;
  pclose(ls);
  long todo[4096]; int nt = 0; todo[nt++] = root;
  for (int k = 0; k < nt && nt < 4096; k++) {
    setpriority(PRIO_PROCESS, (id_t)todo[k], prio);
    for (int i = 0; i < n && nt < 4096; i++) if (ppids[i] == todo[k]) todo[nt++] = pids[i];
  }
}

static job_t *byid(long id) {
  for (int i = 0; i < MAXC; i++) if (J[i].state >= S_Q && J[i].id == id) return &J[i];
  return NULL;
}
/* is build b the parent (or ancestor) of job j? nested callers must not wait for their own parent */
static int ancestor(job_t *b, job_t *j) {
  for (long p = j->parent, hops = 0; p && hops < 16; hops++) {
    if (p == b->id) return 1;
    job_t *q = byid(p); if (!q) return 0; p = q->parent;
  }
  return 0;
}

static void finish(job_t *j, const char *why) {
  if (j->state >= S_Q) {
    long long t = now_ms();
    logev("end id=%ld class=%c rc=%ld state=%s why=%s waited_ms=%lld ran_ms=%lld name=%s",
          j->id, j->cls, j->rc, SN[j->state], why, (j->t_go ? j->t_go : t) - j->t_sub,
          j->t_go ? t - j->t_go : 0, j->name);
    done_t *d = &D[nd++ % MAXDONE];
    d->id = j->id; d->rc = j->rc; d->cls = j->cls; d->t_sub = j->t_sub; d->t_go = j->t_go; d->t_end = t;
    snprintf(d->name, sizeof d->name, "%s", j->name);
    for (int i = 0; i < MAXC; i++)      /* answer anyone waiting for this job */
      if (J[i].state == S_CTL && J[i].waitfor == j->id) { say(&J[i], "DONE %ld\n", j->rc); close(J[i].fd); J[i].fd = -1; J[i].state = S_FREE; }
  }
  if (j->fd >= 0) close(j->fd);
  memset(j, 0, sizeof *j); j->fd = -1; j->state = S_FREE;
}

static void grant(job_t *j, int st, const char *msg) {
  j->state = st; j->t_go = now_ms();
  if (st == S_DRAIN) j->t_drain = j->t_go;
  if (msg) say(j, "%s\n", msg);
  logev("grant id=%ld class=%c to=%s waited_ms=%lld name=%s", j->id, j->cls, SN[st], j->t_go - j->t_sub, j->name);
}

static void schedule(void) {
  long long t = now_ms();
  job_t *meas = NULL, *chipown = NULL;
  int nbuild = 0, aged_build = 0;
  for (int i = 0; i < MAXC; i++) {
    job_t *j = &J[i];
    if (j->state < S_Q) continue;
    if (j->cls == 'M' && j->state >= S_GO) meas = j;
    if (j->needchip && j->state >= S_GO) chipown = j;
    if (j->cls == 'B' && j->state >= S_GO) nbuild++;
    if (j->cls == 'B' && j->state == S_Q && t - j->t_sub >= N_ms) aged_build = 1;
  }

  /* 1. the chip turn (and the measurement turn); no chip job starts during a measurement */
  if (!chipown && !(meas && meas->state >= S_DRAIN)) {
    job_t *pick = NULL;
    for (int pass = 0; pass < 3 && !pick; pass++)
      for (int i = 0; i < MAXC; i++) {
        job_t *j = &J[i];
        if (j->state != S_Q || !j->needchip) continue;
        int ok = pass == 0 ? (j->cls == 'C' && t - j->t_sub >= N_ms)          /* aged chip job */
               : pass == 1 ? (j->cls == 'M' && !meas && !aged_build)          /* next measurement */
               :             (j->cls == 'C');                                  /* chip job */
        if (ok && (!pick || j->id < pick->id)) pick = j;
      }
    if (pick) { grant(pick, pick->cls == 'M' ? S_GO : S_RUN, "GO"); if (pick->cls == 'M') meas = pick; chipown = pick; }
  }
  /* a measurement that does not need the chip only needs the measurement turn */
  if (!meas && !aged_build) {
    job_t *pick = NULL;
    for (int i = 0; i < MAXC; i++)
      if (J[i].state == S_Q && J[i].cls == 'M' && !J[i].needchip && (!pick || J[i].id < pick->id)) pick = &J[i];
    if (pick) { grant(pick, S_DRAIN, "GO"); meas = pick; }
  }

  /* 2. drain: a measurement holding the chip waits here for running builds, at most D */
  if (meas && meas->state == S_DRAIN) {
    int left = 0;
    for (int i = 0; i < MAXC; i++)      /* running builds, and (for a no-chip measurement) a running chip job */
      if ((J[i].cls == 'B' || (J[i].cls == 'C' && !meas->needchip)) && J[i].state >= S_GO && !ancestor(&J[i], meas)) left++;
    if (left == 0 || t - meas->t_drain >= D_ms) {
      meas->state = S_RUN; meas->t_run = t;
      say(meas, "QUIET %d\n", left);
      logev("quiet id=%ld drained_ms=%lld builds_still_running=%d name=%s", meas->id, t - meas->t_drain, left, meas->name);
      if (left)                       /* drain cap reached: push the leftovers to the back of the CPU */
        for (int i = 0; i < MAXC; i++)
          if (J[i].cls == 'B' && J[i].state >= S_GO && J[i].pid > 0 && !ancestor(&J[i], meas))
            { renice_tree(J[i].pid, 19); say(&J[i], "YIELD\n"); }
    }
  }

  /* 3. builds */
  int quiet_needed = meas && meas->state >= S_DRAIN;
  if (!quiet_needed) {
    double l = -1;
    for (;;) {
      job_t *pick = NULL;
      for (int i = 0; i < MAXC; i++)
        if (J[i].state == S_Q && J[i].cls == 'B' && (!pick || J[i].id < pick->id)) pick = &J[i];
      if (!pick || nbuild >= maxb) break;
      int aged = t - pick->t_sub >= N_ms;
      if (!aged) { if (l < 0) l = load1(); if (l >= loadcap) break; }
      grant(pick, S_RUN, "GO"); nbuild++;
      if (!aged) break;               /* one load-gated start per tick: load1 lags a minute behind */
    }
  }
}

static void status(job_t *c) {
  long long t = now_ms();
  say(c, "spark-broker: build cap %d, load ceiling %.1f (load1 now %.2f), age rule %lld s, drain cap %lld s\n",
      maxb, loadcap, load1(), N_ms / 1000, D_ms / 1000);
  say(c, "%-6s %-7s %-9s %8s %8s %8s  %s\n", "id", "class", "state", "waited_s", "turn_s", "pid", "name / command");
  int n = 0;
  for (int k = 0; k < 2; k++)
    for (int i = 0; i < MAXC; i++) {
      job_t *j = &J[i];
      if (j->state < S_Q || (k == 0) != (j->state >= S_GO)) continue;
      const char *cl = j->cls == 'B' ? "build" : j->cls == 'C' ? "chip" : "measure";
      say(c, "%-6ld %-7s %-9s %8lld %8lld %8ld  %s%s%s | %.150s\n", j->id, cl,
          j->word[0] && j->state >= S_GO ? (strcmp(j->word, "run") ? j->word : "running") : SN[j->state],
          ((j->t_go ? j->t_go : t) - j->t_sub) / 1000, j->t_go ? (t - j->t_go) / 1000 : 0, j->pid,
          j->name, j->needchip ? " [chip]" : "", j->parent ? " [nested]" : "", j->cmd);
      n++;
    }
  if (!n) say(c, "(queue empty)\n");
  int shown = 0;
  for (int k = nd - 1; k >= 0 && k >= nd - MAXDONE && shown < 8; k--, shown++) {
    done_t *d = &D[k % MAXDONE];
    if (!shown) say(c, "last finished:\n");
    say(c, "  #%ld %c rc=%ld waited %llds ran %llds ended %llds ago  %s\n", d->id, d->cls, d->rc,
        ((d->t_go ? d->t_go : d->t_end) - d->t_sub) / 1000, d->t_go ? (d->t_end - d->t_go) / 1000 : 0,
        (t - d->t_end) / 1000, d->name);
  }
}

static void line(job_t *j, char *s) {
  if (!strncmp(s, "SUB ", 4)) {
    char cls[16] = ""; int nc = 0; long par = 0, pid = 0; int off = 0;
    if (sscanf(s + 4, "%15s %d %ld %ld %n", cls, &nc, &par, &pid, &off) < 4) { say(j, "ERR bad SUB\n"); return; }
    char *rest = s + 4 + off, *tab = strchr(rest, '\t');
    if (tab) { *tab = 0; snprintf(j->cmd, sizeof j->cmd, "%s", tab + 1); }
    snprintf(j->name, sizeof j->name, "%s", rest);
    j->cls = !strcmp(cls, "build") ? 'B' : !strcmp(cls, "chip") ? 'C' : !strcmp(cls, "measure") ? 'M' : 0;
    if (!j->cls) { say(j, "ERR class must be build, chip or measure\n"); return; }
    j->needchip = j->cls == 'C' || (j->cls == 'M' && nc); j->parent = par; j->pid = pid;
    j->id = next_id++; j->t_sub = now_ms(); j->state = S_Q;
    say(j, "ID %ld\n", j->id);
    logev("submit id=%ld class=%c chip=%d parent=%ld pid=%ld name=%s cmd=%.200s", j->id, j->cls, j->needchip, par, pid, j->name, j->cmd);
  } else if (!strncmp(s, "ST ", 3) && j->state >= S_Q) {
    snprintf(j->word, sizeof j->word, "%.15s", s + 3);
    if (!strncmp(s + 3, "done ", 5)) { j->rc = atol(s + 8); snprintf(j->word, sizeof j->word, "done"); }
    else {
      logev("state id=%ld class=%c word=%s", j->id, j->cls, j->word);
      if (j->cls == 'M' && j->state == S_GO && !strcmp(j->word, "chip")) { j->state = S_DRAIN; j->t_drain = now_ms(); }
    }
  } else if (!strcmp(s, "STATUS")) {
    status(j); close(j->fd); j->fd = -1; j->state = S_FREE;
  } else if (!strncmp(s, "WAIT ", 5)) {
    long id = atol(s + 5);
    if (byid(id)) { j->waitfor = id; return; }
    for (int k = nd - 1; k >= 0 && k >= nd - MAXDONE; k--)
      if (D[k % MAXDONE].id == id) { say(j, "DONE %ld\n", D[k % MAXDONE].rc); goto out; }
    say(j, "UNKNOWN %ld\n", id);
  out: close(j->fd); j->fd = -1; j->state = S_FREE;
  } else if (!strcmp(s, "PING")) {
    say(j, "PONG\n");
  }
}

static void usage(void) {
  fprintf(stderr, "usage: spark-broker [-s SOCKET] [-l LOG] [-b MAXBUILDS] [-L LOADCEIL] [-N AGE_MS] [-D DRAIN_MS] [-t TICK_MS] [-f LOADFILE]\n");
  exit(2);
}

int main(int argc, char **argv) {
  const char *home = getenv("HOME");
  char sockp[256], logp[300], lockp[300];
  snprintf(sockp, sizeof sockp, "%s", getenv("SPARK_BROKER_SOCK") ? getenv("SPARK_BROKER_SOCK") : "/tmp/spark-broker/sock");
  snprintf(logp, sizeof logp, "%s/.local/state/spark-broker/events.log", home ? home : "/tmp");
  int o;
  while ((o = getopt(argc, argv, "s:l:b:L:N:D:t:f:")) != -1) switch (o) {
    case 's': snprintf(sockp, sizeof sockp, "%s", optarg); break;
    case 'l': snprintf(logp, sizeof logp, "%s", optarg); break;
    case 'b': maxb = atoi(optarg); break;
    case 'L': loadcap = atof(optarg); break;
    case 'N': N_ms = atoll(optarg); break;
    case 'D': D_ms = atoll(optarg); break;
    case 't': tick_ms = atoll(optarg); break;
    case 'f': loadfile = optarg; break;
    default: usage();
  }
  signal(SIGPIPE, SIG_IGN);
  { char d[256]; snprintf(d, sizeof d, "%s", sockp); char *sl = strrchr(d, '/'); if (sl) { *sl = 0; mkdir(d, 0700); } }
  { char d[300]; snprintf(d, sizeof d, "%s", logp); char *sl = strrchr(d, '/'); if (sl) { *sl = 0; char c[320]; snprintf(c, sizeof c, "mkdir -p '%s'", d); (void)!system(c); } }
  snprintf(lockp, sizeof lockp, "%s.lock", sockp);
  int lk = open(lockp, O_RDWR | O_CREAT | O_CLOEXEC, 0600);
  if (lk < 0 || flock(lk, LOCK_EX | LOCK_NB) < 0) { fprintf(stderr, "spark-broker: another broker owns %s\n", sockp); return 1; }
  logf = fopen(logp, "a");
  { char pp[300]; snprintf(pp, sizeof pp, "%s.pid", sockp); FILE *pf = fopen(pp, "w"); if (pf) { fprintf(pf, "%d\n", getpid()); fclose(pf); } }
  if (strlen(sockp) >= sizeof ((struct sockaddr_un *)0)->sun_path) { fprintf(stderr, "spark-broker: socket path too long\n"); return 2; }
  unlink(sockp);
  int ls = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  struct sockaddr_un a = { .sun_family = AF_UNIX };
  snprintf(a.sun_path, sizeof a.sun_path, "%s", sockp);
  if (ls < 0 || bind(ls, (struct sockaddr *)&a, sizeof a) < 0 || listen(ls, 64) < 0) { perror("spark-broker: socket"); return 1; }
  chmod(sockp, 0600);
  for (int i = 0; i < MAXC; i++) J[i].fd = -1;
  logev("start pid=%d maxb=%d loadcap=%.1f N_ms=%lld D_ms=%lld tick_ms=%lld sock=%s", getpid(), maxb, loadcap, N_ms, D_ms, tick_ms, sockp);
  fprintf(stderr, "spark-broker: listening on %s (log %s)\n", sockp, logp);

  struct pollfd P[MAXC + 1]; int map[MAXC + 1];
  for (;;) {
    int n = 0;
    P[n].fd = ls; P[n].events = POLLIN; map[n++] = -1;
    for (int i = 0; i < MAXC; i++) if (J[i].state != S_FREE && J[i].fd >= 0) { P[n].fd = J[i].fd; P[n].events = POLLIN; map[n++] = i; }
    int r = poll(P, (nfds_t)n, (int)tick_ms);
    if (r < 0 && errno != EINTR) { perror("poll"); return 1; }
    for (int k = 0; r > 0 && k < n; k++) {
      if (!P[k].revents) continue;
      if (map[k] < 0) {
        int c = accept4(ls, NULL, NULL, SOCK_CLOEXEC);
        if (c < 0) continue;
        int slot = -1;
        for (int i = 0; i < MAXC; i++) if (J[i].state == S_FREE) { slot = i; break; }
        if (slot < 0) { (void)!write(c, "ERR full\n", 9); close(c); continue; }
        memset(&J[slot], 0, sizeof J[slot]); J[slot].fd = c; J[slot].state = S_CTL;
        continue;
      }
      job_t *j = &J[map[k]];
      ssize_t m = recv(j->fd, j->in + j->inlen, sizeof j->in - 1 - (size_t)j->inlen, 0);
      if (m <= 0) { finish(j, j->word[0] && !strcmp(j->word, "done") ? "done" : "caller gone"); continue; }
      j->inlen += (int)m; j->in[j->inlen] = 0;
      char *s = j->in, *nl;
      while (j->state != S_FREE && (nl = strchr(s, '\n'))) { *nl = 0; line(j, s); s = nl + 1; }
      if (j->state == S_FREE) continue;
      j->inlen = (int)strlen(s); memmove(j->in, s, (size_t)j->inlen + 1);
      if (j->inlen >= (int)sizeof j->in - 1) j->inlen = 0;
    }
    schedule();
  }
}
