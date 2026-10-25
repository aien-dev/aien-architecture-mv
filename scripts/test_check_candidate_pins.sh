#!/usr/bin/env bash
# Test for tools/candidate/check_pins.om. Offline: lock files are served from a temp tree by a CAND_FILE_AT stub.
# The checker is compiled here with the pinned seeded compiler named by AIEN_OMC (exit 3 = NOT_RUN without it).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../tools/candidate/check_pins.om"
omc="${AIEN_OMC:-}"
[ -n "$omc" ] && [ -x "$omc" ] || { echo "test_check_candidate_pins: AIEN_OMC is not an executable omc (NOT_RUN)" >&2; exit 3; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
chk="$tmp/check_pins"
"$omc" < "$src" > "$chk" && chmod +x "$chk" || { echo "TEST FAIL: $src does not compile with $omc"; exit 1; }
OM=1111111111111111111111111111111111111111; SC=2222222222222222222222222222222222222222
AO=3333333333333333333333333333333333333333; PH=4444444444444444444444444444444444444444
PR=5555555555555555555555555555555555555555; CS=6666666666666666666666666666666666666666
SP=7777777777777777777777777777777777777777; AR=8888888888888888888888888888888888888888
OTHER=9999999999999999999999999999999999999999
cat > "$tmp/stub.sh" <<S
#!/usr/bin/env bash
# like gh api on a missing file or commit: an error body that contains the requested ref, and exit 1
cat "$tmp/files/\$1/\$2/\$3" 2>/dev/null || { echo "{\"message\":\"No commit found for the ref \$2\"}"; exit 1; }
S
chmod +x "$tmp/stub.sh"; export CAND_FILE_AT="$tmp/stub.sh"

serve() { mkdir -p "$(dirname "$tmp/files/$1")"; cat > "$tmp/files/$1"; }
tree() { # tree : the consistent lock files
  rm -rf "$tmp/files"
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
manifest() { # manifest <out> : manifest that agrees with tree
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
pass=0; bad=0
expect() { # expect <0|1> <label> <file> [grep pattern that the output must contain]
  out=$("$chk" "$3" 2>&1); rc=$?
  if [ "$rc" = "$1" ] && { [ -z "${4:-}" ] || grep -q -- "$4" <<<"$out"; }; then pass=$((pass+1))
  else bad=$((bad+1)); echo "TEST FAIL: $2 (rc=$rc)"; echo "$out" | sed 's/^/    /'; fi
}
tree; manifest "$tmp/m.toml"
expect 0 "consistent pins agree" "$tmp/m.toml" "PINS AGREE"
sed "s/^crumb-spec = .*/crumb-spec = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/a.toml"
expect 1 "contract pinned to a revision the code does not consume" "$tmp/a.toml" "contracts.crumb-spec: manifest pins $OTHER"
sed "s/^aien-protocols = .*/aien-protocols = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/b.toml"
expect 1 "aien-protocols pin differs from Cargo.lock" "$tmp/b.toml" "aien-protocols -> commits.aien-protocols"
sed "s/^aienos = .*/aienos = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/c.toml"
expect 1 "aienos pin differs from omega aienos.lock" "$tmp/c.toml" "omega aienos.lock"
sed "s/^physics = .*/physics = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/d.toml"
expect 1 "physics pin differs from omega physics.lock" "$tmp/d.toml" "omega physics.lock"
sed "s/^omega-argus-lock = .*/omega-argus-lock = \"$OTHER\"/" "$tmp/m.toml" > "$tmp/e.toml"
expect 1 "consumed_pins entry differs" "$tmp/e.toml" "consumed_pins.omega-argus-lock"
sed '/^physics = /d;/^omega-physics-lock/d' "$tmp/m.toml" > "$tmp/f.toml"
expect 0 "physics unpinned is allowed" "$tmp/f.toml"
sed '/^spark-crumbs = /d' "$tmp/m.toml" > "$tmp/g.toml"
expect 1 "contract missing from the manifest" "$tmp/g.toml" "not pinned"
# lock-file side
echo "$OTHER" | serve "aien-sovereign-core/$SC/omega.lock"
expect 1 "sovereign-core omega.lock points elsewhere" "$tmp/m.toml" "omega.lock -> commits.omega"
tree; rm "$tmp/files/aien-sovereign-core/$SC/Cargo.lock"
expect 1 "unreadable Cargo.lock" "$tmp/m.toml" "cannot read Cargo.lock"
tree; rm "$tmp/files/omega/$OM/aienos.lock"
expect 1 "unreadable aienos.lock" "$tmp/m.toml" "cannot read aienos.lock"
tree; printf '\n[[package]]\nname = "crumb-spec-extra"\nsource = "git+https://github.com/aien-dev/crumb-spec?rev=%s#%s"\n' "$OTHER" "$OTHER" \
  >> "$tmp/files/aien-sovereign-core/$SC/Cargo.lock"
expect 1 "two revisions of one repo in Cargo.lock" "$tmp/m.toml" "several"
tree; sed -i "s/crumb-spec?rev=$CS#$CS/crumb-spec-fork?rev=$CS#$CS/" "$tmp/files/aien-sovereign-core/$SC/Cargo.lock"
expect 1 "a repo whose name only starts with the contract name does not count" "$tmp/m.toml" "crumb-spec: git revision none"
tree
# a missing lock whose error body carries the omega ref must not read as "argus.lock pins omega"
tree; rm "$tmp/files/omega/$OM/argus.lock"; sed "s/^omega-argus-lock = .*/omega-argus-lock = \"$OM\"/" "$tmp/m.toml" > "$tmp/i.toml"
expect 1 "error body with the ref is not a lock file" "$tmp/i.toml" "consumed_pins.omega-argus-lock: its lock file could not be read"
tree; printf '# pinned after %s\n%s\n' "$OTHER" "$AO" | serve "omega/$OM/aienos.lock"
expect 0 "a leading comment with a sha is skipped" "$tmp/m.toml"
tree; printf '%s %s\n' "$AO" "trailing words" | serve "omega/$OM/aienos.lock"
expect 1 "first line must be exactly the sha" "$tmp/m.toml" "cannot read aienos.lock"
tree
sed '/^aien-sovereign-core = /d' "$tmp/m.toml" > "$tmp/h.toml"
expect 1 "manifest without sovereign-core" "$tmp/h.toml" "lacks"
echo "check_candidate_pins tests: $pass passed, $bad failed"
[ "$bad" -eq 0 ]
