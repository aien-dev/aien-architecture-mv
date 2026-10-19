/*
 * crumb: reader for crumbs, the advisory notes a person writes next to code (RFC-0001 format, RFC-0003 Am2 model).
 * Single file, C11, no dependencies beyond libc and a `git` binary on PATH (for live commit lists and digests).
 *
 * RFC-0003 Amendment 2 (2026-10-19): crumbs are advisory notes. They never block a merge, nothing generated is
 * stored in them, and coordination (claims, locks, whispers, checkpoints) is the lane system, not crumbs.
 *
 *   crumb context <path>      the path's crumb chain (root first) plus the last commits touching it, computed live
 *   crumb explain <path>      same as context
 *   crumb sniff [agent] <dir> same as context for the directory
 *   crumb verify [root]       readability lint: every .crumb is JSON with string schema_version, name, purpose
 *   crumb status [root]       readable / unreadable per crumb
 *   crumb compile [root]      cleanup: strip stored generated data (extensions.generated, generated_policy,
 *                             provenance, seed); idempotent. `migrate` is an alias.
 *   crumb digest [dir]        print the structural digest block of dir, computed from the tree now (never stored)
 *   crumb create <dir> <name> <purpose> [layer]
 *   crumb sha256              sha256 of stdin (self-test helper)
 */
#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define SCHEMA "1.0.0"
#define AM2 "(advisory, RFC-0003 Am2)"
#define LANES_NOTE "coordination is the lane system (Spark ~/.local/state/aien-local-ci/LANES)"
#define CTX_COMMITS 5
#define CTX_LIST_MAX 12
#define CTX_STR_MAX 240

static void die(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "crumb: ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(1);
}
static void *xmalloc(size_t n) { void *p = malloc(n ? n : 1); if (!p) die("out of memory"); return p; }
static void *xrealloc(void *q, size_t n) { void *p = realloc(q, n ? n : 1); if (!p) die("out of memory"); return p; }
static char *xstrdup(const char *s) { size_t n = strlen(s) + 1; char *p = xmalloc(n); memcpy(p, s, n); return p; }

/* ---------- growable buffer ---------- */
typedef struct { char *p; size_t n, cap; } Buf;
static void bput(Buf *b, const char *s, size_t n) {
    if (b->n + n + 1 > b->cap) { b->cap = (b->n + n + 1) * 2; b->p = xrealloc(b->p, b->cap); }
    memcpy(b->p + b->n, s, n); b->n += n; b->p[b->n] = 0;
}
static void bstr(Buf *b, const char *s) { bput(b, s, strlen(s)); }
static void bfmt(Buf *b, const char *fmt, ...) {
    for (size_t cap = 256;;) {   /* heap buffer, grown on demand (fortify builds reject a NULL or 1-byte probe) */
        char *t = xmalloc(cap);
        va_list ap; va_start(ap, fmt); int n = vsnprintf(t, cap, fmt, ap); va_end(ap);
        if (n < 0) { free(t); return; }
        if ((size_t)n < cap) { bput(b, t, (size_t)n); free(t); return; }
        free(t); cap = (size_t)n + 1;
    }
}

/* ---------- minimal ordered JSON DOM (preserves unknown fields) ---------- */
enum { JNULL, JTRUE, JFALSE, JNUM, JSTR, JARR, JOBJ };
typedef struct J { int t; char *s; struct J **v; char **k; size_t n, cap; } J;

static J *jnew(int t) { J *j = xmalloc(sizeof *j); memset(j, 0, sizeof *j); j->t = t; return j; }
static J *jstr(const char *s) { J *j = jnew(JSTR); j->s = xstrdup(s); return j; }
static J *jnum(long x) { char t[32]; snprintf(t, sizeof t, "%ld", x); J *j = jnew(JNUM); j->s = xstrdup(t); return j; }
static void jgrow(J *a) { if (a->n == a->cap) { a->cap = a->cap ? a->cap * 2 : 4; a->v = xrealloc(a->v, a->cap * sizeof *a->v); if (a->t == JOBJ) a->k = xrealloc(a->k, a->cap * sizeof *a->k); } }
static void jpush(J *a, J *v) { jgrow(a); a->v[a->n++] = v; }
static J *jget(const J *o, const char *key) {
    if (!o || o->t != JOBJ) return NULL;
    for (size_t i = 0; i < o->n; i++) if (!strcmp(o->k[i], key)) return o->v[i];
    return NULL;
}
static void jset(J *o, const char *key, J *v) {
    for (size_t i = 0; i < o->n; i++) if (!strcmp(o->k[i], key)) { o->v[i] = v; return; }
    jgrow(o); o->k[o->n] = xstrdup(key); o->v[o->n++] = v;
}
static void jdel(J *o, const char *key) {
    for (size_t i = 0; i < o->n; i++) if (!strcmp(o->k[i], key)) {
        memmove(o->k + i, o->k + i + 1, (o->n - i - 1) * sizeof *o->k);
        memmove(o->v + i, o->v + i + 1, (o->n - i - 1) * sizeof *o->v);
        o->n--; return;
    }
}
static const char *jstrval(const J *o, const char *key) { J *v = jget(o, key); return v && v->t == JSTR ? v->s : NULL; }

