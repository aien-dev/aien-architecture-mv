#!/usr/bin/env bash
# Offline test for pr-gate.sh. A fake `gh` on PATH answers from fixture JSON chosen by $CASE and
# records any merge command line. The local step uses real temporary git repos (bare origin plus
# worktree). Crumbs are advisory (RFC-0003 Am2): the gate must never check them. No network, no auth.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/pr-gate.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export SLEEP_SECS=0
FX="$tmp/fx"; mkdir -p "$FX" "$tmp/bin"; export FX

cat > "$tmp/bin/gh" <<'S'
#!/usr/bin/env bash
d="$FX/$CASE"
case "$1 $2" in
  "pr view")
    if echo "$*" | grep -q mergeCommit && [ -e "$d/merged-flag" ]; then cat "$d/merged.json"
    else
      # UNKNOWN case: the first N answers can be counted
      cat "$d/pr.json"
    fi ;;
  "pr list") cat "$d/list.json" ;;
  "pr merge") echo "$*" > "$d/merge.cmd"; touch "$d/merged-flag" ;;
  api\ repos/*)
    if [ -e "$d/prot404" ]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
    cat "$d/prot.json" ;;
  *) echo "fake gh: unhandled: $*" >&2; exit 2 ;;
esac
S
# A crumb tool that always fails: if pr-gate.sh ever calls it again, the cases below go red.
cat > "$tmp/bin/crumb" <<'S'
#!/usr/bin/env bash
echo "crumb $1: FAIL: pr-gate.sh must not call crumb"; exit 1
S
chmod +x "$tmp/bin/gh" "$tmp/bin/crumb"
export PATH="$tmp/bin:$PATH"

pass=0; bad=0
ok() { pass=$((pass+1)); }
no() { bad=$((bad+1)); echo "TEST FAIL: $1"; }
run() { OUT=$("$gate" "$@" 2>&1); rc=$?; }
expect() { # expect <rc> <label> <gate args...>
  w=$1; l=$2; shift 2; run "$@"
  if [ "$rc" = "$w" ]; then ok; else no "$l (rc=$rc, want $w): $OUT"; fi
}
has() { # has <label> <pattern>   against $OUT
  if echo "$OUT" | grep -qE -- "$2"; then ok; else no "$1 (missing /$2/): $OUT"; fi
}
hasnot() { if echo "$OUT" | grep -qE -- "$2"; then no "$1 (unexpected /$2/): $OUT"; else ok; fi; }

# fixture builder: fx <case> [jq filter applied to the clean PR]
CLEANPR='{"number":7,"state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"feat","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","reviewDecision":"","statusCheckRollup":[{"__typename":"CheckRun","name":"rust","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"StatusContext","context":"legacy-ci","state":"SUCCESS"}]}'
fx() {
  mkdir -p "$FX/$1"
  echo "$CLEANPR" | jq "${2:-.}" > "$FX/$1/pr.json"
  echo '["rust","legacy-ci"]' > "$FX/$1/prot.json"
  echo '[{"number":7,"headRefName":"feat","mergeStateStatus":"CLEAN"},{"number":9,"headRefName":"other","mergeStateStatus":"BEHIND"},{"number":10,"headRefName":"third","mergeStateStatus":"CLEAN"}]' > "$FX/$1/list.json"
  echo '{"state":"MERGED","mergedAt":"2026-10-10T00:00:00Z","mergeCommit":{"oid":"cafebabecafebabecafebabecafebabecafebabe"}}' > "$FX/$1/merged.json"
}

# ---- GitHub-side cases (no worktree)
fx clean;      export CASE=clean;     expect 0 "clean PR passes dry run" repo1 7 --dry-run
has "dry run prints pr PASS" 'GATE pr: PASS'
has "local skipped without worktree" 'GATE local: SKIP no worktree given'
has "merge skipped in dry run" 'GATE merge: SKIP dry run'
has "queue marks BEHIND PR as needing rebase" 'QUEUE #9 other BEHIND needs a rebase onto origin/main'
has "queue shows clean PR plainly" 'QUEUE #10 third CLEAN$'
hasnot "queue omits the PR itself" 'QUEUE #7 '
check_nomerge() { if [ ! -e "$FX/$1/merge.cmd" ]; then ok; else no "$2"; fi; }
check_nomerge clean "dry run must not call gh pr merge"

fx behind '.mergeStateStatus="BEHIND"';       CASE=behind  expect 1 "BEHIND refuses" repo1 7 --dry-run
has "BEHIND reason" 'stale, rebase first'
fx dirty '.mergeStateStatus="DIRTY"';         CASE=dirty   expect 1 "DIRTY refuses" repo1 7 --dry-run
fx blocked '.mergeStateStatus="BLOCKED"';     CASE=blocked expect 1 "BLOCKED refuses" repo1 7 --dry-run
fx unstable '.mergeStateStatus="UNSTABLE"';   CASE=unstable expect 1 "UNSTABLE refuses" repo1 7 --dry-run
fx conflicting '.mergeable="CONFLICTING"';    CASE=conflicting expect 1 "mergeable CONFLICTING refuses" repo1 7 --dry-run
fx unknown '.mergeStateStatus="UNKNOWN"';     CASE=unknown expect 1 "UNKNOWN retries then refuses" repo1 7 --dry-run
has "UNKNOWN reason" 'has not computed mergeability'
fx hooks '.mergeStateStatus="HAS_HOOKS"';     CASE=hooks   expect 0 "HAS_HOOKS passes in dry run" repo1 7 --dry-run
CASE=hooks expect 1 "HAS_HOOKS refuses on a real merge" repo1 7
check_nomerge hooks "HAS_HOOKS real run must not merge"
fx draft '.isDraft=true';                     CASE=draft   expect 1 "draft refuses" repo1 7 --dry-run
fx closed '.state="CLOSED"';                  CASE=closed  expect 1 "closed refuses" repo1 7 --dry-run
fx wrongbase '.baseRefName="release"';        CASE=wrongbase expect 1 "non-main base refuses" repo1 7 --dry-run
fx missing '.statusCheckRollup=[{"__typename":"CheckRun","name":"rust","conclusion":"SUCCESS"}]'
CASE=missing expect 1 "required check absent from rollup refuses" repo1 7 --dry-run
has "names the missing check" 'legacy-ci'
fx failing '.statusCheckRollup[0].conclusion="FAILURE"'
CASE=failing expect 1 "required check present but FAILURE refuses" repo1 7 --dry-run
fx changes '.reviewDecision="CHANGES_REQUESTED"'; CASE=changes expect 1 "CHANGES_REQUESTED refuses" repo1 7 --dry-run
fx reqrev '.reviewDecision="REVIEW_REQUIRED"';    CASE=reqrev expect 1 "REVIEW_REQUIRED refuses" repo1 7 --dry-run
fx approved '.reviewDecision="APPROVED"';         CASE=approved expect 0 "APPROVED passes" repo1 7 --dry-run
fx noprot; touch "$FX/noprot/prot404";            CASE=noprot expect 0 "404 on protection gives SKIP and passes" repo1 7 --dry-run
has "no protection SKIP line" 'GATE checks: SKIP no branch protection'
has "no protection warning" 'WARNING'
fx noprotb '.mergeStateStatus="BEHIND"'; touch "$FX/noprotb/prot404"
CASE=noprotb expect 1 "404 protection does not rescue a BEHIND PR" repo1 7 --dry-run

# ---- merge cases
fx merge;  CASE=merge expect 0 "clean PR merges (non-dry-run)" repo1 7
has "merge PASS with sha" 'GATE merge: PASS squash; merge commit cafebabe'
if grep -q -- '--squash --delete-branch' "$FX/merge/merge.cmd" && ! grep -q -- '--admin' "$FX/merge/merge.cmd"; then ok; else no "merge command has squash+delete-branch and no --admin: $(cat "$FX/merge/merge.cmd" 2>&1)"; fi
fx adm; CASE=adm expect 0 "authorized admin merge" repo1 7 --admin-authorized-by "Drake, 2026-10-10, test"
if grep -q -- '--admin' "$FX/adm/merge.cmd"; then ok; else no "--admin recorded when authorized"; fi
has "authorization text printed" 'authorized by: Drake, 2026-10-10, test'
fx admfail '.mergeStateStatus="BLOCKED"'; CASE=admfail expect 1 "--admin never overrides a BLOCKED PR" repo1 7 --admin-authorized-by "Drake, 2026-10-10, test"
check_nomerge admfail "no merge call for BLOCKED even with authorization"
fx notmerged; echo '{"state":"OPEN","mergedAt":null,"mergeCommit":null}' > "$FX/notmerged/merged.json"
CASE=notmerged expect 1 "merge not confirmed is a FAIL" repo1 7
has "reports not MERGED" 'not MERGED'
CASE=clean expect 2 "bad usage exits 2" repo1
CASE=clean expect 2 "non-numeric PR exits 2" repo1 abc

# ---- local cases with real git repos
# mkrepo <name> [nocrumb]: main has src.txt (+ .crumb); branch feat = commit "feat", then (crumbs) a commit
# that edits .crumb together with source, which is fine now (no separate crumb commit rule).
mkrepo() {
  d="$tmp/$1"; mkdir -p "$d"; git init -q --bare -b main "$d/origin.git"; git init -q -b main "$d/seed"
  ( cd "$d/seed" && echo base > src.txt && { [ "${2:-}" = nocrumb ] || echo c0 > .crumb; } && git add -A && git commit -q -m base \
    && git remote add origin "$d/origin.git" && git push -q origin main )
  git clone -q "$d/origin.git" "$d/w"
  ( cd "$d/w" && git checkout -q -b feat && echo feat > feat.txt && git add -A && git commit -q -m feat
    if [ "${2:-}" != nocrumb ]; then echo c1 > .crumb && echo src1 > src1.txt && git add -A && git commit -q -m "source and crumb together"; fi
    git push -q origin feat )
  W="$d/w"
}
lfx() { # lfx <case> : fixture whose headRefOid is the worktree HEAD
  fx "$1" ".headRefOid=\"$(git -C "$W" rev-parse HEAD)\""
}
mkrepo l1; lfx l1; CASE=l1 expect 0 "local clean passes; last commit mixes source and .crumb" repo1 7 --dry-run --worktree "$W"
has "local PASS" 'GATE local: PASS'
hasnot "no crumb step any more" 'GATE crumb'

mkrepo l2; echo dirt >> "$W/feat.txt"; lfx l2; CASE=l2 expect 1 "dirty worktree refuses" repo1 7 --dry-run --worktree "$W"
has "dirty reason" 'worktree is dirty'

mkrepo l3; git -C "$W" checkout -q -b other; lfx l3; CASE=l3 expect 1 "wrong branch refuses" repo1 7 --dry-run --worktree "$W"
has "wrong branch reason" 'worktree is on other'

mkrepo l4
fx l4 '.headRefOid="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'; CASE=l4 expect 1 "local HEAD differs from GitHub head refuses" repo1 7 --dry-run --worktree "$W"
has "oid mismatch reason" 'differs from GitHub head'

mkrepo l5
( cd "$tmp/l5/seed" && echo more > more.txt && git add -A && git commit -q -m "main moves" && git push -q origin main )
lfx l5; CASE=l5 expect 1 "stale base refuses" repo1 7 --dry-run --worktree "$W"
has "stale base says rebase" 'rebase onto origin/main'

# a crumb that is not even JSON never blocks a merge
mkrepo l6; ( cd "$W" && echo '{broken' > .crumb && git add -A && git commit -q -m "broken note" && git push -q origin feat )
lfx l6; CASE=l6 expect 0 "a broken .crumb does not block the gate" repo1 7 --dry-run --worktree "$W"

mkrepo l8 nocrumb; lfx l8; CASE=l8 expect 0 "repo without crumbs passes" repo1 7 --dry-run --worktree "$W"
hasnot "no crumb notice either" 'GATE crumb'

echo "PASS $pass FAIL $bad"
[ "$bad" -eq 0 ]
