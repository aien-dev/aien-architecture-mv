# AIEN Current Execution Plan

**Status:** AUTHORITATIVE / ACTIVE  
**Effective:** 2026-09-27  
**Plan authority:** [PLAN_AUTHORITY.md](PLAN_AUTHORITY.md)  
**Milestone registry:** [doctrine/ROADMAP.md](doctrine/ROADMAP.md)  
**Architecture authority:** [doctrine/ARCHITECTURE.md](doctrine/ARCHITECTURE.md)

This is the only active cross-project master implementation plan for AIEN.

## 1. North star

AIEN is a persistent intelligent computing system that can understand an objective, define what must become true, discover a physical realization on the available machine, verify the realization, act, learn from evidence, and improve its methods without confusing intelligence with truth or authority.

Canonical execution doctrine:

```text
ATLAS AWAKENS.
AIEN PROPOSES.
OMEGA DEFINES.
FORGE REALIZES.
AEGIS VERIFIES.
HARDWARE ACTS.
EVIDENCE TEACHES.
```

AIENOS owns the trusted operating substrate beneath this loop.

## 2. Current baseline

As of 2026-09-27:

- Atlas M1 is qualified in QEMU with historical bootstrap evidence preserved.
- AIENOS has native DGX Spark boot evidence, QEMU-qualified isolation/capability work, Store/continuity/recovery work, and active M5 encryption/identity implementation.
- Omega has completed the semantic/synthesis line through M18 and has a merged M19 resident-accelerator implementation with a 175-gate qualification run.
- An independent M19 review found evidence-integrity and runtime-correctness issues that require corrective qualification before M20 is trusted.
- The old PHYSICS architectural role has been superseded by FORGE: machine realization/lowering, not a security gatekeeper.
- AEGIS is the cross-cutting invariant/contract verifier.
- J-Space, Fabric, the canonical runtime Capability Graph, and full Skill routing remain incomplete as system-wide first-class components. As of the COMPOSITION-1 merges (2026-09-30 addendum below): host-level implementations of the Capability Graph and Skill Router (advancing F1/F2), a production local-only J-Space branch store (advancing F4), a canonical omega Cortex with World recording, and canonical machine identity (`AienMachineId`) exist in omega `src/runtime/`, each built and tested in its own CI test target, none yet in the R13 living-system build. Fabric (F5) and remote J-Space do not exist. The capability authority root (aienos C library) runs hosted only (`docs/02-implementation-status.md`).
- RSI exists as an evaluation/promotion substrate but should not be placed on the critical path until the execution boundaries below are stable.

Addendum, 2026-09-29 (from live evidence):

- ADR 0016 R15 (quantitative performance) PASSED: `aien-dev/omega#67`, merge `bba3bd3`, receipt `evidence/R15/065c6884...json`, 16/16 gates.
- ADR 0016 R16 (orchestrator retirement) PASSED / CLOSED: `aien-dev/omega#112` merged (`3dd5eaa`), candidate `850fc54`, canonical receipt `evidence/R16/22d7a79a985514ac38139d39c71c9638d9b6b0a6e05425b6810bdb4833d1ea64.json` (`AIEN_RX_R16_ORCHESTRATOR_RETIRED_V1`). All gates G1–G8 PASS on DGX Spark GB10 hardware; 281 sites classified (0 unclassified); 36/36 negative mutants killed; R1–R15 full candidate ladder passed. The runtime edit freeze on `omega/src/runtime/` is LIFTED.
- Omega effect capabilities now carry 64-bit generations (`aien-dev/omega#71`, `8e7a445`); 32-bit v1 effect payloads are refused.
- The FORGE v1 realize/verify seam is closed: `aien-dev/physics#13` merged (`5969159`), Gates 3 and 4 pass.
- AR1 (FORGE substrate-neutral descriptor contract) PASSED: `aien-dev/physics#16` (`1f7c321`) and `aien-dev/physics#13` (`5969159`) merged on main; V1 and V2 combined gates pass.
- ADR 0018 (substrate-neutral physical realization) is ACCEPTED and merged (641bd3c); AR0 is satisfied; see §6 C3.

