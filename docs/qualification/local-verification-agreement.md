<!-- Copied from the Spark operator file ~/workspace/pipeline/benchmark/agreement.md (lane PIPELINE-FINISH, sovereign pipeline mission). Paths below are on the Spark. -->

# Phase-2 agreement (A7): local verdict vs hosted checks, 2026-10-11

> Note 2026-10-19: this is a historical record. The CRUMB-VERIFY gate that appears in the tables below was retired by RFC-0003 Amendment 2 (crumbs are advisory notes, `docs/CRUMB_PROTOCOL_RFC_0003.md`) and is no longer judged.

Lane PIPELINE-FINISH. Local = `aien-local-ci once <repo> <sha> --operator` with the engine built from sc main
bba027d (runs file: `~/handoffs/2026-10-11-lane-FINISH-runs.md`, logs `~/workspace/pipeline/finish/once-*.log`,
receipts `~/.local/state/aien-local-ci/evidence/<repo>/<sha>/`). Hosted = GitHub Actions jobs and steps on the same
commit (`agreement-raw/hosted-<repo>-<sha7>.txt`, made by `finish/hosted-steps.sh`). Mapping of a local gate to a
hosted job or step: the gate file's "Mirrors hosted:" line (`finish/manual-map.txt`, rows made by
`finish/agree-table.sh`; aienos mapped by hand from job names).

