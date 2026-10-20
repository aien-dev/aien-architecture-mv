# Analog Realization — Test Plan (AR1–AR4)

**NOT A MASTER PLAN.** This is a finite workstream document for ADR 0018 (ARCH-0018, ACCEPTED, merged 641bd3c), substrate-neutral physical realization. `CURRENT_EXECUTION_PLAN.md` still owns cross-project sequencing (§6 C3, Lane 6), and `doctrine/ROADMAP.md` still owns milestone status. The AR-gates are ADR 0018 workstream gates, not M-milestones.

**Written:** 2026-09-29. Code facts come from three read-only audits of the commits below.

| Repository | Commit |
|---|---|
| omega | `main` `f308ac7` (live); file:line facts read at `8e7a445` (audit basis); `#60` merged `c0edef0` |
| physics | `main` `5969159` (live); `#13` merged `5969159`; `#16` merged `1f7c321` |
| aien-architecture | `main` `f6baa35` |

General rules for every gate: all code in C (plus assembly where measured); no Python; receipts are digest-named (`evidence/<AREA>/<sha256>.json`) and emitted by code, never hand-written; new code stays clean of the R16 loop-inventory patterns (see `ANALOG_REALIZATION_COLLISION_MAP.md` §4); no edits to `omega/src/runtime/` before R16 closes.

---

## AR1 — FORGE substrate-neutral descriptor contract

Location: physics#16, merged on main (`1f7c321`) following physics#13 (`5969159`) (`forge/v2/`, `tests/test_forge_v2_kat.c`).

| Test | Pass condition |
|---|---|
| V2 KAT | V2 descriptor and V2 evidence records serialize to fixed byte streams whose SHA-256 digests equal frozen literals. The stream begins with magic + version so it cannot be confused with the unversioned 208-byte v1 stream. All integers explicit little-endian. |
| v1 digest reproduction | The 208-byte v1 KAT stream, held as a literal byte array and hashed with physics `main:sha256_clean.c` `sha256_compute`, equals `10d63d05f888eaba4fe473c5f17febe22f462f543ae0c2b005a9a8e5417e09fd`. Hardware-free; no nvrm or NVIDIA headers linked. #13 merged (`5969159`): cross-check `forge_descriptor_run_kat() == 0` and `compute_digest(KAT descriptor)` equals the digest V2 wraps. |
| Wrap, not reserialize | V2 embeds the v1 identity only as an opaque 32-byte digest; `forge/forge_descriptor.c` is not included or linked. |
| Strict decode | Decoder refuses: wrong magic/version, truncated or over-long input, non-zero reserved bytes, unknown enum values, trailing bytes. Every refusal is a distinct error code. |
| Stale calibration refusal | A realization record bound to a calibration whose validity has expired, or whose conditions are outside the envelope, is refused as ineligible. |
| v1 generation refusal | A capability reference with a 32-bit (v1) generation is refused; 64-bit generations accepted (mirrors omega `EffectPayload` v2 behaviour). |
| Provenance explicit | Every V2 evidence record carries `provenance_class`; `SIMULATED_DEVELOPMENT` and `PHYSICAL` are distinct and a missing value is refused. A gate that requires `PHYSICAL` refuses `SIMULATED_DEVELOPMENT`. |
| No vendor names | No vendor or product identifier appears in V2 public type names or fields; vendor data exists only inside the opaque v1 record. |
| SHA-256 reuse | V2 links `sha256_clean.c` and declares `sha256_compute` in a V2-private header; no second exported SHA-256 symbol; `sha256_clean.c` unmodified. |

## AR2 — Analog simulation provider + digital oracle parity

Location: new files only (physics `forge/v2/` or a new non-runtime directory). Must not touch `omega/src/runtime/`.

| Test | Pass condition |
|---|---|
| Exact oracle | Simulated provider with all non-idealities disabled equals `omega_matvec_reference` (`src/omega_matvec.h:74`, exact uint64) bit-for-bit under an `EXACT` contract. |
| Tolerance oracle | With non-idealities enabled, results are compared against `omega_matmul_cpu_oracle_{i32,f16,bf16}` (`src/omega_blackwell_matmul.h:50-55`) under `BOUNDED_DETERMINISTIC` / `BOUNDED_STOCHASTIC` contracts with declared bounds (not the fixed `1e-4` of `omega_blackwell_submit.c`). |
| Injected non-idealities | Each injected separately and combined, with declared magnitudes: quantization, noise, bias, drift, saturation, temperature, latency, calibration age. For each: within-bound cases PASS; out-of-bound cases are **refused** by the contract check, never published. |
| Contract strictness | An `EXACT` contract is never satisfied by the simulated analog realization once any non-ideality is enabled (refused as ineligible, not degraded). |
| Fallback | When the simulated provider is refused, the digital realization produces the result under the same contract. |
| Provenance | Every receipt says `SIMULATED_DEVELOPMENT`. No receipt, log line or document describes a simulated result as physical. |

