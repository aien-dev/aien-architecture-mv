# CAND-3 gates and evidence

CAND-3 is CAND-2 plus the omega changes #301, #304, #305, #306, #309, #312 and the
sovereign-core `omega.lock` bump to `f816473` (#218) and the rust toolchain pin (#216, closes gap G4 for sovereign-core) (see `CAND-3.toml` note). Frozen 2026-10-06. It supersedes CAND-2
(`CAND-2.toml` is not edited). Evidence lives on the Spark under `~/workspace/evidence-out/CAND3-*`. Statuses: PASS, FAIL,
NOT_RUN, BLOCKED_HARDWARE, BLOCKED_OPERATOR, BLOCKED_INSTRUMENT, MISSING_IMPLEMENTATION. "Host" means no chip; "QEMU"
qualifies nothing physical.

## 1. Clean-worktree builds (host only)

Script `~/workspace/cand3-campaign/cand3/cand3_build.sh` (copy in each evidence directory), run from two roots
(`~/workspace/cand3-campaign/cand3/rootA` and `.../rootB/deeper/path-two`); each root has its own detached worktrees at the CAND-3
commits and its own CARGO_HOME filled by `cargo fetch --locked`. Each item is built, hashed, deleted and built again (4 builds per
item). Evidence: `CAND3-BUILD-A/summary.txt`, `CAND3-BUILD-B/summary.txt`, `digests.txt` in each. Both verdicts PASS.
`cand3_compare.sh`: PASS, all 18 required artifacts identical from both roots.

| Item | Result |
|---|---|
| physics boot bins | identical in all four builds, equal to the committed files |
| omega omegatool and libomega_gpu.a | identical in all four builds, equal to CAND-2; the archive carries no gate objects (G6) |
| omega production and window executables (new in the manifest: rx_operator, rx_r13_living_host, rx_r13_living_silicon, rx_r13_living_testbuild_silicon, rx_r11_aien_test, rx_composition_gate_gpu, rx_r15_perf_silicon, rx_r15_perf_silicon_nodigest, r15_reduce) | each identical in all four builds |
| sovereign-core production config, `scripts/repro-build.sh` (toolchain from `rust-toolchain.toml`, 1.98.1) | aien-cli, aien-proof, aien-test identical in all four builds and equal to CAND-2; native engine linked; no home or cargo registry path in aien-cli (G13); zero-CUDA gate PASS |
| aienos C kernel core and full images | identical in all four builds and equal to CAND-2 |
| Pins | `check_candidate.sh` OK; `check_candidate_pins.sh` PINS AGREE (sovereign-core omega.lock f816473, Cargo.lock aien-protocols 7ac6fac, crumb-spec 24194d1, spark-crumbs 9355a92; omega physics.lock 6d7cf0d, aienos.lock bbad5e4, argus.lock b375dca). Consumed revisions, not heads (aien-protocols head 3a4cdbe and interplane main are not what the code consumes; interplane is pinned at its main 9129936) |
| crumb tool | omega and aienos `crumb.lock` pin aien-architecture `d0f0b95` (gap G3); `git diff d0f0b95 dcca843 -- tools/crumb` is empty |
| G4 toolchain | closed for sovereign-core: `rust-toolchain.toml` (sha256 887f9be0...1167) pins 1.98.1; C parts use the installed gcc 13.3.0 and binutils 2.42, unpinned |

Digest delta against CAND-2: none of the nine CAND-2 digests changed. The nine new entries are additions to the list, not changes.

## 2. Results carried from earlier candidates by executable identity (not rerun)

`docs/qualification/CANDIDATE.md` "Carry-forward of evidence by executable identity" (#143) governs what may carry. Its six rules:
(1) the executable's sha256 in this manifest equals the earlier frozen manifest's, to the bit; (2) every input unchanged, and a gate's
own test binary shown byte-identical; (3) same environment class, labelled "carried from CAND-N by executable identity (not rerun)" with
the earlier candidate id and receipt sha256; (4) no change of gate script, harness or thresholds; (5) BLOCKED, NOT_RUN, FAIL and
NOT_QUALIFIED carry only as the same status; (6) silicon performance (R15) never carries.

Rule 1 evidence: `CAND3-BUILD-A/digests.txt` against `CAND-2.toml [executables]`: omega-runtime 5a308427, omega-gpu-engine-lib a4af0881,
aien-cli-native-release 3a17ee79, aien-proof a37247a1, aien-test 34ae31e5, aienos-boot-image 8b1595cc, aienos-ck-core-image a21218dc,
physics-boot-bin 4b22a08c, atlas-m2-boot-bin 1d6d75a6: all nine identical. `cand3_carry_check.sh` (evidence `CAND3-CARRY-79a805d`) rebuilt at the CAND-2 code
commit 79a805d with the CAND-3 recipe: omegatool, libomega_gpu.a and r15_reduce IDENTICAL; rx_r13_living_host and _silicon,
rx_r13_living_testbuild_silicon, rx_r11_aien_test, rx_composition_gate_gpu, rx_r15_perf_silicon and _nodigest CHANGED.
The CAND-2 rx_r11_aien_test rebuild (37c15f75) equals the digest recorded in the CAND-2 window, which supports the check's method.

| Area | Gate | Status | Basis |
|---|---|---|---|
| Native model | strict real-model gate; Omega vs CPU reference; Omega vs HF oracle; paged_attention_batch; runtime e2e; daemon; zero CUDA | PASS, carried from CAND-1 by executable identity (not rerun) | Rule 1: aien-cli, aien-test and libomega_gpu.a identical. Rule 2: model inputs unchanged (`[model]`). Rule 3: same GB10 machine class; earlier receipts in omega `evidence/CAND1-AUDIT-20261005` (SHA256SUMS): `CAND1-NATIVE-2eec75b/receipt-strict-gate.json`, `receipt-omega-vs-ref.json` and `receipt-omega-vs-oracle.json` all sha256 83a64387...; `paged_batch_gb10.log` 6e35de35...; `CAND1-BUILD-2eec75b/zero-cuda.log` 4347852c...; `forge-logs/CAND1-NATIVE-e2e-rerun-063201.log` 20696559...; `daemon_positive.log` 76b0266d.... Rule 4: these gates are run by aien-test and sovereign-core `scripts/`; `git diff 2eec75b 80e071a -- scripts` is empty, and sovereign-core changed only `.github/workflows/hardening.yml`, `crates/aien-replay/mutations/run_mutants.sh`, `omega.lock` and `rust-toolchain.toml` (none is one of these gates); thresholds are in the identical aien-test binary |
| Attention | GB10 attention timing, TinyLlama shape, 100 calls, 3 runs | PASS, carried from CAND-1 by executable identity (not rerun) | Rules 1-2: libomega_gpu.a identical; `tests/gpu_attention_test.c` and `src/omega_gpu_attention_api.h` unchanged 79a805d..f816473 (`git diff` over both files is empty), and `gpu_attention_test` rebuilt at both commits in one path (physics 6d7cf0d, `make build/ab/gpu_attention_test`, 2026-10-06, host only) is byte-identical, sha256 `e28bf26ba59df829436101dbc94bd98716f837c5e3b065c994240353c8274299`, with `libomega_gpu.a` `a4af088104203c9ce1b92b6787f140d822a8039ac86349a0438fb7a379c0fc5c`, the same digests as CAND2-ATTN-IDENTITY (record CAND3-ATTN-IDENTITY, published with the window evidence). Rule 3: same GB10 machine class; earlier receipts in omega `evidence/CAND1-QUIET-AUDIT-20261005`: `CAND1-WINDOW-20261005T1252Z/ATTN-timing-1/timing.json` 6cd0010a..., `-2` 2fc553ff..., `-3` bf12fdad.... Rule 4: the gate is the test binary itself (`gpu_attention_test --out`), its 3.0 ms bound compiled in; the binary is identical |
| Aienux | ck_gates (QEMU): 18 PASS, 2 MISSING_IMPLEMENTATION; TRUST-1 M5 NOT_QUALIFIED; M4_CONTINUITY, M4_RECOVERY, M4_ALLEN, M4_STORE_CRASH (QEMU) | same statuses, carried from CAND-1 by executable identity (not rerun) (rule 5: NOT_QUALIFIED and MISSING_IMPLEMENTATION carry only as themselves) | Rule 1: both aienos images identical. Rules 2 and 4: aienos pin bbad5e4 unchanged since CAND-1, so the gate scripts, harness and thresholds are the same files. Rule 3: same QEMU environment class; earlier receipts in omega `evidence/CAND1-AUDIT-20261005`: `CAND1-CKGATES-bbad5e4/ck_gates_654d4445...json` (sha256 654d4445..., covers ck_gates and the four M4 gates) and `CAND1-TRUST-bbad5e4/trust1_m5_qualification_37f6a233...json` (sha256 37f6a233...) |

| M18, M19 / CHIPWAIT | matmul gates; 3 x M19R | carry-eligible (omegatool identical, tools unchanged) but rerun in the window so the receipts name CAND-3 | - |
| R16, R13, R11, COMPOSITION-2, production hygiene | all | NOT carried: executable CHANGED or gate script changed (rule 4: `r16_qualify.sh` changed in #309) | carry check |
| R15 | silicon performance | NOT carried (rule 6) | - |

## 3. Results rerun on CAND-3

Not yet run. The window is declared in `DECLARED-ATTEMPTS.md` (sha256 recorded when published) and its results are added here after it,
as CAND-2.gates.md section 3. Attempts: A1 R16 ladder with G6 operator control (host, mutants, silicon), A1b R11, A2 R13 test build,
A3 production hygiene, A4 COMPOSITION-2 GPU, A5 CHIPWAIT 3/3, A6 M18. A7 R15 is NOT ATTEMPTED in that window.

## 4. What CAND-3 does not prove (known before the window)

- **R15 / R16 G7:** the SPBM energy reader is not loaded; R15 is not attempted in the first window; G7 needs an R15 PASS. R15 is a separate later attempt.
- **R16 G6:** exercised by execution only if the window's A1 says so; effects already outside the world when a stop lands and a same-uid deletion of the halt mark while no program runs are not covered (`docs/r16-operator-control.md`, omega #309).
- **G8** is the merge-commit step, outside the script.
- **Aienux:** no USB keyboard driver in the C kernel; C loader A/B and rollback parked (MISSING_IMPLEMENTATION). Every Aienux result is QEMU.
- **TRUST-1 M5:** attended hardware boots and owner-key ceremonies blocked on the operator; Secure Boot is off.
- **Toolchain:** G4 closed for sovereign-core (`rust-toolchain.toml`); gcc and binutils are not pinned.
- **CHIPWAIT:** each soak is 100,000 cycles in about 41 to 43 s, not hours of endurance.
- **Known intermittent host failures** under heavy load (omega #313): R13 mode-E wall-clock goal check, mutant-suite log loss, R13 failure reason only on stderr. The window declares full capture and no retry of a FAIL.
- **Open omega PRs not in CAND-3:** #310 (GPU reconvergence), #303, #307 (prime race).

## 5. Results of the qualification window (added 2026-10-06; nothing above changed)

Two windows were declared; section 3 above is left as written. **W1** (`CAND3-LIVING-f816473`) is **INVALID**: every lane
stopped before any test because the per-root worktrees had not been set up (the orchestrator's defect). It is kept
unchanged and counts as no result. **W2** was declared separately before it ran (`DECLARED-ATTEMPTS.md` sha256
9f4b8b91...f184 and `DECLARED-ATTEMPTS-w2.md` ef42d9c8...2ba1), under quietlock hold q57951-1791251173-2972b958,
2026-10-06T01:46:13Z to 02:09:58Z, at omega code f816473, harness 97ee275 (map-only descendant), physics 6d7cf0d.
Each attempt ran once; no FAIL was retried.

| Attempt | Gate | Result on CAND-3 (W2) |
|---|---|---|
| A1 | R16 ladder | NOT_RUN overall, as declared: G1 to G6 PASS, G7 NOT_RUN (no R15 acceptance receipt), G8 NOT_RUN (merge-commit step) |
| A1/G6 | operator emergency control by execution | **PASS**: host, mutants (25, 0 failures) and silicon in the same run; both binaries match the double build |
| A1b | R11 living under load | PASS: checks 436, failures 0, living run exercised (A725 to X925) |
| A2 | R13 test build on silicon | PASS, receipt candidate_bound true, tree_dirty false |
| A3 | production hygiene on silicon | PASS |
| A4 | COMPOSITION-2 on the GPU | PASS, failures 0 |
| A5 | M19 / CHIPWAIT, 3/3 rule | PASS: 3 usable, 0 invalid, 0 failed (each soak about 41 to 43 s, not endurance) |
| A6 | M18 matmul gates | PASS: 18/18 |
| A7 | R15 silicon performance | NOT_RUN: not attempted (declared); SPBM energy reader not loaded |
| A8 | correctness reruns for carried results | none needed (declared): section 2 rests on identical executables |

Xid count 0 before and after every step.

Published evidence, original bytes, immutable, in omega `evidence/` at a7e626a (omega #316):
[`CAND3-BUILD-A`](https://github.com/aien-dev/omega/tree/a7e626a55f39b94a60393c66805b6a9496940e3c/evidence/CAND3-BUILD-A), [`CAND3-BUILD-B`](https://github.com/aien-dev/omega/tree/a7e626a55f39b94a60393c66805b6a9496940e3c/evidence/CAND3-BUILD-B),
[`CAND3-ATTN-IDENTITY`](https://github.com/aien-dev/omega/tree/a7e626a55f39b94a60393c66805b6a9496940e3c/evidence/CAND3-ATTN-IDENTITY), [`CAND3-CARRY-79a805d`](https://github.com/aien-dev/omega/tree/a7e626a55f39b94a60393c66805b6a9496940e3c/evidence/CAND3-CARRY-79a805d),
[`CAND3-LIVING-f816473`](https://github.com/aien-dev/omega/tree/a7e626a55f39b94a60393c66805b6a9496940e3c/evidence/CAND3-LIVING-f816473) (W1, INVALID),
[`CAND3-LIVING-f816473-w2`](https://github.com/aien-dev/omega/tree/a7e626a55f39b94a60393c66805b6a9496940e3c/evidence/CAND3-LIVING-f816473-w2) (W2, with `CLAIM-INDEX.md`), and
[`CAND3-AUDIT-20261006`](https://github.com/aien-dev/omega/tree/a7e626a55f39b94a60393c66805b6a9496940e3c/evidence/CAND3-AUDIT-20261006) (index, commands, `ORIGINAL-SHA256SUMS` of 527 originals taken
before copying, `SHA256SUMS` of the published set, 10 compiled programs left out by the CAND-1 convention with their digests).

Independent reconstruction (2026-10-06, reviewer working only from the published files): 13 of 14 claim rows agree.
The one disagreement is a count: the claim index names two R13 receipts with gate FAIL written by mutated copies;
there are three (015915Z, 015956Z, 020018Z, binaries 5ff99c0c..., 4259b1f7..., 1c612eef..., none a production
binary, all inside the mutant run). Corrected additively in `PUBLICATION-NOTES.md`; no verdict changes.

Limits found in the window, which change no result: mutant runs write receipts into the real `build/qual-runs`
(omega #314); the R11 receipt file is not kept, the pass rule reads exit code and stdout (omega #315); CHIPWAIT
`hashes.sha256` checks fail only for the three unpublished ELF files.

**Verdict: CAND-3 is NOT QUALIFIED overall. R15 is pending** (needs the SPBM energy reader, an operator step), and
with it R16 G7; G8 follows the merge commit. G6 operator emergency control is proven by execution on the candidate,
including silicon, for the first time. Physical Aienux boot, owner-key ceremony and TRUST-1 hardware qualification
stay BLOCKED_OPERATOR; every Aienux result is QEMU.

omega #303, #307 (prime race) and #310 (GPU reconvergence) merged after the freeze; they are not part of CAND-3.

## 6. A7c: R15 silicon and the R16 G7/G8 attempt (added 2026-10-06; nothing above changed)

Declared before it ran in `DECLARED-ATTEMPT-A7c.md` (sha256 70824bb8b6c116a72a047c61e424169338b7dc8eb0ded9c8b65260e73ecdeec9; script `cand3_r15c.sh`
sha256 cdbff59d5ac40acf90da47ada9f4e7d985957db4a6d1a3828f98fdbe14013005). Run once each, under quietlock owner cand3-campaign with Drake's approval token, on
omega code f816473, harness 97ee275, physics 6d7cf0d, aienos bbad5e4, boot of 2026-10-06 11:32Z. The W2 rows for A7 (NOT_RUN) and R16 G7/G8 (NOT_RUN) in section 5 stay as written.

| Attempt | Result |
|---|---|
| A7c R15 silicon | **PASS.** Receipt outcome PASS (`90fdebb8...fdd`, schema AIEN_RX_R15_REACTION_PERFORMANCE_V1; the same raw run without notes is `1b525c90...6224`): 16 of 16 gates, 0 failed processes, 0 Xid, candidate-bound, clean tree, silicon observed, 13 correctness reruns PASS. G2 throughput RES-1/SEQ 1.066, G5 p50 7392 ns / p99 9952 ns, G9 net energy per operation RES-1/SEQ 0.880, G10 3.0 vs 4.0 synchronization events, G15 residency 1.0, X925 clock 3.897 GHz in the preflight |
| R16 G7 | **NOT_RUN.** R15 acceptance part PASS, but ladder rung R11 was NOT_RUN: its living part refused at 1-minute load 2.11 (limit 2). Every other rung PASS. Not rerun; a replacement is a new declaration |
| R16 G8 | **NOT_RUN.** Needs the PR merged with a merge commit; none exists. The script reports its receipt preconditions as met |
| R16 G1-G6 (observed again) | PASS |

**Stated deviation:** Secure Boot was OFF for this run (Drake's decision), against R15 spec clarification C2 (Secure Boot and integrity lockdown stay on). The signed SPBM reader
loaded with "module verification failed: signature and/or required key missing - tainting kernel", so the kernel was tainted. **Machine conditions:** other users' boot-time services were
resident and not stopped (atlas image server holding 18408 MiB GPU memory at 0 % utilisation, a caption server, a MAX Llama serve, two auto-restarting services). The run is reported as measured.
**Receipt limit:** spec section 11 regression itemisation is not in the receipt (said in its notes); the gates are all PASS. **UNVERIFIED:** which process raised the load above 2 for R11; that every restart resets the energy counter.

CAND-3 stays NOT QUALIFIED as a whole: R16 needs a G7 attempt with R11 exercised, and the G8 merge step.

Published evidence (original bytes): omega `evidence/CAND3-LIVING-f816473-A7c/` (omega #317, head a39e44a): [`CAND3-LIVING-f816473-A7c`](https://github.com/aien-dev/omega/tree/a39e44a0029d63a93b090c7bdc783f5582f4683a/evidence/CAND3-LIVING-f816473-A7c).

**Note 2026-10-06 (afternoon; nothing above changed):** the A7c R15 PASS is classified CONDITIONAL, a measured PASS under a declared deviation from C2, in `qualification/exceptions/0002-r15-secure-boot-off.md`. It is NOT unconditional compliance and must not be cited as C2-conformant. It becomes compliant only by a new declared R15 silicon run with Secure Boot ON and the reader module signed by an enrolled key (no kernel taint). Changing machine security settings needs Drake's authorization.

## 7. G7b: replacement attempt of R16 G7 (added 2026-10-06; nothing above changed)

Declared before it ran in `DECLARED-ATTEMPT-G7b.md` (sha256 80c411806d1f628f2e722c5ab31331a1d78718b48f0fce9b3b52193f649d680b), a new attempt that replaces nothing recorded in section 6 (A7c stays as written). Reason: A7c G7 was NOT_RUN only because the R11 living part refused at 1-minute load 2.11; afterwards Drake approved turning off all other AI models (record `~/workspace/r15-practice/ai-services-off-20261006.txt`) and the GPU had no compute apps. Run once, under quietlock owner cand3-campaign (20 minutes), started at 1-minute load 0.72 (14:05:16Z), never killed, on omega code f816473, harness 97ee275, physics 6d7cf0d, aienos bbad5e4. R15 was not rerun: the A7c receipt `90fdebb8bd2c8ff988c6d93afb764c3466bd6c3575cd8176fc605378fdb53fdd` was consumed by the R16 script.

| Gate | Result |
|---|---|
| R16 G7 | **PASS.** Every rung R1-R15 PASS, including R11 living (exercised this time), and the R15 acceptance receipt accepted. Run took 845 s; Xid count 0 |
| R16 G8 | **NOT_RUN.** Needs the PR merged with a merge commit (spec section G8); none exists and none was invented. The script reports its receipt preconditions as met |
| R16 G1-G6 (observed again) | PASS |

R16 receipt (untracked by the script, kept in the evidence): `9dfb29957368bcc0acd8ac600f55efdd4ec31221d44ea4e52fbcf987b3cc4adc.json`. The script's overall line is NOT_RUN because G8 is NOT_RUN.

**Stated deviation:** Secure Boot is OFF (Drake's decision), against R15 spec clarification C2; the R15 receipt consumed here carries that same deviation (section 6). **UNVERIFIED:** which process raised the A7c load above 2; that every restart resets the energy counter.

CAND-3 is still not R16-complete: G7 is PASS, G8 (merge commit) remains.

Published evidence (original bytes): omega `evidence/CAND3-LIVING-f816473-G7b/` (omega #318).

## 8. R16 G8 and the CAND-3 verdict (added 2026-10-06; nothing above changed)

Section 7 is closed. The merge-conflict markers that #148 left in section 7 on main were removed in this PR (section 6 note and section 7 both kept, no wording changed).

**R16 G8: PASS.** R16-G8 is defined in omega `spec/r16-orchestrator-retirement.md`, gate table row R16-G8: the receipt is `evidence/R16/<sha256>.json`, named by the SHA-256 of its own bytes, schema `AIEN_RX_R16_ORCHESTRATOR_RETIRED_V1`, committed unchanged; candidate_commit == run_commit; candidate_bound true; tree_dirty false; silicon_observed true; the PR is merged with a merge commit, not squash. Checked 2026-10-06 against GitHub:

| Item | Value |
|---|---|
| Receipt | omega `evidence/R16/9dfb29957368bcc0acd8ac600f55efdd4ec31221d44ea4e52fbcf987b3cc4adc.json`; sha256 of its bytes equals its file name; bytes equal the copy committed by omega #318 under `evidence/CAND3-LIVING-f816473-G7b/R16-G7/raw/receipts/` |
| PR | omega #319, merged 2026-10-06T14:52:30Z |
| Merge commit | `6500517017e6ac10e4f46f1723a311ac37684c03`, 2 parents (merge commit, not squash) |
| schema / schema_revision | AIEN_RX_R16_ORCHESTRATOR_RETIRED_V1 / 2 |
| candidate_commit, run_commit | both `97ee27584cda0d8eaca136f31a44293cd36c9b02` (the R16-map-only descendant of the pinned omega `f816473`, per `CAND-3.toml`) |
| candidate_bound, tree_dirty, silicon_observed | true, false, true |
| Gates in the receipt | R16-G1 to G7 PASS; R16-G8 NOT_RUN (the script cannot see the merge, `g8_scope` says so); r15_acceptance_still_passing true |

The receipt's own G8 field and its overall line stay NOT_RUN because the merge-commit step is outside the script (section 4). The receipt is not edited. The G8 conditions are met by the merge of #319 as listed. R16 G1 to G8 are therefore all PASS on CAND-3, G7 from section 7 and G8 from this section.

**CAND-3 verdict (2026-10-06, after G8), by this document's own rule.** Sections 5 and 6 held CAND-3 at NOT QUALIFIED because R15 was pending, R16 G7 was NOT_RUN and the G8 merge step was missing. All three are now cleared. This document defines no status called QUALIFIED, so none is invented. Stated exactly:

**CAND-3: R16 COMPLETE (G1 to G8 PASS). R15 is a CONDITIONAL PASS under declared exception 0002 (Secure Boot was OFF, against R15 clarification C2; `qualification/exceptions/0002-r15-secure-boot-off.md`); it is not C2-conformant. The "not qualified" condition of sections 5 and 6 is lifted for R15, G7 and G8 only. A full-candidate QUALIFIED status is NOT asserted, because section 4 lists what CAND-3 does not prove and those items stand: Aienux results are QEMU only, TRUST-1 M5 NOT_QUALIFIED and its hardware boots and owner-key ceremonies BLOCKED_OPERATOR, USB keyboard driver and C loader A/B and rollback MISSING_IMPLEMENTATION, CHIPWAIT is not endurance, gcc and binutils unpinned.** Milestone status in `doctrine/ROADMAP.md` is not changed by this record.
