# CAND-0: build recipe, reproducibility gaps and required gates

Manifest: `qualification/candidates/CAND-0.toml` (schema `CandidateManifestV1`, spec `docs/qualification/CANDIDATE.md`).
Written by lane L1-CAND on 2026-10-05 from clean worktrees at the pinned commits. Every claim is tagged OBSERVED (seen
in a command or file, named), INFERRED, or UNVERIFIED. Nothing here relaxes a gate or counts a skipped check as a pass.

## 1. Which existing mechanism defines what

| Question | Defined in |
|---|---|
| Candidate manifest, freeze rules, required result fields | `docs/qualification/CANDIDATE.md` (C2), manifest `qualification/candidates/CAND-<n>.toml`, checker `scripts/check_candidate.sh`, test `scripts/test_check_candidate.sh` |
| Result record | `EvidenceReceiptV1` in aien-sovereign-core `crates/aien-proof/src/evidence.rs` (`cand:<id>` and `exe:<name>=<digest>` go in `external_refs`) |
| Gate manifest v1 and the runner receipt | ADR 0028 (`docs/adr/0028-aien-test-runner-and-evidence-contract.md`), implemented by `tools/aien-test` in aien-sovereign-core; v2 additions in ADR 0033 (PROPOSED) |
| Committed `.gate` manifests at the pinned commit | 9 in aien-sovereign-core (`crates/aien-runtime/tests/prefill_e2e2*.gate`); none in omega, physics, aienos, aien-protocols, aien-architecture, interplane (OBSERVED, `find -name '*.gate'`) |
| Other gate dialects still in use | omega `tools/manifests/*.chiprun` (run by `tools/chip_run.sh`), aienos `scripts/ck_gates.sh` table, aien-proof `crates/aien-proof/gates/*.json` (closure manifests for phases, not CAND-0 gates), CI workflows |
| Who reads CAND-0 today | omega `tools/c4_requal.sh` reads `qualification/candidates/CAND-0.toml` from aien-architecture `origin/main`; it reports `BOUND` only when status is `frozen` and the omega commit and `aienos.lock` equal the manifest (OBSERVED, `tools/c4_requal.sh` lines 31-37 and 63-64). Keep the `[commits]` key format. |

A multi-repo candidate has a place already: the manifest lists seven repos. No new schema was added; this PR adds two
optional `[commits]` keys (`physics`, `interplane`) that the checker validates when present, plus informational sections
(`consumed_pins`, `model`, `toolchain`, `build`, `env`, `hardware`) that the checker ignores.

## 2. Clean-worktree builds (host only, no chip, no QEMU)

Worktrees at the pinned commits: `~/workspace/overnight-1005/wt-L1-CAND-<repo>`. Every build was run twice, the second
time after deleting the build outputs. Logs: `~/workspace/overnight-1005/logs/L1-CAND-*.log`. Copies of the first-run
binaries: `~/workspace/overnight-1005/artifacts-L1-CAND/`. All seven worktrees were clean (`git status --short` empty) after building.

| Item | Command | Result |
|---|---|---|
| physics boot artifacts | `./m2_build.sh` (physics has no Makefile) | PASS twice; `physics.bin` 4b22a08c... and `atlas_m2.bin` 1d6d75a6... are byte for byte equal to the committed files (OBSERVED, `cmp`) |
| omega | `make -j6 PHYSICS_DIR=<physics wt> OUT_DIR=<omega wt>/build all libomega_gpu` | PASS twice; `omegatool` e702447f... and `libomega_gpu.a` e24cbfc9... identical across runs |
| aien-sovereign-core, production config | `env -u AIEN_DEV_FALLBACK AIEN_OMEGA_DIR=<omega wt> AIEN_PHYSICS_DIR=<physics wt> CARGO_TARGET_DIR=<dir> cargo build --release --locked --offline -p aien-cli -p aien-proof -p aien-test` | PASS twice (2m13s and 2m23s from an empty target directory, warm cargo cache); `aien-cli` 8b24a5bb... identical across runs at the same target path; native engine linked (`cargo:rustc-cfg=has_omega_gpu` in the build output; the binary carries "OmegaGb10Backend (native Omega engine, no CUDA, NVIDIA GB10 sm_121)"); the `libomega_gpu.a` that cargo built through `build.rs` equals the one built with `make` |
| aienos C kernel | `make -C native/kernel -j4` then `make -C native/kernel -j4 full` | PASS twice; both `BOOTAA64.EFI` images identical across runs |
| Zero-CUDA gate | `bash scripts/zero-cuda-gate.sh --self-test` then `bash scripts/zero-cuda-gate.sh <release aien-cli>` | PASS: self-test caught the CUDA probe and accepted the clean library; `aien-cli` needs only libm, libssl, libcrypto, libgcc_s, libc (OBSERVED) |
| Zero-CUDA gate on the Mojo bridge | same script on `libspark_max.so` | PASS (extra, see gap G7) |
| Strict mode | default features, `AIEN_DEV_FALLBACK` unset | `dev-fallback` is declared only in `crates/aien-inference-abi/Cargo.toml` and no other crate enables it (OBSERVED, `grep`), so the build is strict. The strict refusal at run time was NOT exercised by this lane. |