Addendum, 2026-09-30 (course correction, ADR 0020):

- A belief / estimation foundation (ADR 0020, stages EST-0 to EST-10) is inserted after R16 closure and before any stage that depends materially on predicted state (TURING predictive evaluation, J-Space uncertainty-aware reasoning, Cortex predictive abstraction, information-gain experiments, Evolution Arena, Physics Zero). R16 is not interrupted. See Lane 7.

Addendum, 2026-09-30 (reconciliation of docs against code):

- Roadmap M6 `OMEGA_SELF_HOST` stays COMPLETE with its ID, commit and receipt unchanged, but it proved a fixed-output self-copy check, not compiler self-hosting. It is not evidence of a general Omega compiler (`doctrine/ROADMAP.md` §3, M6 correction note; omega `docs/adr/OMEGA-SYSTEMS-CORE-0000.md` item C8). The compiler slice is OSC-1 work.
- J-Space, Cortex and capability status was re-checked against omega, aienos, physics and aien-sovereign-core `main` (`docs/02-implementation-status.md`). J-Space and the omega Cortex are host references in single test targets; three Cortex implementations exist with no recorded owner; the capability authority root is the aienos C library, hosted only; the runtime Capability Graph (F1) is missing. (Superseded in part by the composition-merges addendum below: a host-level F1 graph now exists and omega `rx_cortex` and `rx_jspace` are no longer single-test references.)
- Concept ownership (World state, semantic scheduling, authority root, generations, queues, evidence, Cortex, J-Space) is recorded in `doctrine/ARCHITECTURE.md` §2.8, classified with the R16 retirement map.
- M19R Foundation Repair PASSED / CLOSED: `aien-dev/omega#111` merged (`5517d22`), canonical receipt `evidence/GATE14-FOUNDATION/50dd611bfd28e8320443810b35f7425df5eb112777662e5840c227154271f872.json` on pinned candidate pair Omega `8024e9a` + Physics `e95e3ed` (8/8 criteria satisfied). M19 resident foundation is requalified and closed.

Addendum, 2026-09-30 (composition merges; merge times below are UTC and fall on 2026-10-01):