static void jescape(Buf *b, const char *s) {
    bput(b, "\"", 1);
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        char t[8];
        switch (*p) {
        case '"': bstr(b, "\\\""); break;
        case '\\': bstr(b, "\\\\"); break;
        case '\n': bstr(b, "\\n"); break;
        case '\r': bstr(b, "\\r"); break;
        case '\t': bstr(b, "\\t"); break;
        case '\b': bstr(b, "\\b"); break;
        case '\f': bstr(b, "\\f"); break;
        case 0x7f: bstr(b, "\\u007f"); break;
        default:
            if (*p < 0x20) { snprintf(t, sizeof t, "\\u%04x", *p); bstr(b, t); }
            else bput(b, (const char *)p, 1);
        }
    }
    bput(b, "\"", 1);
}
static void jprint(const J *j, Buf *b, int ind) {
    switch (j->t) {
    case JNULL: bstr(b, "null"); break;
    case JTRUE: bstr(b, "true"); break;
    case JFALSE: bstr(b, "false"); break;
    case JNUM: bstr(b, j->s); break;
    case JSTR: jescape(b, j->s); break;
    case JARR:
        if (!j->n) { bstr(b, "[]"); break; }
        bstr(b, "[\n");
        for (size_t i = 0; i < j->n; i++) {
            for (int s = 0; s < ind + 2; s++) bput(b, " ", 1);
            jprint(j->v[i], b, ind + 2);
            bstr(b, i + 1 < j->n ? ",\n" : "\n");
        }
        for (int s = 0; s < ind; s++) bput(b, " ", 1);
        bput(b, "]", 1); break;
    case JOBJ:
        if (!j->n) { bstr(b, "{}"); break; }
        bstr(b, "{\n");
        for (size_t i = 0; i < j->n; i++) {
            for (int s = 0; s < ind + 2; s++) bput(b, " ", 1);
            jescape(b, j->k[i]); bstr(b, ": ");
            jprint(j->v[i], b, ind + 2);
            bstr(b, i + 1 < j->n ? ",\n" : "\n");
        }
        for (int s = 0; s < ind; s++) bput(b, " ", 1);
        bput(b, "}", 1); break;
    }
}
static char *jdump(const J *j) { Buf b = {0}; jprint(j, &b, 0); bstr(&b, "\n"); return b.p; }
static void jsort(J *j) {   /* jq -S: object keys in byte order, recursively */
    if (j->t == JARR) { for (size_t i = 0; i < j->n; i++) jsort(j->v[i]); return; }
    if (j->t != JOBJ) return;
    for (size_t i = 1; i < j->n; i++) {
        char *k = j->k[i]; J *v = j->v[i]; size_t m = i;
        while (m > 0 && strcmp(j->k[m - 1], k) > 0) { j->k[m] = j->k[m - 1]; j->v[m] = j->v[m - 1]; m--; }
        j->k[m] = k; j->v[m] = v;
    }
    for (size_t i = 0; i < j->n; i++) jsort(j->v[i]);
}
static void jcompact(const J *j, Buf *b) {   /* jq -c */
    switch (j->t) {
    case JARR: bput(b, "[", 1); for (size_t i = 0; i < j->n; i++) { if (i) bput(b, ",", 1); jcompact(j->v[i], b); } bput(b, "]", 1); break;
    case JOBJ: bput(b, "{", 1); for (size_t i = 0; i < j->n; i++) { if (i) bput(b, ",", 1); jescape(b, j->k[i]); bput(b, ":", 1); jcompact(j->v[i], b); } bput(b, "}", 1); break;
    default: jprint(j, b, 0);
    }
}
static char *jcompact_s(const J *j) { Buf b = {0}; bstr(&b, ""); jcompact(j, &b); return b.p; }

typedef struct { const char *p; int depth; int err; } P;
static void pws(P *p) { while (*p->p == ' ' || *p->p == '\t' || *p->p == '\n' || *p->p == '\r') p->p++; }
static void putf8(Buf *b, unsigned c) {
    if (c >= 0xD800 && c < 0xE000) c = 0xFFFD;
    char t[4]; int n;
    if (c < 0x80) { t[0] = (char)c; n = 1; }
    else if (c < 0x800) { t[0] = (char)(0xC0 | c >> 6); t[1] = (char)(0x80 | (c & 63)); n = 2; }
    else if (c < 0x10000) { t[0] = (char)(0xE0 | c >> 12); t[1] = (char)(0x80 | ((c >> 6) & 63)); t[2] = (char)(0x80 | (c & 63)); n = 3; }
    else { t[0] = (char)(0xF0 | c >> 18); t[1] = (char)(0x80 | ((c >> 12) & 63)); t[2] = (char)(0x80 | ((c >> 6) & 63)); t[3] = (char)(0x80 | (c & 63)); n = 4; }
    bput(b, t, (size_t)n);
}
static int hex4(const char *s, unsigned *out) {
    unsigned v = 0;
    for (int i = 0; i < 4; i++) {
        char c = s[i]; v <<= 4;
        if (c >= '0' && c <= '9') v |= (unsigned)(c - '0');
        else if (c >= 'a' && c <= 'f') v |= (unsigned)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') v |= (unsigned)(c - 'A' + 10);
        else return 0;
    }
    *out = v; return 1;
}
static char *pstring(P *p) {
    Buf b = {0}; bstr(&b, "");
    p->p++;
    while (*p->p && *p->p != '"') {
        if (*p->p == '\\') {
            p->p++;
            switch (*p->p) {
            case 'n': bput(&b, "\n", 1); break;
            case 't': bput(&b, "\t", 1); break;
            case 'r': bput(&b, "\r", 1); break;
            case 'b': bput(&b, "\b", 1); break;
            case 'f': bput(&b, "\f", 1); break;
            case '/': case '\\': case '"': bput(&b, p->p, 1); break;
            case 'u': {
                unsigned c, d;
                if (!hex4(p->p + 1, &c)) { p->err = 1; return b.p; }
                p->p += 4;
                if (c >= 0xD800 && c < 0xDC00 && p->p[1] == '\\' && p->p[2] == 'u' && hex4(p->p + 3, &d) && d >= 0xDC00 && d < 0xE000) {
                    c = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00); p->p += 6;
                }
                putf8(&b, c); break;
            }
            default: p->err = 1; return b.p;
            }
            p->p++;
        } else bput(&b, p->p++, 1);
    }
    if (*p->p != '"') p->err = 1; else p->p++;
    return b.p;
}
static J *pvalue(P *p) {
    pws(p);
    if (p->err || ++p->depth > 64) { p->err = 1; return NULL; }
    J *r = NULL;
    char c = *p->p;
    if (c == '{') {
        r = jnew(JOBJ); p->p++; pws(p);
        if (*p->p == '}') p->p++;
        else for (;;) {
            pws(p);
            if (*p->p != '"') { p->err = 1; break; }
            char *k = pstring(p); pws(p);
            if (*p->p != ':') { p->err = 1; break; }
            p->p++;
            J *v = pvalue(p); if (!v) break;
            jset(r, k, v); pws(p);
            if (*p->p == ',') { p->p++; continue; }
            if (*p->p == '}') { p->p++; break; }
            p->err = 1; break;
        }
    } else if (c == '[') {
        r = jnew(JARR); p->p++; pws(p);
        if (*p->p == ']') p->p++;
        else for (;;) {
            J *v = pvalue(p); if (!v) break;
            jpush(r, v); pws(p);
            if (*p->p == ',') { p->p++; continue; }
            if (*p->p == ']') { p->p++; break; }
            p->err = 1; break;
        }
    } else if (c == '"') { r = jnew(JSTR); r->s = pstring(p); }
    else if (!strncmp(p->p, "true", 4)) { r = jnew(JTRUE); p->p += 4; }
    else if (!strncmp(p->p, "false", 5)) { r = jnew(JFALSE); p->p += 5; }
    else if (!strncmp(p->p, "null", 4)) { r = jnew(JNULL); p->p += 4; }
    else if (c == '-' || (c >= '0' && c <= '9')) {
        const char *s = p->p;
        while (*p->p == '-' || *p->p == '+' || *p->p == '.' || *p->p == 'e' || *p->p == 'E' || (*p->p >= '0' && *p->p <= '9')) p->p++;
        r = jnew(JNUM); r->s = xmalloc((size_t)(p->p - s) + 1); memcpy(r->s, s, (size_t)(p->p - s)); r->s[p->p - s] = 0;
        { char *end; (void)strtod(r->s, &end); if (end == r->s || *end) p->err = 1; }
    } else p->err = 1;
    p->depth--;
    return p->err ? NULL : r;
}
static J *jparse(const char *s) {
    P p = { s, 0, 0 };
    J *j = pvalue(&p);
    if (!j) return NULL;
    pws(&p);
    return *p.p ? NULL : j;
}

