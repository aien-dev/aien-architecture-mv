# Current Code → R0–R16 Migration Map

**NOT A MASTER PLAN.** This is a finite workstream plan for ADR 0016, the resident reaction architecture. `CURRENT_EXECUTION_PLAN.md` still owns cross-project sequencing, and `doctrine/ROADMAP.md` still owns milestone status. The R-gates below are ADR 0016 gates, not M-milestones.

**Written:** 2026-09-27. The code facts come from reading `origin/main` of each repository on that date:

| Repository | Commit |
|---|---|
| omega | `1feb832` |
| physics | `a477aee` |
| aienos | `aien-spark/aienos` main, last commit 2026-09-25 |
| aien-sovereign-core | main, 2026-09-27 |
| aegis-runtime | `2bbce76` |
| aien-protocols | main, 2026-09-23 |

The rules are those in ADR 0016 §60: code plus reproducible evidence decides what is true today, ADR 0016 decides the destination, and nothing is deleted before rollback is proven.

---

## 1. What exists today, in one paragraph

Nothing in any repository is reactive. The following were not found anywhere:

- a dependency index;
- a wake-on-change subscription;
- semantic invalidation;
- a loop that outlives one request or one boot.

Every runtime path today is shaped as orchestration:

- `omega/tools/omegatool.c` sequences gates and demos by hand.
- M19 `omega_world_*` is a synchronous register → submit → ring → drain service.
- `aien-sovereign-core` `aien-runtime/src/spine.rs:112` is `for 0..max_steps { step() }`, driven once per request.
- `aegis-runtime` `agent.rs:130` is an LLM tool-turn loop. `heartbeat.rs:94` polls an SQLite task table.
- Aienux boot runs a fixed demo sequence and halts: `aienos-boot/src/handoff.rs:1621`.

Nothing in code drives AIEN → Omega → AEGIS. The word "omega" does not appear in aienos, sovereign-core, or aegis-runtime.

The pieces worth keeping are primitives, not runtimes:

| Primitive | Location |
|---|---|
| Generation-checked kernel capabilities | aienos `caps.rs` |
| Atomic OLD-or-NEW store commits | aienos Store v1 |
| Content-addressed evidence DAG | sovereign-core `aien-proof` |
| Pointer-free coherent shared-world ABI | physics/omega branch `m20-shared-world`, not merged |
| Canonical semantic identity | Omega M4 |
| Realization selection | Omega M12/M14 |
| Native GPU submission | M16–M19 |

## 2. Gate status (evidence-backed only)