- Naming: the 8-agent runtime composition program that produced these merges is **COMPOSITION-1 (formerly misnamed 'M20 program' in agent briefs, 2026-09-30)**. Omega PR titles and branches `m20/identity-convergence`, `m20/cortex-canonical`, `m20-capgraph` and `m20-jspace` belong to COMPOSITION-1, not to roadmap M20. Roadmap M20 remains `OMEGA_TENSOR` (`doctrine/ROADMAP.md`, unchanged). COMPOSITION-1 is Lane 4 work (§16) against Phase F (§9).
- `aien-dev/omega#113` "M20: canonical AIEN machine identity (AienMachineId)", merge `16f8518` (01:33Z). Canonical `AienMachineId` in `src/runtime/aien_machine_id.{c,h}`, byte-identical to AIENOS ADR 0014 `machine_id_digest`; `rx_argus` stamps it when configured. Satisfies the F5 "stable Machine identities" bullet only. Test `test-machine-identity` in rx-host CI.
- `aien-dev/omega#114` "M20 A7: canonical Cortex, World execution recording", merge `43dcb04` (01:37Z). omega `rx_cortex` gains an append-only journal with verified replay, a single writer and typed recall; `rx_cortex_record` records every World crumb through one optional recorder hook in `rx_world.c`. Advances F3 and H2. The PR declares `rx_cortex` canonical and documents sovereign-core `cortex-rs` and `aienos-cortex` as non-authoritative; under `doctrine/ARCHITECTURE.md` §2.8 an ownership move still needs an accepted ADR or R16 gate result, so the Cortex owner remains formally unrecorded.
- `aien-dev/omega#115` "M20: canonical Capability Graph and Skill Router", merge `135d1c2` (01:52Z). `rx_capq` promoted to the canonical runtime Capability Graph (stable keys, upsert, availability/withdraw, 188-byte wire record, machines keyed by `AienMachineId`); new `rx_skillroute` binds one real `AG_SKILL` node. Advances F1 and F2 at host level (F1 credentials/references and Fabric-fed availability not implemented). Entries marked FABRIC-sourced are a record type only; no Fabric feeds them.
- `aien-dev/omega#116` "M20 production J-Space: stable ids, limits, durable checkpoints, World-safe staging", merge `529ebfa` (02:04Z). Generation-checked ids, limits, durable checkpoint, staged branches. Advances F4 as a local branch store only; World-level candidate forking and selected-branch externalization are not wired. Machine placement `JsHome` is a 32-byte placeholder, every remote operation returns `JS_ERR_REMOTE`, and there is no remote transport. World commit does not yet call `js_branch_seal` / `js_space_reclaim_staged` (open interface request from the PR; the test drives it from outside World code).
- `aien-dev/omega#117` "docs: E1 numeric closure gap table", merge `c2160f5` (02:30Z). omega `docs/numeric/E1_GAP_TABLE.md`: of the E1 items, 1 covered, 7 partial, 4 missing. E1 (§8) is not closed; see the E1 note.
- Architecture docs: `aien-dev/aien-architecture#70` (runtime freeze lifted, `e89ba94`) and `#72` (M19 accepted status word, `74f666b`) merged before these.
- Not changed by these merges: no Fabric (F5 membership, leases, placement, failure recovery); no remote J-Space; none of the new modules is in the R13 living-system build; no roadmap milestone closes.

## 3. Program rule

Do not build higher layers on a lower layer whose qualification is known to be misleading.

The critical path is therefore:

```text
CONTROL THE PLAN
    ↓
M19 CORRECTIVE QUALIFICATION
    ↓
FORGE V1 BOUNDARY
    ↓
AIENOS TRUST + IDENTITY
    ↓
OMEGA NUMERICS / TENSORS / AUTODIFF / OPTIMIZER
    ↓
AIENOS NETWORKING + NATIVE INFERENCE + PERSISTENT AGENT
    ↓
BELIEF / ESTIMATION FOUNDATION (ADR 0020: EST-0..EST-3 calibrated, then EST-4..EST-5 into World and the cost model after R16)
    ↓
CAPABILITY GRAPH + WORLD + J-SPACE + FABRIC
    ↓
AIEN_0 + GUIDED SYNTHESIS + ABSTRACTION DISCOVERY
    ↓
INTEGRATED AIEN + CORTEX + RSI
    ↓
SELF-HOSTING / SOVEREIGN CLOSURE
    ↓
PHYSICS ZERO
    ↓
GENERAL AIEN + SUCCESSION
```

## 4. Phase A — Project control and architecture cleanup

### A1. Consolidate plan authority

- Keep this file as the only whole-system implementation plan.
- Keep `doctrine/ROADMAP.md` as the milestone/status registry.
- Keep `doctrine/ARCHITECTURE.md` as the architecture authority.
- Archive every superseded system-wide master plan.
- Mark component-local plans as subordinate to whole-system authority.
- Add agent instructions that forbid treating archived plans as current.

**Exit gate:** an agent can answer “what should I build next?” from these three files without consulting another master plan.

### A2. Complete PHYSICS -> FORGE terminology migration

- Ratify ADR 0014.
- Use FORGE for current machine realization/lowering.
- Preserve old PHYSICS milestone IDs, receipts, artifact names, and Git history.
- Rename live APIs from authority language to realization language.
- Rename the GitHub repository from `physics` to `forge` when repository administration is performed.
- Do not manufacture compatibility by rewriting historical evidence.