/* ---------- files ---------- */
static char *slurp(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    Buf b = {0}; bstr(&b, "");
    char t[4096]; size_t n;
    while ((n = fread(t, 1, sizeof t, f)) > 0) bput(&b, t, n);
    fclose(f);
    return b.p;
}
/* Every file this tool creates is mode 0644 (minus umask), never 0666: fopen() would create it world-writable
 * under a permissive umask (CodeQL cpp/world-writable-file-creation). */
static FILE *fcreate(const char *path) {
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return NULL;
    FILE *f = fdopen(fd, "wb");
    if (!f) close(fd);
    return f;
}
static void spit(const char *path, const char *data) {   /* temp file then rename */
    size_t tn = strlen(path) + 32; char *tmp = xmalloc(tn);
    snprintf(tmp, tn, "%s.tmp%ld", path, (long)getpid());
    FILE *f = fcreate(tmp);
    if (!f) die("cannot write %s: %s", tmp, strerror(errno));
    if (fputs(data, f) < 0 || fclose(f) != 0) die("write failed: %s", tmp);
    if (rename(tmp, path) != 0) die("rename failed: %s", path);
    free(tmp);
}
static char *pjoin(const char *a, const char *b) {
    size_t n = strlen(a) + strlen(b) + 2; char *p = xmalloc(n);
    snprintf(p, n, "%s/%s", a, b); return p;
}
static char *absdir(const char *d) {
    char r[PATH_MAX];
    if (!realpath(d, r)) die("no such directory: %s", d);
    struct stat st; if (stat(r, &st) || !S_ISDIR(st.st_mode)) die("not a directory: %s", d);
    return xstrdup(r);
}
static char *dir_of(const char *p) {
    char *c = xstrdup(p), *s = strrchr(c, '/');
    if (s == c) c[1] = 0; else if (s) *s = 0; else strcpy(c, ".");
    return c;
}
static void chomp(char *s) { size_t n = strlen(s); while (n && (s[n - 1] == '\n' || s[n - 1] == '\r')) s[--n] = 0; }
static int sstrcmp(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }

/* ---------- git, run without a shell (fork + execvp, argv array) ---------- */
#define GIT_MAX_ARGS 24
static char *git_run(const char *top, const char *const *args, const char *stdin_path, size_t *len) {
    const char *argv[GIT_MAX_ARGS + 4]; int n = 0;
    argv[n++] = "git"; argv[n++] = "-C"; argv[n++] = top;
    for (; *args && n < GIT_MAX_ARGS + 3; args++) argv[n++] = *args;
    argv[n] = NULL;
    Buf b = {0}; bstr(&b, "");
    int pfd[2];
    if (pipe(pfd) != 0) { if (len) *len = 0; return b.p; }
    pid_t pid = fork();
    if (pid < 0) { close(pfd[0]); close(pfd[1]); if (len) *len = 0; return b.p; }
    if (pid == 0) {
        int in = open(stdin_path ? stdin_path : "/dev/null", O_RDONLY | O_CLOEXEC);
        if (in >= 0) { dup2(in, 0); close(in); }
        int nul = open("/dev/null", O_WRONLY | O_CLOEXEC);
        if (nul >= 0) { dup2(nul, 2); close(nul); }
        dup2(pfd[1], 1); close(pfd[0]); close(pfd[1]);
        execvp("git", (char *const *)argv);
        _exit(127);
    }
    close(pfd[1]);
    char t[8192]; ssize_t r;
    for (;;) {
        r = read(pfd[0], t, sizeof t);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) break;
        bput(&b, t, (size_t)r);
    }
    close(pfd[0]);
    int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    if (len) *len = b.n;
    return b.p;
}
static char *git_line(const char *top, const char *const *args) { char *s = git_run(top, args, NULL, NULL); chomp(s); return s; }
static char *repo_top(const char *dir) {   /* NULL outside a git work tree */
    static const char *const a[] = { "rev-parse", "--show-toplevel", NULL };
    char *t = git_line(dir, a);
    if (!*t) { free(t); return NULL; }
    return t;
}

/* ---------- traversal policy (shared by verify, status, compile, digest) ----------
 * A directory is excluded when it is (a) under a <root>/.crumbignore entry, (b) .git, (c) a directory git ignores
 * that holds no tracked file, or (d) target, node_modules or __pycache__ holding no tracked file. A directory with any
 * tracked file is real source and always takes part (except via .crumbignore). Symlinked directories are not followed. */
