# EC303 capability inventory v1

Finite workstream under architecture issues 301, 302 and 303. NOT A MASTER PLAN.
The existing execution plan, roadmap, receipt verifier and release desk retain authority.

`catalogue.ec303` is consumed by the handwritten seeded Omega structural check.
It begins with unsigned decimal tokens `303 1 40`, then forty records of twenty
unsigned decimal fields. ASCII space, tab, CR and LF separate tokens. There are
no comments, signs, hex literals, trailing tokens or implicit missing values.
Input must be shorter than 65536 bytes. Each decimal is at most 20 digits and
must fit u64. Records may be reordered; family IDs must occur exactly once.

| Field | Meaning |
|---|---|
| 0 | Family ID, 1 through 40, fixed by families.tsv |
| 1 | Owning repository: 1 Omega, 2 aien-train, 3 CUDApp, 4 architecture |
| 2 | Implementation issue number in that repository |
| 3 | Accountable ledger owner number; routing responsibility is not an active executor |
| 4 | Whole-family state: 0 pending, 1 implemented, 2 verified, 3 integrated, 4 retired |
| 5 | Evidence environment: 0 absent, 1 host, 2 simulator, 3 physical |
| 6 | Required evidence bits: numerical oracle 1, model/config 2, physical 4 |
| 7 | Dependency bitset: bit (family ID minus one); zero means no dependencies |
| 8..11 | Reference IDs for exact source, seed, binary and independent review |
| 12..17 | Reference IDs for consumer, deletion, dependency audit, model/config, compiled controls and numerical oracle |
| 18 | Independent reviewer ledger number, distinct from field 3 |
| 19 | Reserved zero |

Reference IDs are pointers, not hashes or evidence. Nonzero IDs must be resolved
by the existing release reviewer against immutable evidence and actual artifacts.
This check validates structure and necessary conditions only. It does not access
GitHub, resolve reference IDs, authenticate evidence, verify issue assignments,
inspect dependencies on disk, execute a model or authorize a release. A fabricated
nonzero reference can pass structure; the existing evidence verifier must reject it.
The success string explicitly states this limit.

The v1 denominator is forty **capability families**, not forty APIs and not a
claim that all APIs are inventoried. Expanding each family's operator/API and
actual-consumer denominator remains architecture301 work. Unknown source paths,
references and dependencies remain visible in families.tsv and BACKLOG.md.
All forty whole-family rows are pending. Partial implementations have separate
source-backed notes and cannot advance an entire family.

Rules enforced: exact version and denominator; unique in-range IDs; nonzero issue
and owner; bounded state/environment; mandatory per-family numerical/model/physical
requirements cannot be erased; bounded non-self dependencies; cycle refusal even
for pending rows; source/seed references before implementation; binary/review,
independent reviewer and compiled controls before verification; model/oracle/physical
evidence when required; consumer and dependency audit before integration; deletion
before retirement; every transitive dependency integrated before a consumer is
integrated or retired. The checker does not treat simulated results as physical.

Exit 0 means STRUCTURE_OK only. Core refusal codes 1..19 are returned as exits
31..49 by the CLI. Transport refusals: 20 oversize, 21 input error, 22 malformed
tokens/header/trailing bytes, 23 output error. The pure core returns 0 or the
refusal code and can be linked by concatenating the .om source with a consumer.

Build with the independently reconstructed compiler191b776e, using its exact
source lock in SOURCES.md. These are existing Linux command-line build operations,
not a claim that the outer build/CI orchestration has already been retired:

```sh
cat tools/ecosystem303/catalogue.om tools/ecosystem303/cli.om > /tmp/ec303-cli.om
"$OMC" < /tmp/ec303-cli.om > /tmp/ec303
chmod +x /tmp/ec303
/tmp/ec303 < docs/ecosystem303/catalogue.ec303
cat tools/ecosystem303/catalogue.om tests/ecosystem303/catalogue-test.om > /tmp/ec303-test.om
"$OMC" < /tmp/ec303-test.om > /tmp/ec303-test
chmod +x /tmp/ec303-test
/tmp/ec303-test
```

Use unique private scratch paths during concurrent runs. No installed tool or
existing CI gate is changed by this candidate.
