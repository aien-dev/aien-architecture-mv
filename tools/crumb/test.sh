#!/bin/sh
# crumb self-test (RFC-0003 Am2: crumbs are advisory notes). usage: sh test.sh ./crumb. Scratch dirs only.
C=${1:-./crumb}; C=$(cd "$(dirname "$C")" && pwd)/$(basename "$C")
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
fail=0; ok() { echo "PASS $1"; }; bad() { echo "FAIL $1"; fail=1; }
gc() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
crumb() { printf '{\n  "name": "%s",\n  "purpose": "%s",\n  "schema_version": "1.0.0"\n}\n' "$2" "$3" > "$1/.crumb"; }

R="$T/r"; mkdir -p "$R/src/deep" "$R/docs" && cd "$R" || exit 1
git init -q -b main . && echo 'int a;' > src/a.c && echo 'int b;' > src/deep/b.c && echo n > docs/n.md
crumb . r "Test repository root."; crumb docs docs "Design notes."
cat > src/.crumb <<'JSON'
{
  "boundaries": ["no network"],
  "exports": ["a()"],
  "invariants": ["no globals"],
  "name": "src",
  "purpose": "C sources.",
  "related": ["docs"],
  "schema_version": "1.0.0"
}
JSON
gc add -A && gc commit -qm "init (#1)" && echo 'int b2;' > src/deep/b.c && gc commit -qam "touch deep b"

# ---- verify: readability lint ----
out=$("$C" verify .); rc=$?
[ $rc -eq 0 ] && [ "$(echo "$out" | head -1)" = "crumb verify: OK: 3 crumbs readable (advisory, RFC-0003 Am2)" ] && ok "verify: valid crumbs, OK first line, exit 0" || bad "verify valid ($rc: $out)"
[ "$(echo "$out" | wc -l)" -eq 1 ] && ok "verify: one line when there is nothing to say" || bad "verify extra lines"
"$C" verify src | head -1 | grep -q 'OK: 3 crumbs' && ok "verify from a subdirectory lints the whole repository" || bad "verify subdir"
echo '{broken' > docs/.crumb; out=$("$C" verify .); rc=$?
[ $rc -eq 1 ] && echo "$out" | head -1 | grep -q '^crumb verify: FAIL: 1 of 3 crumbs unreadable' && echo "$out" | grep -q '^UNREADABLE docs: not valid JSON' && ok "verify: invalid JSON fails, exit 1, names the crumb" || bad "verify invalid JSON ($rc: $out)"
echo '["a"]' > docs/.crumb; "$C" verify . | grep -q 'UNREADABLE docs: not a JSON object' && ok "verify: non-object fails" || bad "verify non-object"
printf '{"schema_version":"1.0.0","name":"docs"}\n' > docs/.crumb; out=$("$C" verify .); rc=$?
[ $rc -eq 1 ] && echo "$out" | grep -q 'UNREADABLE docs: purpose is missing' && ok "verify: missing purpose fails, exit 1" || bad "verify missing purpose ($rc)"
printf '{"schema_version":1,"name":"docs","purpose":"p"}\n' > docs/.crumb; "$C" verify . >/dev/null; [ $? -eq 1 ] && ok "verify: numeric schema_version fails" || bad "verify numeric schema_version"
git checkout -q -- docs/.crumb
cp src/.crumb "$T/src.crumb"
jq '.extensions = {"generated": {"digest": "sha256:x"}, "provenance": {"entries": []}, "owner_lane": "x"}' "$T/src.crumb" > src/.crumb
out=$("$C" verify .); rc=$?
[ $rc -eq 0 ] && echo "$out" | head -1 | grep -q '^crumb verify: OK: 3 crumbs readable' && echo "$out" | grep -q '^WARN       src: stores extensions.generated, extensions.provenance' && ok "verify: stored generated block is a warning line, exit 0" || bad "verify generated warning ($rc: $out)"

