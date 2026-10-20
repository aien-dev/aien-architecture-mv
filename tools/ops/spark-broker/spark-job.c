/* spark-job: hand a job to spark-broker and run it when the broker says so.
 *
 *   spark-job build CMD...                        build or CPU-heavy job (runs at nice 5)
 *   spark-job chip CMD...                         correctness run on the GB10 chip
 *   spark-job measure [--no-chip] [--no-receipt] [--ledger ID] NAME CMD...
 *                                                 a timing: chip turn, builds drained,
 *                                                 then a spark-window, then CMD
 *   spark-job status                              the queue, what runs, wait ages, lock holders
 *   spark-job wait ID                             block until job ID ends; exit with its code
 *
 * The waiting happens in the broker's queue, never inside a lock. When the
 * turn comes this program takes the old lock files itself (shared quiet
 * lock for a build, the GB10 lock for chip work, the exclusive quiet lock
 * through spark-window for a measurement), so the 27B server and anything
 * not yet converted keep working exactly as before.
 * Inside a job (SPARK_JOB set) a nested call runs at once when its parent
 * already holds what it needs. With no broker running, it falls back to the
 * old lock wrappers (quiet-build.locks, quiet-measure.locks) and says so.
 * Environment: SPARK_BROKER_SOCK, SPARK_QUIET_LOCK, SPARK_GB10_LOCK,
 * SPARK_JOB_WINDOW=0 (take the quiet lock directly, no spark-window),
 * SPARK_JOB_LEGACY_DIR (where the old wrappers live).
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
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static int sock = -1;
static pid_t child;
static char rbuf[4096]; static int rlen;

static const char *env(const char *k, const char *d) { const char *v = getenv(k); return v && *v ? v : d; }
static void die(const char *m) { fprintf(stderr, "spark-job: %s\n", m); exit(2); }

static void usage(void) {
  fprintf(stderr,
    "usage: spark-job build CMD...\n"
    "       spark-job chip CMD...\n"
    "       spark-job measure [--no-chip] [--no-receipt] [--ledger ID] NAME CMD...\n"
    "       spark-job status\n"
    "       spark-job wait ID\n");
  exit(2);
}

static int connect_broker(void) {
  const char *p = env("SPARK_BROKER_SOCK", "/tmp/spark-broker/sock");
  int s = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  struct sockaddr_un a = { .sun_family = AF_UNIX };
  if (s < 0 || strlen(p) >= sizeof a.sun_path) return -1;
  strcpy(a.sun_path, p);
  if (connect(s, (struct sockaddr *)&a, sizeof a) < 0) { close(s); return -1; }
  return s;
}
static void sendf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void sendf(const char *fmt, ...) {
  char b[2048]; va_list ap; va_start(ap, fmt); int n = vsnprintf(b, sizeof b, fmt, ap); va_end(ap);
  if (n > 0 && sock >= 0) (void)!send(sock, b, (size_t)n < sizeof b ? (size_t)n : sizeof b - 1, MSG_NOSIGNAL);
}
/* read one line from the broker; prints a "still waiting" line every minute */
static int readline(char *out, size_t cap, const char *what, long id) {
  time_t t0 = time(NULL), last = t0;
  for (;;) {
    char *nl = memchr(rbuf, '\n', (size_t)rlen);
    if (nl) {
      size_t n = (size_t)(nl - rbuf); if (n >= cap) n = cap - 1;
      memcpy(out, rbuf, n); out[n] = 0;
      rlen -= (int)(nl - rbuf + 1); memmove(rbuf, nl + 1, (size_t)rlen);
      return 0;
    }
    struct pollfd p = { .fd = sock, .events = POLLIN };
    int r = poll(&p, 1, 5000);
    if (r < 0 && errno == EINTR) continue;
    if (r > 0) {
      ssize_t m = recv(sock, rbuf + rlen, sizeof rbuf - 1 - (size_t)rlen, 0);
      if (m <= 0) return -1;
      rlen += (int)m;
    }
    if (what && time(NULL) - last >= 60) {
      last = time(NULL);
      fprintf(stderr, "spark-job: #%ld still %s after %ld s (spark-job status shows the queue)\n", id, what, (long)(last - t0));
    }
  }
}

static void fwd(int sig) { if (child > 0) kill(child, sig); }
static int yield_fd = -1;   /* a build's shared quiet lock: dropped when the broker says YIELD */
static void onchld(int sig) { (void)sig; }   /* wakes poll() when the child ends */