## Verdict
- **A7 is NOT met yet.** It asks for >= 3 post-merge heads per repo. This file has 1 head per repo (9 heads, 9
  repos). The six anchor-merge heads compared at 19:15Z (`hosted-checks-merges-2026-10-11.txt`) add a second head
  for aien-architecture, physics and spark-rsi, but those local runs predate the sandbox fixes (sc#445) and are not
  usable as agreement evidence. Phase 3 (making the Spark check required) must wait for more heads.
- Where both sides judged the same gate, every disagreement has a found cause. None is a case of the local runner
  passing something GitHub failed. All 11 are local FAILs that GitHub passed, caused by the local
  sandbox or by gates sharing one checkout. Each has a fix PR or a machine fix.
- The hosted "AIEN Verification" thin gate shows "success" on 8 heads only because it is neutral in phase 2: no
  bundle is published to aien-dev/aien-receipts yet, so it reports "not enrolled" (log line "Fetch the signed
  verification bundle ... 404"). It is not yet an independent verdict.

## Per head
| repo | head | local verdict | hosted overall | gates compared | agree | disagree | local only / no hosted verdict |
|---|---|---|---|---|---|---|---|
| aien-protocols | 5c23169 | PASS | success | 7 | 7 | 0 | 0 |
| aegis-runtime | 94eca7c | PASS | success | 7 | 7 | 0 | 0 |
| aien-architecture | 2611941 | PASS | success | 4 | 4 | 0 | 1 (ARCH-SCRIPT-TESTS, no hosted job) |
| spark-rsi | f74a7db | PASS | success | 5 | 5 | 0 | 0 |
| physics | 57aafa0 | NOT_RUN (gpu_lock, on purpose) | success | 13 | 13 | 0 | 0 (5 chip gates: both sides not run) |
| benchmarks | 0c81edd | FAIL | success | 1 | 1 | 0 | 5 (hosted ci.yml is manual-dispatch only, so GitHub ran none of them on push) |
| aien-sovereign-core | bba027d | FAIL | success | 11 | 9 | 2 | 1 |
| omega | 771af52 | FAIL | success | 28 | 23 | 5 | 31 (21 no hosted job, 10 hosted job path-skipped) |
| aienos | 0880564 | FAIL | failure (thin gate only) | 10 | 7 | 3 | 11 |

## Disagreements and their reasons
| repo | gate | local | hosted | reason | fix |
|---|---|---|---|---|---|
| aien-sovereign-core | SC-TEST | FAIL | success | Chrome test (browser_mirror) dies with SIGTRAP: crashpad needs a writable HOME; the sandbox HOME is read-only | sc#448 (fresh HOME in run.sh); proof run on its head recorded in the runs file |
| aien-sovereign-core | SC-AGENT-PREFLIGHT | FAIL | success | same Chrome/HOME cause | sc#448 |
| omega | OMEGA-ARGUS | FAIL | success | gates of one head run in parallel in one checkout: `make` relinks build/omegatool every time ("Text file busy") | run omega serial: worker honours `--jobs host=1` after sc#450 |
| omega | OMEGA-BASE | FAIL | success | same shared-checkout race | sc#450 |
| omega | OMEGA-FACULTY-ARM | FAIL | success | same shared-checkout race (also concurrent pin clones of build/pins/aienos-src) | sc#450 |
| omega | OMEGA-M10 | FAIL | success | same shared-checkout race | sc#450 |
| omega | OMEGA-M11 | FAIL | success | same shared-checkout race | sc#450 |
| aienos | AIENOS-DISK-QEMU | FAIL dirty_after | success | transient gate outputs `native/crypto/out/` and `native/disk/qemu/build.log` were not ignored, so a gate saw another gate's leftovers | aienos#307 (red/green proven) |
| aienos | CRUMB-VERIFY | FAIL dirty_after | success | same | aienos#307 |
| aienos | AIENOS-CRYPTO-BOUNDARY | FAIL | success | target aarch64-unknown-none missing in the sandbox toolchain copy | machine fix done; PASS on aienos aa5075d |

Not counted as disagreements (no hosted counterpart on this head) but local FAILs with a known cause:
omega VISOR + RX-HOST-REFERENCE (omega#404), 3 more omega race FAILs, aienos INFER-CRATE (target, fixed),
ZERO-DISK-SECRETS + CK-HOLD-SELFTEST + CK-QEMU-GATES (dirty tree, aienos#307), VERIFY-ALL (clippy `sort_by_key` in
aienos-kernel, owner finding), sc PREFILL-E2E-2 (needs a writable workspace dir and the TinyLlama checkpoint inside
the sandbox: open blocker), benchmarks BENCH-FMT + BENCH-VERIFY (reproduce known hosted failures).

Hosted aienos "AIEN Verification" failure: the pinned aien-test build picked up aienos's vendored `.cargo` config
(`no matching package named async-trait`). Fix aienos#306 (build outside the tree). The other eight repos have no
`.cargo` config, so they are not affected.

## Per gate rows (local | hosted counterpart | hosted | thin-gate smoke | result)

### aien-protocols
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| CRUMB-VERIFY | run PASS | (no hosted job) | - | CRUMB-VERIFY: PASS | AGREE |
| PROTO-ANTI-SLOP | cached PASS | Enforce Sovereign Voice and Anti-Slop Invariant | success | PROTO-ANTI-SLOP: PASS | AGREE |
| PROTO-CHECK | cached PASS | Cargo Workspace Check | success | - | AGREE |
| PROTO-CLIPPY | cached PASS | Cargo Clippy Invariant | success | - | AGREE |
| PROTO-FMT | cached PASS | Verify Code Formatting | success | PROTO-FMT: PASS | AGREE |
| PROTO-TEST | cached PASS | Run Workspace Unit and Integration Tests | success | - | AGREE |
| PROTO-ZERO-DISK-SECRETS | cached PASS | Enforce Zero Disk Secrets Invariant | success | PROTO-ZERO-DISK-SECRETS: PASS | AGREE |

### aegis-runtime
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| AEGIS-ANTI-SLOP | run PASS | Enforce Sovereign Voice and Anti-Slop Invariant | success | AEGIS-ANTI-SLOP: PASS | AGREE |
| AEGIS-CHECK | run PASS | Cargo Check | success | - | AGREE |
| AEGIS-CLIPPY | run PASS | Cargo Clippy Invariant | success | - | AGREE |
| AEGIS-FMT | run PASS | Verify Code Formatting | success | - | AGREE |
| AEGIS-TEST | run PASS | Run Workspace Unit and Integration Tests | success | - | AGREE |
| AEGIS-ZERO-DISK-SECRETS | run PASS | Enforce Zero Disk Secrets Invariant | success | AEGIS-ZERO-DISK-SECRETS: PASS | AGREE |
| CRUMB-VERIFY | run PASS | (no hosted job) | - | CRUMB-VERIFY: PASS | AGREE |

### aien-architecture
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| ARCH-CRUMB-TOOL-TEST | run PASS | Build and test the crumb tool | success | - | AGREE |
| ARCH-DOCTRINE | run PASS | (no hosted job) | - | ARCH-DOCTRINE: PASS | AGREE |
| ARCH-QUALIFICATION-STATUS | run PASS | job r16 | success | - | AGREE |
| ARCH-SCRIPT-TESTS | run PASS | (no hosted job) | - | - | no hosted counterpart |
| CRUMB-VERIFY | run PASS | Crumbs must be exactly what the compiler produces now | success | CRUMB-VERIFY: PASS | AGREE |

### spark-rsi
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| CRUMB-VERIFY | run PASS | (no hosted job) | - | CRUMB-VERIFY: PASS | AGREE |
| RSI-CHECK | run PASS | Cargo Check | success | - | AGREE |
| RSI-FMT | run PASS | Verify Code Formatting | success | - | AGREE |
| RSI-TEST | run PASS | step Run Tests | success | - | AGREE |
| RSI-ZERO-DISK-SECRETS | run PASS | (no hosted job) | - | RSI-ZERO-DISK-SECRETS: PASS | AGREE |

### physics
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| CRUMB-VERIFY | run PASS | job crumb | success | - | AGREE |
| PHYSICS-ANALOG-SIM | run PASS | job analog-sim | success | - | AGREE |
| PHYSICS-FORGE-GATE34 | run NOT_RUN | forge Gate 3/4 (SKIP: needs GB10 chip) | skipped | - | AGREE (both not run) |
| PHYSICS-FORGE-V2 | run PASS | job forge-v2 | success | - | AGREE |
| PHYSICS-FORM0 | run PASS | job form0 | success | - | AGREE |
| PHYSICS-GATE34-WRITER | run PASS | job gate34-writer | success | - | AGREE |
| PHYSICS-M15 | run NOT_RUN | m15 gates (SKIP: reads real GB10 GPU sysfs) | skipped | - | AGREE (both not run) |
| PHYSICS-M16-REQUAL | run NOT_RUN | m16 requalification (SKIP: needs GB10 native submission) | skipped | - | AGREE (both not run) |
| PHYSICS-M2 | run PASS | job m2 | success | - | AGREE |
| PHYSICS-M3 | run PASS | job m3 | success | - | AGREE |
| PHYSICS-NVRM-LIFECYCLE | run NOT_RUN | nvrm lifecycle gates (SKIP: needs GB10 + NVRM) | skipped | - | AGREE (both not run) |
| PHYSICS-SUBMISSION-VISIBILITY | run NOT_RUN | submission visibility gates (SKIP: needs GB10 + NVRM) | skipped | - | AGREE (both not run) |
| PHYSICS-ZERO-DISK-SECRETS | run PASS | (no hosted job) | - | PHYSICS-ZERO-DISK-SECRETS: PASS | AGREE |

### benchmarks
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| BENCH-CHECK | run PASS | (no hosted job) | - | - | no hosted counterpart |
| BENCH-FMT | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| BENCH-GENERATE | run PASS | (no hosted job) | - | - | no hosted counterpart |
| BENCH-TEST | run PASS | (no hosted job) | - | - | no hosted counterpart |
| BENCH-VERIFY | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| BENCH-ZERO-DISK-SECRETS | run PASS | (no hosted job) | - | BENCH-ZERO-DISK-SECRETS: PASS | AGREE |

### aien-sovereign-core
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| CRUMB-VERIFY | run PASS | (no hosted job) | - | CRUMB-VERIFY: PASS | AGREE |
| PREFILL-E2E-2 | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| SC-AGENT-PREFLIGHT | run FAIL | Run Required Agent Preflight | success | - | DISAGREE |
| SC-ANTI-SLOP | run PASS | Enforce Sovereign Voice and Anti-Slop Invariant | success | SC-ANTI-SLOP: PASS | AGREE |
| SC-CHECK | run PASS | step Cargo Workspace Check | success | - | AGREE |
| SC-CLIPPY | run PASS | step Cargo Clippy Invariant | success | - | AGREE |
| SC-FMT | run PASS | step Verify Code Formatting | success | SC-FMT: PASS | AGREE |
| SC-LINKED-COMPOSE | run PASS | job Linked composition tests (real librx_compose, CPU) | success | - | AGREE |
| SC-RELEASE-GATE-NEGATIVES | run PASS | step Release gate negative tests (pins, digests, model inputs, signatures) | success | - | AGREE |
| SC-TEST | run FAIL | step Run Workspace Unit and Integration Tests | success | - | DISAGREE |
| SC-ZERO-CUDA | run PASS | step Zero-CUDA Gate (aien-cli links no NVIDIA CUDA library or symbol) | success | - | AGREE |
| SC-ZERO-DISK-SECRETS | run PASS | Enforce Zero Disk Secrets Invariant | success | SC-ZERO-DISK-SECRETS: PASS | AGREE |

### omega
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| CRUMB-VERIFY | run PASS | job crumb | success | - | AGREE |
| OMEGA-ALGEBRA | run PASS | job algebra | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-ANS | run PASS | job ans | success | - | AGREE |
| OMEGA-ARGUS | run FAIL | job argus | success | - | DISAGREE |
| OMEGA-BASE | run FAIL | Build and base gates (make test) | success | - | DISAGREE |
| OMEGA-BROWNIAN | run PASS | job brownian | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-COMPILER | run PASS | job compiler | success | - | AGREE |
| OMEGA-COMPOSITION-GATE-GPU | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-CRUMBLINE | run PASS | job crumbline | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-ESTIMATION | run PASS | job estimation | success | - | AGREE |
| OMEGA-EVIDENCE-IMMUTABLE | run PASS | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-FACULTY-ARM | run FAIL | job omega-faculty-arm | success | - | DISAGREE |
| OMEGA-GATE14-COMBINE | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-LANGUAGE | run PASS | job language | success | - | AGREE |
| OMEGA-M10 | run FAIL | job test-m10 | success | - | DISAGREE |
| OMEGA-M11 | run FAIL | job test-m11 | success | - | DISAGREE |
| OMEGA-M12 | run PASS | job test-m12 | success | - | AGREE |
| OMEGA-M13 | run PASS | job test-m13 | success | - | AGREE |
| OMEGA-M14 | run PASS | job test-m14 | success | - | AGREE |
| OMEGA-M15 | run PASS | job test-m15 | success | - | AGREE |
| OMEGA-M17 | run NOT_RUN | job test-m17 (SKIP: needs GB10 chip, physical SM execution gate) | skipped | - | AGREE (both not run) |
| OMEGA-M19 | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-M19R-QUALIFY | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-M5 | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-M6 | run PASS | job test-m6 | success | - | AGREE |
| OMEGA-M7 | run PASS | job test-m7 | success | - | AGREE |
| OMEGA-M8 | run PASS | job test-m8 | success | - | AGREE |
| OMEGA-M9 | run PASS | job test-m9 | success | - | AGREE |
| OMEGA-NUMERIC-CPU | run PASS | job numeric-cpu | success | - | AGREE |
| OMEGA-NUMERIC-LIFECYCLE | run PASS | job numeric-lifecycle | success | - | AGREE |
| OMEGA-NUMERIC-TRANSC | run PASS | job numeric-transc | success | - | AGREE |
| OMEGA-NUMERIC-TRANSC-DIGEST | run PASS | job numeric-transc-digest | success | - | AGREE |
| OMEGA-NUMERIC-TRANSC-FULL | blocked BLOCKED_OPERATOR | job test-numeric-transc-full (SKIP: 2^32 inputs x 9 ops against the oracle, twice; too long for a hos... | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-NUMERIC2 | run PASS | job numeric2 | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-PATH | run PASS | job path | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-PHYSICS0 | run PASS | job physics0 | success | - | AGREE |
| OMEGA-POLYGLOT | run PASS | job polyglot | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-PROD-HYGIENE-SILICON | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R12-SILICON | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R13-HOST | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R13-SILICON | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R13-TESTBUILD-HOST | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R13-TESTBUILD-SILICON | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R14-HOST | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R14-SILICON | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R15-G7-HOST | run PASS | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R15-PARITY-HOST | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R15-PARITY-SILICON | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R16-AUTHPATH | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-R16-AUTHPATH-SILICON | run NOT_RUN | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-RUNTIME | run PASS | job runtime | success | - | AGREE |
| OMEGA-RX-HOST-REFERENCE | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-SEARCHTRACE | run PASS | job searchtrace | success | - | AGREE |
| OMEGA-TENSOR | run PASS | job tensor | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-TRAIN | run PASS | job train | success | - | AGREE |
| OMEGA-TURING | run PASS | job turing | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-TURING-YIELD | run PASS | (no hosted job) | - | - | no hosted counterpart |
| OMEGA-VISOR | run FAIL | job visor | skipped | - | no hosted verdict (hosted job skipped) |
| OMEGA-ZERO-DISK-SECRETS | run PASS | (no hosted job) | - | OMEGA-ZERO-DISK-SECRETS: PASS | AGREE |

### aienos
| gate | local | hosted counterpart | hosted | thin | result |
|---|---|---|---|---|---|
| AIENOS-CK-B7B-PROBE | run PASS | B7b preparation probe | - | - | no hosted counterpart |
| AIENOS-CK-GATE-SELFTEST | run PASS | Gate runner self-test | - | - | no hosted counterpart |
| AIENOS-CK-HOLD-SELFTEST | run FAIL | Gate hold self-test | - | - | no hosted counterpart |
| AIENOS-CK-HOST-TESTS | run PASS | Host unit tests (plain and ASan + UBSan) | - | - | no hosted counterpart |
| AIENOS-CK-OWNER-KEYS | run PASS | Hardware staging image refuses TEST keys (build only) | - | - | no hosted counterpart |
| AIENOS-CK-QEMU-GATES | run FAIL | QEMU TCG gates | - | - | no hosted counterpart |
| AIENOS-CK-STAGE-TESTS | run PASS | Stage host tests | - | - | no hosted counterpart |
| AIENOS-CRYPTO-BOUNDARY | run FAIL | job crypto (crypto-boundary.yml) | success | - | DISAGREE |
| AIENOS-DISK-QEMU | run FAIL | native/disk qemu NVMe payload | success | - | DISAGREE |
| AIENOS-INFER-CRATE | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| AIENOS-NATIVE-ARGUS | run PASS | job native/argus (test sanitize) | success | - | AGREE |
| AIENOS-NATIVE-CAPABILITY | run PASS | job native/capability (mutants) | success | - | AGREE |
| AIENOS-NATIVE-CRYPTO | run PASS | job native/crypto (test sanitize mutants) | success | - | AGREE |
| AIENOS-NATIVE-DISK | run PASS | job native/disk (test sanitize mutants) | success | - | AGREE |
| AIENOS-NATIVE-M5 | run PASS | job native/m5 (test sanitize mutants) | success | - | AGREE |
| AIENOS-NATIVE-NET | run PASS | job native/net (test sanitize mutants) | success | - | AGREE |
| AIENOS-NATIVE-SIG | run PASS | job native/sig (test sanitize mutants) | success | - | AGREE |
| AIENOS-STORE-NATIVE | run PASS | make -C native/store test mutants | - | - | no hosted counterpart |
| AIENOS-VERIFY-ALL | run FAIL | bash scripts/verify_all.sh | - | - | no hosted counterpart |
| AIENOS-ZERO-DISK-SECRETS | run FAIL | (no hosted job) | - | - | no hosted counterpart |
| CRUMB-VERIFY | run FAIL | job crumb | success | - | DISAGREE |