| Gate | Status | Evidence |
|---|---|---|
| R0 `R0_REACTION_ARCHITECTURE_LOCKED` | PASS on merge of ADR 0016 | `docs/adr/0016-resident-reaction-architecture.md` |
| R1 `R1_SHARED_WORLD_PASS` | NOT CLAIMED | Host reference pool exists (`omega/src/runtime/rx_world.*`). The canonical pool must unify with `OMEGA_SHARED_WORLD_V1`. |
| R2 `R2_CROSS_ENGINE_ABI_PASS` | NOT CLAIMED | The ABI exists on unmerged branch `m20-shared-world` (58/58 host checks). There is no silicon run. |
| R3 `R3_REACTION_CORE_PASS` | **PASS (host reference, CPU only)** | omega `tests/runtime/rx_heartbeat_test.c` (`make test-r3`). Receipt `omega/evidence/R3/ef3e5565b9deda5226b58caf00c3e05f467cf03f6ae91984c10898d98e28c321.json`: candidate `9dd9594`, clean tree, 15/15 tests, 8,948 checks, 0 failures. |
| R4 `R4_CAUSAL_TRACE_PASS` | **PASS (host reference, CPU only)** | Same receipt. Every reaction crumb in every test is audited for trigger, inputs, authority, outputs, and ancestry: 1,727 audited, 7,016 digests re-verified. |
| R5 `R5_RESOURCE_ARBITRATION` | PASS | host reference, not silicon (#36-#38) |
| R6 `R6_REACTION_STABILITY` | PASS | host reference, not silicon (#36-#38) |
| R7 `R7_NATIVE_AUTHORITY` | PASS | host, against the native C authority (#41, #43) |
| R8 `R8_CONSTITUTIONAL_AEGIS` | PASS | host (#48, `fe4924a`) |
| R9 `R9_GENERATION_BARRIER` | PASS | host (#42, `00be7ae`) |
| R10 `R10_CONTINUOUS_OMEGA` | PASS | DGX Spark CPU (#46, `0a787ee`) |
| R11 `R11_CONTINUOUS_COGNITION` | PASS | DGX Spark CPU (#47, `628daf5`) |
| R12 resident GPU seat | PASS | GB10 silicon (#44, `05b0692`; hardening #45, `4331bf3`) |
| R13 faculties as one causal system | PASS (causal verification PASS, AIEN goal MET) | GB10 silicon (#49, `fcb5793`) |
| R14 living recovery | PASS | GB10 silicon (#50, `f70ae10`) |
| R15 quantitative performance | HISTORICAL PASS (16/16 at `3e9e53b`); requal FAIL 14/16 at `3108fc2` (omega `evidence/REQUAL-3108fc2/`); NOT requalified on CAND-0 | DGX Spark (#67, `bba3bd3`, 16/16 gates) |
| R16 orchestrator retirement | HISTORICAL PASS at `850fc54`; receipt INVALID as a current claim; requal FAIL at `3108fc2`; NOT requalified on CAND-0 | DGX Spark (`aien-spark/omega#112` merged, `3dd5eaa`, receipt `evidence/R16/22d7a79a985514ac38139d39c71c9638d9b6b0a6e05425b6810bdb4833d1ea64.json`) |

The R3/R4 claims are scoped to the host reference runtime. They say nothing about GPU execution (R12) or about the native Aienux capability root (R7).

---

## 3. Module map

Legend:

- **Keep**: used as is.
- **Adapt**: kept, with a changed role or an extension.
- **Replace**: superseded as the mechanism for this purpose. It stays in place as the reference oracle until R16.
- **Oracle**: legacy behavior the new path is compared against.

Parallelization groups (§4) are marked **G0–G6**.

### 3.1 Omega (`aien-spark/omega`, C11)

| Current module | Current responsibility | Target responsibility | Decision | Depends on | Risk | Tests | Milestone | Group |
|---|---|---|---|---|---|---|---|---|
| `tools/omegatool.c` (3,962 lines) | CLI that hand-sequences every gate suite and demo | Legacy orchestrated runtime = reference oracle; later one launcher that seeds stimuli and observes | **Oracle** until R16 | everything | Low while untouched | `--run-*-gates` (M4–M14: 111/111 rerun 2026-09-27) | R15 compare, R16 retire | — |
| `src/runtime/rx_world.{c,h}` (new) | Host reference reaction runtime: object pool (id, generation, per-field versions, persistence class, content digest), dependency index by field mask, ready set by priority class, explicit lifecycle, versioned snapshot + atomic publication, causal crumbs (SHA-256 DAG) | Seed of `runtime/{object,reaction,dependency,publication,causal}`; the object pool moves onto the shared-world region at R1/R2 | **Keep → Adapt** | `sha256.c`, `rx_caproot` | One world mutex (deliberately simple, ADR 0016 §56); not a performance claim | `make test-r3`: 15 tests, 8,129 checks, 0 fail; 4/4 engine and 4/4 root deliberate-break (mutation) checks detected | R3, R4 (done host); R1, R5, R6, R15 next | G1 |
| `src/runtime/rx_caproot.{c,h}` (new) | Host capability root: separate non-dumpable mint process; table in a sealed memfd, read-only to the runtime; mint / attenuate-only delegation / revoke (cascading via chain walk) / reclaim (generation++) / lease clock / epoch | Linux-host stand-in for the Aienux kernel root; semantics must equal `aienos caps.rs` plus epoch/lease | **Keep (host)**; native root is aienos | Linux memfd seals (kernel ≥ 5.1; verified on 7.0) | Who may request a fresh mint is not yet authenticated (R7/R8) | Attack tests: forged, stale-generation replay, revoked, wrong subject, wrong resource, insufficient rights, lease expiry, epoch change, amplification, resource widening, non-delegable, cascading revoke, revoke mid-run, mprotect / mmap-write / pwrite / ftruncate / `/proc` reopen / direct-store SIGSEGV | R7 (host part) | G1 |
| `src/omega_accelerator_world.{c,h}` (M19, 1,369 lines) | Synchronous GPU world: buffer/code registries with `OmegaHandle{epoch,id,gen,type,permissions}`; submit/ring/drain; exactly-once completion (M19R); rolling digest | GPU **realization backend** under R2/R12. `OmegaHandle.permissions` becomes a cached view; the right comes from a capability reference validated against the root (I3) | **Adapt** | physics `nvrm`, `m16` | M19R Lanes A/B are editing this file now | M19 gates (GPU); M19R lifecycle gates | R2, R12 | G2 (after M19R Gate 2) |
| `src/omega_world_gates.c` | M19 qualification gates | Unchanged; becomes the regression oracle for R12 | **Keep** | M19 world | Shared with M19R Lanes A/B | `--run-m19-gates` (GPU) | R12, R14 | — |
| `src/omega_evidence.{c,h}` | Run-scoped, non-clobbering evidence paths; run commit / dirty tree; observed hardware identity | Receipt plumbing for every R-gate | **Keep** (already reused by the R3 receipt) | — | `run_commit` is HEAD, so every R receipt must also bind `OMEGA_CANDIDATE_COMMIT` | used by all suites | all | — |
| `omega_types.h`, `omega_core`, `omega_canonical`, `omega_codec`, `omega_validate` (M4) | Canonical `OMG0` encoding, `SEMANTIC_ID` content identity | Identity rule and canonical encoding in the per-type object contract (ADR 0016 §26); `SemanticId` alongside `ObjectId`/`Generation` | **Keep** | — | Do not change bytes: historical IDs depend on them | M4 gates 12/12 | R1 | G2 |
| `omega_machine` (G_M), `omega_realize*`, `omega_realize_synth` (M13/M14) | Machine graph; G_S × G_M → G_R synthesis | Omega realization faculty invoked by reactions, not by callers | **Adapt** (wrap as reactions) | R5, R6 | `omega_machine.c:96` `is_physics_authorized` is a frozen fingerprint field; never treat it as authority | M13/M14 gates 20/20 | R10 | G5 |
| `omega_matvec` (M12 "living matvec") | Measures regimes, selects a realization adaptively | Prototype of "hot operation → cost evidence crosses threshold → optimization reaction" | **Adapt** | R10 | — | M12 gates 10/10 | R10 | G5 |
| `omega_verify` (M7, V0–V2) | Verification ladder | Verification reactions gate realization promotion; the ladder is also applied to the runtime itself (§55) | **Keep** | — | — | M7 gates 10/10 | R10, R13 | G5 |
| `omega_synthesis`, `omega_library`, `omega_discovery` (M9–M11) | Synthesis, library, abstraction discovery | Unchanged inside; triggered by reactions | **Keep frozen** (M19R rule: Lane E must not edit) | — | M9–M11 gates depend on exact files | M9–M11 gates 30/30 | R10 | G5 |
| `omega_blackwell_*` (M17/M18 codegen, encoder, QMD, submit) | Native sm_121 code generation and submission | FORGE realization for GPU-placed reactions | **Keep** | physics `m16` | M19R Lane D is adding FP32 SIMT | M17/M18 gates (GPU) | R12 | G2 |
| branch `m20-shared-world`: `omega_shared_world_worker.*`, STRONG.SYS/MEMBAR opcodes | Persistent GPU worker scaffold (returns `WORKER_INCOMPLETE`); ordering opcodes fixture-checked | Resident GPU reaction worker: observe eligible GPU reactions → claim → execute → publish descriptors (§15) | **Adapt** | R2, idle GB10 | Never silicon-observed; the name collides with ROADMAP M20 = `OMEGA_TENSOR` | codegen fixtures | R12 | G2 |

### 3.2 FORGE / historical PHYSICS (`aien-spark/physics`)

| Current module | Current responsibility | Target responsibility | Decision | Depends on | Risk | Tests | Milestone | Group |
|---|---|---|---|---|---|---|---|---|
| branch `m20-shared-world`: `shared_world/omega_shared_world_abi.h`, `omega_shared_world.{c,h}` | Pointer-free 128-byte descriptor; object records `{id, generation, offset, length}`; epoch; SPSC rings with ABA/replay/torn guards; LDAR/STLR confirmed | **Canonical R1/R2 substrate.** Extend object records with type, version, per-field change mask, persistence class, capability reference, publication state. Rings become wake/claim transport, not RPC. | **Adapt** | `physics_coherent` | Turning rings into "one queue for everything" (§57) | `test_shared_world_host`: 58/58, 2.3M messages (host) | R1, R2 | G2 |
| branch `m20-shared-world`: `coherent/physics_coherent.{c,h}` | Coherent region allocate / resolve / revoke; hides RM handles | Trusted machine registry: physical addresses stay here (I1) | **Adapt** | `nvrm` | Not run on GB10 yet | syntax-checked only | R2, R12 | G2 |
| `nvrm/nvrm.{c,h}` (+ `nvrm_free`, M19R #12) | Userspace RM client: allocation, free, completion | GPU resource backend; GPU reset and worker kill for containment | **Keep** | driver 580.173.02 | — | `tests/run_nvrm_lifecycle_gates.sh` | R12, R14 | G2 |
| `m3/capability.s`, `m3/effect_broker.s`, `m3/receipt_ledger.s` | Bare-metal 32-slot capability ledger (slot + generation, attenuation, revoke), 10-stage effect broker, SHA-256 receipt chain | Assembly-level reference oracle for capability and effect semantics | **Keep** (historical, QEMU-qualified) | — | Python gate tooling at repo root violates the no-Python rule | `m3/tests/test_m3_authority.s` 21/21 | R7 oracle, R8 effects | — |
| `m16/` native path | libcuda-free channel/GPFIFO | Unchanged | **Keep** | — | — | M16 requalification | R12 | — |

### 3.3 Aienux (`aien-spark/aienos`, Rust; kernel files are under `crates/aienos-kernel/src/`)

| Current module | Current responsibility | Target responsibility | Decision | Depends on | Risk | Tests | Milestone | Group |
|---|---|---|---|---|---|---|---|---|
| `crates/aienos-kernel/src/caps.rs` (466 lines) | Kernel-owned `CapTable`; handles `{index, generation}`; `derive` enforces subset + DERIVE right; cascading `revoke`; tombstones | **The native capability root** (ADR 0014 gives capabilities to Aienux). Add epoch and lease/expiry; expose a read-only authority view for resident readiness checks | **Adapt** | — | ABI frozen in `abi.rs` (generation-0 rejected); adding fields needs an ABI version | kernel unit tests, `ipc.rs:461`, `task_runtime.rs:664/813` | R7 (native) | G3 |
| `artifact_loader.rs:796`, `admission.rs:291` | Only mint path: admission grants → caps | AEGIS `PolicyDecision` → root mint (slow path); fast path = existing capability | **Adapt** | R7 | Minting remains centralized in the kernel (correct) | `artifact_loader_tests.rs`, H01–H29 corpus | R8 | G3 |
| `kernel/src/scheduler.rs` (380 lines, host-tested) | Fixed-capacity run-queue policy | Native physical admission below semantic readiness (§8): schedules work, not faculties | **Adapt** | R5 host semantics | Not driven by a live loop yet | host tests | R5 (native) | G3 |
| `store/engine.rs`, `checkpoint.rs`, `recovery.rs`, `recovery_core.rs` (Store v1) | A/B superblock atomic commit; crash recovery | Durable side of the generation barrier; commits go through the ADR 0015 ordered protocol | **Keep** | ADR 0015 (merged) | Store v1 catalog bound of 4,096 entries (ADR 0015 Builder 9) | Store golden/negative, `qemu_store_crash_test.sh` | R9 | G4 |
| `continuity.rs` (872 lines) | Agent provisioning/resume, manifest sequence | "Boot becomes awakening" (§30): restore last valid generation, rebuild indexes, re-mint capabilities | **Adapt** | R9, ADR 0015 | Continuity format not frozen (aienos ADR 0016 Proposed) | `continuity_tests.rs`, `qemu_continuity_test.sh` | R9, R14 | G4 |
| `aienos-aegis` (host crate): `capability.rs` HMAC token, `broker.rs`, `world.rs` JSpaceWorld | HMAC-SHA256 token over editable JSON scope; in-memory audit; branch overlay with rollback | Token: **Replace** as an authority mechanism (a keyed MAC over editable fields in the same process is convention, not a root). JSpaceWorld rollback semantics: **Adapt** for speculative reactions (§24) | Replace / Adapt | R7, R8 | Not linked into kernel or boot today, so low blast radius | `phase_3_to_5_integration.rs` | R8, R13 | G3 |
| `aienos-cortex` (host) | Epistemic records (observation / fact / hypothesis) | Cortex hot state as world objects; new observation wakes AIEN reactions | **Adapt** | R11 | — | crate tests | R11 | G5 |
| `aienos-boot/src/handoff.rs:1621` | Fixed boot demo sequence → halt | Awakening sequence (§30); deterministic maintenance controls stay | **Keep** as maintenance/recovery path | R9 | Must never be removed (§49) | QEMU suites | R14, R16 (kept) | — |

### 3.4 AIEN runtime (`aien-spark/aien-sovereign-core`, Rust)

| Current module | Current responsibility | Target responsibility | Decision | Depends on | Risk | Tests | Milestone | Group |
|---|---|---|---|---|---|---|---|---|
| `aien-runtime/src/spine.rs` (339), `aien-scheduler/src/lib.rs` (927) | Per-request inference spine: `run_until_complete` loop, token scheduler, KV | Token scheduler stays as a **physical** batching scheduler. Cognition (interpret, update belief, plan) becomes reactions over world objects; inference is a realization those reactions request | **Oracle** for request handling; **Adapt** the scheduler | R5, R8 | Largest behavioral change; must shadow first (§32 REACTION SHADOW) | `runtime_end_to_end`, `runtime_spine_integration` | R11, R15, R16 | G5 |
| `aien-runtime/src/world.rs` WorldStore (`fork_world`, `commit_draft`) | Path-copying branchable world | Speculative branches as native reactions (§24); promotion explicit | **Adapt** | R9 | — | runtime tests | R11, R13 | G5 |
| `aien-runtime/src/sequence.rs` SequenceArena `{slot, generation}` | Generation-checked sequence handles | Pattern already matches I2; keep | **Keep** | — | — | runtime tests | R11 | — |
| `aien-proof` (`evidence.rs` 1,235 lines, `chain.rs` 434 lines, `gate.rs` 1,438 lines) | Content-addressed receipts (BLAKE3), dependency DAG with cycle rejection, gate manifests | Durable form of causal crumbs at generation commit; gate manifests for R-receipts | **Adapt** | R4, R9 | Hash mismatch: Omega uses SHA-256, aien-proof uses BLAKE3. Choose one causal-identity hash before crumbs become durable (R9). | proof tests | R4 → R9 | G4 |
| `cortex-rs` (SQLite) | Claims/entities memory | Stays outside the trusted runtime path; reached via typed `EpistemicRef` (ADR 0015) | **Keep** | ADR 0015 | SQLite conflicts with ADR 0015's "no generic DB in semantic layers" if pulled inward | cortex tests | R11 | — |
| `aien-cli/src/goals.rs:33` (`goals.json`) | Goals as a JSON file | Goal objects in the shared world; changing one wakes cognition | **Replace** | R11 | — | — | R11 | G5 |
| `aien-cli/src/commands.rs:1536` (spawns `spark-aegis`) | AEGIS reached by shelling out | Removed from the reaction path; AEGIS state participates in readiness | **Replace** | R8 | — | — | R8 | G5 |
| `crates/spark-aegis` symlink → `~/workspace/spark-aegis` (not a git repo) | Workspace member via absolute symlink | Must become a real repository or be removed | **Fix** (build hygiene) | — | Repo does not build anywhere but this machine | — | — | — |

### 3.5 aegis-runtime (`aien-spark/aegis-runtime`, Rust; last change 2026-09-23)

| Current module | Current responsibility | Target responsibility | Decision | Depends on | Risk | Tests | Milestone | Group |
|---|---|---|---|---|---|---|---|---|
| `agent.rs:130` tool-turn loop; `heartbeat.rs:94` / `main.rs:251` polling | LLM agent loop; timed SQLite task polling | Legacy orchestration; never on the reaction path | **Oracle → retire** | — | — | `aegis_tests.rs` | R16 | — |
| `enforcement.rs:31` string denylist; `policy_guard.rs` probe score | Pre-dispatch checks | Not authority. Effect admission belongs to capability root + effect broker (ADR 0005) | **Replace** | R7, R8 | — | `policy_guard_tests.rs` | R8 | — |
| `events/bus.rs` (tokio broadcast; used only by a test) | Event bus | Do not adopt: "one queue for everything" (§57) | **Retire** | — | — | `stage2_primitives_tests.rs` | — | — |
| `orchestration/` (run, budget, trigger, termination) | Types only | Budgets become reaction activation budgets (R6) | **Replace** | R6 | — | — | R6 | — |

### 3.6 aien-protocols

| Current module | Current responsibility | Target responsibility | Decision | Milestone |
|---|---|---|---|---|
| `aien-action-protocol` `CapabilityGrant {capability, scope, expires_at}` | Serde description of a grant | Wire description only; never authority | **Keep as description** | R8 |
| `aien-agent-state-abi` `AgentStateEvent` (before/after digests) | State transition event | Maps onto a causal crumb's inputs/outputs digests | **Adapt** | R4 → R9 |

---

## 4. Order and parallelization

```text
G0  R0 ADR 0016 ─────────────────────────────────────────────── (merge)
         │
G1  host runtime (omega src/runtime; new files only)
    R3 ✔ ─ R4 ✔ ─ R5 modulation ─ R6 storm/loop ─ R7-host ─ R8 resident AEGIS
         │                                            │
G2  shared-world substrate (physics shared_world + omega worker)
    [after M19R Gate 2 and an idle GB10]              │
    R1 unify pool ↔ OMEGA_SHARED_WORLD_V1 ─ R2 ABI ───┼──────────── R12 silicon
         │                                            │
G3  native root (aienos)                              │
    caps.rs epoch + lease ─ read-only authority view ─ R7-native ─ R8-native
         │
G4  durability [ADR 0015 merged 2026-09-27; starts after R5–R8]
    choose causal hash ─ R9 generation barrier via Store v1
         │
G5  faculties
    R10 Omega continuous realization   (after R5, R6)
    R11 AIEN continuous cognition      (after R8, shadow mode first)
         │
G6  integration (serial)
    R13 golden path ─ R14 failure path ─ R15 performance proof ─ R16 retire orchestration
```

Why this order:

- R5 and R6 come before any real faculty. A reaction system without admission and storm control must not grow (§22: inspection before scale).
- R7 comes before R8 because the root must exist before resident authority can refer to it.
- R9 uses the ADR 0015 commit protocol (merged 2026-09-27) and follows R5–R8.
- R12 needs silicon. Its claim is never made from host runs (§60 item 8).

Disjoint ownership, so these groups can run at the same time:

- G1 touches only `omega/src/runtime/**` and `omega/tests/runtime/**`.
- G2 touches `physics/shared_world/**`, `physics/coherent/**`, and new omega worker files.
- G3 touches aienos.
- G4 touches aienos store and aien-proof.

These groups share no files with M19R Lanes A–E, except that G2 must wait for M19R Gate 2 before adapting `omega_accelerator_world.*`.

## 5. Open items found while mapping

1. **Naming collision.** The unmerged "M20 Stage 1 `OMEGA_SHARED_WORLD`" work conflicts with ROADMAP M20 = `OMEGA_TENSOR`. Recommend relabelling it R1/R2 under ADR 0016 when those branches are merged.
2. **Causal-identity hash.** Omega uses SHA-256 (semantic IDs, crumbs). `aien-proof` uses BLAKE3. Pick one before crumbs become durable (R9). Recommend SHA-256 for continuity with `SEMANTIC_ID` and the Physics/M3 receipt chain.
3. **Mint authentication.** Both the host root and the kernel root enforce attenuation. Neither yet authenticates which principal may request a fresh (non-delegated) mint. This is R7/R8 scope.
4. **Python.** It remains in physics (`run_milestone2_gates.py`, `seam*_*.py`), sovereign-core (11 files) and spark-rsi. None of it is touched by this track, and R-gate tooling stays C/bash/Rust.
5. **`spark-aegis` symlink.** sovereign-core depends on an absolute-path symlink to an untracked directory.