/* run argv as a child with the job's environment; returns its exit code */
static int run(char **argv, int nice_by) {
  child = fork();
  if (child < 0) die("fork failed");
  if (child == 0) {
    if (nice_by) setpriority(PRIO_PROCESS, 0, getpriority(PRIO_PROCESS, 0) + nice_by);
    execvp(argv[0], argv);
    fprintf(stderr, "spark-job: cannot run %s: %s\n", argv[0], strerror(errno));
    _exit(127);
  }
  int st;
  for (;;) {                  /* wait for the child; meanwhile a build listens for YIELD */
    pid_t w = waitpid(child, &st, yield_fd >= 0 && sock >= 0 ? WNOHANG : 0);
    if (w == child) break;
    if (w < 0) { if (errno == EINTR) continue; return 127; }
    struct pollfd p = { .fd = sock, .events = POLLIN };
    if (poll(&p, 1, 100) > 0) {
      char b[256]; ssize_t m = recv(sock, b, sizeof b - 1, 0);
      if (m <= 0) { close(sock); sock = -1; continue; }
      b[m] = 0;
      if (strstr(b, "YIELD")) {
        flock(yield_fd, LOCK_UN); close(yield_fd); yield_fd = -1;
        fprintf(stderr, "spark-job: build asked to yield to a measurement (drain cap): quiet lock released, running at nice 19\n");
      }
    }
  }
  child = 0;
  return WIFEXITED(st) ? WEXITSTATUS(st) : 128 + WTERMSIG(st);
}

static int lockfile(const char *path, int how) {
  int fd = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0666);
  if (fd < 0) fd = open(path, O_RDONLY | O_CLOEXEC);
  if (fd < 0) { fprintf(stderr, "spark-job: cannot open %s\n", path); exit(2); }
  while (flock(fd, how) < 0) if (errno != EINTR) { perror("spark-job: flock"); exit(2); }
  return fd;
}

/* fallback when no broker answers: the old lock wrappers */
static int legacy(const char *cls, int chip, char **cmd) {
  const char *dir = env("SPARK_JOB_LEGACY_DIR", NULL);
  char qb[512], qm[512]; const char *home = env("HOME", "/tmp");
  if (dir) { snprintf(qb, sizeof qb, "%s/quiet-build.locks", dir); snprintf(qm, sizeof qm, "%s/quiet-measure.locks", dir); }
  else { snprintf(qb, sizeof qb, "%s/.local/bin/quiet-build.locks", home); snprintf(qm, sizeof qm, "%s/.local/bin/quiet-measure.locks", home); }
  fprintf(stderr, "spark-job: no broker answering; using the old lock wrappers for this %s job\n", cls);
  int n = 0; while (cmd[n]) n++;
  char **a = calloc((size_t)n + 4, sizeof *a); int k = 0;
  const char *g = env("SPARK_GB10_LOCK", "/tmp/aien-gb10.lock");
  if (!strcmp(cls, "build")) a[k++] = qb;
  else if (!strcmp(cls, "measure")) { a[k++] = qm; if (chip) { a[k++] = "flock"; a[k++] = (char *)g; } }
  else { a[k++] = "flock"; a[k++] = (char *)g; }
  for (int i = 0; i < n; i++) a[k++] = cmd[i];
  a[k] = NULL;
  return run(a, 0);
}

/* no broker answering: start one (detached, its own session) unless SPARK_BROKER_AUTOSTART=0.
 * Two callers racing here is safe: the broker refuses to start twice (lock on SOCKET.lock). */
static int autostart(void) {
  if (!strcmp(env("SPARK_BROKER_AUTOSTART", "1"), "0")) return 0;
  char self[512], bin[600]; ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
  if (n <= 0) return 0;
  self[n] = 0; char *sl = strrchr(self, '/'); if (sl) *sl = 0;
  snprintf(bin, sizeof bin, "%s/spark-broker", self);
  if (access(bin, X_OK)) return 0;
  pid_t p = fork();
  if (p == 0) {
    setsid();
    int nul = open("/dev/null", O_RDWR); if (nul >= 0) { dup2(nul, 0); dup2(nul, 1); dup2(nul, 2); }
    if (fork() == 0) { execl(bin, "spark-broker", (char *)NULL); _exit(127); }
    _exit(0);
  }
  if (p > 0) waitpid(p, NULL, 0);
  for (int i = 0; i < 40; i++) { int s = connect_broker(); if (s >= 0) { close(s); fprintf(stderr, "spark-job: started spark-broker (%s)\n", bin); return 1; } usleep(50000); }
  return 0;
}