## AR3 — Calibration, uncertainty and evidence qualification

| Test | Pass condition |
|---|---|
| Calibration identity | Changing the calibration record changes the realization identity; the same calibration gives the same identity. |
| Staleness | Calibration past its validity, or conditions outside its envelope, makes the realization ineligible; recalibration restores eligibility with a new digest and new evidence. |
| Uncertainty propagation | The declared error model (bias, noise, quantization, drift, temperature coefficient) propagates to a predicted bound; the contract check uses the declared bound; a realization whose predicted bound exceeds the contract is not offered. |
| Evidence completeness | Every result record contains: substrate descriptor digest, calibration digest, contract digest and kind, measured error vs oracle, sample count, measurement conditions (temperature, clock/supply state where applicable, calibration age, load, latency), `provenance_class`. A record missing any field fails the gate. |
| Reproducibility | Receipts are emitted by code, digest-named, and a fresh-clone rerun reproduces every deterministic digest. |

## AR4 — First physical analog operation

Precondition: operator decision on a physical device; AR3 PASS; R16 closed.

Operation: matvec. Two realizations of **one** semantic program with **one** SemanticResultContract: the digital oracle, and the physical analog device.

| PASS criterion | How it is shown |
|---|---|
| Bounded error | Measured error vs oracle within the contract bound at the declared confidence. |
| Repeatability | Repeated runs within the declared spread. |
| Calibration bound | Fresh calibration digest bound into the realization identity; a stale one is refused in a negative test. |
| No authority bypass | Device access only through an Aienux capability with a 64-bit generation; a revoked or stale capability is refused. |
| Complete evidence | AR3 completeness check passes with `provenance_class` = `PHYSICAL`. |
| No vendor identity in the semantic program | The program, contract and World objects are byte-identical between the digital and analog runs; vendor data appears only in the FORGE substrate record. |
| Clean digital fallback | Disconnecting or refusing the device yields the digital result under the same contract. |
| Faulted device cannot corrupt the World | Injected device faults (wrong values, timeouts, out-of-envelope) produce refused results and evidence; no World publication occurs. |

## Dependency graph

```text
AR0 (ADR 0018 accepted, merged 641bd3c) - PASS
  └─► AR1 (V2 descriptor contract)      ◄── physics#13 merged (5969159), physics#16 merged (1f7c321) - PASS
        └─► AR2 (simulated provider)
              └─► AR3 (calibration/uncertainty/evidence)
                    └─► AR4 (physical analog matvec)   ◄── R16 closed (omega#68) + operator device decision
                          └─► AR5 (multi-substrate selection) ◄── omega#60 merged (c0edef0) + R16 closed
                                └─► AR6 (Fabric analog Machine) ◄── Fabric F5
                                      └─► AR7 (J-Space/RSI optimization) ◄── H3
Side constraint: any ARGUS telemetry work ◄── ARGUS perf gate decided (aienos#160 vs omega#70) + ABI v2
```

## Blockers

1. **AR0:** PASS (ADR 0018 accepted, merged 641bd3c; `aien-spark/aien-architecture`, `docs/adr/0018-substrate-neutral-physical-realization.md`).
2. **AR1:** PASS. `aien-spark/physics#13` merged on main (`5969159`, Gates 3 and 4 pass 11/11, 10/10); companion `aien-spark/physics#16` merged on main (`1f7c321`, 47/47 KAT + 6/6 PASS).
3. **AR2/AR3:** must not touch `aien-spark/omega` `src/runtime/` while `aien-spark/omega#68` (R16, draft `d73315e`) is open; new C code in physics/aienos/omega must stay clean of R16 inventory patterns.
4. **AR4:** R16 close (`aien-spark/omega#68` → `evidence/R16/<sha256>.json` on `main`); no physical analog device exists or has been chosen.
5. **AR5:** `aien-spark/omega#60` merged on main (`c0edef0`, merged at 2026-09-29T12:56:58Z); substrate axis and error field in `RxCmObservation` to follow post-R16.
6. **AR6:** Fabric (`CURRENT_EXECUTION_PLAN.md` Phase F5) not started.
7. **AR7:** RSI optimization loop (`CURRENT_EXECUTION_PLAN.md` Phase H3) not started.
8. **ARGUS telemetry:** performance gate disputed (`aien-spark/aienos#160` +6.2% vs `aien-spark/omega#70` +3.87%; 5% vs 2% bar undecided); `aien-spark/omega#70` `src/runtime/rx_argus.c` loops collide with R16 G2.
9. **Omega seams (post-R16):** `src/runtime/rx_route.h:61` `RX_COG_HW_*` bitmask must become substrate-neutral; `src/runtime/rx_contract.{h,c}` needs non-exact contract kinds.
