# Mixed Algebra - Current State

**NOT A MASTER PLAN.** This is a finite workstream document for ADR 0019 (ARCH-0019, ACCEPTED 2026-09-29), mixed-algebra semantics and realization in Omega. It builds on ADR 0018 (ARCH-0018, ACCEPTED). `CURRENT_EXECUTION_PLAN.md` still owns cross-project sequencing and `doctrine/ROADMAP.md` still owns milestone status. Nothing in this document is a milestone.

**Written:** 2026-09-29. Code facts come from two read-only audits of the commits below; code was read, README and spec claims were not taken as evidence. Ten file:line claims were re-checked by hand on the same date (see §17).

| Repository | Commit |
|---|---|
| omega | `main` `6fdc4c3` (includes #75 program id v2, #71 cap64, #60 empirical, #68 R16) |
| omega (parked) | `experiment/ternary-semantics` `ae1e2a3` (base `878275f`, M19 era) |
| omega (open PR) | `#32` `feat/forge-v1-numeric` head `25a0c5f` (base `1feb832`) |
| physics | `main` `f63a6ef` (`#13` merged `5969159`, `#16` merged `1f7c321`) |
| aien-architecture | `main` `8ec9b1d` |
| aienos | `main` `603c91d` (via `gh api`) |

Paths prefixed `ternary:` are on the parked branch, `pr32:` on PR #32, `physics:` on physics main. Unprefixed `src/` paths are omega main.

## Status legend

| Status | Meaning |
|---|---|
| IMPLEMENTED | Code on `main`, exercised by a test or receipt. |
| PARTIAL | Code on `main` covers only part of what mixed algebra needs, or is a stand-in. |
| PLANNED | Written down in a spec, ADR, plan or unmerged branch; not on `main`. |
| MISSING | Neither code nor accepted plan. |
| CONFLICTING | Two authorities disagree, or existing code blocks the target shape. |

Planned is never reported as implemented. Unmerged branches count as PLANNED even when they have receipts.

## 1. Omega semantics and identity

| Item | Status | Evidence | Note |
|---|---|---|---|
| Canonical encoding OMG0 | IMPLEMENTED | `src/omega_types.h:14`; `src/omega_canonical.c:56-80` | Magic, version, kind, key-sorted attributes. |
| TypeTag set | PARTIAL | `src/omega_types.h:45-60` | Unsigned, signed, bitvector, byte, sequence, tuple, refs. No float, trit, modulus, sparse or tensor tag. |
| Overflow policy | IMPLEMENTED | `src/omega_types.h:81-86` | WRAP / SATURATE / FAIL_CLOSED exists; usable for symmetric-saturation ternary. |
| Program identity v2 | IMPLEMENTED, narrow | `src/omega_program.h:41-53`; `src/omega_program.c:103-112` | Body is a chain of unary `{op, u64 imm}` steps over ADD/SUB/MUL/AND/OR. Cannot name matvec, matmul, float or residue ops. |
| Op-family spec ids | PARTIAL | `MatVecSemanticSpec.spec_id`, `OmegaMatMulSpec.spec_id` | Matvec and matmul identities live outside program id v2. |
| Ternary / trit / Z3 / residue on main | MISSING | grep of `src/` | Only false positives (`omega_synthesis.c:217` comment, `z3` variable in `rx_costmodel.c:269`). |

## 2. IRs

| Item | Status | Evidence | Note |
|---|---|---|---|
| Action graph IR | IMPLEMENTED | `src/runtime/rx_graph.h:180-274` | Agent-level graph; no numeric domain. |
| State projection IR | IMPLEMENTED | `src/runtime/rx_projection.h:213-248` | Cognitive state, not numeric. |
| Capability query | IMPLEMENTED | `src/runtime/rx_capq.h:84-126,227-263` | Latency, energy, cost, confidence, evidence level. No precision, error bound or algebra field; I/O types are opaque bitmasks. |
| Typed result constraints | IMPLEMENTED, exact-only | `src/runtime/rx_contract.h:61-99` | Integer, enum and digest fields; no tolerance, ULP or error rule. |
| Plan IR | IMPLEMENTED | `src/runtime/rx_plan.h:134-275` | Plan cache and execute. |

## 3. Realization, cost model and routing

| Item | Status | Evidence | Note |
|---|---|---|---|
| RealizationObject | IMPLEMENTED | `src/omega_realize.h:8-24` | AArch64 bytes plus semantic/machine/realization triple id. |
| `omega_program_realize` | MISSING | declared `src/omega_program.h:117`; `src/visor/visor_realization.c:437` | Declared, never defined. Each op family has its own synth. |
| Empirical cost model | IMPLEMENTED, matvec-only | `src/runtime/rx_costmodel.h:36-71`; `rx_costmodel.c:40,286` | `RX_CM_OPS 1u`, 8 arms, features M, N, state bytes as `*8` (u64). Widening changes the serialized digest (`:180`). |
| Empirical optimizer | IMPLEMENTED (CPU matvec) | `tests/runtime/rx_empirical_optimizer.c:77`; `evidence/EMPIRICAL/*.json` | Arms reference, scalar, unroll2, unroll4_dual, quad4, planted_wrong; 44 checks, 0 failures. |
| Cognitive routing | IMPLEMENTED, GPU bit unused | `src/runtime/rx_route.h:47-63`; `rx_route.c:323,488` | Hardware-named `RX_COG_HW_*`; precision is binary APPROX/EXACT; ops RECOGNIZE/PLAN only. ADR 0018 §15 already requires replacing `RX_COG_HW_*`. |
| Generation / promotion | IMPLEMENTED | `src/runtime/rx_generation.h:19-122` | R9 barrier; 64-bit generations. |

## 4. CPU path

| Item | Status | Evidence | Note |
|---|---|---|---|
| Own AArch64 encoder + W^X exec | IMPLEMENTED | `src/aarch64_encoder.c`; `src/omega_exec.c:15,21` | No external assembler at run time. |
| Matvec synth (scalar, quad4) | IMPLEMENTED | `src/omega_matvec.c:210`; `src/omega_matvec_quad.c:73` | u64 wrapping arithmetic only. |
| Ternary AArch64 lowering (INT, PLANES) | PLANNED | `ternary:src/omega_ternary_a64.h:16-24` | Ran on Spark in the parked experiment (TG4, TG5); not on main. |

## 5. GPU / Blackwell path

Kernels are produced by Omega itself (own sm_121 SASS encoder, own QMD, own pushbuffer) over the physics M16 native RM channel. No CUDA toolkit or libcuda.

| Numeric format | Status | Evidence | Note |
|---|---|---|---|
| INT32 SIMT (IMAD, mod 2^32) | IMPLEMENTED, silicon | `evidence/omega_blackwell_matmul_stage1_receipt.json` | Exact on 16x16x16, 32x16x64. |
| FP16 / BF16 HMMA m16n8k16, FP32 accumulate | IMPLEMENTED, silicon | `evidence/omega_blackwell_matmul_stage2_receipt.json`; `src/omega_blackwell_codegen.h:18-54` | Small shapes only, no tiling. |
| FP32 SIMT (FADD, FMUL, FFMA, MUFU, conversions) | PLANNED | `pr32:src/omega_blackwell_codegen.c:433-522`; ROADMAP Gate 5 "Open, not merged" | Conflicts with main in codegen `.c`/`.h` and `.gitignore`. |
| INT8 (IMMA, DP4A) | MISSING | no encoder opcode | Could be emulated via INT32 IMAD or BF16 HMMA (exact within 2^24). |
| FP8 E4M3/E5M2, NVFP4/FP4, tcgen05/UMMA | MISSING | no grep hits | |
| Ternary on GPU | PLANNED, static only | `ternary:src/omega_ternary_sass.h:4-11` | Cost counting; nothing executed on GB10. Needs oracle-checked LOP3 (any LUT), SEL, ISETP.EX, SHF.L. |
| Physics pin | IMPLEMENTED | `Makefile:24,47-60` (`physics.lock` `fecbedb`) | `check-physics-lock` enforced. |

## 6. Buffers, tensor layout, quantization, numeric types

| Item | Status | Evidence | Note |
|---|---|---|---|
| Buffer / layout descriptor | MISSING | `src/omega_matvec.c:270`; `src/omega_blackwell_matmul.c:111` | Raw dense row-major pointers only; no stride or tensor type. |
| Vector spec | PARTIAL | `src/omega_vector.h:12-20` | Element type, width, count. |
| Quantization (scale, zero point, int8/int4/fp8/fp4) | MISSING | grep of `src/` | |
| Integer / float representations | PARTIAL | `src/omega_blackwell_matmul.h:13-17,58-61` | u64 wrap, u32 wrap, FP16/BF16 to FP32 converters. No IEEE soft-float reference on main (PR #32 has one, but its FP32 reference ops are plain C float, `pr32:src/omega_numeric.c:29-31`). |
| Sparse | MISSING | | Neither domain nor layout. |

## 7. Verification

| Item | Status | Evidence | Note |
|---|---|---|---|
| Tiers V0-V5 | PARTIAL | `src/omega_verify.h:8-15` | V3-V5 stubs. |
| V1 differential | IMPLEMENTED, exact u64 | `src/omega_verify.h:36-38` | Exact equality on (a,b,c) triples. |
| V2 | PARTIAL | `src/omega_verify.c:175` `(void)real;` | Ignores the realization. |
| CPU oracles | IMPLEMENTED | `src/omega_matvec.h:74`; `src/omega_blackwell_matmul.h:51-55` | u64 matvec; i32/f16/bf16 matmul (FP32 sequential accumulate). |
| GPU float parity | PARTIAL | `src/omega_blackwell_submit.c:655-663`; `src/omega_blackwell_gates.c:800-803` | Hard-coded `1e-4` absolute, not a declared contract. |
| Sanitizer builds | MISSING | Makefile, `mk/`, CI | No asan/ubsan anywhere. |

## 8. Benchmarks and energy meter

| Item | Status | Evidence | Note |
|---|---|---|---|
| Arm timing harness | IMPLEMENTED (test-side) | `tests/runtime/rx_empirical_optimizer.c:77-215` | Template for "run every verified realization, check oracle, time it". |
| Energy meter | IMPLEMENTED (test-side) | `rx_empirical_optimizer.c:345-371`; `tests/runtime/r15_measure.c:161-208` | hwmon device `aien_spbm`, `energyN_input`. Not a library. |
| ptrace instruction counter | PLANNED | `ternary:src/omega_ternary_measure.h:14-30` | Reusable harness utility. |
| CI | IMPLEMENTED | `.github/workflows/rx-host.yml` | Path filters; new files outside them need the filter extended. |

## 9. Evidence receipts

| Item | Status | Evidence | Note |
|---|---|---|---|
| Omega evidence writer | IMPLEMENTED, per-gate shape | `src/omega_evidence.h:48-74` | Run id, commit, dirty flag, physics commit, digest-named files. No shared schema file. |
| FORGE V2 ExecutionEvidenceV2 | PLANNED (type only) | `physics:forge/v2/forge_substrate_v2.h` | Mandatory `provenance_class`; no producer yet. Omega GPU runs do not emit V2 records. |
| `evidence-immutable.yml` | IMPLEMENTED | omega CI | Guards `evidence/`. |

## 10. FORGE v1 / v2 substrate model

| Item | Status | Evidence | Note |
|---|---|---|---|
| FORGE v1 types and seam | IMPLEMENTED, GB10-bound | `physics:forge/forge_types.h:18-76`; `forge_realize.h` | Submit takes `Nvrm *`. |
| v1 descriptor | IMPLEMENTED | `physics:forge/forge_descriptor.h:45-78`; `forge_descriptor.c:343` | Refuses any vendor except `0x10de`. No numeric-format or precision fields. |
| v1 lowering | PARTIAL (stand-in) | `physics:forge/forge_realize.c:66-80,230-296` | "Lowering simulation": copies IR bytes as code; submit only pushes a semaphore release. Never launches a compute kernel. |
| FORGE Substrate V2 | IMPLEMENTED, host-only data contract | `physics:forge/v2/forge_substrate_v2.h`; `docs/FORGE_SUBSTRATE_V2_SPEC.md` | Classes CPU/GPU/analog/neuromorphic/FPGA/optical; 0x8000+ reserved. Host gates re-run by the audit: 51 KAT + 6/6 PASS. |
| V2 representation axis | PARTIAL | `forge_substrate_v2.h:114-118` | INT, FLOAT, FIXED, analog voltage/current, spike, optical intensity/phase, plus bits. One input and one output repr per substrate record. No trit, residue, Z3, float sub-format, rounding mode or accumulator width. |
| V2 result contract | PARTIAL | spec §7, §14 Q3 | Error kinds EXACT/BOUNDED_DETERMINISTIC/BOUNDED_STOCHASTIC/MEASURED_DISTRIBUTION. No I/O type or algebra field; no ULP bound. |
| AR2 simulated provider | PLANNED | `docs/plans/analog-realization/ANALOG_REALIZATION_TEST_PLAN.md` | No code. |

## 11. Machine and Fabric

| Item | Status | Evidence | Note |
|---|---|---|---|
| Machine naming | IMPLEMENTED (doctrine) | ARCH-0002 | Machine 1, Machine 2; vendor is metadata. |
| OS-0010 Fabric identity and advertisement | PLANNED (Proposed) | aienos `603c91d` | Opaque `MachineId`; categories CPU, Memory, Accelerators, Models, Tools, Load. No numeric-format category. |
| Fabric code | MISSING | aienos tree | Plan §9 F5, after native networking. |
| ARGUS trust on join | IMPLEMENTED (ADR) | ARCH-0017 §2.4 | A joining Machine starts at "observed". |

## 12. Existing ternary work (parked)

Branch `experiment/ternary-semantics` `ae1e2a3`, spec says PARKED 2026-09-26. 18 files, +3719 lines, only shared file is the Makefile. Base `878275f` predates program id v2, cap64 and the `rx_*` runtime.

| Component | Kind | Status | Evidence | Note |
|---|---|---|---|---|
| T32 word, 11 ops, symmetric saturation | DATA | PLANNED, reusable | `ternary:src/omega_ternary.h:19-48`; `.c:24-30` | 32 balanced trits, range +/-926510094425920. |
| TritVec digit model, fast model, self-check | DATA | PLANNED, reusable | `.c:48-113,255,340` | TG1: 3,978,394 checks, 0 mismatches. |
| PLANES pack/unpack/valid | DATA | PLANNED, reusable | `.c:215-239` | See encoding below. |
| Tryte pack/unpack | DATA | PLANNED, reusable | `.c:416-456` | 5 trits per byte; bytes >= 243 and nonzero padding refused. |
| A64 INT and PLANES kernels | DATA (realization) | PLANNED, reusable | `ternary:src/omega_ternary_a64.h:16-24` | TG3 41 encodings vs GNU as oracle; TG4 336,000 native runs match. |
| OMG1 encode / id | SEMANTICS | PLANNED, not reusable as-is | `.c:406-509` | OMG0 grammar with magic byte 3 patched to `0x31` (`.c:491-499`). |
| TProgram id, verify, synth | SEMANTICS | PLANNED, never run | `ternary:src/omega_ternary_verify.h:14-35`; `omega_ternary_synth.h` | Parallel to pre-v2 identity. |
| Gate script | harness | BROKEN | Makefile `test-ternary` calls `tests/run_ternary_gates.sh` | File does not exist on the branch. |

**Encoding agreement (PLANES):** each trit uses one bit in a positive plane (low 32 bits) and one in a negative plane (high 32 bits). Per-trit code (pos, neg): `00` = 0, `10` = +1, `01` = -1, **`11` = invalid**, checked by `(pos & neg) == 0` (`ternary:src/omega_ternary.c:237-239`). The INT realization is the value as two's-complement int64. PLANES and INT produce the same OMG1 id; OMG1 ids differ from OMG0 ids.

## 13. Conflicts

1. **R16 status.** R16 was recorded COMPLETE and CLOSED (`aien-spark/omega#112` merged, `3dd5eaa`, receipt `22d7a79a...`); correction 2026-10-05: that is a historical PASS at `850fc54`, the receipt is INVALID as a current claim, requalification at `3108fc2` recorded R16 FAIL, and R16 is NOT requalified on CAND-0 (omega `evidence/REQUAL-3108fc2/`, `reports/L2-EVID.md`). The runtime-edit freeze on `omega/src/runtime/` is LIFTED.
2. **Three machine-identity shapes.** `CqCandidate.machine_id` is `uint32_t` (`src/runtime/rx_capq.h:107`); FORGE V2 `machine_identity` is 32 bytes; OS-0010 `MachineId` is opaque. Not reconciled (FORGE V2 spec §14 Q4).
3. **`rx_contract` is exact-only** (`rx_contract.h:75-99`); ADR 0018 §3.1 requires ULP, relative and distributional bounds.
4. **Program id v2 is scalar-u64-unary only** (`omega_program.h:43-53`); cannot name any tensor, float or residue op.
5. **OMG1 ids differ from OMG0 ids** for the same value; a new magic conflicts with "OMG0 stays canonical" unless the domain becomes data inside OMG0.
6. **physics main has 5 Python files** (`m2_build.py`, `run_milestone2_gates.py`, `generate_physics_audit.py`, `seam1_physics_audit.py`, `seam2_physics_harness.py`), against the no-Python rule.
7. **Cost-model widening breaks promoted models**: `RX_CM_OPS`/features change the serialized digest (`rx_costmodel.h:180`).
8. **Router precision is binary** (`rx_route.h:63`) and hardware-named.
9. **Stale doc counts and references.** ADR 0018 §11 and the analog plan say FORGE V2 has 47 KAT checks; the audit re-run counted 51. ADR 0018 header still calls ARCH-0017 "reserved, not yet on `main`" (it is merged).
10. **FORGE v2 digital fallback counts only DIGITAL_CPU/GPU** classes; an exact ternary FPGA would not qualify.
11. **Branch drift.** The ternary branch base is far behind main; PR #32 conflicts in codegen. Both need rebase before any reuse.

## 14. Seams for mixed-algebra

1. **Cost-model arms** (`rx_costmodel.h:57-171`): each algebra's realization of one op is an arm; needs `RX_CM_OPS > 1` and a per-op size feature.
2. **Empirical harness arm table** (`rx_empirical_optimizer.c:77-215`): run, oracle-check, time, read `aien_spbm`.
3. **Living kernel pattern** (`omega_matvec.h:12-89`, `omega_matvec_quad.h:20`): new realization kinds added out of file.
4. **Capability catalog** (`rx_capq.h:104-141`): a domain realization registers as a `CqCandidate`.
5. **Router** (`rx_route.h:61-91`): placement fields, to be replaced per ADR 0018 §15.
6. **Realization identity** (`omega_realize.h:21-24`; Blackwell four-part id `omega_blackwell_matmul.h:40-46`): encoding and format belong on the realization side.
7. **GPU submission** (`omega_blackwell_submit.c`; PR #32 `omega_gb10_execute_simt_op` if merged).
8. **Generation barrier** (`rx_generation.h`): how a learned selection becomes durable.
9. **FORGE V2 repr / result contract**: extension point for numeric formats, via the reserved-range rules in V2 spec §5.2.
10. **Overflow policy** (`omega_types.h:81-86`): already carries SATURATE for balanced ternary.

## 15. What ADR 0018 already settles

ADR 0019 extends ARCH-0018; it must not re-decide these.

1. OMEGA owns meaning, FORGE owns realization, AEGIS owns admissibility, AIEN gains no hardware authority (§2).
2. Semantic meaning never names device, vendor, bus or substrate family; same program, same identity everywhere (§2.1).
3. SemanticResultContract is Omega-owned, part of semantic identity, and carries I/O types, contract kind, abs/rel/ULP/distributional bounds, norm, oracle, confidence and samples (§3.1).
4. Four contract kinds; EXACT is default and never realized on a weaker substrate; undeclared uncertainty means EXACT only (§3.2, §3.3).
5. Calibration is FORGE-produced per substrate instance, content-addressed, bound into realization identity; stale means ineligible; recalibration never widens a contract (§4).
6. Evidence v2 is additive with `provenance_class`; no pointers across boundaries (§5).
7. Substrate access is an Aienux capability with 64-bit generations; no new loop, scheduler or service (§6).
8. Fabric transport is cost metadata; remote substrates are capability providers (§7).
9. Digital fallback is the eligible-set rule on the same contract digest, on any Machine (§14 Q7).
10. Substrate classes and V2 wire encodings (AR1, physics#16).

## 16. What ADR 0019 must answer

1. **Where an algebraic domain lives:** Omega type (semantic) or FORGE repr (realization), for wrapping 2^n, Z3/GF(3), balanced-ternary integer, residue sets, IEEE formats and reals-with-error.
2. **Trit: semantic domain or realization of Z?** Decides whether OMG1-style distinct ids survive, and saturation versus wrap semantics.
3. **Z3 versus balanced ternary**: which algebras are in scope and which ops are exact.
4. **Conversions**: explicit semantic ops with contracts, or FORGE-internal boundary ops; who proves round trips; where CRT reconstruction and overflow detection live.
5. **The fourth code** (PLANES `11`): stays invalid, or becomes a bottom/poison value with propagation rules; never publishable either way?
6. **Identity across algebras**: when an int8 and a BF16 matmul are the same operation; what enters `realization_id` (encoding, format, accumulation order).
7. **Per-domain error units**: ULP needs a declared float format; LSB units for integer, residue and ternary; tensor-core accumulation order.
8. **Quantization**: new program identity with a contract relative to the original, or a realization choice under a BOUNDED contract; who may promote it.
9. **Quantization scales and tables**: calibration artifacts, program constants or contract data.
10. **Advertising formats**: repeatable format field in V2 substrate records, or one record per format (max 8 per Machine).
11. **Cost and error axis** in the empirical model, replacing hardware-named routing.
12. **Machine 2 arrival**: which identity shape wins; whether an exact FPGA counts as digital fallback; phase-analog beyond OPTICAL_PHASE.
13. **Sparse**: domain or layout property.
14. **R16 freeze**: `CURRENT_EXECUTION_PLAN.md` must record the lift before Omega contract or type changes.

## 17. Spot-check log

Re-checked by hand on 2026-09-29 against the pinned commits; all matched the audits:
`rx_route.h:61,63`; `omega_program.h:41-53,117` and `visor_realization.c:437`; `omega_verify.c:175`; `rx_costmodel.h:37`; `omega_types.h:14,45-60`; `rx_capq.h:107`; `ternary:omega_ternary.c:237-239,445-456,491-499`; `ternary` Makefile `:127` missing script; `omega_blackwell_submit.c:655-663` and `omega_blackwell_gates.c:800-803`; `physics:forge_descriptor.c:343`; `physics:forge_realize.c:68`; `physics:forge_substrate_v2.h:94,114-118`; physics `.py` list; `CURRENT_EXECUTION_PLAN.md:45,540`; `ROADMAP.md:282` and Gate 5 row; ADR 0018 header ARCH-0017 wording and 47 KAT text. The only correction: audit A placed the GPU `1e-4` check in `omega_blackwell_gates.c` and audit B in `omega_blackwell_submit.c`; both are true (two separate checks), and both are listed.