Not built by this lane: the aienos Rust kernel and its cargo crates, the QEMU test-variant images, aien-protocols,
aien-architecture and interplane (no executables in the manifest for them). aienos QEMU and every chip run are NOT_RUN.

## 3. Reproducibility gaps (precise)

- G1, aienos pin. omega `aienos.lock` holds d39dd5bc3deb (an ancestor of the CAND-0 aienos 9d41efc9d1be). The omega gates that build the aienos capability library bind to d39dd5b, and `c4_requal.sh` will print `NOT_BOUND` for CAND-0 until omega's `aienos.lock` equals the candidate or a new candidate is cut. omega `argus.lock` pins b375dcaa2887 on branch `feat/argus-0` (OBSERVED, file contents).
- G2, aien-protocols pin (closed in the manifest). The CAND-0 pin is 7ac6facb630ca7e9a6ab4125b292203fe2bb6687, the revision aien-sovereign-core 0c1d249 `Cargo.lock` consumes through git dependencies (4 entries; the same lock also holds crumb-spec 24194d1b7917 and spark-crumbs 9355a92bc9ad, which the `[contracts]` pins follow). aien-protocols main, 3a4cdbe8d360, is 8 commits later (mostly `specs/` and licence changes) and is not what the build uses; it is not in the candidate.
- G3, crumb compiler. omega and aienos `crumb.lock` pin aien-architecture d0f0b95d344b; CAND-0 pins c5d80978c7a2. `git diff d0f0b95 c5d80978 -- tools/crumb` is empty (OBSERVED), so the crumb tool source is identical.
- G4, no toolchain pin. No `rust-toolchain` file in any pinned repo; CI uses the floating stable channel. This lane used rustc 1.98.1.
- G5, network and cache. The builds used `--offline` and succeeded only because `~/.cargo` already holds the crates and the three git checkouts (no `vendor/` directory). A cold machine needs crates.io and GitHub. UNVERIFIED on a cold cache.
- G6, path baked into artifacts. omega compiles `-DOMEGA_PHYSICS_DIR=<absolute physics path>` into `libomega_gpu.a`. Identical digests were obtained only with the same physics path both times. INFERRED that a different checkout path gives different bytes (not tested). omega's default `PHYSICS_DIR=../physics` is a sibling-directory dependency; `build.rs` refuses an omega checkout whose HEAD differs from `omega.lock`, and omega refuses a physics HEAD that differs from `physics.lock` unless `PHYSICS_LOCK_CHECK=0`.
- G7, Mojo and MAX in the Rust build. `crates/spark-max-cabi/build.rs` runs `mojo build` whenever a `mojo` binary is on PATH and ignores a missing one with only a warning. Here `mojo` is `~/.local/bin/mojo`, a symlink into `~/max-env` (a Python virtual environment). The resulting `libspark_max.so` (3630076d...) needs `libKGENCompilerRTShared.so` and `libAsyncRTMojoBindings.so` from that environment; it is copied into the source tree (git-ignored) and its build path is compiled into `aien-cli` through `option_env!("SPARK_MAX_SO_BUILT")`. Two consequences: the `aien-cli` digest is tied to the target directory path, and the build depends on a Modular install outside the pinned set. Whether the production GB10 path ever loads this library is UNVERIFIED. `zero-cuda-gate.sh` is only run on `aien-cli` in CI, not on this library.
- G8, unpinned CI inputs. physics `host-gates.yml` checks out omega and aien-architecture at `ref: main`. omega host suites run with `PHYSICS_DIR=/nonexistent PHYSICS_LOCK_CHECK=0` (OBSERVED), so those gates do not exercise the pinned physics. For CAND-0 runs the physics lock check should stay on (recommendation).
- G9, CI tests the stub configuration. aien-sovereign-core CI runs `cargo test --workspace` with `AIEN_DEV_FALLBACK=1` and no native engine link (OBSERVED, `ci.yml` lines 44-47). That is host evidence for the dev configuration, not for the strict native `aien-cli` hashed above.
- G10, aienos images. The C kernel QEMU gates build their own test-variant images (fw_cfg, SMP skip, store crash, stale handoff, xHCI mutations) through `native/kernel/Makefile` flags. Only the core and full images are in the manifest. The receipt of `ck_gates.sh` carries its own `physical: NOT_RUN`.
- G11, model location. The checkpoint lives outside every repo (`~/models/TinyLlama-1.1B-Chat-v1.0`). Its sha256 equals `model_sha256` in the committed oracle fixture manifest, which is the only in-repo pin (OBSERVED). The Hugging Face revision is recorded in the directory's `.cache/huggingface` metadata.
- G12, interplane. Its CI uses pip, pytest and Python scripts. That is the "yardstick outside AIEN" arrangement; the commit is pinned but its gates are not AIEN-native.