static char **g_ign; static size_t g_nign;
static char **g_trk; static size_t g_ntrk;    /* tracked paths (git ls-files) */
static char **g_gign; static size_t g_ngign;  /* wholly untracked+ignored directories, "dir/" */
static void load_ignore(const char *root) {   /* one relative directory per line, '#' comments */
    char *p = pjoin(root, ".crumbignore"), *txt = slurp(p);
    free(p);
    if (!txt) return;
    for (char *l = strtok(txt, "\n"); l; l = strtok(NULL, "\n")) {
        size_t n = strlen(l); while (n && (l[n - 1] == '/' || l[n - 1] == '\r' || l[n - 1] == ' ')) l[--n] = 0;
        if (!n || l[0] == '#') continue;
        g_ign = xrealloc(g_ign, (g_nign + 1) * sizeof *g_ign); g_ign[g_nign++] = xstrdup(l);
    }
}
static int ignored_subtree(const char *rel) {
    for (size_t i = 0; i < g_nign; i++) {
        size_t n = strlen(g_ign[i]);
        if (!strncmp(rel, g_ign[i], n) && (rel[n] == 0 || rel[n] == '/')) return 1;
    }
    return 0;
}
static void policy_load(const char *top, int git) {
    load_ignore(top);
    if (!git) return;
    static const char *const a1[] = { "ls-files", "-z", NULL };
    static const char *const a2[] = { "ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--directory", NULL };
    size_t n; char *raw = git_run(top, a1, NULL, &n);
    for (char *s = raw; s < raw + n; s += strlen(s) + 1) { g_trk = xrealloc(g_trk, (g_ntrk + 1) * sizeof *g_trk); g_trk[g_ntrk++] = xstrdup(s); }
    raw = git_run(top, a2, NULL, &n);
    for (char *s = raw; s < raw + n; s += strlen(s) + 1) {
        size_t l = strlen(s); if (!l || s[l - 1] != '/') continue;
        g_gign = xrealloc(g_gign, (g_ngign + 1) * sizeof *g_gign); g_gign[g_ngign++] = xstrdup(s);
    }
}
static int tracked_under(const char *rel) {
    size_t n = strlen(rel);
    for (size_t i = 0; i < g_ntrk; i++) if (!strncmp(g_trk[i], rel, n) && g_trk[i][n] == '/') return 1;
    return 0;
}
static int skip_dir(const char *rel) {   /* rel: root-relative directory, no trailing slash */
    if (ignored_subtree(rel)) return 1;
    const char *b = strrchr(rel, '/'); b = b ? b + 1 : rel;
    if (!strcmp(b, ".git")) return 1;
    if (tracked_under(rel)) return 0;
    size_t n = strlen(rel);
    for (size_t i = 0; i < g_ngign; i++) if (strlen(g_gign[i]) == n + 1 && !strncmp(g_gign[i], rel, n)) return 1;
    return !strcmp(b, "target") || !strcmp(b, "node_modules") || !strcmp(b, "__pycache__");
}
typedef struct { char **d; size_t n, cap; } Dirs;
static void dirs_add(Dirs *ds, const char *d) {
    for (size_t i = 0; i < ds->n; i++) if (!strcmp(ds->d[i], d)) return;
    if (ds->n == ds->cap) { ds->cap = ds->cap ? ds->cap * 2 : 32; ds->d = xrealloc(ds->d, ds->cap * sizeof *ds->d); }
    ds->d[ds->n++] = xstrdup(d);
}
static void find_crumbs(const char *top, const char *rel, Dirs *ds) {
    char *full = *rel ? pjoin(top, rel) : xstrdup(top); DIR *dp = opendir(full);
    if (!dp) { free(full); return; }
    struct dirent *e;
    while ((e = readdir(dp))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        char *r = *rel ? pjoin(rel, e->d_name) : xstrdup(e->d_name), *f = pjoin(top, r); struct stat st;
        if (lstat(f, &st) == 0) {
            if (S_ISDIR(st.st_mode)) { if (!skip_dir(r)) find_crumbs(top, r, ds); }
            else if (!strcmp(e->d_name, ".crumb") && S_ISREG(st.st_mode)) dirs_add(ds, *rel ? rel : ".");
        }
        free(r); free(f);
    }
    closedir(dp); free(full);
}
static int dircmp(const void *a, const void *b) {   /* "." first, then byte order */
    const char *x = *(char *const *)a, *y = *(char *const *)b;
    if (!strcmp(x, ".")) return strcmp(y, ".") ? -1 : 0;
    if (!strcmp(y, ".")) return 1;
    return strcmp(x, y);
}
/* Resolve the root (git top level when inside a work tree) and list every crumb directory that takes part. */
static char *crumb_dirs(const char *root, Dirs *ds, int *git) {
    char *r = absdir(root), *top = repo_top(r);
    *git = top != NULL;
    if (!top) top = r; else free(r);
    policy_load(top, *git);
    memset(ds, 0, sizeof *ds);
    find_crumbs(top, "", ds);
    if (ds->n) qsort(ds->d, ds->n, sizeof *ds->d, dircmp);
    return top;
}
static char *crumb_file(const char *top, const char *d) { return strcmp(d, ".") ? pjoin(top, d) : xstrdup(top); }

/* ---------- the crumb model (RFC-0003 Am2) ---------- */
static const char *const GEN_KEYS[] = { "generated", "generated_policy", "provenance", "seed", NULL };
/* NULL when readable; otherwise the reason. *out gets the parsed object when it is one. */
static const char *check_crumb(const char *path, J **out) {
    char *txt = slurp(path);
    if (out) *out = NULL;
    if (!txt) return "cannot read the file";
    J *c = jparse(txt); free(txt);
    if (!c) return "not valid JSON";
    if (c->t != JOBJ) return "not a JSON object";
    if (out) *out = c;
    if (!jstrval(c, "schema_version")) return "schema_version is missing or not a string";
    if (!jstrval(c, "name")) return "name is missing or not a string";
    if (!jstrval(c, "purpose")) return "purpose is missing or not a string";
    return NULL;
}
static void stored_generated(const J *c, Buf *b) {   /* comma list of stored generated keys, empty when none */
    J *x = jget(c, "extensions");
    if (!x || x->t != JOBJ) return;
    for (int i = 0; GEN_KEYS[i]; i++) if (jget(x, GEN_KEYS[i])) bfmt(b, "%sextensions.%s", b->n ? ", " : "", GEN_KEYS[i]);
}
static int strip_generated(J *c) {
    J *x = jget(c, "extensions"); int n = 0;
    if (!x || x->t != JOBJ) return 0;
    for (int i = 0; GEN_KEYS[i]; i++) if (jget(x, GEN_KEYS[i])) { jdel(x, GEN_KEYS[i]); n++; }
    if (n && x->n == 0) jdel(c, "extensions");
    return n;
}

