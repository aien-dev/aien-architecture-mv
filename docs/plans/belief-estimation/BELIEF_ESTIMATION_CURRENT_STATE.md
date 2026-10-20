# Belief Estimation - Current State

**NOT A MASTER PLAN.** This is a finite workstream document for ADR 0020 (ARCH-0020), the belief / estimation layer. `CURRENT_EXECUTION_PLAN.md` owns sequencing and `doctrine/ROADMAP.md` owns milestone status. Nothing in this document is a milestone.

**Written:** 2026-09-30, before any estimation code existed. Facts come from three read-only audits of the commits below. Code was read; README and spec claims were not taken as evidence. Nine claims were re-checked by hand (section 7).

| Repository | Commit |
|---|---|
| aien-spark/omega | `6b9d4b7` (main; `b608dff` after a docs-only merge during the audit) |
| aien-spark/aien-architecture | `ede9f16` |
| aien-spark/aienos | `f0facc7` |
| aien-spark/physics | `f63a6ef` |

Status words: IMPLEMENTED, PARTIAL, EXPERIMENTAL, PLANNED, MISSING, CONFLICTING, OBSOLETE. "Host reference" means C code exercised by tests but not wired into a live service.

## 1. Headline

- No belief state, state estimate, covariance, innovation or Kalman code exists in any of the four repositories (grep for `kalman`, `covariance`, `innovation`, `BeliefState`: zero hits). The layer is **MISSING** and must be built.
- Three existing pieces already do part of the job and must be reused, not shadowed: the Omega cost model (a Bayesian predictor with calibrated intervals), the TURING PRD1 prediction file plus qint.v1 scorer (a predicted Gaussian per held-out point, scored in bits), and the TURING CAL-0 freeze and blinding machinery.
- R16 was recorded CLOSED (correction 2026-10-05: historical PASS at `850fc54` only; requalification at `3108fc2` recorded R16 FAIL; NOT requalified on CAND-0; omega `evidence/REQUAL-3108fc2/`): gates G1-G8 passed then, PR #112 merged (`3dd5eaa`), receipt `evidence/R16/22d7a79a985514ac38139d39c71c9638d9b6b0a6e05425b6810bdb4833d1ea64.json` recorded. The `src/runtime/` edit hold is lifted, so R16 no longer blocks EST-4; EST-4 and EST-5 stay blocked on calibration (next line).
- Calibration (2026-10-05): v5 ended **HELD_OUT_FAIL** on its sealed held-out run (section 10); EST-3 stays FAILED, EST-4 and EST-5 stay blocked, and no estimator output may be treated as calibrated.

## 2. Concept inventory

