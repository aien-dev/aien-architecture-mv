#!/usr/bin/env bash
# tools/candidate/parity/mkcases.sh <repo> <outdir>: (re)build the case directories of the parity
# corpus from scripts/testdata/cand-draft-fixture.toml, the live CAND-0/CAND-4 manifests and the
# recipes of the two test suites, plus the adversarial cases. The committed cases/ were made by
# this script; expected/ was then recorded with run.sh ... record from the bash checkers at
# 1dd84d1 (git show 1dd84d1:scripts/check_candidate.sh), which the .om binaries must reproduce.
# Each case is a directory: m.toml (+ amendments, files/), optional `args` (one arg per line,
# default "m.toml"), `mode` (sha | shawords | emptysha | gh | files | fileswords, see run.sh) and
# optional `limit` (a named difference from the bash; README "Limits").
set -eu
repo="$1"; out="$2"
good="$repo/scripts/testdata/cand-draft-fixture.toml"
live="$repo/qualification/candidates/CAND-0.toml"
live4="$repo/qualification/candidates/CAND-4.toml"
H64a=$(printf 'a%.0s' $(seq 64)); H64b=$(printf 'b%.0s' $(seq 64)); H64c=$(printf 'c%.0s' $(seq 64)); Z64=$(printf '0%.0s' $(seq 64))
rm -rf "$out"; mkdir -p "$out/candidate" "$out/pins"
C="$out/candidate"
mk() { mkdir -p "$C/$1"; echo "${2:-sha}" > "$C/$1/mode"; }
frozen() { sed -e 's/^status = .*/status = "frozen"/' -e "s/^omega-runtime = .*/omega-runtime = \"$H64a\"/" \
      -e "s/^aienos-boot-image = .*/aienos-boot-image = \"$H64b\"/" -e "s/^aien-proof = .*/aien-proof = \"$H64c\"/" "$good"; }
