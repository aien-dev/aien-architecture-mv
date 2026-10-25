#!/usr/bin/env bash
# tests/gates/run.sh: the one entry point for the local verification gates of aien-architecture.
# Every step runs the SAME command as the hosted job it mirrors (.github/workflows/crumb.yml and
# qualification-status.yml) or the repository's own offline scripts. Manifests under tests/gates/
# name this script plus one step word, so no manifest needs shell expansion (ADR 0028 P6).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
step="${1:?usage: tests/gates/run.sh <step>}"
obs() { printf 'AIEN-OBS %s %s\n' "$1" "$2"; }

case "$step" in
  crumb-verify)
    # Hosted crumb.yml step "Crumbs must be exactly what the compiler produces now", with the
    # same make target. The binary is built in a private copy of tools/crumb, not in place:
    # crumb-tool-test builds and runs tools/crumb/crumb at the same time, and two gates writing
    # and executing one file raced ("Text file busy", failed tool tests; SANDBOX lane 2026-10-11).
    tool=$(mktemp -d)
    trap 'rm -rf "$tool"' EXIT
    cp tools/crumb/Makefile tools/crumb/crumb.c "$tool/"
    make -C "$tool" crumb
    "$tool/crumb" verify .
    ;;
  crumb-tool-test)
    # Hosted crumb.yml step "Build and test the crumb tool".
    make -C tools/crumb test
    ;;
  qualification-status)
    # Hosted qualification-status.yml checks out aien-spark/omega (default branch, unpinned)
    # as omega-evidence and runs the script against it. Locally the sibling ../omega plays
    # that role; its commit is recorded so the receipt says which evidence was read.
    if [ ! -d ../omega/evidence ]; then
      echo "run.sh: ../omega is missing; the hosted job checks out aien-dev/omega as omega-evidence" >&2
      exit 3
    fi
    obs sibling_omega_commit "\"$(git -C ../omega rev-parse HEAD 2>/dev/null || echo unknown)\""
    sh scripts/verify-r16-status.sh ../omega
    ;;
  doctrine)
    # Repository script (aien-architecture#7): doctrine consistency, pure text, no network.
    bash scripts/check_doctrine.sh "$ROOT"
    ;;
  script-tests)
    # The offline tests of the repository's own operator scripts. Each builds temporary git
    # repos and fake gh/crumb tools under mktemp; no network, no auth (see their headers).
    for t in scripts/test_pr_gate.sh scripts/test_rebase_crumb.sh scripts/test_check_candidate.sh scripts/test_check_candidate_pins.sh; do
      echo "== $t"
      bash "$t"
    done
    obs script_tests_run 4
    ;;
  zero-legacy)
    # #316: the seeded .om closure checker and its native comparator, built by the pinned seed
    # compiler named in tools/zero-legacy/omega.pin. AIEN_OMC must point at that omc binary
    # (seed/out/omc of aien-dev/omega-mv at the pinned commit, sha256 checked here); without it
    # the step is NOT_RUN (exit 3), never a pass. This shell only sequences; every judgment is
    # made by the two .om programs.
    omc="${AIEN_OMC:-}"
    if [ -z "$omc" ] || [ ! -x "$omc" ]; then
      echo "run.sh: AIEN_OMC is not an executable omc; see tools/zero-legacy/omega.pin (NOT_RUN)" >&2
      exit 3
    fi
    want=$(sed -n 's/^omc_sha256: //p' tools/zero-legacy/omega.pin)
    have=$(sha256sum "$omc" | cut -d' ' -f1)
    if [ "$have" != "$want" ]; then
      echo "run.sh: AIEN_OMC sha256 $have is not the pinned $want (NOT_RUN)" >&2
      exit 3
    fi
    b=$(mktemp -d)
    trap 'rm -rf "$b"' EXIT
    "$omc" < tools/zero-legacy/closure.om > "$b/closure"
    "$omc" < tools/zero-legacy/expect.om > "$b/expect"
    chmod +x "$b/closure" "$b/expect"
    # Compile the real scanner with a test-only main and one bad-fd syscall injection.
    # Refuse stale transformations instead of silently testing a different code path.
    [ "$(grep -c '^fn main to int$' tools/zero-legacy/closure.om)" = 1 ]
    [ "$(grep -c '^r = getdnts int fd dbuf 0 len dbuf$' tools/zero-legacy/closure.om)" = 1 ]
    {
      printf 'global io_fault ulong 1\n'
      sed -e 's/^fn main to int$/fn inventory_main to int/' \
          -e '/^r = getdnts int fd dbuf 0 len dbuf$/a\
if eq get io_fault 0 1\
r = getdnts -1 dbuf 0 len dbuf\
end\
put io_fault 0 1' tools/zero-legacy/closure.om
      cat tools/zero-legacy/fixtures/io-errors.om
    } > "$b/io-errors.om"
    "$omc" < "$b/io-errors.om" > "$b/io-errors"
    chmod +x "$b/io-errors"
    obs closure_sha256 "\"$(sha256sum "$b/closure" | cut -d' ' -f1)\""
    cd tools/zero-legacy
    set +e
    "$b/closure" fixtures/tree release fixtures/manifest.txt > "$b/tree.out"; rc_tree=$?
    "$b/closure" fixtures/clean release fixtures/clean-manifest.txt > "$b/clean.out"; rc_clean=$?
    "$b/closure" fixtures/clean release > "$b/clean2.out"; rc_clean2=$?
    "$b/expect" "$b/tree.out" fixtures/tree.expected; rc_e1=$?
    "$b/expect" "$b/clean.out" fixtures/clean.expected; rc_e2=$?
    "$b/io-errors" fixtures/clean/src read-error > "$b/read-error.out"; rc_read=$?
    "$b/io-errors" fixtures/clean/src directory-error > "$b/dir-error.out"; rc_dir=$?
    set -e
    cd "$ROOT"
    obs read_error_exit "$rc_read"
    obs directory_error_exit "$rc_dir"
    obs tree_release_exit "$rc_tree"
    obs clean_release_exit "$rc_clean"
    obs clean_undeclared_exit "$rc_clean2"
    obs expect_tree_exit "$rc_e1"
    obs expect_clean_exit "$rc_e2"
    # The hostile tree must be refused (1), the clean tree accepted (0), the clean tree with
    # its hex vectors undeclared refused (1), and both reports must match their expected rows.
    [ "$rc_tree" = 1 ] && [ "$rc_clean" = 0 ] && [ "$rc_clean2" = 1 ] && [ "$rc_e1" = 0 ] && [ "$rc_e2" = 0 ] && [ "$rc_read" = 0 ] && [ "$rc_dir" = 0 ]
    ;;
  *)
    echo "run.sh: unknown step '$step'" >&2
    exit 2
    ;;
esac
