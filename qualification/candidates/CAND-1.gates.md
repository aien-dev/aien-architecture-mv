# CAND-1 gates and evidence

CAND-1 is CAND-0 plus the 2026-10-05 overnight fixes (see `CAND-1.toml` note). Frozen 2026-10-05T05:35Z.
Evidence lives on the Spark under `~/workspace/evidence-out/CAND1-*`. The campaign ledger is
`~/handoffs/2026-10-05-overnight-campaign.md`. Published copies (immutable, with SHA256SUMS): omega `evidence/CAND1-AUDIT-20261005` (omega #288) and `evidence/CAND1-QUIET-AUDIT-20261005` (omega #292), whose `INDEX.md` maps each claim below to its artifact. Statuses: PASS, FAIL, NOT_RUN, BLOCKED_HARDWARE,
BLOCKED_OPERATOR, MISSING_IMPLEMENTATION. "Host" means no chip; "QEMU" qualifies nothing physical.

## 1. Clean-worktree builds (host only)

Script `~/workspace/overnight-1005/C1/cand1_build.sh 2eec75b...` (copy in the evidence directory). Each item is
built, hashed, deleted and built again. Evidence: `CAND1-BUILD-2eec75b/summary.txt`. Verdict PASS.

| Item | Result |
|---|---|
| physics boot bins | both runs equal each other and the committed files |
| omega `all libomega_gpu` | omegatool and libomega_gpu.a identical across runs; the archive has no omegatool or gate objects (G6) |
| sovereign-core, production config, `scripts/repro-build.sh` | aien-cli, aien-proof, aien-test identical across runs; native engine linked (`has_omega_gpu`); no home-directory or cargo registry path in aien-cli (G13); no spark-max crate compiled (G7) |
| Zero-CUDA gate on aien-cli | PASS (self-test first) |
| aienos C kernel core and full images | identical across runs |
| omega link check at cb06d08 | libomega_gpu.a, gpu_matmul_api_test and the COMPOSITION-2 GPU binary build (`CAND1-BUILD-cb06d08`) |

## 2. Gate results on CAND-1

| Area | Gate | Status | Evidence / notes |
|---|---|---|---|
| R16 | G1/G2 loop inventory, every repo at its CAND-1 commit | PASS | 513 sites, 0 unclassified, 0 stale, no WARN; `CAND1-R16INV-cb06d08` (before the SC-126..129 rows: 4 unclassified, FAIL, kept) |
| CI | GitHub checks on the CAND-1 commits | PASS | omega cb06d08 39 success, 2 skipped (map-only 80ca5d4: 30 success, 11 skipped), aienos 14/14 (2 skipped), interplane 8/8, sovereign-core 1/1 (Workspace Verification & Invariant Audit). Rechecked 2026-10-05 with all result pages; the CAND1-AUDIT-20261005 finding F6 ("28 success") read only the first page of 30 and is wrong |
| Aienux | ck_gates (QEMU) | 18 PASS, 0 FAIL, 2 MISSING_IMPLEMENTATION | `CAND1-CKGATES-bbad5e4`; KEYBOARD (no xHCI/USB HID driver in the C kernel), M0_ROLLBACK (C loader A/B parked) |
| Aienux | TRUST-1 M5 qualification | NOT_QUALIFIED: 20 PASS, 11 BLOCKED, 5 MISSING_IMPLEMENTATION, 1 FAIL (fix needs an operator action) | `CAND1-TRUST-bbad5e4`; the FAIL is `t1_gate7_preflight`: Secure Boot is off on this machine (operator setting since 2026-10-01), so the preflight correctly refuses |
| Native model | strict real-model gate (TinyLlama, GB10, production build, 0 fallback) | PASS | `CAND1-NATIVE-2eec75b/receipt-strict-gate.json` |
| Native model | Omega vs own CPU reference | PASS | `receipt-omega-vs-ref.json` |
| Native model | Omega vs independent HF oracle | PASS | step-0 max abs logit difference 0.0435 against bound 0.15, same token; `receipt-omega-vs-oracle.json` |
| Native model | native paged_attention_batch, 3 sequences decoding together | PASS | `paged_batch_gb10.log`: ran on chip with >= 2 sequences per call, 0 fallback, 0 chip errors; a skipped body would fail the step |
| Native model | runtime e2e on chip | PASS | rerun with the same binary: both tests pass (`runtime_e2e_gb10-rerun.log`). The first run refused only because the batch script set AIEN_REQUIRE_RELEASE without AIEN_CHECKPOINT_ID (script defect, fixed: the label now names the test fixture weights); every functional check had passed |
| Native model | daemon serves a turn; refuses to start without a checkpoint | PASS | `daemon_positive.log`, `daemon_missing_checkpoint.log` |
| Native model | zero CUDA (script self-test, dynamic deps, symbols, strings) | PASS | `zero_cuda.log` |
| Living runtime | R16 harness `tools/r16_qualify.sh` (omega 80ca5d4, code = cb06d08) | NOT_RUN overall: G1-G5 PASS; G6 MISSING_IMPLEMENTATION; G7 FAIL (derived); G8 NOT_RUN | `CAND1-LIVING-cb06d08/R16-ladder`. G6 per-item checks now exist (omega #287, 12 items) but one item, operator emergency controls, has no implementation, so G6 cannot pass. The recorded run said G7 NOT_RUN (no R15 receipt supplied); the script passes G7 only with an R15 receipt whose outcome is PASS, and the only CAND-1 R15 acceptance receipt is FAIL (section 2a), so G7 is FAIL by that rule, not by a new R16 run. G8 is the merge-commit step outside the script |
| Living runtime | R1-R10, R12-R14 host and silicon, R15 parity host and silicon | PASS | same run; receipts copied to `qual-runs-after-R16/` |
| Living runtime | R11 living under load | PASS (on tree 81efb09, source-equivalent; not bound by the receipt) | quiet window 2 (section 2a): living run exercised, 436 checks, 0 failures, receipt `R11-living/receipt/.../rx_aien_faculty_receipt.json` in `CAND1-WINDOW2-20261005T1259Z` (run_commit 81efb09, tree clean; the receipt has `candidate_bound: false`, so its tie to CAND-1 is the source equivalence in section 2a, not a field in the receipt). In window 1 it refused its own quiet hold (NOT_RUN, harness defect fixed by omega #286) |
| Living runtime | R15 performance acceptance | FAIL | quiet window 2, declared binding before the result: 13 of 16 gates PASS; G15 GPU residency 0.849 against 0.99 (one of 58 processes stalled); G9 energy and G16 metrics FAIL because the energy reader (SPBM driver) is not loaded since the 2026-10-03 reboot, so 17 metrics are missing (instrument absent, BLOCKED_OPERATOR to restore). Receipt `R15-silicon/receipt/f3c77266...json` |
| Attention | GB10 attention timing, TinyLlama shape, 100 calls | PASS | quiet window 1, CAND-1 tree 80ca5d4: medians 1.24, 1.21, 1.18 ms against 3.0 ms, 0 violations, worst scaled error 0.0032. Under the shared load before the window the same check read about 5.78 ms |
| Living runtime | R13 test build on silicon, candidate bound | PASS | receipt `candidate_bound: true`, `candidate_commit: 80ca5d4...`, `silicon_observed: true` (unbound at CAND-0) |
| Living runtime | production hygiene on silicon | PASS | ARGUS linked and observing; refuses to run unobserved |
| Living runtime | COMPOSITION-2 GPU tier | PASS | 14/14 steps, chip failures 0 (FAIL at CAND-0: link error, fixed by omega #283) |
| Living runtime | CHIPWAIT campaign, 3 runs | PASS | `CAND1-LIVING-cb06d08/CHIPWAIT`, mechanical verdict PASS, failed [] |
| Living runtime | M18 full qualification | PASS | 18/18 gates, `CAND1-LIVING-cb06d08/M18` |
| Continuity | identity and memory restored after interruption (QEMU): M4_CONTINUITY, M4_RECOVERY, M4_ALLEN cold restore, M4_STORE_CRASH | PASS (QEMU only) | `CAND1-CKGATES-bbad5e4`; physical restore on Machine 1 is BLOCKED_HARDWARE (attended boots) |
| INTERPLANE | trust gates with exit codes, injection coverage by name, empty and partial runs refused | PASS (offline gates) | interplane #48, #49 at 5330a1c; gate M on main is the interplane owner's run after its campaign |

## 2a. Quiet windows of 2026-10-05 (how the chip timing results bind to CAND-1)

Both windows ran under an exclusive `quietlock` hold (no other GPU or build job; flag owner, start and end in each
window's `00-identity` and `99-identity`). The compiled candidate did not change: every fix made during the
campaign is harness, test or tool code (`git diff cb06d08 <harness commit> -- src physics.lock aienos.lock` is
empty), so there is no CAND-2 and no old result is relabelled.

| Window | Tree run | Binding to CAND-1 | Results | Evidence |
|---|---|---|---|---|
| 1, 12:52Z | omega 80ca5d4 (the CAND-1 chip tree) | is CAND-1 (map-only descendant of cb06d08) | attention timing PASS 3 of 3; R11 NOT_RUN (refused its own hold); R15 INVALID (harness preflight crashed on SMMU cycle lines, no trial ran) | `CAND1-WINDOW-20261005T1252Z` |
| 2, 12:59Z | omega 81efb09 = cb06d08 plus the omega #286 harness fixes (branch `cand2/cand1-harness-overlay`) | no difference in `src`, `physics.lock`, `aienos.lock`; the R15 executables are byte-identical to the CAND-1 build | R11 PASS; R15 FAIL (binding) | `CAND1-WINDOW2-20261005T1259Z` |

Harness fixes found by these windows: omega #286 (R11 recognises its own hold; R15 preflight counts CPU cycles only),
omega #290 (the R15 sampler no longer leaves a 24 h `sleep` holding the quiet flag).

## 3. What CAND-1 does not prove (remaining gaps)

- **R15 performance acceptance FAILED** (section 2a), so R16 G7 fails with it. Two separate causes:
  the energy reader is not loaded, so energy (G9) and the metrics set (G16) cannot be measured (restoring it means
  loading a signed kernel module, an operator action); and one trial process in 58 lost the GPU in about 15 % of its
  liveness samples (16348 of 19253 live, trial SEQ-06; G15 = 0.849). The seat, sampler and reducer code is the same as in the 2026-09-29 runs that
  scored 1.0. The cause of the one stall is not established; a later diagnostic run cannot replace this verdict.
- **R16 G6:** per-item checks exist (omega #287) but operator emergency controls have no implementation
  (MISSING_IMPLEMENTATION), so G6 cannot pass. **G8** is the merge-commit step, outside the script.
- **Aienux** has no USB keyboard driver in the C kernel and the C loader A/B and rollback are parked (MISSING_IMPLEMENTATION).
- **TRUST-1 M5:** 11 gates need attended hardware boots or operator ceremonies; 5 have no implementation; the
  Gate 7 preflight refuses because Secure Boot is off on this machine (operator setting). Not qualified.
- **Physical machine:** every Aienux result is QEMU. Nothing here qualifies the Spark booting Aienux.
- **Contract pins in the manifest are wrong** (found 2026-10-05 by `scripts/check_candidate_pins.sh`). `CAND-1.toml`
  `[contracts]` pins the crumb-spec and spark-crumbs heads (`10b8251`, `98bb7cb`); the sovereign-core `Cargo.lock` at
  `2eec75b` consumes `24194d1` and `9355a92` (two commits behind each head, the revisions CAND-0 pins). The built
  executables used the consumed revisions, so the digests are unaffected; the manifest line is wrong. A frozen
  manifest is not edited; CAND-2 pins the consumed revisions.
- **Path independence** tested 2026-10-05 by a build at a second checkout path (`CAND1-PATH2-2eec75b`): 8 of 9
  executables reproduce the CAND-1 digests, including aien-cli. omegatool (`omega-runtime`) does not: it embeds the
  physics checkout path in three strings (control: the second-path omega checkout built with the physics path set
  back to the original reproduced the CAND-1 digest, so that path alone makes the difference). FAIL for
  omegatool; fixing it changes the binary and needs a new candidate.
- **Clean reconstruction** 2026-10-05 (`CAND1-RECON-2eec75b`): fresh `git clone` of all four repos from GitHub at the
  CAND-1 commits, a new CARGO_HOME filled by `cargo fetch --locked` (cold: the
  fetch downloaded 487 crates; the script does not itself check that the directory was empty), then the same double build. Same result as
  the second path: 8 of 9 match the CAND-1 digests and each item builds identically twice; omegatool differs only by
  the embedded physics path. So the candidate rebuilds from the public GitHub sources (with this machine's toolchain), except omegatool.
- **EST v5 D2** ran 2026-10-05 (clean window) and scored HELD_OUT_FAIL (PIT bin 0 = 0.0681, below 0.07; 22 of 23 statistics passed). It ran from omega branch `lane44/est-v5` and measures the machine's temperature forecasting, not the CAND-1 build, so it is not a CAND-1 gate result. Record: `docs/plans/belief-estimation/BELIEF_ESTIMATION_CURRENT_STATE.md` section 10.
