#!/bin/sh
# Bootstrap trust boundary: authenticate AIEN_OMC independently before executing it.
# Fixture judgments remain in gate.om; the compiler cannot authenticate itself.
set -eu
root="${1:?usage: gate.sh ROOT}"
cd "$(dirname "$0")"
not_run() { echo "gate.sh: AIEN_OMC is unavailable or not independently pinned (NOT_RUN)" >&2; exit 3; }
[ -n "${AIEN_OMC:-}" ] && [ -x "$AIEN_OMC" ] || not_run
want=$(sed -n 's/^omc_sha256: //p' ../zero-legacy/omega.pin) || not_run
[ "${#want}" -eq 64 ] || not_run
case "$want" in *[!0-9a-f]*) not_run ;; esac
have=$(sha256sum -- "$AIEN_OMC") || not_run
have=${have%% *}
[ "$have" = "$want" ] || not_run
mkdir -p build
"$AIEN_OMC" < gate.om > build/gate
chmod +x build/gate
[ -s build/gate ] || { echo "gate.sh: AIEN_OMC produced no program from gate.om (NOT_RUN)" >&2; exit 3; }
exec build/gate "$AIEN_OMC" "$root"