## 4. Required gates for CAND-0

Evidence classes: **host** (this machine's CPU, no device), **simulator** (host software model of a device, for example omega `--sim`, physics analog-sim),
**QEMU** (emulated machine, qualifies nothing physical), **physical** (GB10 chip or real hardware). Commands come from the repositories' own CI workflows,
scripts and test headers. Status for every row except the zero-CUDA rows: NOT_RUN by lane L1-CAND (not this lane's job). Chip, QEMU and `aien-test` rows go through
`~/.claude/skills/orchestrate-lanes/lanes.sh queue --heavy`. Run each gate from a clean worktree at the pinned commit and bind the receipt to `cand:CAND-0`.

### aien-sovereign-core (0c1d249)
| Gate | Command (repo root) | Class |
|---|---|---|
| format | `cargo fmt --all -- --check` | host |
| installer tests | `bash scripts/test-install-release.sh`; `bash scripts/test-install.sh` | host |
| compile | `cargo check --workspace --all-targets` | host |
| lint | `cargo clippy --workspace --all-targets -- -D warnings` | host |
| workspace tests | `AIEN_DEV_FALLBACK=1 cargo test --workspace --verbose -- --test-threads=1` | host (dev fallback recorded, gap G9) |
| zero-CUDA | `bash scripts/zero-cuda-gate.sh --self-test`; `bash scripts/zero-cuda-gate.sh <release aien-cli>` | host. **PASS** (lane L1-CAND, section 2) |
| preflight | `bash scripts/test-preflight-branch-guard.sh`; `AIEN_PROOF_OFF=1 AIEN_DEV_FALLBACK=1 AIEN_PREFLIGHT_CONTEXT=merged-tree bash scripts/agent-preflight.sh` | host |
| secrets and voice audits | the two inline audit steps at the end of `.github/workflows/ci.yml` | host |
| PREFILL-E2E-2 (9 gates: main plus mutants M1 to M8) | `aien-test run crates/aien-runtime/tests/prefill_e2e2.gate` and the eight `prefill_e2e2_m<N>.gate` files; or `aien-test test ./...` | host (real TinyLlama on CPU, `cache: never`, up to 120 min) |
| native chip parity | `AIEN_OMEGA_DIR=<omega wt> AIEN_PHYSICS_DIR=<physics wt> cargo test -p aien-omega-gpu --release --test parity -- --ignored --nocapture` (test `chip_parity_f32_and_bf16`) | physical |
| native backend parity | same env, `cargo test -p aien-inference-abi --release --test omega_backend_parity -- --ignored --nocapture` (4 chip tests; one is labelled diagnostic) | physical |
| real-model strict gate | `AIEN_E2E_CHECKPOINT=~/models/TinyLlama-1.1B-Chat-v1.0 AIEN_STRICT_RECEIPT=<path> cargo test -p aien-inference-runtime --release --test strict_real_model omega_vs_reference_real_model -- --ignored --nocapture` | physical |
| logit drift | `AIEN_E2E_CHECKPOINT=... cargo test -p aien-inference-runtime --release --test logit_drift -- --ignored --nocapture` | physical |

### omega (e5593ae)
| Gate | Command | Class |
|---|---|---|
| host suites | `make PHYSICS_DIR=<physics wt> <target>...` for the targets in `host-suites.yml`: test-searchtrace test-estimation test-est-tools test-estimation-v3 test-est3c-tools test-inertial-alignment test-numeric-cpu test-numeric-qualify test-e1-combine test-chipwait-campaign test-gpu-wait test-gpu-wait-mutants test-train test-compiler-quick test-compiler-full physics0-test | host |
| host suites 2 | `host-suites-2.yml`: test-visor test-turing test-turing-exp001-a test-turing-exp001-coders test-turing-verify-indep test-turing-qcont test-turing-qrecord test-brownian-tps test-polyglot-asm test-polyglot-encoder test-algebra test-algebra-asan test-realize test-phase-twin test-ma-digital-bottom test-path test-crumbline test-library test-vcstore test-resolve test-vcstore-genesis test-resolve-genesis test-genesis test-genesis-real test-program-ir test-vc-bridge test-r15-instr test-r15-receipt test-r16-inventory test-r16-negative test-r16-surface test-r16-negative-mutants test-r16-qualify-selftest test-argus-runtime test-machine-identity-argus test-numeric-reduce-cpu test-divsqrt-host test-tensor test-tensor-store test-m20-receipt test-tensor-mutations | host |
| host suites 3 | `host-suites-3.yml`: test-numeric-lifecycle test-numeric-transc test-numeric-transc-digest test-language, plus the per-milestone matrix `test-${m}` defined in that file | host |
| resident reaction host | `rx-host.yml`: test-r3 test-r7 test-r8 test-r9 test-r12 test-action-graph test-state-projection test-capability-query test-capability-graph test-skillroute-compose test-semantic-comm test-cognitive-routing test-sem-incremental test-cortex test-jspace-prod test-composition test-composition-attach-asan test-composition-gate test-fabric test-fabric-living test-machine-identity test-effect-cap64 test-workflow-fusion test-typed-results test-costmodel test-program-id test-program-realize test-r10 test-r11 test-r16-authpath-linkmap test-r16-authpath-linkmap-silicon test-prod-hygiene test-prod-hygiene-silicon (static checks only) test-prod-refuses-test-pieces test-empirical test-plan-reuse | host |
| turing yield, smoke | `make test-turing-yield test-turing-energy`; `pr-smoke.yml`: test test-language test-numeric-transc | host |
| GPU engine without the chip | `make PHYSICS_DIR=<physics wt> test-gpu-matmul-api test-gpu-elementwise test-gpu-attention` (host-only refusals plus the IR simulator battery, including `--sweep --sim`) | simulator |
| C4 requalification | `tools/c4_requal.sh --mutants` (refuses a dirty tree; BOUND needs gap G1 closed) | host |
| evidence immutability | `.github/workflows/evidence-immutable.yml` check | host |
| chip engine gates | `tools/run_gpu_matmul_api_chip.sh <evidence dir> <physics wt>`; `tools/run_gpu_elementwise_chip.sh ...`; `tools/run_gpu_attention_chip.sh ...` (verdict `OMEGA_GPU_ATTENTION_PASS`, timing median < 3 ms) | physical |
| chip, declared SKIP in CI | `rx-host.yml` and `host-suites*.yml` declare these Spark-only: test-r12-silicon test-r13-host test-r14-host test-r13-silicon test-r13-testbuild-host test-r13-testbuild-silicon test-prod-hygiene-silicon (probe run) test-r14-silicon test-r15-g7-host test-r15-parity-host test-r15-parity-silicon test-r16-authpath test-r16-authpath-silicon test-composition-gate-gpu test-m5 test-m19 test-m19r-qualify test-gate14-combine test-m17 test-numeric-transc-full | physical (the `-host` and `test-r16-authpath` ones need both Spark core classes and no chip) |

### physics (6d7cf0d)
| Gate | Command | Class |
|---|---|---|
| FORGE V2 known answers | `tests/run_forge_v2_gates.sh` | host |
| analog simulation | `tests/run_forge_analog_sim_gates.sh` | simulator |
| Gate 3/4 receipt writer | `OMEGA_DIR=<omega wt> tests/test_forge_gates_receipt.sh <omega wt>` | host |
| M2 PHYSICS_BOOT (15 gates) | `./run_m2_gates.sh` (leaves the committed receipt untouched) | QEMU |
| M3 PHYSICS_EFFECTS (19 gates) | `m3/tests/run_m3_gates.sh` | QEMU |
| GB10 gates, declared SKIP in CI | `tests/run_forge_gates.sh`, `tests/run_m15_gates.sh`, `tests/run_m16_requalification.sh`, `tests/run_nvrm_lifecycle_gates.sh`, `tests/run_submission_visibility_gates.sh` (one at a time, never killed) | physical |

### aienos (9d41efc)
| Gate | Command | Class |
|---|---|---|
| capability and store suites | `make -C native/capability test`; `make -C native/store test mutants` | host |
| native suites | `make -C native/<suite> <targets>` for net, sig, crypto, m5, disk (`test sanitize mutants`), argus (`test sanitize`), capability (`mutants`) | host |
| C kernel unit tests | `make -C native/kernel test sanitize stage-test stage-sanitize` | host |
| gate runner self-test, owner keys | `bash scripts/ck_gates.sh --self-test`; `bash scripts/ck_owner_keys_check.sh` | host |
| Rust crates | `cargo test --locked --offline -p aienos-crypto`; `cargo test --locked --offline -p aienos-kernel crypto::`; `cargo clippy --locked --offline -p aienos-crypto --all-targets -- -D warnings`; `cargo check --locked --offline -p aienos-kernel --target aarch64-unknown-none --no-default-features`; `cargo fmt -p aienos-infer --check`; `cargo clippy -p aienos-infer --all-targets -- -D warnings`; `cargo test -p aienos-infer`; `cargo build -p aienos-infer --target aarch64-unknown-none` | host |
| C kernel QEMU gates | `bash scripts/ck_gates.sh --out <dir>`: M1 M3 SMMU NVME_SHUTDOWN P2_ARTIFACT M0_ROLLBACK M4_NVME M4_STORE M4_STORE_CRASH M4_CONTINUITY M4_RECOVERY M4_ALLEN ARGUS1_REVOKE KEYBOARD NET SMP DISK_LAYOUT FPU INFER SCREEN (a gate with no C implementation prints NOT_RUN, never PASS) | QEMU |
| end to end harness | `bash scripts/verify_all.sh` (`AIENOS_STRICT=1` turns a skipped step into a failure) | QEMU |
| Machine 1 and hardware | any physical aienos claim | BLOCKED_OPERATOR / BLOCKED_HARDWARE until Drake provides the machine; never inferred from QEMU |

### aien-protocols (7ac6fac), aien-architecture (c5d8097), interplane (58c5198)
| Repo | Command | Class |
|---|---|---|
| aien-protocols | `cargo fmt --all -- --check`; `cargo check --workspace --all-targets`; `cargo clippy --workspace --all-targets -- -D warnings`; `cargo test --workspace --verbose` | host |
| aien-architecture | `make -C tools/crumb test`; `./tools/crumb/crumb verify .`; `AIEN_OMC=<pinned omc> tests/gates/run.sh doctrine`; `scripts/test_check_candidate.sh`; `scripts/check_candidate.sh qualification/candidates/CAND-0.toml`; `sh scripts/verify-r16-status.sh <omega checkout>` | host |
| interplane | the `ci.yml` jobs (cargo fmt, clippy, test, conformance; Python fixtures, pytest, trust digest; see gap G12) | host |
| interplane live model | `qualification.yml` (manual, needs a live model endpoint) | physical or external endpoint, BLOCKED_OPERATOR until an endpoint is named |

### All repos
`crumb verify <repo root>` (CI runs it; last step before any commit).
