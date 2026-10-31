# Native catalogue structural checker qualification

Functional core and initial CLI7570dd7; native mutant generator
da44baf7c3c50ff02e436b661fe80e2dc97815d6; corrected CLI
02ca3df89ee30cd251a28e327a13ace21638496f. Exact source file digests are in
final-sources.sha256. Compiler source/profile A is pinned in
docs/ecosystem303/SOURCES.md; executable SHA256
191b776ef98821597c3e30655da6d680a9b66edbc9ceaca3c39c61ea6df098e9.

Scope: local host structural validation of the forty-family EC303 v1 catalogue.
It does not authenticate references, qualify APIs, replace the release verifier,
change an installed gate or prove ecosystem completion. All forty family rows
remain pending. Existing services, hardware and compiler sources were untouched.

The author unit suite and real catalogue pass. Three complete compiled mutants
remove denominator, cycle and deletion checks and are each detected with exit1;
each compiler returned0. Native handwritten tests/ecosystem303/mutate.om creates
these exact single-site mutations and rejects a missing or repeated match.
See mutants/ for complete executable-source inputs, outputs and exits.

Independent review is preserved in independent/REPORT.md with all supplied raw
source units, byte fixtures, compiler outputs and exits. The independent suite
passes768checks. Seventeen generated hostile byte streams return their expected
statuses. The reviewer independently generated, compiled and detected all three
mutants. The review found R1: a negative write result converted to unsigned caused
trap105. Corrected signed handling now returns the documented23 for /dev/full
and closed stdout. Original RED and corrected GREEN are both retained.

Reproduction commands for author tests are in docs/ecosystem303/FORMAT.md. For
the independent suite concatenate the exact core with independent/independent.om,
compile using profile A, check compiler status and ELF, then execute. The
standalone independent/inputs.om consumes one raw mode byte0..16 and emits the
byte fixture to feed the CLI. Compare each result with the retained per-case
status. Binaries are not shipped; recorded binary hashes enable fresh builds.

Repository checks: scripts/check_doctrine.sh passes30files with zero failures;
scripts/verify-r16-status.sh against omega-ecosystem660-seed passes its existing
receipt check. That script's first invocation omitted its required Omega checkout
argument and failed; qualification-status-first.stderr is retained. Its corrected
success is only the pre-existing repository status check, not an ecosystem gate.
Final required Crumb verification is recorded in the handoff after the evidence
commit, avoiding a self-referential hash cycle in this packet.

Outer development tools include the existing shell, git, checksum/ELF utilities
and C-built Crumb checker. They are disclosed build/inspection dependencies and
are not marked replaced. No Python or foreign execution engine was introduced.

compile.cost and unit.cost are single shared-host diagnostic measurements:
compiler0.01s/1716KiB peak RSS and unit0.00s/192KiB. The timer's resolution and
shared host prevent a performance conclusion. No model quality, GPU throughput,
latency, energy or speedup claim is made. Development failures remain visible.

SHA256SUMS seals repository-relative evidence paths excluding itself. Verify
from the repository root. Some independent original hash receipts reference the
reviewer's scratch binary names; these remain original observations, not a claim
that omitted ELF files are distributed with this packet.
