#!/bin/sh
# gate.sh: the one step outside gate.om, like tools/zero-legacy/gate.sh: compile gate.om with the
# compiler named by AIEN_OMC and hand over. No judgment is made here; gate.om checks the pin.
# usage: sh tools/doctrine/gate.sh ROOT
set -eu
root="${1:?usage: gate.sh ROOT}"
cd "$(dirname "$0")"
[ -n "${AIEN_OMC:-}" ] && [ -x "$AIEN_OMC" ] || { echo "gate.sh: AIEN_OMC is not an executable omc (NOT_RUN)" >&2; exit 3; }
mkdir -p build && "$AIEN_OMC" < gate.om > build/gate && chmod +x build/gate
[ -s build/gate ] || { echo "gate.sh: AIEN_OMC produced no program from gate.om (NOT_RUN)" >&2; exit 3; }
exec build/gate "$AIEN_OMC" "$root"