# ---- compile: cleanup only, idempotent ----
before=$(jq -cS 'del(.extensions)' src/.crumb)
out=$("$C" compile .); [ $? -eq 0 ] && echo "$out" | head -1 | grep -q '^crumb compile: 3 crumbs, 1 rewritten, 0 skipped' && echo "$out" | grep -q '^STRIPPED   src' && ok "compile strips stored generated data and counts rewrites" || bad "compile strip ($out)"
jq -e '.extensions == {"owner_lane": "x"}' src/.crumb >/dev/null && ok "compile keeps other extensions keys" || bad "compile dropped other extensions"
[ "$before" = "$(jq -cS 'del(.extensions)' src/.crumb)" ] && ok "compile leaves the hand-written keys alone" || bad "compile touched hand keys"
s1=$(cat src/.crumb .crumb docs/.crumb | cksum); out=$("$C" compile .)
echo "$out" | grep -q ', 0 rewritten' && [ "$s1" = "$(cat src/.crumb .crumb docs/.crumb | cksum)" ] && ok "compile is idempotent (second run rewrites 0, bytes unchanged)" || bad "compile idempotent"
jq '.extensions = {"generated_policy": "on-demand", "seed": {"files": []}}' "$T/src.crumb" > src/.crumb
"$C" migrate . | grep -q '^crumb migrate: 3 crumbs, 1 rewritten' && ! jq -e 'has("extensions")' src/.crumb >/dev/null && ok "migrate is an alias; an emptied extensions object is dropped" || bad "migrate alias"
[ -z "$(git status --porcelain -- .crumb docs/.crumb)" ] && ok "compile never rewrites a clean crumb" || bad "compile rewrote clean crumbs"
[ "$(stat -c %a src/.crumb 2>/dev/null || stat -f %Lp src/.crumb)" = 644 ] && ok "rewritten crumb is mode 0644" || bad "crumb mode"
cp "$T/src.crumb" src/.crumb
echo '{broken' > docs/.crumb; "$C" compile . | grep -q 'SKIPPED    docs: not valid JSON' && ok "compile skips an unreadable crumb and says so" || bad "compile skip"
git checkout -q -- docs/.crumb

# ---- status ----
out=$("$C" status .); echo "$out" | head -1 | grep -q '^crumb status: 3 crumbs, 0 unreadable' && echo "$out" | grep -q '^READABLE   src$' && ok "status prints readable per crumb" || bad "status ($out)"

# ---- traversal: .crumbignore and build directories ----
mkdir -p ign target/x node_modules/p && echo '{bad' > target/x/.crumb && echo '{bad' > node_modules/p/.crumb && echo '{bad' > ign/.crumb
printf '# guarded\nign/\n' > .crumbignore
"$C" verify . | head -1 | grep -q 'OK: 3 crumbs' && ok "verify honours .crumbignore and skips untracked target/ and node_modules/" || bad "verify traversal"
rm -rf ign target node_modules .crumbignore

# ---- context / explain / sniff ----
ctx=$("$C" context src/deep/b.c)
echo "$ctx" | head -1 | grep -q '^CRUMB CONTEXT src/deep/b.c (advisory, RFC-0003 Am2)' && ok "context header names the path" || bad "context header"
[ "$(echo "$ctx" | grep '^-- ' | head -1)" = "-- .crumb" ] && [ "$(echo "$ctx" | grep '^-- ' | tail -1)" = "-- src/.crumb" ] && ok "context shows the crumb chain root first" || bad "context chain ($ctx)"
for k in 'purpose: C sources.' 'invariant: no globals' 'export: a()' 'related: docs' 'boundary: no network'; do
  echo "$ctx" | grep -qF "  $k" && ok "context shows $k" || bad "context missing $k"