static int status_cmd(void) {
  sock = connect_broker();
  if (sock < 0) printf("spark-broker is not running (jobs fall back to the old lock wrappers)\n");
  else {
    sendf("STATUS\n");
    char b[4096]; ssize_t m;
    while ((m = recv(sock, b, sizeof b, 0)) > 0) fwrite(b, 1, (size_t)m, stdout);
  }
  fflush(stdout);
  if (strcmp(env("SPARK_JOB_WINDOW", "1"), "0")) {
    printf("lock files (kernel lock table):\n"); fflush(stdout);
    char *a[] = { "spark-window", "locks", NULL };
    run(a, 0);
  }
  return 0;
}

int main(int argc, char **argv) {
  if (argc < 2) usage();
  signal(SIGPIPE, SIG_IGN);
  const char *cls = argv[1];
  if (!strcmp(cls, "status")) return status_cmd();
  if (!strcmp(cls, "wait")) {
    if (argc < 3) usage();
    sock = connect_broker(); if (sock < 0) die("no broker running");
    sendf("WAIT %ld\n", atol(argv[2]));
    char l[256]; if (readline(l, sizeof l, "waiting", atol(argv[2])) < 0) die("broker went away");
    if (!strncmp(l, "DONE ", 5)) return atoi(l + 5);
    fprintf(stderr, "spark-job: %s\n", l); return 2;
  }
  int chip = 0, receipt = 1, i = 2; const char *ledger = NULL, *name = NULL;
  if (!strcmp(cls, "chip")) chip = 1;
  else if (!strcmp(cls, "measure")) {
    chip = 1;
    for (; i < argc && !strncmp(argv[i], "--", 2); i++) {
      if (!strcmp(argv[i], "--no-chip")) chip = 0;
      else if (!strcmp(argv[i], "--no-receipt")) receipt = 0;
      else if (!strcmp(argv[i], "--ledger") && i + 1 < argc) ledger = argv[++i];
      else if (!strcmp(argv[i], "--")) { i++; break; }
      else usage();
    }
    if (i >= argc) usage();
    name = argv[i++];
  } else if (strcmp(cls, "build")) usage();
  if (i >= argc) usage();
  char **cmd = argv + i;

  char cmdline[400] = ""; size_t off = 0;
  for (char **c = cmd; *c && off < sizeof cmdline - 2; c++)
    off += (size_t)snprintf(cmdline + off, sizeof cmdline - off, "%s%s", c == cmd ? "" : " ", *c);
  for (char *c = cmdline; *c; c++) if (*c == '\n' || *c == '\t') *c = ' ';
  if (!name) { const char *b = strrchr(cmd[0], '/'); name = b ? b + 1 : cmd[0]; }

  /* nested: inside a job that already holds what this one needs, run at once */
  long parent = 0; char pcls = 0; int pchip = 0;
  const char *sj = getenv("SPARK_JOB");
  if (sj) sscanf(sj, "%ld:%c:%d", &parent, &pcls, &pchip);
  int nested_direct = parent && (!strcmp(cls, "build") || (chip && pchip) || (!strcmp(cls, "measure") && (pcls == 'M' || pchip)));
  if (nested_direct) return run(cmd, 0);

  sock = connect_broker();
  if (sock < 0 && autostart()) sock = connect_broker();
  if (sock < 0) return legacy(cls, chip, cmd);
  sendf("SUB %s %d %ld %ld %s\t%s\n", cls, chip, parent, (long)getpid(), name, cmdline);
  char l[256];
  if (readline(l, sizeof l, NULL, 0) < 0 || strncmp(l, "ID ", 3)) { fprintf(stderr, "spark-job: broker refused: %s\n", l); return legacy(cls, chip, cmd); }
  long id = atol(l + 3);
  fprintf(stderr, "spark-job: #%ld queued as %s%s (spark-job status shows the queue)\n", id, cls, chip ? " [chip]" : "");
  if (readline(l, sizeof l, "queued", id) < 0) { fprintf(stderr, "spark-job: broker went away while queued; using the old wrappers\n"); return legacy(cls, chip, cmd); }

  struct sigaction sa = { .sa_handler = fwd }; sigemptyset(&sa.sa_mask);
  sigaction(SIGTERM, &sa, NULL); sigaction(SIGINT, &sa, NULL); sigaction(SIGHUP, &sa, NULL);
  struct sigaction sc = { .sa_handler = onchld }; sigemptyset(&sc.sa_mask); sigaction(SIGCHLD, &sc, NULL);
  char sjv[64];
  snprintf(sjv, sizeof sjv, "%ld:%c:%d", id, cls[0] == 'b' ? 'B' : cls[0] == 'c' ? 'C' : 'M', chip);
  setenv("SPARK_JOB", sjv, 1);
  const char *Q = env("SPARK_QUIET_LOCK", "/tmp/aien-quiet.lock"), *G = env("SPARK_GB10_LOCK", "/tmp/aien-gb10.lock");
  int rc;

  if (!strcmp(cls, "build")) {
    int q = open(Q, O_RDWR | O_CREAT | O_CLOEXEC, 0666);      /* honour old exclusive holders */
    if (q >= 0 && flock(q, LOCK_SH | LOCK_NB) < 0) { sendf("ST lockwait\n"); while (flock(q, LOCK_SH) < 0 && errno == EINTR) ; }
    sendf("ST run\n");
    yield_fd = q;
    rc = run(cmd, 5);
  } else if (!strcmp(cls, "chip")) {
    sendf("ST lockwait\n");
    lockfile(G, LOCK_EX);
    setenv("AIEN_GB10_LOCK_HELD", "1", 1);
    sendf("ST run\n");
    rc = run(cmd, 0);
  } else {
    if (chip) {
      sendf("ST lockwait\n");
      lockfile(G, LOCK_EX);
      setenv("AIEN_GB10_LOCK_HELD", "1", 1);
      sendf("ST chip\n");
    }
    if (readline(l, sizeof l, "draining builds", id) < 0 || strncmp(l, "QUIET", 5)) { fprintf(stderr, "spark-job: broker went away before the quiet turn\n"); return 2; }
    if (atoi(l + 6)) fprintf(stderr, "spark-job: #%ld drain cap reached, %d build(s) still running at nice 19\n", id, atoi(l + 6));
    if (!strcmp(env("SPARK_JOB_WINDOW", "1"), "0")) {
      lockfile(Q, LOCK_EX);
      sendf("ST run\n");
      if (receipt) {
        int n = 0; while (cmd[n]) n++;
        char **a = calloc((size_t)n + 4, sizeof *a); a[0] = "spark-receipt"; a[1] = (char *)name; a[2] = "--";
        memcpy(a + 3, cmd, (size_t)n * sizeof *a); rc = run(a, 0);
      } else rc = run(cmd, 0);
    } else {
      /* open a window (spark-window takes the quiet lock exclusive through quiet-measure) */
      char wid[128] = ""; int tries = 0;
      for (;;) {
        int pfd[2]; if (pipe(pfd) < 0) die("pipe failed");
        pid_t w = fork();
        if (w == 0) {
          dup2(pfd[1], 1); close(pfd[0]); close(pfd[1]);
          if (ledger) execlp("spark-window", "spark-window", "open", name, "--ledger", ledger, (char *)NULL);
          else execlp("spark-window", "spark-window", "open", name, (char *)NULL);
          _exit(127);
        }
        close(pfd[1]);
        ssize_t m = read(pfd[0], wid, sizeof wid - 1); close(pfd[0]);
        wid[m > 0 ? m : 0] = 0; char *nl = strchr(wid, '\n'); if (nl) *nl = 0;
        int st; waitpid(w, &st, 0);
        if (WIFEXITED(st) && WEXITSTATUS(st) == 0 && wid[0]) break;
        if (!(WIFEXITED(st) && WEXITSTATUS(st) == 3)) { fprintf(stderr, "spark-job: spark-window open failed\n"); sendf("ST done 2\n"); return 2; }
        if (tries++ % 12 == 0) fprintf(stderr, "spark-job: #%ld another window is open; waiting for it to close\n", id);
        sendf("ST windowwait\n");
        sleep(5);
      }
      fprintf(stderr, "spark-job: #%ld window %s open\n", id, wid);
      sendf("ST run\n");
      int n = 0; while (cmd[n]) n++;
      char **a = calloc((size_t)n + 6, sizeof *a); int k = 0;
      a[k++] = "spark-window"; a[k++] = "run";
      if (receipt) { a[k++] = "spark-receipt"; a[k++] = (char *)name; a[k++] = "--"; }
      memcpy(a + k, cmd, (size_t)n * sizeof *a);
      rc = run(a, 0);
      char *c[] = { "spark-window", "close", wid, NULL };
      run(c, 0);
    }
  }
  sendf("ST done %d\n", rc);
  return rc;
}