**Exit gate:** current code/docs say FORGE for the live subsystem; PHYSICS appears only in historical compatibility/evidence contexts.

## 5. Phase B — M19 corrective qualification

M19 is reopened before M20.

### B1. Evidence integrity

- Receipts are append-only/content-addressed.
- Old milestone reruns cannot overwrite old receipts.
- Test counts are derived from observed execution.
- Candidate Git commit, binary, manifest, hardware descriptor, realization identities, actual gates run, and actual results are bound into the receipt.
- Hardware identity is probed from the machine rather than asserted by a source constant.
- Qualification code and receipts are separated so qualifying a candidate does not modify the candidate tree.

### B2. Resident accelerator correctness

- Implement complete allocate/use/revoke/free lifecycle.
- Measure actual coherent/device allocation state, not only CPU RSS.
- Make completion monotonic and dispatch commit exactly-once.
- Keep queue sequence identity distinct from completion-payload identity.
- Test duplicated completion, completion skip-ahead, timeout races, error-after-success, cancellation, teardown with work in flight, stale handles, and repeated allocation cycles.
- Run a long silicon soak proving flat resource use.

**Exit gate:** M19 is requalified with immutable evidence and no known resource-lifecycle or exactly-once defects.

## 6. Phase C — FORGE v1

FORGE becomes a typed machine-realization subsystem.

### C1. Boundary

```text
OMEGA RealizationRequest
        ↓
FORGE MachineDescriptor + realization search
        ↓
Candidate Realization
        ↓
AEGIS contract/invariant verification
        ↓
Hardware submission
        ↓
Execution evidence + machine facts
        ↘
         OMEGA / AIEN feedback
```

### C2. Responsibilities

FORGE owns:

- machine discovery normalization;
- physical lowering;
- code generation backend integration;
- register/allocation/layout planning;
- memory placement;
- accelerator queue realization;
- DMA/IOMMU/device realization;
- machine-specific scheduling and autotuning;
- feedback of physical constraints and alternatives.

FORGE does not own human intent, semantic truth, capability policy, or learned planning.

**Exit gate:** Omega can request a realization without importing Forge implementation internals directly.

### C3. Substrate-neutral realization (ADR 0018, workstream AR0–AR7)

ADR 0018 (ACCEPTED, merged 641bd3c) extends FORGE from the digital CPU+GPU Machine to any physical substrate (analog, neuromorphic, FPGA/CGRA, optical/photonic, future) attached as a capability provider. AR0–AR7 are **workstream gates, not roadmap milestones**; they carry no M-number and do not reorder §17. Supporting documents: `docs/plans/analog-realization/` (NOT A MASTER PLAN).

| Gate | Scope | Blocked on |
|---|---|---|
| AR0 | ADR 0018 accepted and merged | **PASS:** Accepted by operator Drake Stapleton, merged 641bd3c |
| AR1 | FORGE substrate-neutral descriptor contract (V2 descriptor + evidence, KATs, v1 KAT digest wrapped) | **PASS:** V2 contract in `physics#16` (`1f7c321`), C1 foundation in `physics#13` (`5969159`), combined gates pass |
| AR2 | Analog **simulation** provider + digital oracle parity, receipts `SIMULATED_DEVELOPMENT` | AR1. May proceed as new files; must not touch `omega/src/runtime/` |
| AR3 | Calibration, uncertainty and evidence qualification | AR2. Same file rule as AR2 |
| AR4 | First physical analog operation (matvec, digital oracle vs physical analog, same contract) | AR3 + R16 closed (`aien-dev/omega#68`) + an operator decision on a physical device |
| AR5 | Omega multi-substrate empirical selection | `aien-dev/omega#60` landed + R16 closed |
| AR6 | Fabric-connected analog Machine | Phase F5 (Fabric) |
| AR7 | J-Space / RSI multi-substrate optimization | Phase H3 (RSI optimization loop) |