static int cmd_verify(const char *root) {
    Dirs ds; int git; char *top = crumb_dirs(root, &ds, &git);
    Buf det = {0}; bstr(&det, ""); size_t bad = 0;
    for (size_t i = 0; i < ds.n; i++) {
        char *dir = crumb_file(top, ds.d[i]), *cp = pjoin(dir, ".crumb"); J *c;
        const char *why = check_crumb(cp, &c);
        if (why) { bad++; bfmt(&det, "UNREADABLE %s: %s\n", ds.d[i], why); }
        if (c) {
            Buf g = {0}; bstr(&g, ""); stored_generated(c, &g);
            if (g.n) bfmt(&det, "WARN       %s: stores %s (generated data is never stored; run: crumb compile)\n", ds.d[i], g.p);
            free(g.p);
        }
        free(dir); free(cp);
    }
    if (bad) printf("crumb verify: FAIL: %zu of %zu crumbs unreadable %s\n", bad, ds.n, AM2);
    else printf("crumb verify: OK: %zu crumbs readable %s\n", ds.n, AM2);
    fputs(det.p, stdout);
    return bad ? 1 : 0;
}
static int cmd_status(const char *root) {
    Dirs ds; int git; char *top = crumb_dirs(root, &ds, &git);
    Buf det = {0}; bstr(&det, ""); size_t bad = 0;
    for (size_t i = 0; i < ds.n; i++) {
        char *dir = crumb_file(top, ds.d[i]), *cp = pjoin(dir, ".crumb");
        const char *why = check_crumb(cp, NULL);
        if (why) { bad++; bfmt(&det, "UNREADABLE %s: %s\n", ds.d[i], why); }
        else bfmt(&det, "READABLE   %s\n", ds.d[i]);
        free(dir); free(cp);
    }
    printf("crumb status: %zu crumbs, %zu unreadable %s\n", ds.n, bad, AM2);
    fputs(det.p, stdout);
    return 0;
}
static int cmd_compile(const char *label, const char *root) {   /* cleanup only: strip stored generated data */
    Dirs ds; int git; char *top = crumb_dirs(root, &ds, &git);
    Buf det = {0}; bstr(&det, ""); size_t changed = 0, skipped = 0;
    for (size_t i = 0; i < ds.n; i++) {
        char *dir = crumb_file(top, ds.d[i]), *cp = pjoin(dir, ".crumb"); J *c;
        const char *why = check_crumb(cp, &c);
        if (!c) { skipped++; bfmt(&det, "SKIPPED    %s: %s\n", ds.d[i], why); }
        else if (strip_generated(c)) { jsort(c); char *out = jdump(c); spit(cp, out); free(out); changed++; bfmt(&det, "STRIPPED   %s\n", ds.d[i]); }
        free(dir); free(cp);
    }
    printf("crumb %s: %zu crumbs, %zu rewritten, %zu skipped (generated data is never stored, RFC-0003 Am2)\n", label, ds.n, changed, skipped);
    fputs(det.p, stdout);
    return skipped ? 1 : 0;
}

/* ---------- crumb digest: structural digest of a directory, computed from the tree now, never stored ----------
 * Kept from the RFC-0003 compiler so a reader can still fingerprint a subtree:
 *  - files = tracked files of the working tree (git ls-files) minus every .crumb, blob ids via git hash-object;
 *  - digest = sha256(semantic kernel || source_tree || children_root || evidence_root), content only;
 *  - semantic kernel = {purpose, layer, invariants, exports, related, boundaries} as written, keys sorted, compact;
 *  - children = the nearest crumbed descendants (named by path relative to the parent crumb directory);
 *  - evidence = tracked files under an evidence/ or receipts/ component, or ending in .receipt.json. */
typedef struct { uint32_t h[8]; uint64_t len; unsigned char buf[64]; size_t nb; } Sha;
static const uint32_t K256[64] = {
 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2 };