mk good; cp "$good" "$C/good/m.toml"
mk missing-omega; sed '/^omega = /d' "$good" > "$C/missing-omega/m.toml"
mk missing-id; sed 's/^id = .*//' "$good" > "$C/missing-id/m.toml"
mk short-sha; sed 's/^omega = .*/omega = "abc123"/' "$good" > "$C/short-sha/m.toml"
mk nonexistent-sha; sed 's/^aienos = .*/aienos = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"/' "$good" > "$C/nonexistent-sha/m.toml"
mk frozen-unbuilt; sed 's/^status = .*/status = "frozen"/' "$good" > "$C/frozen-unbuilt/m.toml"
mk no-executables; sed '/^omega-runtime/d;/^aienos-boot/d;/^aien-proof =/d' "$good" > "$C/no-executables/m.toml"
mk frozen-ok; frozen > "$C/frozen-ok/m.toml"
mk zero-digest-frozen; frozen | sed "s/^aien-proof = .*/aien-proof = \"$Z64\"/" > "$C/zero-digest-frozen/m.toml"
mk zero-digest-draft; sed "s/^aien-proof = .*/aien-proof = \"$Z64\"/" "$good" > "$C/zero-digest-draft/m.toml"
mk hash-in-digest; frozen | sed "s/^aien-proof = .*/aien-proof = \"${H64c}#frag\"/" > "$C/hash-in-digest/m.toml"
mk hash-in-note; sed 's/^note = .*/note = "issue #5 and #6"  # trailing comment/' "$good" > "$C/hash-in-note/m.toml"
mk missing-crumb-spec; sed '/^crumb-spec = /d' "$good" > "$C/missing-crumb-spec/m.toml"
mk missing-spark-crumbs; sed '/^spark-crumbs = /d' "$good" > "$C/missing-spark-crumbs/m.toml"
mk nonexistent-spark-crumbs; sed 's/^spark-crumbs = .*/spark-crumbs = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"/' "$good" > "$C/nonexistent-spark-crumbs/m.toml"
mk short-crumb-spec; sed 's/^crumb-spec = .*/crumb-spec = "abc"/' "$good" > "$C/short-crumb-spec/m.toml"
mk gh-good gh; cp "$good" "$C/gh-good/m.toml"
mk gh-404 gh; cp "$C/nonexistent-sha/m.toml" "$C/gh-404/m.toml"
mk gh-404-contract gh; cp "$C/nonexistent-spark-crumbs/m.toml" "$C/gh-404-contract/m.toml"
mk live-cand0; cp "$live" "$C/live-cand0/m.toml"
mk gh-live-cand0 gh; cp "$live" "$C/gh-live-cand0/m.toml"
mk short-physics; sed 's/^physics = .*/physics = "abc123"/' "$live" > "$C/short-physics/m.toml"
mk nonexistent-interplane; sed 's/^interplane = .*/interplane = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"/' "$live" > "$C/nonexistent-interplane/m.toml"
mk frozen-live-unbuilt; sed 's/^omega-runtime = .*/omega-runtime = "UNBUILT"/' "$live" > "$C/frozen-live-unbuilt/m.toml"
# amendments
amend() { # amend <dir> <n> <manifest-sha> [extra line...]
  local d="$1" n="$2" s="$3"; shift 3
  { printf 'schema = "CandidateAmendmentV1"\ncandidate = "CAND-0"\namendment = "%s"\ndate = "2026-10-06"\nreason = "test"\nmanifest-sha256 = "%s"\n\n[model]\n' "$n" "$s"
    printf 'oracle-fixture-safetensors-sha256 = "%s"\n' "$H64a"; for l in "$@"; do printf '%s\n' "$l"; done; } > "$d/m.amendment-$n.toml"
}
cx() { frozen; printf '\n[model]\nmodel-id = "m"\n'; }
cx > /tmp/cx.$$; MSHA=$(sha256sum /tmp/cx.$$ | cut -d' ' -f1)
am() { mk "$1"; cp /tmp/cx.$$ "$C/$1/m.toml"; }
am amend-valid; amend "$C/amend-valid" 1 "$MSHA"
am amend-zero-digest; amend "$C/amend-zero-digest" 1 "$MSHA" "tokenizer-json-sha256 = \"$Z64\""
am amend-edited; amend "$C/amend-edited" 1 "$MSHA"; echo '# edited after the freeze' >> "$C/amend-edited/m.toml"
am amend-executables; amend "$C/amend-executables" 1 "$MSHA" "[executables]" "omega-runtime = \"$H64b\""
am amend-commits; amend "$C/amend-commits" 1 "$MSHA" "[commits]" "physics = \"0123456789012345678901234567890123456789\""
am amend-override; amend "$C/amend-override" 1 "$MSHA" "model-id = \"other\""
am amend-wrong-candidate; amend "$C/amend-wrong-candidate" 1 "$MSHA"; sed -i 's/^candidate = .*/candidate = "CAND-9"/' "$C/amend-wrong-candidate/m.amendment-1.toml"
am amend-wrong-number; amend "$C/amend-wrong-number" 1 "$MSHA"; sed -i 's/^amendment = .*/amendment = "2"/' "$C/amend-wrong-number/m.amendment-1.toml"
am amend-two; amend "$C/amend-two" 1 "$MSHA"; amend "$C/amend-two" 2 "$MSHA" "[model]" "extra-sha256 = \"$H64b\""; sed -i 's/^amendment = "2"/amendment = "2"/' "$C/amend-two/m.amendment-2.toml"
am amend-no-keys; amend "$C/amend-no-keys" 1 "$MSHA"; sed -i '/oracle-fixture/d' "$C/amend-no-keys/m.amendment-1.toml"
am amend-unknown-top; amend "$C/amend-unknown-top" 1 "$MSHA"; printf 'stray = "x"\nother = "y"\nthird = "z"\n' >> "$C/amend-unknown-top/m.amendment-1.toml"
am amend-bad-schema; amend "$C/amend-bad-schema" 1 "$MSHA"; sed -i 's/^schema = .*/schema = "Nope"/;/^date = /d' "$C/amend-bad-schema/m.amendment-1.toml"
am amend-dir-skipped; amend "$C/amend-dir-skipped" 1 "$MSHA"; mkdir -p "$C/amend-dir-skipped/m.amendment-7.toml"; : > "$C/amend-dir-skipped/m.amendment-7.toml/.keep"
am amend-many-bad; amend "$C/amend-many-bad" 1 "$MSHA" "[model]" $(for i in $(seq 1 24); do printf 'k%02d-sha256 = "zz"\n' $i; done | tr '\n' ' ') "[contracts]" 'x = "1"' "[consumed_pins]" 'y = "2"' 'model-id = "dup"' ; sed -i 's/ k\([0-9]*\)-sha256 = "zz"/\nk\1-sha256 = "zz"/g' "$C/amend-many-bad/m.amendment-1.toml"
am amend-sha-not-real; amend "$C/amend-sha-not-real" 1 "$MSHA" "a-sha256 = \"abc\"" "b-sha256 = \"$Z64\"" "c-sha256 = \"$H64c\""
am amend-order; for n in 1 2 10; do amend "$C/amend-order" $n "$MSHA"; sed -i 's/^candidate = .*/candidate = "CAND-X"/' "$C/amend-order/m.amendment-$n.toml"; done; echo "bash globs <stem>.amendment-*.toml in the locale's collation (en_US: 10, 1, 2); the .om walks the names in byte order (1, 10, 2); only the order of FAIL lines of several amendments differs" > "$C/amend-order/limit"
mk live-cand4; cp "$live4" "$C/live-cand4/m.toml"; cp "$repo/qualification/candidates/CAND-4.amendment-1.toml" "$C/live-cand4/m.amendment-1.toml"
# adversarial
mk dup-key; { cat "$good"; printf '\n[commits]\nomega = "abc"\nid = "later"\n'; } > "$C/dup-key/m.toml"
mk dup-key-section; sed 's/^id = .*/id = "first"\nid = "second"/' "$good" > "$C/dup-key-section/m.toml"; sed -i 's/^aien-proof = .*/aien-proof = "UNBUILT"\naien-proof = "zz"/' "$C/dup-key-section/m.toml"
mk wrong-type; sed 's/^status = .*/status = frozen/; s/^created = .*/created = 2026/; s/^omega-runtime = .*/omega-runtime = [1, 2]/' "$good" > "$C/wrong-type/m.toml"
mk wrong-type-amend; cp /tmp/cx.$$ "$C/wrong-type-amend/m.toml"; amend "$C/wrong-type-amend" 1 "$MSHA"; sed -i 's/^amendment = .*/amendment = 1/' "$C/wrong-type-amend/m.amendment-1.toml"
mk extra-section; { cat "$good"; printf '\n[extra]\nfoo = "bar"\n[[array]]\nx = "y"\n[executables.sub]\nz = "UNBUILT"\n'; } > "$C/extra-section/m.toml"
mk crlf; sed 's/$/\r/' "$good" > "$C/crlf/m.toml"
mk crlf-amend; sed 's/$/\r/' /tmp/cx.$$ > "$C/crlf-amend/m.toml"; amend "$C/crlf-amend" 1 "$(sha256sum "$C/crlf-amend/m.toml" | cut -d' ' -f1)"; sed -i 's/$/\r/' "$C/crlf-amend/m.amendment-1.toml"
mk trailing-space; sed 's/^\(\[[a-z]*\]\)$/\1   /; s/^\(schema = ".*"\)$/\1 \t /; s/^\(omega = ".*"\)$/  \1  /' "$good" > "$C/trailing-space/m.toml"
mk no-final-newline; printf '%s' "$(cat "$good")" > "$C/no-final-newline/m.toml"
mk no-final-newline-exe; { sed '/^aien-proof = /d' "$good"; printf 'aien-proof = "UNBUILT"'; } > "$C/no-final-newline-exe/m.toml"
mk nul-byte; { printf 'id = "CA\0ND-0"\n'; sed '/^id = /d' "$good"; } > "$C/nul-byte/m.toml"
mk non-ascii; { printf 'note = "caf\xc3\xa9"\nnote2 = "caf\xe9 raw"\n'; sed 's/^id = .*/id = "CAND-caf\xc3\xa9"/' "$good"; } > "$C/non-ascii/m.toml"
mk non-ascii-invalid; sed 's/^id = .*/id = "CAND-\xe9"/; s/^created = .*/created = "2026" # \xe9/' "$good" > "$C/non-ascii-invalid/m.toml"; echo "bash under a UTF-8 LANG refuses the regex on invalid UTF-8; the .om matches bytes" > "$C/non-ascii-invalid/limit"
mk non-ascii-space; sed 's/^status = .*/status = "draft, not frozen"\xe2\x80\x83/' "$good" > "$C/non-ascii-space/m.toml"; echo "bash under a UTF-8 LANG counts U+2003 (any iswspace character) as [[:space:]]; the .om knows the six ASCII spaces only" > "$C/non-ascii-space/limit"
mk non-ascii-nbsp; sed 's/^status = .*/status = "draft, not frozen"\xc2\xa0/' "$good" > "$C/non-ascii-nbsp/m.toml"
mk empty-value; sed 's/^id = .*/id = ""/; s/^status = .*/status = ""/' "$good" > "$C/empty-value/m.toml"
mk junk-lines; { printf '  # leading comment\n\t[commits] junk\nkey = "v" junk\n= "x"\n[]\n[bad key]\nkey = "unterminated\nkey == "v"\n'; cat "$good"; printf '[ spaced ]\n   [tail]   # c\nzzz = "1"\n'; } > "$C/junk-lines/m.toml"
mk compact; sed 's/ = /=/' "$good" > "$C/compact/m.toml"
mk many-exe-bad; { cat "$good"; printf '[executables]\n'; for i in $(seq 1 40); do printf 'bin-%02d = "nope%d"\n' $i $i; done; for i in $(seq 1 10); do printf 'img-%02d = "UNBUILT"\n' $i; done; } | sed 's/^status = .*/status = "frozen"/' > "$C/many-exe-bad/m.toml"
mk many-exe-ok; { cat "$good"; printf '[executables]\n'; for i in $(seq 1 200); do printf 'bin-%03d = "UNBUILT"\n' $i; done; } > "$C/many-exe-ok/m.toml"
mk empty-file; : > "$C/empty-file/m.toml"
mk only-comments; printf '# a\n\n   # b\n' > "$C/only-comments/m.toml"
mk no-arg; cp "$good" "$C/no-arg/m.toml"; : > "$C/no-arg/args"
mk missing-file; printf 'nope.toml\n' > "$C/missing-file/args"
mk dir-arg; mkdir -p "$C/dir-arg/d.toml"; : > "$C/dir-arg/d.toml/.keep"; printf 'd.toml\n' > "$C/dir-arg/args"
mk subdir-path; mkdir -p "$C/subdir-path/sub"; cp /tmp/cx.$$ "$C/subdir-path/sub/m.toml"; (cd "$C/subdir-path/sub" && amend . 1 "$MSHA"); printf 'sub/m.toml\n' > "$C/subdir-path/args"
mk dotslash-path; cp /tmp/cx.$$ "$C/dotslash-path/m.toml"; amend "$C/dotslash-path" 1 "$MSHA"; printf './m.toml\n' > "$C/dotslash-path/args"
mk stem-no-toml; cp /tmp/cx.$$ "$C/stem-no-toml/m.txt"; amend "$C/stem-no-toml" 1 "$MSHA"; mv "$C/stem-no-toml/m.amendment-1.toml" "$C/stem-no-toml/m.txt.amendment-1.toml"; printf 'm.txt\n' > "$C/stem-no-toml/args"
mk sha-check-words; cp "$good" "$C/sha-check-words/m.toml"; echo "shawords" > "$C/sha-check-words/mode"
mk status-superseded; sed 's/^status = .*/status = "superseded"/' "$C/frozen-ok/m.toml" > "$C/status-superseded/m.toml"
mk status-bad; sed 's/^status = .*/status = "final"/' "$good" > "$C/status-bad/m.toml"
mk uppercase-sha; sed 's/^omega = .*/omega = "25B4A51141FA48BE01D1CDBAC8617D41065E523D"/' "$good" > "$C/uppercase-sha/m.toml"
mk sha-check-unset-empty; cp "$good" "$C/sha-check-unset-empty/m.toml"; echo "emptysha" > "$C/sha-check-unset-empty/mode"
rm -f /tmp/cx.$$ /tmp/nul.$$