Order inside the existing sequence: V2 contract landed early in physics#16, but AR1 completion follows the C1 FORGE boundary (physics#13); AR2-AR3 run beside Phase C/E without touching Omega runtime code; AR4-AR5 follow R16; AR6 follows F5; AR7 follows H3.

**Exit gate (AR4):** one matvec realized on a physical analog substrate satisfies the same SemanticResultContract as its digital oracle, with bounded error, repeatability, a fresh bound calibration, complete evidence, no authority bypass, no vendor identity in the semantic program, clean digital fallback, and no way for a faulted device to corrupt the World.

## 7. Phase D — AIENOS trusted substrate

Continue the AIENOS component roadmap without redefining this plan.

### D1. M5 encryption and identity

Finish and qualify:

- owner-controlled key hierarchy;
- sealed volume keys;
- AES-256-GCM-SIV object envelopes;
- anti-rollback anchors;
- migration authorization;
- production/test identity separation;
- deterministic recovery;
- owner-signed trust chain on Machine 1.

Resolve hardware qualification blocks instead of bypassing them.

### D2. M6 minimal networking

Build the minimum native networking needed by the system:

- device ownership and discovery;
- bounded driver authority;
- Ethernet/IP/routing;
- secure transport;
- service discovery sufficient for Fabric later;
- deterministic failure/recovery.

### D3. M7 native CPU inference

- Move the stable inference contract behind an AIENOS platform boundary.
- Run without Linux syscalls under the native configuration.
- Bind model/tokenizer/weight identities.
- Preserve sequence/KV/Cortex continuity contracts.
- Compare against a frozen reference oracle.

### D4. M8 persistent-agent proof

First public whole-system proof:

1. power on;
2. AIENOS boots without Linux underneath;
3. local model and AIEN runtime start;
4. user interacts;
5. Cortex stores a meaningful fact;
6. power off;
7. power on;
8. the same provisioned agent identity resumes and recalls it;
9. recovery remains possible with the model unavailable.

**Exit gate:** persistent agent continuity is a demonstrated machine property, not a diagram.

## 8. Phase E — Omega sovereign training substrate

This lane can proceed in parallel with AIENOS D1-D3 once M19R/Forge boundaries are stable.

### E1. Numerical closure

Before tensor training:

- general FP32 load/store/arithmetic;
- comparison/select/conversion;
- reductions;
- defined division/sqrt behavior;
- Omega-owned frozen transcendental sequences where needed, each with a declared error bound (ADR 0018 `BOUNDED_DETERMINISTIC`, not `EXACT`) and bit-identical CPU/GB10 parity; DIV and SQRT stay correctly rounded;
- CPU/GB10 parity under frozen numeric contracts.

Status 2026-09-30: not closed. omega `docs/numeric/E1_GAP_TABLE.md` (`aien-dev/omega#117`, `c2160f5`) maps these items to merged Gate 5 evidence: 1 covered, 7 partial, 4 missing; largest gaps are division/sqrt on GB10, the transcendental set with GB10 kernels, and reductions beyond one warp. EXP/LOG are frozen and error-bounded (EXP within 40 ulp), not exact. 2026-10-01: the transcendental bullet above was changed from "exact sequences" to declared bounds by explicit owner decision (merge of this change); ADR 0018 keeps `EXACT` as the default for every other operation.

### E2. M20 OMEGA_TENSOR

- immutable semantic tensors;
- shapes, strides, layouts, views;
- generation-checked runtime storage;
- elementwise ops, reduction, broadcasting, transpose, general matmul;
- generalize tensor-core realization beyond narrow K/tile assumptions;
- no semantic in-place mutation.

### E3. M21 OMEGA_AUTODIFF

```text
Omega forward graph
    ↓ differentiate
Omega backward graph
```

The backward pass is ordinary Omega and uses the same Forge/AEGIS path.

### E4. M22 OMEGA_OPTIMIZER

- SGD first; Adam/AdamW after;
- updates write into shadow state;
- validation precedes one atomic generation switch;
- crash/fault injection must yield OLD or NEW, never half-updated.