done
echo "$ctx" | grep -q '^== RECENT COMMITS (live from git, last 5) ==' && echo "$ctx" | grep -q 'touch deep b' && ok "context lists commits touching the path, live" || bad "context commits"
echo "$ctx" | grep -q 'init (#1)' && ok "context includes older commits on the path" || bad "context older commit"
echo "$ctx" | grep -Eqi 'STALE|CURRENT|CONFLICT|CONTINUATION|lock' && bad "context still prints freshness/locks/continuation" || ok "context has no freshness, locks or continuation sections"
i=0; while [ $i -lt 8 ]; do echo $i >> src/a.c; gc commit -qam "c$i"; i=$((i+1)); done
[ "$("$C" context src | sed -n '/RECENT COMMITS/,$p' | grep -c '^  [0-9a-f]')" -eq 5 ] && ok "context shows at most 5 commits" || bad "context commit bound"
jq --argjson n "$(seq 1 40 | jq -R . | jq -s .)" '.invariants = $n' "$T/src.crumb" > src/.crumb
[ "$("$C" context src | wc -l)" -lt 40 ] && "$C" context src | grep -q 'invariant: ... 28 more' && ok "context output is bounded" || bad "context bounded"
cp "$T/src.crumb" src/.crumb
[ "$("$C" explain src/a.c)" = "$("$C" context src/a.c)" ] && ok "explain is context" || bad "explain"
[ "$("$C" sniff agent-x src)" = "$("$C" context src)" ] && [ "$("$C" sniff src)" = "$("$C" context src)" ] && ok "sniff is context for the directory" || bad "sniff"
echo '{bad' > docs/.crumb; "$C" context docs | grep -q '^-- docs/.crumb (unreadable: not valid JSON)' && ok "context reports an unreadable crumb instead of failing" || bad "context unreadable"
git checkout -q -- docs/.crumb
"$C" context "$T/nonexistent" >/dev/null 2>&1; [ $? -ne 0 ] && ok "context on a missing path fails" || bad "context missing"
mkdir -p "$T/plain/a" && crumb "$T/plain" plain "Not a repository." && "$C" context "$T/plain/a" | grep -q '(not a git repository)' && ok "context works outside git" || bad "context outside git"

# ---- digest: computed live, never stored ----
d1=$("$C" digest . | jq -r .digest); case "$d1" in sha256:*) ok "digest prints a root digest";; *) bad "digest ($d1)";; esac
"$C" digest . | jq -e '.children | map(.name) == ["docs", "src"]' >/dev/null && ok "digest lists child crumbs" || bad "digest children"
echo x >> src/a.c; [ "$("$C" digest . | jq -r .digest)" != "$d1" ] && [ -z "$(git status --porcelain -- '*.crumb' '**/.crumb')" ] && ok "a source change moves the digest and writes nothing" || bad "digest moves"
git checkout -q -- src/a.c

# ---- retired commands: one line, exit 0 ----
for cmd in claim update whisper close checkpoint resume; do
  out=$("$C" $cmd a b c d); rc=$?
  [ $rc -eq 0 ] && [ "$out" = "crumb $cmd: retired by RFC-0003 Am2; coordination is the lane system (Spark ~/.local/state/aien-local-ci/LANES)" ] && ok "$cmd retired (exit 0)" || bad "$cmd retired ($rc: $out)"
done
for cmd in seed backfill propose; do
  out=$("$C" $cmd .); rc=$?
  [ $rc -eq 0 ] && [ "$out" = "crumb $cmd: retired by RFC-0003 Am2; write crumbs by hand" ] && ok "$cmd retired (exit 0)" || bad "$cmd retired ($rc: $out)"
done
[ -z "$(git status --porcelain)" ] && [ ! -e .git/crumb ] && ok "retired commands write nothing" || bad "retired commands wrote files"

# ---- create, sha256, misc ----
mkdir -p new && echo x > new/f && "$C" create new new "Hand written." code | grep -q CREATED && "$C" verify . | head -1 | grep -q 'OK: 4 crumbs' && ok "create writes a readable crumb" || bad "create"
"$C" create new new "x" >/dev/null; [ $? -eq 2 ] && ok "create refuses to overwrite" || bad "create overwrite"
printf 'abc' | "$C" sha256 | grep -q '^ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad$' && ok "sha256 known vector (abc)" || bad "sha256"
"$C" --strict verify . >/dev/null && ok "--strict is accepted for old callers" || bad "--strict"
mkdir -p "$T/none" && cd "$T/none" && git init -q . && "$C" verify . | grep -q '^crumb verify: OK: 0 crumbs readable' && ok "a repository with no crumbs verifies OK" || bad "no crumbs"
exit $fail