# ---------------- pins ----------------
P="$out/pins"
OM=1111111111111111111111111111111111111111; SC=2222222222222222222222222222222222222222
AO=3333333333333333333333333333333333333333; PH=4444444444444444444444444444444444444444
PR=5555555555555555555555555555555555555555; CS=6666666666666666666666666666666666666666
SP=7777777777777777777777777777777777777777; AR=8888888888888888888888888888888888888888
OTHER=9999999999999999999999999999999999999999
serve() { mkdir -p "$(dirname "$cur/files/$1")"; cat > "$cur/files/$1"; }
tree() {
  rm -rf "$cur/files"
  echo "$OM" | serve "aien-sovereign-core/$SC/omega.lock"
  serve "aien-sovereign-core/$SC/Cargo.lock" <<L
[[package]]
name = "aien-protocol-types"
source = "git+https://github.com/aien-dev/aien-protocols?rev=$PR#$PR"

[[package]]
name = "aien-probe"
source = "git+https://github.com/aien-dev/aien-protocols?rev=$PR#$PR"

[[package]]
name = "crumb-spec"
source = "git+https://github.com/aien-dev/crumb-spec?rev=$CS#$CS"

[[package]]
name = "spark-crumbs"
source = "git+https://github.com/aien-dev/spark-crumbs?rev=$SP#$SP"

[[package]]
name = "serde"
source = "registry+https://github.com/rust-lang/crates.io-index"
L
  echo "$PH" | serve "omega/$OM/physics.lock"
  echo "$AO" | serve "omega/$OM/aienos.lock"
  printf '%s\n# argus pin, comment with no hex\n' "$AR" | serve "omega/$OM/argus.lock"
}
manifest() {
  cat > "$1" <<M
schema = "CandidateManifestV1"
id = "CAND-T"
[commits]
omega = "$OM"
aienos = "$AO"
aien-sovereign-core = "$SC"
aien-protocols = "$PR"
physics = "$PH"
[contracts]
crumb-spec = "$CS"
spark-crumbs = "$SP"
[consumed_pins]
sovereign-core-omega-lock = "$OM"
sovereign-core-cargo-lock-aien-protocols = "$PR"
omega-physics-lock = "$PH"
omega-aienos-lock = "$AO"
omega-argus-lock = "$AR"
something-else = "not read"
M
}
pk() { cur="$P/$1"; mkdir -p "$cur"; echo files > "$cur/mode"; tree; manifest "$cur/m.toml"; }
pk agree
pk contract-other; sed -i "s/^crumb-spec = .*/crumb-spec = \"$OTHER\"/" "$cur/m.toml"
pk protocols-other; sed -i "s/^aien-protocols = .*/aien-protocols = \"$OTHER\"/" "$cur/m.toml"
pk aienos-other; sed -i "s/^aienos = .*/aienos = \"$OTHER\"/" "$cur/m.toml"
pk physics-other; sed -i "s/^physics = .*/physics = \"$OTHER\"/" "$cur/m.toml"
pk consumed-other; sed -i "s/^omega-argus-lock = .*/omega-argus-lock = \"$OTHER\"/" "$cur/m.toml"
pk physics-unpinned; sed -i '/^physics = /d;/^omega-physics-lock/d' "$cur/m.toml"
pk contract-missing; sed -i '/^spark-crumbs = /d' "$cur/m.toml"
pk omega-lock-elsewhere; echo "$OTHER" | serve "aien-sovereign-core/$SC/omega.lock"
pk cargo-unreadable; rm "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk aienos-unreadable; rm "$cur/files/omega/$OM/aienos.lock"
pk two-revisions; printf '\n[[package]]\nname = "crumb-spec-extra"\nsource = "git+https://github.com/aien-dev/crumb-spec?rev=%s#%s"\n' "$OTHER" "$OTHER" >> "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk fork-name; sed -i "s/crumb-spec?rev=$CS#$CS/crumb-spec-fork?rev=$CS#$CS/" "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk error-body-ref; rm "$cur/files/omega/$OM/argus.lock"; sed -i "s/^omega-argus-lock = .*/omega-argus-lock = \"$OM\"/" "$cur/m.toml"
pk leading-comment; printf '# pinned after %s\n%s\n' "$OTHER" "$AO" | serve "omega/$OM/aienos.lock"
pk trailing-words; printf '%s %s\n' "$AO" "trailing words" | serve "omega/$OM/aienos.lock"
pk no-sovereign; sed -i '/^aien-sovereign-core = /d' "$cur/m.toml"
pk no-omega; sed -i '/^omega = /d' "$cur/m.toml"
# adversarial
pk three-revisions; printf '\n[[package]]\nname = "x"\nsource = "git+https://github.com/aien-dev/crumb-spec.git#%s"\n[[package]]\nname = "y"\nsource = "git+https://github.com/aien-dev/crumb-spec?branch=main#%s"\n' "$OTHER" "$OM" >> "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk omega-lock-empty; : > "$cur/files/aien-sovereign-core/$SC/omega.lock"
pk omega-lock-comments-only; printf '# c\n\n  # d\n' > "$cur/files/aien-sovereign-core/$SC/omega.lock"
pk lock-crlf; printf '%s\r\n' "$OM" > "$cur/files/aien-sovereign-core/$SC/omega.lock"; printf '  %s  \n' "$AO" > "$cur/files/omega/$OM/aienos.lock"
pk lock-no-newline; printf '%s' "$PH" > "$cur/files/omega/$OM/physics.lock"
pk lock-uppercase; printf '%s\n' "$(echo $PH | tr a-f A-F)" > "$cur/files/omega/$OM/physics.lock"; sed -i "s/^physics = .*/physics = \"AAAA\"/" "$cur/m.toml"
pk cargo-empty; : > "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk cargo-crlf; sed -i 's/$/\r/' "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk cargo-two-on-line; printf '\n[[package]]\nname = "x"\nsource = "git+https://github.com/aien-dev/spark-crumbs?rev=%s#%s" # %s"\n' "$SP" "$SP" "$OTHER" >> "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk manifest-crlf; sed -i 's/$/\r/' "$cur/m.toml"
pk dup-consumed; printf 'omega-argus-lock = "%s"\n' "$OTHER" >> "$cur/m.toml"
pk many-consumed; for i in $(seq 1 30); do printf 'extra-%02d = "x"\n' $i >> "$cur/m.toml"; done; printf 'sovereign-core-omega-lock = "%s"\n' "$OTHER" >> "$cur/m.toml"
pk all-unreadable; rm -rf "$cur/files"
pk wrong-type; sed -i 's/^aienos = .*/aienos = 3/' "$cur/m.toml"
pk extra-section; printf '[extra]\nfoo = "bar"\n[consumed_pins.sub]\nomega-argus-lock = "x"\n' >> "$cur/m.toml"
pk no-arg; : > "$cur/args"
pk missing-file; printf 'nope.toml\n' > "$cur/args"
pk physics-pinned-unreadable; rm "$cur/files/omega/$OM/physics.lock"
pk consumed-empty-value; sed -i 's/^omega-argus-lock = .*/omega-argus-lock = ""/' "$cur/m.toml"
pk lock-leading-blank; printf '\n\n   %s   \n' "$OM" > "$cur/files/aien-sovereign-core/$SC/omega.lock"
pk lock-ws-only; printf '  \n\t\n' > "$cur/files/aien-sovereign-core/$SC/omega.lock"
pk lock-nul; printf '%s\0\n' "$OM" > "$cur/files/aien-sovereign-core/$SC/omega.lock"; echo "bash prints 'warning: command substitution: ignored null byte in input' on stderr when a fetched file holds a NUL byte; the .om drops the byte silently" > "$cur/limit"
pk cargo-big; for i in $(seq 1 800); do printf '[[package]]\nname = "pad-%d"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\n\n' $i; done >> "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk cargo-dotgit-and-hash; sed -i "s|aien-protocols?rev=$PR#$PR|aien-protocols.git#$PR|" "$cur/files/aien-sovereign-core/$SC/Cargo.lock"
pk file-at-words; echo fileswords > "$cur/mode"
echo "cases: $(ls "$C" | wc -l) candidate, $(ls "$P" | wc -l) pins"