### E5. Training provenance

Separate:

- per-dispatch execution provenance; and
- full parameter/optimizer state provenance at committed training steps.

Do not hash full model contents after every small kernel launch.

**Exit gate:** a complete training step is deterministic enough to reproduce/verify and transactionally recoverable.

## 9. Phase F — Agency and composition

### F1. Canonical Capability Graph

One runtime graph of:

- providers;
- tools;
- skills;
- machines;
- models;
- credentials/references;
- requested capabilities;
- constraints;
- availability.

MCP is one provider adapter, not the system ontology.

Status 2026-09-30: implemented at host level as omega `rx_capq` (`aien-dev/omega#115`, `135d1c2`), machines keyed by `AienMachineId` (`#113`). Credentials and live provider advertisement over Fabric are not implemented; not yet in the living-system build.

### F2. Skill Router

Skills are signed/versioned reusable procedures. Tools are atomic operations. The router selects procedures/capabilities without exposing raw provider sprawl to the model.

Status 2026-09-30: implemented at host level as omega `rx_skillroute` (`aien-dev/omega#115`, `135d1c2`): routes a requirement to a digest-pinned local skill or a remote provider record and binds one `AG_SKILL` action-graph node. Remote provider execution depends on Fabric, which does not exist.

### F3. World and effects

- World = branchable execution state.
- Cortex = durable epistemic memory.
- Effects begin as typed Omega effect programs.
- Forge realizes physical/external operations.
- AEGIS verifies contracts.
- Effect Broker is a narrow protocol adapter.
- World commit binds selected branch, effect receipts, evidence roots, and identities.

Status 2026-09-30: World execution is recorded into omega `rx_cortex` through one optional recorder hook (`aien-dev/omega#114`, `43dcb04`). World commit does not yet bind J-Space branches (`js_branch_seal` / `js_space_reclaim_staged` are not called from World code), and the Cortex owner is not yet recorded under `doctrine/ARCHITECTURE.md` §2.8.

### F4. J-Space

- fork candidate Worlds;
- execute reversible alternatives;
- keep score dimensions explicit;
- prune dominated candidates;
- externalize only the selected verified branch.

Status 2026-09-30: production J-Space for local branches merged (`aien-dev/omega#116`, `529ebfa`): generation-checked ids, limits, durable checkpoints, staged branches. Remote operations return `JS_ERR_REMOTE`; machine placement is a placeholder; not yet in the living-system build.

### F5. Fabric

After native networking:

- stable Machine identities;
- authenticated membership;
- capability advertisement;
- topology/latency measurement;
- leases;
- placement;
- failure recovery.

Start with coarse work units, not per-layer distributed inference.

Status 2026-09-30: not started. Only stable Machine identities exist (`AienMachineId`, `aien-dev/omega#113`, `16f8518`).

**Exit gate:** one objective can be decomposed, explored across branches/machines, realized, verified, committed, and remembered through canonical typed interfaces.

## 10. Phase G — Sovereign learned search

### G1. M23 search-guide training corpus

Instrument synthesis deeply:

- parent/child candidate;
- transformation;
- semantic features;
- verifier outcome;
- realization outcome;
- measured cost/performance;
- prune/failure/success reason.

Learned guidance prioritizes search; verification still decides validity.

### G2. M24 AIEN_0

Train a deliberately small first sovereign guide to score candidate next actions from:

- current state;
- remaining objective;
- candidate operation semantics.

The exact parameter count is secondary to a frozen experiment contract.

### G3. Sealed evaluation

Before final training, commit:

- holdout seed commitment;
- generator/version;
- metrics;
- thresholds;
- allowed data;
- architecture;
- optimizer;
- training budget.

Train, freeze model digest, reveal holdout, evaluate once, write immutable receipt.

### G4. M25 guided synthesis