#define ROR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
static void sha_block(Sha *s, const unsigned char *p) {
    uint32_t w[64], a, b, c, d, e, f, g, h;
    for (int i = 0; i < 16; i++) w[i] = (uint32_t)p[4*i] << 24 | (uint32_t)p[4*i+1] << 16 | (uint32_t)p[4*i+2] << 8 | p[4*i+3];
    for (int i = 16; i < 64; i++) {
        uint32_t s0 = ROR(w[i-15], 7) ^ ROR(w[i-15], 18) ^ (w[i-15] >> 3), s1 = ROR(w[i-2], 17) ^ ROR(w[i-2], 19) ^ (w[i-2] >> 10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    a = s->h[0]; b = s->h[1]; c = s->h[2]; d = s->h[3]; e = s->h[4]; f = s->h[5]; g = s->h[6]; h = s->h[7];
    for (int i = 0; i < 64; i++) {
        uint32_t t1 = h + (ROR(e, 6) ^ ROR(e, 11) ^ ROR(e, 25)) + ((e & f) ^ (~e & g)) + K256[i] + w[i];
        uint32_t t2 = (ROR(a, 2) ^ ROR(a, 13) ^ ROR(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    s->h[0] += a; s->h[1] += b; s->h[2] += c; s->h[3] += d; s->h[4] += e; s->h[5] += f; s->h[6] += g; s->h[7] += h;
}
static void sha_init(Sha *s) {
    static const uint32_t iv[8] = { 0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19 };
    memcpy(s->h, iv, sizeof iv); s->len = 0; s->nb = 0;
}
static void sha_add(Sha *s, const void *data, size_t n) {
    const unsigned char *p = data; s->len += n;
    while (n) {
        size_t k = 64 - s->nb; if (k > n) k = n;
        memcpy(s->buf + s->nb, p, k); s->nb += k; p += k; n -= k;
        if (s->nb == 64) { sha_block(s, s->buf); s->nb = 0; }
    }
}
static void sha_hex(Sha *s, char *out) {   /* out: 65 bytes */
    uint64_t bits = s->len * 8; unsigned char pad = 0x80, z = 0, lb[8];
    sha_add(s, &pad, 1); while (s->nb != 56) sha_add(s, &z, 1);
    for (int i = 0; i < 8; i++) lb[i] = (unsigned char)(bits >> (56 - 8 * i));
    sha_add(s, lb, 8);
    for (int i = 0; i < 8; i++) snprintf(out + 8 * i, 9, "%08x", s->h[i]);
}

typedef struct { char *blob, *path; } CFile;
static int cfcmp(const void *a, const void *b) { return strcmp(((const CFile *)a)->path, ((const CFile *)b)->path); }
typedef struct { char *dir, *dig; } DDig;
typedef struct { CFile *f; size_t nf; DDig *dd; size_t ndd, cdd; char *top; } Comp;
static int is_crumb_name(const char *path) {
    const char *b = strrchr(path, '/'); b = b ? b + 1 : path;
    return !strcmp(b, ".crumb") || !strcmp(b, ".crumb.local");
}
static int is_evidence(const char *p) {
    size_t n = strlen(p);
    if (n >= 13 && !strcmp(p + n - 13, ".receipt.json")) return 1;
    static const char *w[] = { "evidence/", "receipts/", NULL };
    for (int k = 0; w[k]; k++) for (const char *s = p; (s = strstr(s, w[k])); s++) if (s == p || s[-1] == '/') return 1;
    return 0;
}
static void comp_load_files(Comp *c) {
    Buf present = {0}; bstr(&present, ""); size_t np = 0; char **pp = NULL;
    for (size_t i = 0; i < g_ntrk; i++) {
        const char *s = g_trk[i];
        if (!*s || is_crumb_name(s)) continue;
        char *full = pjoin(c->top, s); struct stat st;
        if (stat(full, &st) == 0 && S_ISREG(st.st_mode)) { pp = xrealloc(pp, (np + 1) * sizeof *pp); pp[np++] = xstrdup(s); bstr(&present, s); bput(&present, "\n", 1); }
        free(full);
    }
    c->nf = 0; c->f = NULL;
    if (!np) return;
    const char *td = getenv("TMPDIR"); if (!td || !*td) td = "/tmp";
    char *tmpl = pjoin(td, "crumb-digest-XXXXXX"); int fd = mkstemp(tmpl);
    if (fd < 0) die("cannot create temp file in %s", td);
    if (write(fd, present.p, present.n) != (ssize_t)present.n) die("temp write failed");
    close(fd);
    static const char *const a[] = { "hash-object", "--stdin-paths", NULL };
    char *hs = git_run(c->top, a, tmpl, NULL); unlink(tmpl); free(tmpl);
    char *sv = NULL, *ln = strtok_r(hs, "\n", &sv);
    c->f = xmalloc(np * sizeof *c->f);
    for (size_t i = 0; i < np; i++) {
        if (!ln) die("git hash-object returned too few ids");
        c->f[i].blob = xstrdup(ln); c->f[i].path = pp[i]; ln = strtok_r(NULL, "\n", &sv);
    }
    c->nf = np;
    qsort(c->f, c->nf, sizeof *c->f, cfcmp);
}
static const char *dig_of(Comp *c, const char *dir) { for (size_t i = 0; i < c->ndd; i++) if (!strcmp(c->dd[i].dir, dir)) return c->dd[i].dig; return NULL; }
static void dig_set(Comp *c, const char *dir, const char *dig) {
    if (c->ndd == c->cdd) { c->cdd = c->cdd ? c->cdd * 2 : 16; c->dd = xrealloc(c->dd, c->cdd * sizeof *c->dd); }
    c->dd[c->ndd].dir = xstrdup(dir); c->dd[c->ndd++].dig = xstrdup(dig);
}
static size_t utf8_prefix(const char *s, int cps) {
    size_t i = 0; int k = 0;
    while (s[i] && k < cps) { i++; while (((unsigned char)s[i] & 0xC0) == 0x80) i++; k++; }
    return i;
}
typedef struct { char *rel; char *name; } Kid;
static int kidcmp(const void *a, const void *b) { return strcmp(((const Kid *)a)->name, ((const Kid *)b)->name); }
static void collect_kids(Comp *c, const char *dir, const char *prefix, Kid **out, size_t *n, size_t *cap) {
    int root = !strcmp(dir, "."); char *dfull = root ? xstrdup(c->top) : pjoin(c->top, dir); DIR *dp = opendir(dfull);
    char **names = NULL; size_t nn = 0;
    if (dp) { struct dirent *e; while ((e = readdir(dp))) if (strcmp(e->d_name, ".") && strcmp(e->d_name, "..")) { names = xrealloc(names, (nn + 1) * sizeof *names); names[nn++] = xstrdup(e->d_name); } closedir(dp); }
    if (nn) qsort(names, nn, sizeof *names, sstrcmp);
    for (size_t i = 0; i < nn; i++) {
        char *kd = root ? xstrdup(names[i]) : pjoin(dir, names[i]), *kf = pjoin(c->top, kd); struct stat st;
        if (lstat(kf, &st) || !S_ISDIR(st.st_mode) || skip_dir(kd)) { free(kd); free(kf); continue; }
        char *kc = pjoin(kf, ".crumb"); struct stat sb; int has = !stat(kc, &sb) && S_ISREG(sb.st_mode);
        size_t pl = strlen(prefix), nl = strlen(names[i]); char *name = xmalloc(pl + nl + 2); memcpy(name, prefix, pl); memcpy(name + pl, names[i], nl + 1);
        if (has) {
            if (*n == *cap) { *cap = *cap ? *cap * 2 : 16; *out = xrealloc(*out, *cap * sizeof **out); }
            (*out)[*n].rel = kd; (*out)[(*n)++].name = name;
        } else { name[pl + nl] = '/'; name[pl + nl + 1] = 0; collect_kids(c, kd, name, out, n, cap); free(name); free(kd); }
        free(kf); free(kc);
    }
    free(names); free(dfull);
}
static J *comp_object(Comp *c, const char *d, char *dig_out) {
    int root = !strcmp(d, ".");
    char pre[PATH_MAX]; if (!root) snprintf(pre, sizeof pre, "%s/", d); else pre[0] = 0;
    Sha st, ev; sha_init(&st); sha_init(&ev); long nfiles = 0, nev = 0;
    for (size_t i = 0; i < c->nf; i++) {
        if (!root && strncmp(c->f[i].path, pre, strlen(pre))) continue;
        sha_add(&st, c->f[i].blob, strlen(c->f[i].blob)); sha_add(&st, " ", 1); sha_add(&st, c->f[i].path, strlen(c->f[i].path)); sha_add(&st, "\n", 1);
        nfiles++;
        if (is_evidence(c->f[i].path)) { sha_add(&ev, c->f[i].blob, strlen(c->f[i].blob)); sha_add(&ev, "\n", 1); nev++; }
    }
    char sth[65], evh[65]; sha_hex(&st, sth); sha_hex(&ev, evh);
    char *dfull = crumb_file(c->top, d), *full = pjoin(dfull, ".crumb"), *txt = slurp(full); J *cr = txt ? jparse(txt) : NULL;
    J *sem = jnew(JOBJ);
    if (cr && cr->t == JOBJ) {
        static const char *ks[] = { "purpose", "layer", "invariants", "exports", "related", "boundaries", NULL };
        for (int k = 0; ks[k]; k++) { J *v = jget(cr, ks[k]); if (v && v->t != JNULL) jset(sem, ks[k], v); }
    }
    jsort(sem); char *semc = jcompact_s(sem);
    Kid *kv = NULL; size_t nn = 0, kcap = 0; collect_kids(c, d, "", &kv, &nn, &kcap);
    if (nn) qsort(kv, nn, sizeof *kv, kidcmp);
    J *kids = jnew(JARR); Sha crs; sha_init(&crs);
    for (size_t i = 0; i < nn; i++) {
        const char *kdig = dig_of(c, kv[i].rel); if (!kdig) kdig = "uncomputed";
        char *kdf = crumb_file(c->top, kv[i].rel), *kcf = pjoin(kdf, ".crumb"), *kt = slurp(kcf); J *kj = kt ? jparse(kt) : NULL;
        const char *kp = kj ? jstrval(kj, "purpose") : NULL; if (!kp) kp = "";
        char *kpur = xstrdup(kp); kpur[utf8_prefix(kpur, 96)] = 0; chomp(kpur);
        const char *la[] = { "log", "-1", "--format=%h", "HEAD", "--", kv[i].rel, ":!**/.crumb", NULL };
        char *lc = git_line(c->top, la);
        J *o = jnew(JOBJ); jset(o, "name", jstr(kv[i].name)); jset(o, "digest", jstr(kdig)); jset(o, "purpose", jstr(kpur)); jset(o, "last_commit", jstr(lc));
        jpush(kids, o); sha_add(&crs, kdig, strlen(kdig)); sha_add(&crs, "\n", 1);
        free(kdf); free(kcf); free(kt);
    }
    char crh[65]; sha_hex(&crs, crh);
    Sha ds; sha_init(&ds); sha_add(&ds, semc, strlen(semc)); sha_add(&ds, sth, 64); sha_add(&ds, crh, 64); sha_add(&ds, evh, 64);
    char dgh[65]; sha_hex(&ds, dgh);
    strcpy(dig_out, dgh);
    J *g = jnew(JOBJ); char t[80];
    jset(g, "compiler", jstr("crumb-compile/1"));
    snprintf(t, sizeof t, "sha256:%s", sth); jset(g, "source_tree", jstr(t));
    jset(g, "files", jnum(nfiles)); jset(g, "children", kids);
    snprintf(t, sizeof t, "sha256:%s", crh); jset(g, "children_root", jstr(t));
    jset(g, "evidence_files", jnum(nev));
    snprintf(t, sizeof t, "sha256:%s", evh); jset(g, "evidence_root", jstr(t));
    snprintf(t, sizeof t, "sha256:%s", dgh); jset(g, "digest", jstr(t));
    jsort(g); free(dfull); free(full); free(txt);
    return g;
}
static int depth_of(const char *d) { if (!strcmp(d, ".")) return -1; int n = 0; for (; *d; d++) if (*d == '/') n++; return n; }
static int deepcmp(const void *a, const void *b) {
    const char *x = *(char *const *)a, *y = *(char *const *)b; int dx = depth_of(x), dy = depth_of(y);
    return dx != dy ? dy - dx : strcmp(x, y);
}
static int cmd_digest(const char *dir) {
    char r[PATH_MAX]; if (!realpath(dir, r)) die("no such directory: %s", dir);
    Dirs ds; int git; char *top = crumb_dirs(r, &ds, &git);
    if (!git) die("crumb digest: not inside a git repository: %s", dir);
    size_t tl = strlen(top); const char *want = r[tl] ? r + tl + 1 : ".";
    Comp c; memset(&c, 0, sizeof c); c.top = top; comp_load_files(&c);
    if (ds.n) qsort(ds.d, ds.n, sizeof *ds.d, deepcmp);
    static const char *const ha[] = { "rev-parse", "HEAD", NULL };
    char *head = git_line(top, ha); if (strlen(head) != 40) head = xstrdup("0000000000000000000000000000000000000000");
    for (size_t i = 0; i < ds.n; i++) {
        char dg[65]; J *g = comp_object(&c, ds.d[i], dg); dig_set(&c, ds.d[i], dg);
        if (!strcmp(ds.d[i], want)) { jset(g, "generated_at_commit", jstr(head)); jsort(g); fputs(jdump(g), stdout); return 0; }
    }
    die("crumb digest: %s holds no .crumb", want);
    return 1;
}

/* ---------- crumb context / explain / sniff ---------- */
static void print_trunc(const char *prefix, const char *s) {
    size_t n = utf8_prefix(s, CTX_STR_MAX);
    char *c = xmalloc(n + 1); memcpy(c, s, n); c[n] = 0;
    for (char *p = c; *p; p++) if (*p == '\n' || *p == '\r' || *p == '\t') *p = ' ';
    printf("  %s%s%s\n", prefix, c, s[n] ? " ..." : "");
    free(c);
}
static void print_val(const char *label, const J *v) {   /* string, array of anything, or object; bounded */
    char pre[64]; snprintf(pre, sizeof pre, "%s: ", label);
    if (!v || v->t == JNULL) return;
    if (v->t == JSTR) { print_trunc(pre, v->s); return; }
    if (v->t == JARR || v->t == JOBJ) {
        for (size_t i = 0; i < v->n && i < CTX_LIST_MAX; i++) {
            const J *e = v->v[i]; char *cs = e->t == JSTR ? NULL : jcompact_s(e);
            if (v->t == JOBJ) { Buf b = {0}; bfmt(&b, "%s: %s", v->k[i], e->t == JSTR ? e->s : cs); print_trunc(pre, b.p); free(b.p); }
            else print_trunc(pre, e->t == JSTR ? e->s : cs);
            free(cs);
        }
        if (v->n > CTX_LIST_MAX) printf("  %s... %zu more\n", pre, v->n - CTX_LIST_MAX);
        return;
    }
    char *cs = jcompact_s(v); print_trunc(pre, cs); free(cs);
}
static int cmd_context(const char *target) {
    char r[PATH_MAX];
    if (!realpath(target, r)) die("no such file or directory: %s", target);
    struct stat st; if (stat(r, &st)) die("cannot stat %s", target);
    int isdir = S_ISDIR(st.st_mode);
    char *dir = isdir ? xstrdup(r) : dir_of(r), *top = repo_top(dir);
    size_t tl = top ? strlen(top) : 0;
    const char *rel = top ? (r[tl] ? r + tl + 1 : ".") : r;
    printf("CRUMB CONTEXT %s%s %s\n", rel, isdir && strcmp(rel, ".") ? "/" : "", AM2);
    printf("== CRUMBS (root first) ==\n");
    char **chain = NULL; size_t nc = 0; char *d = xstrdup(dir);
    for (;;) {
        char *cp = pjoin(d, ".crumb"); struct stat sb;
        if (stat(cp, &sb) == 0 && S_ISREG(sb.st_mode)) { chain = xrealloc(chain, (nc + 1) * sizeof *chain); chain[nc++] = xstrdup(d); }
        free(cp);
        if ((top && !strcmp(d, top)) || !strcmp(d, "/")) break;
        char *up = dir_of(d); if (!strcmp(up, d)) { free(up); break; }
        free(d); d = up;
    }
    free(d);
    if (!nc) printf("  (no .crumb at or above this path)\n");
    for (size_t i = nc; i-- > 0; ) {
        const char *cr = top ? (chain[i][tl] ? chain[i] + tl + 1 : "") : chain[i];
        char *cp = pjoin(chain[i], ".crumb"); J *c; const char *why = check_crumb(cp, &c);
        printf("-- %s%s.crumb%s%s%s\n", cr, *cr ? "/" : "", why ? " (unreadable: " : "", why ? why : "", why ? ")" : "");
        if (c) {
            static const char *const keys[] = { "name", "layer", "purpose", "invariants", "exports", "related", "boundaries", NULL };
            static const char *const labels[] = { "name", "layer", "purpose", "invariant", "export", "related", "boundary", NULL };
            for (int k = 0; keys[k]; k++) print_val(labels[k], jget(c, keys[k]));
        }
        free(cp);
    }
    printf("== RECENT COMMITS (live from git, last %d) ==\n", CTX_COMMITS);
    if (!top) printf("  (not a git repository)\n");
    else {
        char nb[16]; snprintf(nb, sizeof nb, "-%d", CTX_COMMITS);
        const char *la[] = { "log", nb, "--date=short", "--format=%h %ad %s", "--", rel, NULL };
        char *lg = git_run(top, la, NULL, NULL); int any = 0;
        for (char *s = strtok(lg, "\n"); s; s = strtok(NULL, "\n")) { print_trunc("", s); any = 1; }
        if (!any) printf("  (no commits touch this path)\n");
    }
    return 0;
}

/* ---------- create, retired commands, main ---------- */
static int cmd_create(const char *dir, const char *name, const char *purpose, const char *layer) {
    char *d = absdir(dir), *cp = pjoin(d, ".crumb");
    struct stat s; if (stat(cp, &s) == 0) { printf("EXISTS %s (edit it by hand)\n", cp); return 2; }
    J *c = jnew(JOBJ);
    if (layer && *layer) jset(c, "layer", jstr(layer));
    jset(c, "name", jstr(name)); jset(c, "purpose", jstr(purpose)); jset(c, "schema_version", jstr(SCHEMA));
    jsort(c); spit(cp, jdump(c));
    printf("CREATED %s\n", cp);
    return 0;
}
static int retired(const char *cmd) {
    int byhand = !strcmp(cmd, "seed") || !strcmp(cmd, "backfill") || !strcmp(cmd, "propose");
    printf("crumb %s: retired by RFC-0003 Am2; %s\n", cmd, byhand ? "write crumbs by hand" : LANES_NOTE);
    return 0;
}
static void usage(void) {
    fputs("usage: crumb <command> ...   (crumbs are advisory notes, RFC-0003 Am2)\n"
          "  context <path>                  crumb chain root first (purpose, invariants, exports, related, boundaries)\n"
          "                                  plus the last commits touching the path, computed live\n"
          "  explain <path>                  same as context\n"
          "  sniff [agent] <dir>             same as context for the directory\n"
          "  verify [root]                   readability lint; exit 1 only for unreadable or invalid crumbs\n"
          "  status [root]                   READABLE / UNREADABLE per crumb\n"
          "  compile [root]                  strip stored generated data from crumbs (idempotent); alias: migrate\n"
          "  digest [dir]                    print the structural digest block of dir, computed now\n"
          "  create <dir> <name> <purpose> [layer]\n"
          "  sha256                          sha256 of stdin\n"
          "retired (print one line, exit 0): claim update whisper close checkpoint resume list store-id seed backfill propose\n", stderr);
    exit(1);
}
int main(int argc, char **argv) {
    while (argc > 1 && !strcmp(argv[1], "--strict")) { argv++; argc--; }   /* accepted for old callers; no store any more */
    if (argc < 2) usage();
    const char *c = argv[1]; int a = argc - 2; char **v = argv + 2;
    static const char *const gone[] = { "claim", "update", "whisper", "close", "checkpoint", "resume", "list", "store-id",
                                        "seed", "backfill", "propose", NULL };
    for (int i = 0; gone[i]; i++) if (!strcmp(c, gone[i])) return retired(c);
    if ((!strcmp(c, "context") || !strcmp(c, "explain")) && a <= 1) return cmd_context(a ? v[0] : ".");
    if (!strcmp(c, "sniff") && a <= 2) return cmd_context(a ? v[a - 1] : ".");
    if ((!strcmp(c, "verify") || !strcmp(c, "validate")) && a <= 1) return cmd_verify(a ? v[0] : ".");
    if (!strcmp(c, "status") && a <= 1) return cmd_status(a ? v[0] : ".");
    if ((!strcmp(c, "compile") || !strcmp(c, "migrate")) && a <= 1) return cmd_compile(c, a ? v[0] : ".");
    if (!strcmp(c, "digest") && a <= 1) return cmd_digest(a ? v[0] : ".");
    if (!strcmp(c, "create") && a >= 3) return cmd_create(v[0], v[1], v[2], a > 3 ? v[3] : NULL);
    if (!strcmp(c, "sha256") && a == 0) {
        Sha s; char h[65]; unsigned char t[8192]; size_t n;
        sha_init(&s); while ((n = fread(t, 1, sizeof t, stdin)) > 0) sha_add(&s, t, n); sha_hex(&s, h);
        printf("%s\n", h); return 0;
    }
    usage();
    return 1;
}
