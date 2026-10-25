#!/usr/bin/env bash
# 18: a .crumb-only commit does not trigger recompilation. On a clone of a cargo workspace, build once
# (warm-up into TARGET_DIR), build again with no change (noise floor), then commit a change that touches only
# a .crumb file (`crumb propose` writes extensions.proposed) and build a third time with -v: the third build
# must report 0 "Compiling" and 0 "Dirty" lines. TARGET_DIR is reused, never deleted.
# Env: TARGET_DIR (default ${XDG_CACHE_HOME:-$HOME/.cache}/aien/pipeline/target-cold),
# CARGO_ARGS (default --locked --offline). The cache stays outside the temporary clone.
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
proof_begin 18 "crumb-only commit avoids unrelated recompilation" "${1:-}"
[ -f "$SRC/Cargo.toml" ] || proof_na "no Cargo.toml at the repository root"
command -v cargo >/dev/null 2>&1 || proof_na "cargo not on PATH"
TD=${TARGET_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/aien/pipeline/target-cold}
export CARGO_TARGET_DIR=$TD
ARGS=${CARGO_ARGS:---locked --offline}
clone_repo "$TMP/a"; cd "$TMP/a" || exit 1
note "target dir: $TD ($(du -sh "$TD" 2>/dev/null | cut -f1) before)"
counts() { echo "compiling=$(grep -c '^ *Compiling' <<<"$1") dirty=$(grep -c '^ *Dirty' <<<"$1") fresh=$(grep -c '^ *Fresh' <<<"$1")"; }

# shellcheck disable=SC2086
measure build_1_warmup cargo build $ARGS; check "build 1 succeeds" [ "$RC" -eq 0 ]
[ "$RC" -eq 0 ] || { echo "$OUT" | tail -5; proof_end; }
# shellcheck disable=SC2086
measure build_2_no_change cargo build -v $ARGS; C2=$(counts "$OUT"); num "build2_$C2"
check "build 2 (no change) compiles nothing" grep -q 'compiling=0 dirty=0' <<<"$C2"

L=$(leaf_crumb_dir .) || L=.
$CRUMB propose "$L" "proof 18: proposed purpose, crumb-only change" >/dev/null || { echo "propose failed" >&2; exit 1; }
CH=$(git status --porcelain | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//'); num "changed_paths=$CH"
check_eq "the change touches exactly one .crumb file" "$(git status --porcelain | wc -l)/$(git status --porcelain | grep -c '\.crumb$')" "1/1"
git add -A && git commit -q -m "crumb-only change (proof 18)"
# shellcheck disable=SC2086
measure build_3_after_crumb_commit cargo build -v $ARGS; C3=$(counts "$OUT"); num "build3_$C3"
check "build 3 after the crumb-only commit compiles nothing" grep -q 'compiling=0 dirty=0' <<<"$C3"
check "build 3 still reports fresh crates" grep -qv 'fresh=0' <<<"$C3"
note "target dir after: $(du -sh "$TD" 2>/dev/null | cut -f1)"
proof_end