AIEN_0 must measurably reduce search cost/time-to-valid-realization while preserving verification parity. If it does not, it has not earned integration.

### G5. M26 abstraction discovery

AIEN proposes reusable abstractions. Omega admits them only when they preserve semantics and improve compression/reuse/search on held-out tasks.

## 11. Phase H — Integrated AIEN

### H1. Runtime integration

Integrate the learned guide into:

- J-Space;
- Skill selection;
- Omega synthesis;
- planning.

It proposes; it never self-grants capability.

### H2. Cortex epistemic engine

Consolidate Cortex around:

- claims;
- evidence;
- episodes;
- hypotheses;
- confidence/verification tiers;
- retractions;
- promotions;
- provenance links.

Model output is not automatically fact.

### H3. RSI optimization loop

Bring RSI back onto the path only now.

RSI may propose and evaluate improvements to:

- Forge plans;
- J-Space widths;
- routing;
- cache/layout policy;
- Skill retrieval;
- model placement;
- later model candidates.

RSI cannot directly modify or promote the live trusted path.

## 12. Phase I — Sovereign closure and self-hosting

- Remove permanent Linux/CUDA/foreign-runtime dependencies where doctrine requires sovereignty.
- Preserve those tools as historical/reference oracles rather than pretending they were never used.
- Demonstrate boot, recovery, core build/realization, and continued operation without them.
- Keep Atlas as the founding bootstrap exception where explicitly defined.

**Exit gate:** the installed lineage can reconstruct and operate its required trusted stack without depending on an external vendor service or incumbent OS.

## 13. Phase J — Physics Zero (M27-M35)

Physics Zero is scientific discovery and is distinct from Forge.

Sequence:

1. M27 contamination firewall and sealed evaluation protocol.
2. M28 hidden-law worlds.
3. M29 executable theory discovery.
4. M30 active experiment selection that discriminates competing theories.
5. M31 reusable concept formation.
6. M32 alien-law worlds.
7. M33 novel-regime extrapolation.
8. M34 prediction of previously unobserved phenomena.
9. M35 bounded real-lab experimentation.

Evaluation rewards prediction, calibration, compression, and discriminating experiments, not resemblance to human textbook vocabulary.

## 14. Phase K — General AIEN (M36-M40)

### M36 Human interface

Natural language/perception maps into the existing semantic/planning architecture. Chat is an interface, not the architecture.

### M37 Resident cognition

Long-lived cognitive execution on the persistent accelerator substrate with bounded resources and deterministic reconstruction.

### M38 Continual library learning

Wake -> Solve -> Verify -> Sleep compounding loop with measured admission and retirement of abstractions.

### M39 Scientific autonomy

Extended observe -> hypothesize -> predict -> experiment -> falsify -> revise campaigns inside declared physical bounds.

### M40 Succession

AIEN-N may design/train AIEN-N+1, but neither parent nor child may self-approve promotion. Evaluation is frozen first; candidate runs in isolated Worlds/canaries; independent verification and operator/governance rules decide promotion; rollback remains real.

## 15. Final release gate

The project is complete only when the clean-machine golden path works end-to-end:

```text
Power on
→ Atlas awakens
→ AIENOS reconstructs trusted system state
→ Cortex restores durable memory
→ AIEN resumes
→ objective arrives
→ J-Space explores alternatives
→ Skill/Capability Graph resolves needs
→ Fabric places eligible work
→ Omega defines semantics
→ Forge realizes for available hardware
→ AEGIS verifies
→ hardware/tools act
→ World commits
→ provenance/evidence seal
→ Cortex learns
→ AIEN continues
```

The release campaign must include destructive/adversarial recovery tests: stale handles, revoked capabilities, interrupted state transitions, machine loss, network ambiguity, accelerator failure, corrupt candidates, and attempted self-promotion.

## 16. Work that may run in parallel now

**Lane 1 — M19R / Forge:** evidence repair, resource lifecycle, exactly-once completion, Forge boundary.

