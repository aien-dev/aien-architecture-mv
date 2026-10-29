#!/bin/sh
# gate.sh: the one step outside gate.om, like seed/rung0/load0.sh: compile gate.om with the
# compiler named by AIEN_OMC and hand over. No judgment is made here; gate.om checks the pin.
set -eu
cd "$(dirname "$0")"
[ -n "${AIEN_OMC:-}" ] && [ -x "$AIEN_OMC" ] || { echo "gate.sh: AIEN_OMC is not an executable omc (NOT_RUN)" >&2; exit 3; }
mkdir -p build
"$AIEN_OMC" < gate.om > build/gate || { echo "gate.sh: gate.om did not compile" >&2; exit 1; }
chmod +x build/gate
exec build/gate "$AIEN_OMC"
