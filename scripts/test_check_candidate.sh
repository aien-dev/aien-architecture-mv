#!/usr/bin/env bash
# Test for tools/candidate/check_candidate.om. Offline: sha existence is stubbed (CAND_SHA_CHECK) and,
# for the real gh code path, a fake `gh` on PATH. No network or auth needed. The checker is compiled
# here with the pinned seeded compiler named by AIEN_OMC (exit 3 = NOT_RUN without it); the mutants
# below are sed edits of the .om source, recompiled, each proving one check bites.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../tools/candidate/check_candidate.om"
omc="${AIEN_OMC:-}"
[ -n "$omc" ] && [ -x "$omc" ] || { echo "test_check_candidate: AIEN_OMC is not an executable omc (NOT_RUN)" >&2; exit 3; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
chk="$tmp/check_candidate"
"$omc" < "$src" > "$chk" && chmod +x "$chk" || { echo "TEST FAIL: $src does not compile with $omc"; exit 1; }
stub="$tmp/stub.sh"
cat > "$stub" <<'S'
#!/usr/bin/env bash
[ "$2" != "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" ]
S
chmod +x "$stub"; export CAND_SHA_CHECK="$stub"
good="$here/testdata/cand-draft-fixture.toml"   # the 2026-10-01 draft, kept as a fixture so these tests do not depend on the live manifest
live="$here/../qualification/candidates/CAND-0.toml"
pass=0; bad=0
expect() { # expect <0|1> <label> <file>
  "$chk" "$3" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$1" ]; then pass=$((pass+1)); else bad=$((bad+1)); echo "TEST FAIL: $2 (rc=$rc)"; fi
}
expect 0 "CAND-0 valid" "$good"
sed '/^omega = /d' "$good" > "$tmp/a.toml";            expect 1 "missing omega" "$tmp/a.toml"
sed 's/^id = .*//' "$good" > "$tmp/b.toml";            expect 1 "missing id" "$tmp/b.toml"
sed 's/^omega = .*/omega = "abc123"/' "$good" > "$tmp/c.toml"; expect 1 "short sha" "$tmp/c.toml"
sed 's/^aienos = .*/aienos = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"/' "$good" > "$tmp/d.toml"; expect 1 "nonexistent sha" "$tmp/d.toml"
sed 's/^status = .*/status = "frozen"/' "$good" > "$tmp/e.toml"; expect 1 "frozen with UNBUILT" "$tmp/e.toml"
sed '/^omega-runtime/d;/^aienos-boot/d;/^aien-proof =/d' "$good" > "$tmp/f.toml"; expect 1 "no executables" "$tmp/f.toml"
H64a=$(printf 'a%.0s' $(seq 64)); H64b=$(printf 'b%.0s' $(seq 64)); H64c=$(printf 'c%.0s' $(seq 64))
Z64=$(printf '0%.0s' $(seq 64))
frozen() { # frozen <out> : valid frozen manifest with real-looking digests
  sed -e 's/^status = .*/status = "frozen"/' -e "s/^omega-runtime = .*/omega-runtime = \"$H64a\"/" \
      -e "s/^aienos-boot-image = .*/aienos-boot-image = \"$H64b\"/" -e "s/^aien-proof = .*/aien-proof = \"$H64c\"/" "$good" > "$1"
}

# --- new: positive frozen case
frozen "$tmp/fz.toml";                                          expect 0 "frozen with real digests" "$tmp/fz.toml"
# --- new: all-zero digest rejected (frozen and draft)
sed "s/^aien-proof = .*/aien-proof = \"$Z64\"/" "$tmp/fz.toml" > "$tmp/z.toml"; expect 1 "all-zero digest (frozen)" "$tmp/z.toml"
sed "s/^aien-proof = .*/aien-proof = \"$Z64\"/" "$good" > "$tmp/z2.toml";        expect 1 "all-zero digest (draft)" "$tmp/z2.toml"
# --- new: '#' inside a quoted value is kept, not truncated
sed "s/^aien-proof = .*/aien-proof = \"${H64c}#frag\"/" "$tmp/fz.toml" > "$tmp/h.toml"; expect 1 "digest with # is not truncated into validity" "$tmp/h.toml"
sed 's/^note = .*/note = "issue #5 and #6"  # trailing comment/' "$good" > "$tmp/n.toml"; expect 0 "# in note and trailing comment ok" "$tmp/n.toml"
# --- new: contracts pinned
sed '/^crumb-spec = /d' "$good" > "$tmp/k1.toml";               expect 1 "missing crumb-spec" "$tmp/k1.toml"
sed '/^spark-crumbs = /d' "$good" > "$tmp/k2.toml";             expect 1 "missing spark-crumbs" "$tmp/k2.toml"
sed 's/^spark-crumbs = .*/spark-crumbs = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"/' "$good" > "$tmp/k3.toml"; expect 1 "nonexistent spark-crumbs sha" "$tmp/k3.toml"
sed 's/^crumb-spec = .*/crumb-spec = "abc"/' "$good" > "$tmp/k4.toml"; expect 1 "short crumb-spec sha" "$tmp/k4.toml"

# --- new: real gh code path, via a faithful offline stub of `gh` on PATH.
# The stub accepts `gh api repos/aien-dev/<repo>/commits/<sha> -q .sha`, prints the sha and
# exits 0 for known shas, prints a 404 message and exits 1 for deadbeef..., and logs argv.
mkdir -p "$tmp/bin"; log="$tmp/gh.log"
cat > "$tmp/bin/gh" <<'S'
#!/usr/bin/env bash
echo "$*" >> "$GH_STUB_LOG"
[ "$1" = "api" ] || exit 2
sha="${2##*/}"
if [ "$sha" = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" ]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
echo "$sha"
S
chmod +x "$tmp/bin/gh"
ghexpect() { # ghexpect <rc> <label> <file>
  ( unset CAND_SHA_CHECK; PATH="$tmp/bin:$PATH" GH_STUB_LOG="$log" "$chk" "$3" >/dev/null 2>&1 ); rc=$?
  if [ "$rc" = "$1" ]; then pass=$((pass+1)); else bad=$((bad+1)); echo "TEST FAIL: $2 (rc=$rc)"; fi
}
: > "$log"
ghexpect 0 "gh path: CAND-0 valid" "$good"
grep -q 'api repos/aien-dev/crumb-spec/commits/10b825133580f7a4388ce78aca64b5db52c5d35b ' "$log" \
  && pass=$((pass+1)) || { bad=$((bad+1)); echo "TEST FAIL: gh was not called for crumb-spec"; }
[ "$(wc -l < "$log")" -eq 7 ] && pass=$((pass+1)) || { bad=$((bad+1)); echo "TEST FAIL: expected 7 gh calls, got $(wc -l < "$log")"; }
ghexpect 1 "gh path: 404 sha rejected" "$tmp/d.toml"
ghexpect 1 "gh path: 404 contract sha rejected" "$tmp/k3.toml"


# --- live candidate manifest (CAND-0 is frozen): valid, 9 pins checked through the gh path, and its optional pins bite.
expect 0 "live CAND-0 valid" "$live"
grep -q '^status = "frozen"' "$live" && pass=$((pass+1)) || { bad=$((bad+1)); echo "TEST FAIL: live CAND-0 is not frozen"; }
: > "$log"
ghexpect 0 "gh path: live CAND-0 valid" "$live"
[ "$(wc -l < "$log")" -eq 9 ] && pass=$((pass+1)) || { bad=$((bad+1)); echo "TEST FAIL: expected 9 gh calls for the live manifest, got $(wc -l < "$log")"; }
sed 's/^physics = .*/physics = "abc123"/' "$live" > "$tmp/p1.toml";   expect 1 "short physics sha" "$tmp/p1.toml"
sed 's/^interplane = .*/interplane = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"/' "$live" > "$tmp/p2.toml"; expect 1 "nonexistent interplane sha" "$tmp/p2.toml"
sed 's/^omega-runtime = .*/omega-runtime = "UNBUILT"/' "$live" > "$tmp/p3.toml"; expect 1 "frozen live manifest with UNBUILT" "$tmp/p3.toml"

# --- amendments: <stem>.amendment-<n>.toml next to the manifest is read; a frozen manifest edit is refused.
amd="$tmp/amd"; mkdir -p "$amd"; frozen "$amd/CX.toml"; printf '\n[model]\nmodel-id = "m"\n' >> "$amd/CX.toml"
amend() { # amend <n> <manifest-sha> [extra line...] : write CX.amendment-<n>.toml
  local n="$1" s="$2"; shift 2
  { printf 'schema = "CandidateAmendmentV1"\ncandidate = "CAND-0"\namendment = "%s"\ndate = "2026-10-06"\nreason = "test"\nmanifest-sha256 = "%s"\n\n[model]\n' "$n" "$s"
    printf 'oracle-fixture-safetensors-sha256 = "%s"\n' "$H64a"; for l in "$@"; do printf '%s\n' "$l"; done; } > "$amd/CX.amendment-$n.toml"
}
MSHA=$(sha256sum "$amd/CX.toml" | cut -d' ' -f1)
amend 1 "$MSHA";                                                expect 0 "amendment: valid amendment accepted" "$amd/CX.toml"
"$chk" "$amd/CX.toml" 2>/dev/null | grep -q '(amendments: 1)' && pass=$((pass+1)) || { bad=$((bad+1)); echo "TEST FAIL: amendment file not picked up"; }
amend 1 "$MSHA" "tokenizer-json-sha256 = \"$Z64\"";             expect 1 "amendment: all-zero digest in amendment refused (file is read)" "$amd/CX.toml"
cp "$amd/CX.toml" "$amd/CX.orig"; amend 1 "$MSHA"
echo '# edited after the freeze' >> "$amd/CX.toml";              expect 1 "amendment: frozen manifest edited after amendment refused" "$amd/CX.toml"
cp "$amd/CX.orig" "$amd/CX.toml"
amend 1 "$MSHA" "[executables]" "omega-runtime = \"$H64b\"";     expect 1 "amendment: [executables] cannot be amended" "$amd/CX.toml"
amend 1 "$MSHA" "[commits]" "physics = \"0123456789012345678901234567890123456789\""; expect 1 "amendment: [commits] cannot be amended" "$amd/CX.toml"
amend 1 "$MSHA" "model-id = \"other\"";                       expect 1 "amendment: a key already in the manifest is not overridden" "$amd/CX.toml"
cp -r "$amd" "$tmp/amdov"   # kept for the override mutant below
amend 1 "$MSHA"; sed -i 's/^candidate = .*/candidate = "CAND-9"/' "$amd/CX.amendment-1.toml"; expect 1 "amendment: wrong candidate refused" "$amd/CX.toml"
amend 1 "$MSHA"; sed -i 's/^amendment = .*/amendment = "2"/' "$amd/CX.amendment-1.toml";        expect 1 "amendment: number must match file name" "$amd/CX.toml"
amend 1 "$MSHA"
live4="$here/../qualification/candidates/CAND-4.toml"
expect 0 "live CAND-4 with Amendment 1 valid" "$live4"
"$chk" "$live4" 2>/dev/null | grep -q '(amendments: 1)' && pass=$((pass+1)) || { bad=$((bad+1)); echo "TEST FAIL: live CAND-4 amendment not picked up"; }
[ -z "$(cd "$here/.." && git diff 7f99d7ee4221bb3cd8b3bc23bf167a64baac24e4 -- qualification/candidates/CAND-4.toml 2>/dev/null)" ] && pass=$((pass+1)) || { bad=$((bad+1)); echo "TEST FAIL: frozen CAND-4.toml differs from 7f99d7e"; }
echo '# edited' >> "$amd/CX.toml"   # left edited for the mutant below

# --- mutants. Each broken copy of the checker (one sed edit of the .om source, recompiled) must
# wrongly accept the bad input, proving the test above really depends on that check.
mutant() { # mutant <label> <sed-expr> <input-file>
  sed "$2" "$src" > "$tmp/mut.om"
  if cmp -s "$src" "$tmp/mut.om"; then bad=$((bad+1)); echo "TEST FAIL: mutant '$1' did not change the checker"; return; fi
  "$omc" < "$tmp/mut.om" > "$tmp/mut" 2>/dev/null && chmod +x "$tmp/mut" || { bad=$((bad+1)); echo "TEST FAIL: mutant '$1' does not compile"; return; }
  "$tmp/mut" "$3" >/dev/null 2>&1; rc=$?
  if [ "$rc" = 0 ]; then pass=$((pass+1)); else bad=$((bad+1)); echo "TEST FAIL: mutant '$1' still rejected (rc=$rc), test does not bite"; fi
}
mutant "no zero-digest check" 's/^z = zero64 e$/z = false/' "$tmp/z.toml"
mutant "old # truncation" 's/^ret and lt i e ne get src i 34$/ret and lt i e and ne get src i 34 ne get src i 35/' "$tmp/h.toml"
mutant "contracts not required" 's/^const NREQ ulong 7$/const NREQ ulong 5/' "$tmp/k1.toml"
mutant "optional pins not checked" '/^optpins$/d' "$tmp/p1.toml"
mutant "optional pin sha existence not checked" '/^fn optpin /,/^fn optpins /s/^if not shaex i e$/if false/' "$tmp/p2.toml"
mutant "manifest pin not checked" 's/^if not mfeq e$/if false/' "$amd/CX.toml"
mutant "amendment may override" 's/^if inmf x$/if false/' "$tmp/amdov/CX.toml"
echo "passed=$pass failed=$bad"
[ "$bad" -eq 0 ]
