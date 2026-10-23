# Ecosystem303 integration queue and remaining gates

Finite implementation workstream under issues301/302/303. NOT A MASTER PLAN.
Canonical decisions remain PLAN_AUTHORITY.md, CURRENT_EXECUTION_PLAN.md,
doctrine/ARCHITECTURE.md, doctrine/ROADMAP.md and accepted ADRs. This inventory
does not change their milestone statuses. Observation date2026-10-23.

## Ownership and isolated delivery

L786 coordinates the inventory and dependency queue. L408 remains the sole writer
of shared seeded compiler sources. L418 owns the existing C-to-Omega migration;
L491 retains training/locality work; L384 owns the shared inference regression
test train, not model training. L457 retains the canonical inference motor;
L605/L386 retain GPU/compiler work. L444/L617/L641 retain portability work;
L495 owns retirement. L773 is the current sole PR/judge publisher, as recorded
in the live DESK file. No paused owner was restarted and no compiler, runtime,
driver, live model, service or hardware window was taken over.

L689 owns model-weight flow scheduling, not the dataset loader or training
checkpoint schema. Dataset/tokenizer ownership is being reconciled separately;
L786 is accountable for routing any unowned capability, without claiming a
currently active implementation owner.

Three workers were used because the session has four slots including the
coordinator. They rotated from compiler qualification, tensor metadata and
distributed admission into independent reviews and native numeric consumption.
Their changes are isolated to the paths below, excluding mechanical repository
metadata required by existing checks. Proposed changes require independent
review and the existing desk's exact-head verification before integration.

| Candidate | Exclusive paths | Consumed interfaces | Acceptance and remaining integration gate |
|---|---|---|---|
| Omega qualify/ecosystem660-seed | seed/qualification/ecosystem660; evidence/ECOSYSTEM660 | Three distinct source/seed profiles in SOURCES.md | Fresh source reconstruction, capability/refusal cases and compiled controls recorded. Stack on existing definition-export ancestry; do not assume host and struct branches are combined. |
| Omega feat/ecosystem663-admission | native/ecosystem663; tests/ecosystem663; docs/ecosystem663; evidence/ECOSYSTEM663 | M20 metadata-v1: ED24 and ES8; compiler A | 14457 author checks,48380 independent checks and3 compiled controls. No allocation or arithmetic replacement; actual .om consumers are distributed7 and ecosystem6. |
| train feat/distributed7-admission | native/distributed7; tests/distributed7; docs/distributed7; evidence/DISTRIBUTED7 | Exact tensor sourcef60b6d62c1bf90de42455effae977de66adeca1268669f6144809a3327aec7a4; compiler A/C | 265 checks,5 compiled controls, independent81 sequence enumerations and boundary checks. Requires existing transport owner to allocate an authenticated collective envelope. |
| train ecosystem6 numeric consumer | native/ecosystem6; tests/ecosystem6; docs/ecosystem6; evidence/ECOSYSTEM6 | Same M20 metadata; exact L720 add32/mul32; compiler A | Native affine forward, analytic VJP and SGD compared with an independent exact arithmetic oracle. Candidate remains under construction/review until its own receipt is published. |
| architecture ecosystem/303-inventory | tools/ecosystem303; tests/ecosystem303; docs/ecosystem303; evidence/ECOSYSTEM303 | EC303 v1 forty-family schema; compiler A | Native unit suite,768 independent checks,17 hostile stream cases,3 compiled controls. Output-error defect corrected and retested. Structure only; release reviewers must authenticate referenced evidence. |

Each packet contains its reproducible source composition and acceptance commands.
Use the exact compiler SHA256 in SOURCES.md, require compiler exit0 and a genuine
ELF executable before executing any test. A failed compile followed by a shell
executing an empty file is invalid evidence. Historical setup failures remain
in the packets and do not contribute to passing counts.

## Dependency order and executable limits

1. Reconcile the three compiler profiles through L408 and retain individual
   provenance. Omega660/665/650 own compiler semantics, integrated facilities,
   independent trust and reproducibility. This candidate does not modify omc.om.
2. Omega663/664 and train5/6 consume the frozen tensor metadata contract. Existing
   L720 IEEE addition/multiplication permits real native numerical work now.
   A full allocator, operator library, differentiation engine, modules and
   optimizer catalogue are still required; a bounded affine model cannot close
   those issues. Data/tokenizer owners retain their existing implementations.
3. Train5/6 then compose actual train, transactional checkpoint, resume, held-out
   evaluation and export. Omega665 owns graph/model export. Native whole-workflow
   consumer cutover is unqualified; existing first-party trainer code remains.
4. Omega638/661 and CUDApp35/5/36 compose the native source-to-model GPU path with
   the existing motor. Omega666 then qualifies tokenization through serving,
   streaming, batching, isolation, cancellation, quantization and quality/cost.
   No hardware runs were authorized outside the existing window protocol.
5. CUDApp62 runs the SAME model/config/workload on a physical second vendor.
   A configured MacBook was reached: Apple M2,10 GPU cores,8GiB total system
   memory, Metal4, macOS26.6.2. Its gate is BLOCKED_IMPLEMENTATION: the seeded
   model path is absent. The unavailable offline metal compiler does not prove
   absence of the runtime. The configured iMac did not answer SSH, so its own
   discovery gate is BLOCKED_HARDWARE and its GPU identity is unverified.
   AMD/AGX lab results from268a2e9d are SIMULATOR evidence only.
6. Train7 must exercise real workers, actual reductions, failure recovery and
   optimizer/gradient/parameter sharding. Admission is useful but transfers no
   tensor data. Existing HTK1 task kinds do not implement collectives. Transport
   allocation and authentication must be agreed with the existing Fabric owner.
7. Omega667 and architecture301 expand every family into a versioned API/operator
   denominator and actual consumer inventory. Omega633/649/651 retain package,
   lifecycle and retrieval work. Each family in families.tsv names an open issue;
   a routing ledger owner does not imply that an implementation worker is active.

New explicit non-LLM leaves are train8 vision,9 audio,10 video,11 diffusion,
12 classical ML,13 graph/geometric, and Omega668 numerical/scientific libraries
including FFT/signal. They preserve existing scientific/sparse/backend owners.
The complete goal includes these domains; no transformer-only compatibility
claim is made. Reference versions in SOURCES.md are finite starting points.

## Consumer cutover, deletion and dependencies

This batch contains additive qualified components and native component consumers.
No production replacement meets its full cutover gate yet. Production cutovers0;
retirements0. Removing the existing tensor engine, trainer, tokenizer or server
now would break active consumers. Architecture300 and Omega599 remain open.

Before any retirement, the responsible issue must name every actual consumer,
switch it to the qualified native implementation, run its acceptance workload,
audit transitive runtime/build dependencies, remove superseded first-party
sources and obsolete dependencies from active trees, and reproduce the result
from a fresh checkout. Preserve Git history and immutable evidence. Packages
used as independent numerical oracles must be disclosed and cannot execute the
delivered first-party workload. No hidden PyTorch/foreign runtime is acceptable.

This batch's test executables are native seeded .om. Existing Linux shell/git,
C bootstrap tools, checksum/ELF inspection tools and repository verification
remain outer development dependencies; they are not falsely marked retired.
No new Python implementation, wrapper or test was introduced. Compiler output
identity establishes consistency, not semantic correctness.

Whole-model quality, throughput, latency, memory, energy and cost comparisons
are NOT_RUN. Shared-host component timings are diagnostic only, with no speedup
claim. Keep regressions, no-win comparisons and failed controls in immutable
receipts; distinguish host, simulator and physical-device environments.
