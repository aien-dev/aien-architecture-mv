#!/usr/bin/env bash
# 13: two compiles of the same tree produce byte-identical .crumb files.
# Two clones at the same commit have every generated block stripped, then each is compiled from nothing.
# Under a frozen clock (faketime; the RFC-0003 D3 stamps are the only time-dependent bytes) the files must be
# byte-identical; under the real clock, one second apart, the files minus the compiled_at stamp must be identical.
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
proof_begin 13 "determinism: same tree, two compiles, identical .crumb bytes" "${1:-}"

strip_generated() {   # strip_generated <repo> : remove extensions.generated from every tracked .crumb
  local c
  for c in $(git -C "$1" ls-files '*.crumb' '**/.crumb'); do
    jq 'del(.extensions.generated)' "$1/$c" > "$1/$c.tmp" && mv "$1/$c.tmp" "$1/$c"
  done
}
compare() {   # compare <a> <b> <raw|jqfilter> -> prints identical/total
  local id=0 n=0 c
  for c in $(git -C "$1" ls-files '*.crumb' '**/.crumb'); do
    n=$((n+1))
    if [ "$3" = raw ]; then cmp -s "$1/$c" "$2/$c" && id=$((id+1))
    else [ "$(jq -S "$3" "$1/$c")" = "$(jq -S "$3" "$2/$c")" ] && id=$((id+1)); fi
  done
  echo "$id/$n"
}
all_of() { echo "${1#*/}/${1#*/}"; }   # "k/n" -> "n/n"

FROZEN='@2026-10-11 00:00:00 i0'
if command -v faketime >/dev/null 2>&1; then
  clone_repo "$TMP/a"; clone_repo "$TMP/b"; strip_generated "$TMP/a"; strip_generated "$TMP/b"
  check_eq "both clones at the same commit" "$(git -C "$TMP/a" rev-parse HEAD)" "$(git -C "$TMP/b" rev-parse HEAD)"
  cd "$TMP/a" || exit 1
  measure compile_a_from_nothing_frozen faketime -f "$FROZEN" $CRUMB compile .
  note "$(echo "$OUT" | tail -1)"
  RW=$(echo "$OUT" | tail -1 | sed -n 's/.*crumbs, \([0-9]*\) rewritten.*/\1/p'); num "rewritten_from_nothing=$RW"
  check_eq "every crumb was regenerated" "$RW" "$(crumb_dirs . | wc -l)"
  cd "$TMP/b" || exit 1
  measure compile_b_from_nothing_frozen faketime -f "$FROZEN" $CRUMB compile .
  cd "$TMP" || exit 1
  R=$(compare "$TMP/a" "$TMP/b" raw); num "byte_identical_frozen_clock=$R"
  check_eq "every .crumb byte-identical under a frozen clock" "$R" "$(all_of "$R")"
else
  note "faketime not installed: frozen-clock comparison NOT_RUN"; FAILS=$((FAILS+1))
fi

clone_repo "$TMP/c"; clone_repo "$TMP/d"; strip_generated "$TMP/c"; strip_generated "$TMP/d"
( cd "$TMP/c" && $CRUMB compile . >/dev/null ); sleep 1.1; ( cd "$TMP/d" && $CRUMB compile . >/dev/null )
R2=$(compare "$TMP/c" "$TMP/d" 'del(.extensions.generated.compiled_at)'); num "identical_minus_compiled_at_real_clock=$R2"
check_eq "real clock, one second apart: identical apart from the compiled_at stamp" "$R2" "$(all_of "$R2")"
D3c=$(cd "$TMP/c" && $CRUMB digest .); D3d=$(cd "$TMP/d" && $CRUMB digest .); num "root_digest_real_clock=$D3c"   # D11: computed on demand, never stored
check_eq "root Merkle digest identical (crumb digest, D11)" "$D3c" "$D3d"
R4=$(compare "$TMP/c" "$TMP/d" raw); num "raw_identical_real_clock=$R4"
note "raw files under the real clock differ only in compiled_at (informational)"
proof_end