| Concept | Status | Where | Note |
|---|---|---|---|
| Observation as typed evidence | PARTIAL | aienos `native/argus/argus_abi.h:218-237` (128-byte ARGUS event, evidence_digest, logical tick, no wall clock); FORGE v2 `forge/v2/forge_substrate_v2.h:328-355` (EXPERIMENTAL, reference model only) | Events are security observations, not numeric measurements with declared noise. |
| Belief / state estimate | MISSING | none | |
| Covariance / uncertainty with declared units | MISSING (as a state quantity) | | Uncertainty exists only as the per-prediction fields below. |
| Prediction distribution | IMPLEMENTED (two narrow forms) | omega `src/runtime/rx_costmodel.h:79-88` (`RxCmPrediction`: mean and sd of log2 ps, Student-t dof, `fail_p` Beta posterior mean, point energy); `src/turing/ty_prd.h:1-4` (PRD1: per index u32 family, f64 loc, f64 scale, Gaussian only) | Neither carries a state vector or covariance. |
| Innovation / residual | MISSING as a type | | TURING scores code length, not residuals. |
| Normalized surprise | MISSING | | |
| Transition / observation model identity | MISSING | | Cost model identity is its blob digest (`rx_costmodel.c:422-443`, magic OGCM v1). |
| Estimator | PARTIAL | cost model is a conjugate Bayesian regression per (cell, arm), `rx_costmodel.h:21-28` | Static regression, not a dynamic state estimator. |
| Calibration of stated uncertainty | IMPLEMENTED (cost model); IMPLEMENTED (engine confidence) | `rx_cm_calibrate`, `rx_costmodel.c:385-411` (split conformal on held-out residuals, needs 10+ points); `rx_route.h:68,120` (`RxCogCalibration`, per-bin hit rate of an engine's stated confidence) | Both are reusable patterns for EST-3; neither calibrates a dynamic estimate. |
| Calibration protocol, freeze, blinding | IMPLEMENTED | omega `calibration/` (CAL-0, PR #92): `BLINDING_PROTOCOL.md`, `scripts/freeze_receipt.sh`, `schemas/*.json`, independent-scorer rule | The statistic (code length vs baseline) does not transfer; the freeze and blinding machinery does. |
| Evidence root / digest | PARTIAL | `src/omega_evidence.h` (write-once content-addressed files under `build/qual-runs/<run>/`); `src/turing/ty_qrecord.h:10` (digest = SHA-256(domain, 0x00, bytes)) | No single evidence-root type. ARCH-0020 adopts the TURING domain-separated digest rule. |
| World generation, staleness | IMPLEMENTED | `src/runtime/rx_world.h:292-316` (per-field version and writer), `:172` (`RxObjRef{id,generation}`), `rx_world.c:1180-1195` (stale read refused at publish) | World objects hold eight u64 fields and no doubles (`rx_world.h:34`), so a covariance cannot live in one object. EST-4 decides the encoding. |
| External input path into World | IMPLEMENTED | `rx_world_publish_external`, `rx_world.h:604-608` (capability required) | Natural entry for observations in EST-4. |
| State Projection with uncertainty | PARTIAL | `rx_projection.h:78` (NONE / POINT / INTERVAL request), `:137-143` (count, sum, sumsq, min, max) | `PJ_OP_PREDICT` exists as a label only (tests use it). |
| Uncertainty transport | CONFLICTING (wording) | `rx_semcomm.h:26`: "Omega does not estimate uncertainty. A type may declare one field as its producer's uncertainty" | Not a real conflict: an estimator is a producer. ARCH-0020 records that the estimation layer is that producer and that semcomm stays a transport. |
| Read-only observation tap | MISSING | ARGUS rings are single producer, single consumer; `argus_ring_pop` consumes (`argus_abi.h:506`) | An estimator must never pop a producer ring. A live feed needs a second, read-only ring filled by the ARGUS consumer (EST-4 scope). |
| Estimator isolation from authority | IMPLEMENTED pattern | omega `Makefile:716-720` (`nm -u` refusal for the cost model); aienos `argus_contain.c:293` (containment only on DETERMINISTIC confidence) | No numeric confidence reaches authorization today. One injection point exists: `AienosContainAuthorizer.decide` (`aienos_contain.h:223-227`). Record as a watch item. |
| J-Space | IMPLEMENTED (host reference), not wired | omega `src/runtime/rx_jspace.c/.h`; spec `docs/06-jspace.md:50-62` (separate score dimensions incl. uncertainty, Pareto filter) | `docs/02-implementation-status.md:35` (dated 2026-09-23) still says no implementation. Discrepancy recorded. |
| Cortex | IMPLEMENTED (host reference), not wired | omega `src/runtime/rx_cortex.c/.h` (`CX_OBSERVATION` class, protection bits `rx_cortex.h:38-50`) | |
| TURING T unit, held-out scoring | IMPLEMENTED | omega `docs/turing/TURING_YIELD_PROFILE_V0.md:21-29`; `src/turing/ty_qcont.h`; records `turing.q*.v0` | qworld (`ty_qrecord.h:64-77`) has no evidence-root field; adding one needs a v1 domain. |
| Information-gain experiment selection | PLANNED | `doctrine/DISCOVERY.md:273-274,335` | No code. |
| Physics Zero prediction needs | PLANNED | `doctrine/DISCOVERY.md:222-233` (`UNCERTAINTY_MODEL`, `PREDICTIVE_SCORE`), ROADMAP M29 "calibrated prediction" | This layer supplies the machinery; it is not Physics Zero. |
| Evolution Arena | PLANNED (spec only) | `docs/specs/EVOLUTION_ARENA_SPEC_V1.md` | No prediction or uncertainty dimensions; header still says PROPOSED and still calls omega #68 a draft (:8, :39). Stale. |
| FORGE physical evidence | IMPLEMENTED v1 (duration + success only); EXPERIMENTAL v2 | physics `forge/forge_types.h:66-76`; `forge/v2/forge_substrate_v2.h:192-207` | v2 has temperature, energy with MEASURED / ESTIMATED source, confidence_ppm. No v2 records on disk. |
| Effect Broker | IMPLEMENTED but CONFLICTING | aienos `crates/aienos-aegis/src/broker.rs:113-194` (Rust) | Conflicts with the recorded C-target decision; out of scope here. |
| Aienux physical sensors | MISSING | | Thermal, power and clock sampling exists only as Omega test tooling. |

## 3. Candidate real signals (EST-2)

| Signal | Source | Samples | Evidence binding | Verdict |
|---|---|---|---|---|
| CPU thermal zone 0, 1 Hz | omega `evidence/R15/raw/20260929T020536Z-ad8e1f2ea4e4-silicon/machine-state.ndjson` and `.../20260929T025735Z-3e9e53be3358-silicon/machine-state.ndjson` (fields `t`, `thermal_mc` x7, `spbm_uj`, `busy`, `gpu`) | 1953 and 2009 lines, one continuous series each, max gap about 1.13 s | each run's `raw/SHA256SUMS`, bound to the R15 receipt `raw_digest_sha256` | **Chosen.** Two independent runs give a natural fit / held-out split. Load marks exist in `machine-state-marks.txt`. Produced by shell tooling (`tools/r15_machine_state.sh`), no Python. |
| Machine power (differenced `spbm_uj`) | same files | same | same | Second candidate; cumulative counter must be differenced. |
| 10 Hz telemetry (`power_uw`, `nvml_mw`) | R15 per-trial `.jsonl` | about 225 samples per trial segment | same | Rejected for EST-2: short disjoint segments. |
| `research/r14-failure-modes/.../machine-1hz.log` | | 607 lines, 45 gaps over 3 s | none | Rejected: not digest-bound. |

Honesty note: both runs were recorded on 2026-09-29, before this workstream existed. Their summary statistics had not been examined for estimation purposes when the EST-3 protocol was frozen, but the data are not blind in the CAL-0 sense. EST-3 therefore treats run B as held-out and reports it as "pre-existing, unexamined" evidence. A fresh collection after the freeze is the stronger test and is listed as EST-3b.

## 4. Doctrine lines that need tightening (ARCH-0020 section 6)

- `AIEN.md:534` "Observations are immutable ground truth": the observation **record** is immutable; the measured value is evidence with noise.
- `AIEN.md:533` claims "tagged with Bayesian confidence scores": such a score never grants authority or promotion.
- `doctrine/ARCHITECTURE.md:55,160` Cortex "maintains continuous world models" / "records world state": live estimates belong to the estimation layer and World; Cortex keeps epistemically significant events only.
- `doctrine/ARCHITECTURE.md:75` "receipts record ground truth": scoped to measurements, not estimates.
- ARCH-0018 AR3 (`docs/adr/0018-...:204`) owns substrate calibration and uncertainty. ARCH-0020 estimates dynamic state; AR3 characterizes substrates. An AR3 calibration artifact may be an observation-noise input to an estimator model; neither replaces the other.

These are recorded here, not edited, because `doctrine/` changes need their own reviewed change.

## 5. What must not be duplicated

- Cost-model uncertainty (EST-5 extends `RxCmPrediction`, does not add a second cost model).
- PRD1 and qint.v1 (EST-6 emits PRD1 predictions for held-out observations and lets TURING score them).
- CAL-0 freeze and blinding (EST-3 reuses `freeze_receipt.sh` style receipts).
- World generations (EST-4 reuses `RxObjRef` generation and field versions for staleness).
- The `nm -u` authority-isolation check (copied, not reinvented, in `mk/estimation.mk`).

## 6. Watch items

1. `AienosContainAuthorizer.decide` accepts a pluggable verdict function; a probability-based authorizer could be injected there. ARCH-0020 forbids it.
2. ARGUS `STATISTICAL` confidence class is reserved for ARGUS-5; it must not be fed by estimator output without a separate decision.
3. `docs/02-implementation-status.md` is a week stale on J-Space and Cortex.
4. `EVOLUTION_ARENA_SPEC_V1.md` activation hold still names omega #68 as a draft.

## 7. Claims re-checked by hand

| Claim | Result |
|---|---|
| `rx_semcomm.h:26` says Omega does not estimate uncertainty | confirmed |
| PRD1 header and record layout (`ty_prd.h:1-4`) | confirmed |
| `rx_cm_calibrate` at `rx_costmodel.c:385` | confirmed |
| machine-state.ndjson line counts 1953 / 2009 and field names | confirmed |
| `evidence/R16/` holds final receipt `22d7a79a...` and full qualification logs | confirmed |
| cost-model `nm -u` check at `Makefile:716-720` | confirmed |
| `mk/turing_qcont.mk` standalone pattern, `-ffp-contract=off` | confirmed |
| digest rule SHA-256(domain, 0x00, bytes) at `ty_qrecord.h:10` | confirmed |
| No kalman / covariance / innovation / BeliefState hits in omega, aien-architecture, aienos | confirmed |

## 8. Calibration record (update 2026-10-01, omega `d78fd11`)

Three frozen calibration attempts exist. All three FAILED. Each record is kept as evidence; none is overwritten.

| Attempt | omega record | Verdict | Fault, from forensics |
|---|---|---|---|
| v1 (EST-3) | #105, `docs/estimation/receipts/est23-v1/` | FAIL | Estimator: heavy tails and volatility clustering (excess kurtosis 5.4). Not bias or overall variance (mean NIS 1.02). |
| v2 | #118 (`8a56ace`), `receipts/est23-v2/` | FAIL at C1 pre-check | Experiment: 100 mC quantization, 80 % exact-zero changes on a quiet machine. |
| v3 (EST-3c) | #129 (`d78fd11`), `receipts/est3c-v3/` | FAIL at Phase A; sealed run NOT_RUN | Best family (adaptive-scale Student-t, quantization-aware) met every one-step rule in sample but failed ten-step 95 % coverage (0.809, band 0.90-0.99). D1 multi-step changes are persistent (variance ratio at 10 steps 2.14); the independent-increment horizon rule cannot represent it. |

- v3 protocol: `docs/estimation/EST3C_PROTOCOL_V3.md`, sha256 `2f6393320eb632214afa4db7b6a79f3c14ceec4a2b570c459e115c3f5634eade`, frozen at omega `4b079ed`. Binding params `docs/estimation/receipts/est3c-v3/params.txt` (sha256 `6be9c829...174026`, tool commit `93b3579`, clean tree). Forensics: `docs/estimation/EST3C_FORENSICS.md`.
- The held-out set D2 was never collected, so no held-out outcome has been seen. A successor is a new protocol version with fresh fit and sealed data, and needs a model of change persistence. No v3 refit or rescore is allowed.
- Implemented in omega: `src/estimation/est_pred.{h,c}` (discrete quantization-aware predictive layer, five candidate families behind one contract) with hostile tests; fit/eval tools in `tools/estimation/est3c_*`.
- **EST-4 (World belief state) and EST-5 (uncertainty-aware cost model): NOT_RUN, blocked on a PASSING calibration.** No estimator output may be treated as calibrated.

## 9. Calibration record v4 (update 2026-10-01, omega `6ff7c30`)

v4 ends **INCONCLUSIVE**. All three data collections the frozen protocol allows were voided because other work ran on the Spark inside the measurement windows, so v4 gives no calibration verdict. EST-3 stays FAILED (v1-v3 above). Record: omega #153 (`6ff7c30`), `docs/estimation/receipts/est-v4/RESULT.md`.

- Protocol `docs/estimation/protocols/est-v4.md`, sha256 `7baff66f1baf13f648b38ea04516b423e34e4c4b4d7528701f15272ca441f116`, frozen at omega `1a147e4`, unchanged. Three families with a persistence-aware horizon law: G1 first-order lag, G2 AR change, G3 two-tank. Tool `tools/estimation/est4*` (C), bound at build time to commit, protocol and data hashes.

| Attempt | Seeds D1 / D2 | Phase A | Sealed run | Why void |
|---|---|---|---|---|
| 1 | 0xE5C4D1 / 0xD2E5C4 | PASS (G1) | PASS | Another lane's multi-core host builds/tests and a QEMU run in both windows; host tests at ~10:05Z in D2 |
| 2 | 0xE5C4D2 / 0xD2E5C5 | PASS (G1) | PASS | A ~2-min host build in D2; foreign builds and single-core tests seen in both windows |
| 3 | 0xE5C4D3 / not collected | not run | NOT_RUN | A foreign host test suite started 4 s after the quiet flag was taken; fails the validity standard fixed before attempt 3 |

- The PASS numbers of attempts 1 and 2 (G1 held-out cov95 0.9476 and 0.9570, ten-step cov95 0.9321 and 0.9534) are on record only and are **not** evidence of calibration. Each void was decided on machine load alone, and voiding never moved a result toward PASS.
- Finding for a v5 (from the contamination record, not tuning): the blocker is measurement isolation, not the model. Keep the v4 families and rules; change only the collection to a machine-enforced exclusive window (host builds and tests refuse while the flag is held, or an operator-reserved slot), with the "no foreign build or test" rule written into the frozen protocol.
- **EST-4 and EST-5: still NOT_RUN, blocked** (v4 section 10 unblocks them only on a v4 PASS). No estimator output may be treated as calibrated.

## 10. Calibration record v5 (update 2026-10-05, omega `30c65a3`)

v5 ends **HELD_OUT_FAIL**. The sealed held-out run D2 was collected once in a clean window and scored once; the selected family was not calibrated on it. EST-3 stays FAILED (v1-v3), v4 stays INCONCLUSIVE. Record: omega #170 (merged `30c65a3`), `docs/estimation/receipts/est-v5/RESULT.md`, receipt `receipt-7f0bb7018d066bc438e7a8a9bf87c0d45615f60be2d029b6ab5194168e3db3d1.json`, tag `est-v5-d2-heldout-fail` (`14fc76a`).

- Protocol `docs/estimation/protocols/est-v5.md`, sha256 `275cd5b72570d5182ef73d635e16775026e9d911e818b8e12f8300a701187af5`, frozen at omega `b37e34b`, unchanged. v5 kept the v4 families and rules and changed only window protection (section 9's finding).
- D1 (2026-10-01): `WINDOW_CLEAN samples=1317 foreign=0` on the second attempt; Phase A PASS, G1 (first-order lag) selected; params sha256 `6be2b579980f22b48d8224b36dec39b6154cc82c15a85979291672b2c5c2aa3a`.
- D2 (2026-10-05 11:28:38Z, seed `0xD2E5C6`): `WINDOW_CLEAN samples=1312 foreign=0`, pre-check VALID; raw data and `d2.sha256` committed (`eec20d2`) before the single `est5 recorded` run.
- Score on 2651 steps: G1 mean one-step log score -1.80307, ahead of E0 (-2.10541) and F1 (-2.97852). G1 passed 22 of 23 gated statistics (coverage50 0.533, coverage80 0.822, coverage95 0.953, PIT bins 1-9, quarters, regimes, ten-step, bias, lag-1) and failed one: PIT bin 0 = 0.0681 against the band 0.07-0.13. One failed gated statistic means not calibrated (protocol section 6), so the verdict is HELD_OUT_FAIL. The small margin is description only.
- Finding for a v6 (from the receipt, not tuning): window isolation now works (both v5 windows clean), so the open issue is back in the model; the lowest PIT tenth is under-filled (too much predictive weight on low temperatures). A v6 needs its own frozen protocol, fit and sealed held-out run; nothing in v5 may be re-scored or retuned.
- **EST-4 and EST-5: still NOT_RUN, blocked.** No estimator output may be treated as calibrated.
