# CAND-2 gates and evidence

CAND-2 is CAND-1 plus the 2026-10-05 cand3 campaign fixes (see `CAND-2.toml` note). Frozen 2026-10-05T17:57Z. It
supersedes CAND-1 (`CAND-1.toml` is not edited). Evidence lives on the Spark under
`~/workspace/evidence-out/CAND2-*`. The campaign ledger is `~/handoffs/2026-10-05-cand3-campaign.md`. Statuses:
PASS, FAIL, NOT_RUN, BLOCKED_HARDWARE, BLOCKED_OPERATOR, BLOCKED_INSTRUMENT, MISSING_IMPLEMENTATION. "Host" means no
chip; "QEMU" qualifies nothing physical.

## 1. Clean-worktree builds (host only)

Script `~/workspace/cand3-campaign/cand2/cand2_build.sh` (copy in each evidence directory), run twice, from two
roots: `~/workspace/cand3-campaign/cand2/rootA` and `~/workspace/cand3-campaign/cand2/rootB/deeper/path-two`. Each
root has its own detached worktrees at the CAND-2 commits and its own CARGO_HOME, empty before
`cargo fetch --locked` (root A's fetch log lists the downloads). Each item is built, hashed, deleted and built
again. Evidence: `CAND2-BUILD-A/summary.txt`, `CAND2-BUILD-B/summary.txt`. Verdict PASS for both.

| Item | Result |
|---|---|
| physics boot bins | identical in all four builds and equal to the committed files |
| omega `all libomega_gpu` | omegatool and libomega_gpu.a identical in all four builds; the archive has no omegatool or gate objects (G6) |
| sovereign-core, production config, `scripts/repro-build.sh` | aien-cli, aien-proof, aien-test identical in all four builds; native engine linked (`has_omega_gpu`); aien-cli carries the native backend string; no home-directory or cargo registry path in aien-cli (G13) |
| Zero-CUDA gate on aien-cli | PASS in both roots (self-test first) |
| aienos C kernel core and full images | identical in all four builds |
| **Path independence** | PASS: all nine digests are the same from root A and root B. CAND-1's omegatool FAIL (embedded physics checkout path) is closed by omega #296 |
| Pins | `scripts/check_candidate.sh` OK; `scripts/check_candidate_pins.sh` PINS AGREE (sovereign-core omega.lock and Cargo.lock, omega physics/aienos/argus locks, every known consumed pin) |
| crumb tool | omega and aienos `crumb.lock` pin aien-architecture `d0f0b95`; `git diff d0f0b95 7390f5d -- tools/crumb` is empty (gap G3 unchanged: different commit, same tool source) |

Eight digests equal CAND-1's: omega-gpu-engine-lib, aien-cli-native-release, aien-proof, aien-test, both aienos
images and both physics bins. Only omega-runtime (omegatool) is new.

## 2. Results carried from CAND-1 by executable identity (not rerun)

CANDIDATE.md freeze rule 3 reruns the results a change affects. These CAND-1 results ran executables whose CAND-2
digests are byte-identical, at inputs that did not change; they are carried, labelled as such, and their receipts
still name CAND-1. They are not new runs.

| Area | Gate | CAND-1 status | Why it carries |
|---|---|---|---|
| Native model | strict real-model gate; Omega vs CPU reference; Omega vs HF oracle; paged_attention_batch; runtime e2e; daemon; zero CUDA | PASS | aien-cli, aien-test and libomega_gpu.a digests identical; same model inputs |
| Attention | GB10 attention timing, TinyLlama shape (quiet window 1) | PASS | gpu_attention_test is built from `tests/gpu_attention_test.c`, `src/omega_gpu_attention_api.h` and libomega_gpu.a; the two sources are unchanged cb06d08..79a805d and CFLAGS lost only `-DOMEGA_PHYSICS_DIR` (#296), which neither file uses. Measured: built at cb06d08 and at 79a805d in the same worktree, the binary is byte-identical (sha256 e28bf26b...4299) and so is libomega_gpu.a (evidence `CAND2-ATTN-IDENTITY`, host build only) |
| Aienux | ck_gates (QEMU): 18 PASS, 2 MISSING_IMPLEMENTATION | as CAND-1 | aienos images identical |
| Aienux | TRUST-1 M5: NOT_QUALIFIED | as CAND-1 | aienos images identical; the attended steps are still blocked on the operator |
| Continuity | M4_CONTINUITY, M4_RECOVERY, M4_ALLEN, M4_STORE_CRASH (QEMU only) | PASS (QEMU) | aienos images identical |

## 3. Results rerun on CAND-2 (omegatool changed)

Every living-runtime result ran omegatool or binaries built from the changed omega tree, so none carries. They ran in
one quiet window, 2026-10-05 18:04:14Z to 18:23:25Z, under `quietlock hold` (owner cand3-campaign), from the
map-only harness commit c62f47b (code-identical to 79a805d) and physics 6d7cf0d, under declared attempts:
`DECLARED-ATTEMPTS.md` sha256 `8a6e06dac775ed2e5c17b3a5c5ba96d80f457654803755f00c840110a56585cf`, announced before
the window. Each attempt ran once; nothing was rerun or replaced. Evidence: `~/workspace/evidence-out/CAND2-LIVING-79a805d/`;
its `CLAIM-INDEX.md` ties every claim below to a file copied under its sha256 in `receipts/`. An independent reader (its notes are the
"Conditions and limits" section of `CLAIM-INDEX.md`) re-derived every status from the raw files before this page
changed and agreed with each one.

| Attempt | Gate | Status | Evidence (sha256 prefix) |
|---|---|---|---|
| A1 | R16 harness `tools/r16_qualify.sh` | **not PASS** (R16_QUALIFY_RESULT=NOT_RUN): G1-G5 PASS; G6 MISSING_IMPLEMENTATION (11 of 12 items PASS, the operator emergency stop is not wired into the production program); G7 NOT_RUN (no R15 PASS exists); G8 outside the script. G6 and G7 were expected in the declaration | receipt `40742fde` |
| A1b | R11 living under load | PASS: 436 checks, 0 failures, living run exercised (work moved from Cortex-A725 to Cortex-X925, AIEN noticed, Omega re-realized); load 1.09 at start | log `1ba30ea2` |
| A2 | R13 test build on silicon, candidate bound | PASS (`candidate_bound` true, tree clean) | receipt `220b5256` |
| A3 | production hygiene on silicon | PASS (link map clean, ARGUS linked and observing, refuses to run unobserved) | log `eeaecad7` |
| A4 | COMPOSITION-2 GPU tier | PASS | receipt `06fa0b05` |
| A5 | CHIPWAIT campaign, 3 runs of M19R full mode | PASS 3/3: each run 18/18 M19 gates, 157/157 regression gates, long soak 100000 cycles passed. Limit: each soak is 41 to 43 s of chip time; it meets the written criterion, it is not hours of endurance. The run files carry no commit; binding rests on the command line and snapshots | verdict `147a7652`, runs `28a74464`, `bb174c40`, `77d12724` |
| A6 | M18 full qualification | PASS: 18/18 M18 gates (36 evaluated with the regression gates) | log `7317ef22` |
| A7 | R15 silicon performance acceptance | NOT_RUN, harness defect: the window's r15 lane never built the R15 programs (absent after the chipwait lane). Not an instrument refusal and not a performance result | `R15-silicon/run-dir-progress.log` |
| A7b | R15 silicon, declared after A7 and before it ran (`DECLARED-ATTEMPT-A7b.md` sha256 `f56a97d6`), rebuilt then run once at 18:26Z | BLOCKED_INSTRUMENT: no `aien_spbm` hwmon (the signed SPBM reader is not loaded), as declared. R15 is not PASS, so R16 G7 cannot pass | `A7b-R15/` |
| - | INTERPLANE offline gates, GitHub checks at the pinned commit 2049968 | PASS: 9/9 check runs completed success, 17:57Z to 17:59Z (read from GitHub at 18:06Z; not copied into the evidence directory) | GitHub check runs at 2049968 |

Machine conditions: Xid count 0 before and after every step. Present throughout and not stopped (not ours): another
account's idle GPU process (18408 MiB) and an idle ollama server with no model loaded. 1-minute load 0.60 to 2.42.

**CAND-2 verdict:** not qualified. Every rerun gate that can pass did pass (R11, R13, production hygiene,
COMPOSITION-2, M19 3/3, M18), but R16 cannot pass while G6 is missing and R15 cannot run without the SPBM energy
reader (operator action).

## 4. What CAND-2 does not prove (known before the window)

- **R16 G6:** the operator emergency stop exists in the runtime (omega #300, host-tested, 13 mutants) but the
  production program does not wire it and has no operator entry point, so the item reads MISSING_IMPLEMENTATION and
  G6 cannot pass. No silicon run exercises a stop. **G8** is the merge-commit step, outside the script.
- **R15 / R16 G7:** the SPBM energy reader is not loaded (operator action: load the signed module, steps in
  `~/handoffs/2026-10-05-spbm-energy-operator-steps.md`). R15 refuses to start (omega #295, BLOCKED_INSTRUMENT), so
  G7, which needs an R15 PASS, cannot pass. CAND-1's R15 FAIL (G15 residency 0.849 from one stalled trial, SEQ-06)
  is unexplained; a 30-trial diagnostic later saw 100 % residency in every trial, which is a clue, not a verdict.
- **Aienux:** no USB keyboard driver in the C kernel; C loader A/B and rollback parked (MISSING_IMPLEMENTATION).
- **TRUST-1 M5:** attended hardware boots and owner-key ceremonies are blocked on the operator; Secure Boot is off.
- **Physical machine:** every Aienux result is QEMU. Nothing here qualifies the Spark booting Aienux.
- **Toolchain:** no rust-toolchain file pins the compiler (gap G4); both roots used the same installed toolchain.

## 5. Published evidence (added 2026-10-05 after publication; nothing above changed)

The original bytes of the four Spark directories are published, immutable, in omega `evidence/` at
c8463fd (omega #304), following the CAND-1 convention (#288, #292):

| Spark directory | Published copy |
|---|---|
| `CAND2-BUILD-A` | [`evidence/CAND2-BUILD-A`](https://github.com/aien-dev/omega/tree/c8463fdd8b834a713500344f34d6fb2e94c233f6/evidence/CAND2-BUILD-A) |
| `CAND2-BUILD-B` | [`evidence/CAND2-BUILD-B`](https://github.com/aien-dev/omega/tree/c8463fdd8b834a713500344f34d6fb2e94c233f6/evidence/CAND2-BUILD-B) |
| `CAND2-ATTN-IDENTITY` | [`evidence/CAND2-ATTN-IDENTITY`](https://github.com/aien-dev/omega/tree/c8463fdd8b834a713500344f34d6fb2e94c233f6/evidence/CAND2-ATTN-IDENTITY) |
| `CAND2-LIVING-79a805d` | [`evidence/CAND2-LIVING-79a805d`](https://github.com/aien-dev/omega/tree/c8463fdd8b834a713500344f34d6fb2e94c233f6/evidence/CAND2-LIVING-79a805d) |

[`evidence/CAND2-AUDIT-20261005`](https://github.com/aien-dev/omega/tree/c8463fdd8b834a713500344f34d6fb2e94c233f6/evidence/CAND2-AUDIT-20261005)
holds the index (each claim to its file), `SHA256SUMS` of the originals taken before copying,
`PUBLICATION-NOTES.md` and the list of compiled programs left out by the CAND-1 convention (sizes and
digests recorded). A7 (R15 NOT_RUN, harness defect) and A7b (R15 BLOCKED_INSTRUMENT) stay separate. CHIPWAIT:
each soak is 100,000 cycles in about 41 to 43 seconds, not an endurance run; its run files carry no commit field,
so its link to CAND-2 is through the recorded commands, binary hashes and machine snapshots.

Independent reconstruction (2026-10-05, reviewer working only from the published files): all 13 statuses in §1
to §3 agree with this page; `sha256sum -c` passes for all 530 listed files; 20 random files match the Spark
originals byte for byte; no existing evidence file was changed.