**Lane 2 — AIENOS:** M5 trust/encryption -> M6 network -> M7 inference -> M8 persistent agent.

**Lane 3 — Omega training:** FP32 numerics -> M20 tensor -> M21 autodiff -> M22 optimizer.

**Lane 4 — Composition (COMPOSITION-1):** Capability Graph, Skill Router, World/effects, J-Space, Fabric interface design.

- Alias: COMPOSITION-1 (formerly misnamed 'M20 program' in agent briefs, 2026-09-30). Any "M20" in omega PRs #113 to #116 or `m20*` branch names means COMPOSITION-1; roadmap M20 is `OMEGA_TENSOR` (Lane 3).
- Merged so far: `aien-dev/omega#113`, `#114`, `#115`, `#116` (see §2 composition-merges addendum). Open: World commit binding of J-Space, Cortex ownership ADR, living-system integration, Fabric.

**Lane 5 — Resident reaction runtime (ADR 0016):** R0–R16, sequenced in [`docs/plans/CURRENT_CODE_TO_R0_R16_MIGRATION.md`](docs/plans/CURRENT_CODE_TO_R0_R16_MIGRATION.md).

- Host-only gates R3–R8 proceed now in new Omega files (`omega/src/runtime/`), disjoint from M19R.
- R1/R2 (shared world, cross-engine ABI) and R12 (resident CPU/GPU cooperation) wait for M19R Gate 2 and an idle GB10.
- R9 (generation barrier) commits through the now-merged ADR 0015 protocol and follows R5–R8.
- Lane 4's World/effects and J-Space work must be expressed as reactions over the shared world, not as a new orchestrator.

**Lane 6 — Substrate-neutral realization (ADR 0018):** AR0–AR7, sequenced in §6 C3; collision rules in `docs/plans/analog-realization/ANALOG_REALIZATION_COLLISION_MAP.md`.

- Must not add a new central loop, scheduler, service or callback path, and must not create a second World.
- The runtime edit freeze on `omega/src/runtime/` is LIFTED following R16 closure (`aien-dev/omega#112`).
- The ARGUS event ABI is untouched; analog telemetry needs are documentation only.
- New code in R16-scanned repositories (omega, aienos, physics) must stay clean of the R16 loop-inventory patterns.

**Lane 7 - Belief / estimation layer (ADR 0020):** EST-0 to EST-10; current state in [`docs/plans/belief-estimation/BELIEF_ESTIMATION_CURRENT_STATE.md`](docs/plans/belief-estimation/BELIEF_ESTIMATION_CURRENT_STATE.md).

- EST-0 to EST-3 (contract, linear Kalman reference, one real signal, calibration) may run before R16 closes only as a standalone module: new files under `omega/src/estimation/` and `omega/tests/estimation/`, own `mk/estimation.mk` targets, not in `all` or `test`, not included by `omega/src/runtime/`.
- EST-4 onward (World, cost model, TURING, J-Space, Cortex, curiosity, information gain) is unblocked following R16 closure and the lifting of the `omega/src/runtime/` hold.
- Estimator output never becomes an authority input and never replaces raw evidence. An estimator that fails EST-3 calibration is not promoted.
- New estimation code stays clean of the R16 loop-inventory patterns.

These lanes converge before AIEN_0 is promoted into the live runtime.

## 17. Immediate next gates

Do not start another master plan. Execute these:

1. Merge plan-authority consolidation and Forge naming ADR.
2. Complete M19 corrective qualification.
3. Establish the typed Omega/Forge boundary.
4. Finish and qualify AIENOS M5 trust/encryption.
5. Finish Omega general FP32 numerical support.
6. Proceed to AIENOS M6 and Omega M20 (`OMEGA_TENSOR`) in parallel.

The ADR 0018 workstream runs as Lane 6 and does not reorder these gates.

The ADR 0020 workstream runs as Lane 7 and does not reorder these gates; its EST-4 and later stages follow R16 closure.
