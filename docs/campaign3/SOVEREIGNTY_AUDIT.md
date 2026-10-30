# CAND-4 sovereignty audit (Campaign 3, item C3-8)

Date: 2026-10-08. Subject: the internal candidate CAND-4 ([release/candidate.toml](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/release/candidate.toml), [manifest](../../qualification/candidates/CAND-4.toml)). CAND-4 is internal only. No release of CAND-4 is published, physical Spark rollback has not been run, and this audit proposes no key creation and no publication.

Snapshot read on GitHub main: aien-sovereign-core `f5ba66b` (updated 2026-10-08 for the Campaign 2 merges up to `6bbe2ec`), aienos `8641977`, aien-architecture `78770cc`. Every claim below links to a merged file or commit on main, or is marked UNVERIFIED or NOT_RUN. Evidence from main after CAND-4 is labelled as such; it is not evidence about the CAND-4 package.

## Reading the table

Environment columns are kept separate on purpose. A PASS in one column says nothing about another.

- host: a Linux process on the Spark or another machine, CPU only, no emulator, no GB10 GPU work.
- QEMU: the AIENOS C kernel or boot chain inside the QEMU emulator (GitHub ARM64 CI is also QEMU). Never a physical result.
- Linux-hosted GB10: Linux on the Spark with the GB10 GPU driven through the Linux NVIDIA driver. A result about Linux processes, not about AIENOS.
- native physical Spark: AIENOS code running on the real Spark with no Linux underneath.

Status values: PASS, FAIL, PARTIAL, NOT_RUN, UNVERIFIED, N/A. Verdicts: YES, PARTIAL, NO.

## Summary

| # | Question | host | QEMU | Linux-hosted GB10 | native physical Spark | verdict | essential external dependency |
|---|---|---|---|---|---|---|---|
| 1 | Build and verify offline from supported inputs | PARTIAL | N/A | N/A | NOT_RUN | PARTIAL | Linux, a cargo cache filled online first, pinned git sources; network denial not enforced |
| 2 | Boot without a cloud dependency | N/A | PASS | N/A | PARTIAL | PARTIAL | UEFI firmware; the C kernel has never booted on the Spark; Linux stays the installed OS |
| 3 | Retain and recover user identity and data | PARTIAL | PASS | NOT_RUN | NOT_RUN | PARTIAL | Linux filesystem on every live path; native disk path is QEMU only |
| 4 | Execute authorized local computations | PASS | PARTIAL | PASS | NOT_RUN | PARTIAL | Linux plus the NVIDIA driver for real inference; native inference is a QEMU load and probe only |
| 5 | Replace the model without replacing identity | PASS (main after CAND-4) | NOT_RUN | NOT_RUN | NOT_RUN | PARTIAL | Linux host; GB10 and native swap not run |
| 6 | Recover from interrupted updates | PASS | PASS | N/A | NOT_RUN | PARTIAL | Linux install script; UEFI BootNext; kill -9 is not power loss |
| 7 | Refuse unauthorized effects | PARTIAL | PARTIAL | NOT_RUN | NOT_RUN | PARTIAL | Linux daemon; the double-effect defect #320 found after CAND-4 is fixed on main (#321) and was never in CAND-4 |
| 8 | Operate without a mandatory external control service | UNVERIFIED | N/A | PASS | NOT_RUN | PARTIAL | Local services only found (loopback Cortex, local vault); full source audit not done |

Where a cell rests on code that landed on main after CAND-4 was packaged (rows 3, 4, 5 and 7, host column), the section says so; that is evidence about the current source line, not about the CAND-4 package.

Overall: CAND-4 is not shown to be sovereign. Parts of it work offline on Linux, parts are proven in an emulator, and the native path has no physical evidence beyond a 2026-09-24 first boot and an attended recovery USB boot. See "Essential paths that still depend on Linux or another external system".

## 1. Build and verify offline from supported inputs

Evidence:
- [Offline build receipt](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/docs/release/receipts/2026-10-07-final-switch-kill-and-offline-build.md) (sovereign-core #308, merged): `cargo fetch --locked` then `--offline --locked`, 7 crates, 170 s, PASS. Environment: host Linux on the Spark.
- [CAND-4 release demo receipt](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/docs/release/receipts/2026-10-06-cand4-release-demo.md): fresh clones and fresh CARGO_HOME, `release-build.sh --offline`, all 7 binaries equal the CAND-4 digests, the package built twice gave identical bytes, signature and digest checks ran from `file://` URLs. Environment: Spark, Linux.  This is a host result (CPU build on Linux), so the GB10 column is N/A.
- [CAND-4 manifest](../../qualification/candidates/CAND-4.toml) note: clean-worktree double build, 25 of 25 digests identical (CAND4-BUILD-REAL3, VERDICT PASS).
- Fail-closed tamper checks in the demo: a changed `release.toml` and a missing signature were both refused (steps S9, S10).

Limits:
- Network denial was not enforced. `unshare -rn` was not permitted, so the offline claim rests on cargo's `--offline` flag only (receipt above).
- The build is not vendored. A first online `cargo fetch` is required; the offline build uses a warm cache. The check is not in CI (needs network, about 3 minutes).
- The inputs include git pins on other repositories and a model download (unsloth/Llama-3.2-1B-Instruct, Llama 3.2 Community License, internal distribution only). Fetching them needs a network once.
- Verification needs the pinned signer in `allowed_signers`. See the discrepancy list for the signer.
- A package built from a main later than `d5b78ff` is expected to be refused by the gate; this was not tried: UNVERIFIED (demo receipt, Limits).
- Build and verify run only on Linux. Nothing builds or verifies natively on AIENOS.

## 2. Boot without a cloud dependency

Evidence:
- QEMU: the newest committed C kernel gate receipt, [ck_gates_cb14...json](https://github.com/aien-dev/aienux/blob/8641977/evidence/ck_gates_cb1404163d23657165e31bc566fb4c4829a9e1ee7a5d5dc4685454b0c2685948.json), records the boot, Store, network, SMP, crash, continuity, recovery, ALLEN, keyboard, FPU, infer and screen children as PASS, with M0_ROLLBACK NOT_RUN, overall NOT_ALL_GATES_PASS. The runs use local QEMU and local AAVMF firmware, with no cloud service named.
- QEMU console and input: aienos #280 (console session, C3-1a) merged, TEST-ONLY console image, QEMU only.
- Physical: [M2 first native boot, 2026-09-24](https://github.com/aien-dev/aienux/blob/8641977/evidence/m2_first_boot_2026-09-24.md): native AIENOS code at EL2 with no Linux underneath, a report read back by Linux, return to Linux undamaged. [Attended recovery USB boot](https://github.com/aien-dev/aienux/blob/8641977/evidence/recovery_boot_machine1.md): read-only inspection, return to Linux.
- Statement of record: [ROADMAP status](https://github.com/aien-dev/aienux/blob/8641977/ROADMAP.md) "Nothing in AIENOS is physically qualified" and "No physical boot of the C kernel has happened"; [CURRENT_EXECUTION_PLAN.md](../../CURRENT_EXECUTION_PLAN.md) §2 correction of 2026-10-08 (arch #163).

Limits:
- The C kernel in CAND-4 (`aienos-ck-core-image`) has never booted on the physical Spark. The 2026-09-24 boot ran an earlier image.
- A QEMU PASS is not a Spark result. SMMU, NVMe, input and network on the physical machine are unqualified. The Spark's IORT exceeded the SMMU service limits at the time of the ROADMAP status; later cuts #269 and #270 were QEMU or host only.
- The C loader (signatures, A/B, rollback) is parked, per the same ROADMAP block and the gate receipt's M0_ROLLBACK reason.
- Secure Boot is off on the Spark (arch qualification exception 0002).

## 3. Retain and recover user identity and data

Evidence:
- Design record: [ADR 0035](../adr/0035-persistent-cognitive-entity-boundary-aien.md) (ALLEN, accepted). Persona profile bound to the existing identity: sovereign-core #302 (merged, `37039ec`). Identity crates on main after CAND-4 (not in the CAND-4 package): `crates/aien-allen`, `aien-allen-profile`, `aien-allen-memory` ([identity_test.rs](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/crates/aien-allen/tests/identity_test.rs)). Environment: host.
- QEMU: gates M4_STORE_CRASH, M4_CONTINUITY, M4_RECOVERY and M4_ALLEN are PASS in the [receipt above](https://github.com/aien-dev/aienux/blob/8641977/evidence/ck_gates_cb1404163d23657165e31bc566fb4c4829a9e1ee7a5d5dc4685454b0c2685948.json). aienos #260 (merged): ALLEN native genesis at provisioning and QEMU cold restore.
- Main after CAND-4: sovereign-core #322 (`6bbe2ec`), [RESULT-v3.md](https://github.com/aien-spark/aien-sovereign-core/blob/6bbe2ec269768c7c9b94b9484c757ca45f55f564/docs/campaigns/allen-e2e/RESULT-v3.md), ALLEN end-to-end demo v3 PASS 10/10: S1 one identity, S2 profile and memory, S5 kill -9 restart kept the identity, profile, notes, goal and the DONE result without re-executing it, S6 forget removed a note from every state file. Environment: real CPU, Linux host. Earlier runs v1 and v2 FAILED and stay recorded.

Limits:
- No physical result. TRUST-1 and M5 are NOT_QUALIFIED; the owner key ceremony and TPM sealing are BLOCKED_OPERATOR ([plan](../../CURRENT_EXECUTION_PLAN.md) §2 lines on TRUST-1; aienos issue #32 open).
- Every C kernel image uses TEST Store keys and a TEST machine id; no production key path exists.
- The live ALLEN stack runs on a Linux filesystem. The native NVMe Store (aienos issue #31) is open and QEMU only.
- GB10 column: the branch demo used CPU, so GB10 is NOT_RUN.

## 4. Execute authorized local computations

Evidence:
- Linux-hosted GB10: in the [CAND-4 release demo](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/docs/release/receipts/2026-10-06-cand4-release-demo.md) the installed CAND-4 `aien` ran one GB10 StreamTurn (rc 0, 16 tokens) and the NP1 workflow steps S1 to S8 all returned `ok:true`. The same receipt reports text-level agreement with a Hugging Face oracle (token ids and logits not exposed, so only decoded text was compared).
- Host, main after CAND-4 (not the CAND-4 source d5b78ff): the golden path and effect ledger tests in sovereign-core ([effects.rs](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/crates/aien-runtime/src/effects.rs)).
- QEMU: gate INFER is PASS. Per [GATES.md rows 129 to 134](https://github.com/aien-dev/aienux/blob/8641977/native/kernel/GATES.md) it checks that the kernel ingests the model file, hashes it, and probes tensor count and vocabulary. It is not token generation.

Limits:
- Real inference runs on Linux (CPU, or GB10 through the Linux NVIDIA driver). Native AIENOS CPU or GPU inference is not done. aienos issue #34 (runtime and native CPU inference) is OPEN; #31, #32, #33, #35 are also OPEN.
- GB10 results are hardware results for Omega kernels under Linux, not for AIENOS (plan, "Environments, kept separate").
- The CAND-4 tested model is a 1B instruct model; this audit makes no quality claim.

## 5. Replace the model without replacing identity

Evidence:
- Main after CAND-4: [RESULT-v3.md](https://github.com/aien-spark/aien-sovereign-core/blob/6bbe2ec269768c7c9b94b9484c757ca45f55f564/docs/campaigns/allen-e2e/RESULT-v3.md) (sovereign-core #322, `6bbe2ec`), S7 PASS: after kill -9 and a restart on a second model, the `Model:` line and model digest changed (f55217be to 75311d91) while ID0, profile, work note and goal stayed unchanged; S8 PASS: the second model then wrote a checked document whose provenance names the new model digest and the same ALLEN id. Environment: real CPU, Linux host.
- Main: the persona profile is bound to the existing identity (sc #302). ADR 0035 records that ALLEN is the agent the AgentRoot already names ("There is no `AllenId`") and that the model is identified only by a digest in the boot handoff ("there is no ModelId type", as of the 2026-10-04 audit). I did not check the Rust crates for a model field: UNVERIFIED.

Limits:
- Sovereign-core #307 (recovery matrix) MERGED 2026-10-08 as `2a83095`: R7 (restart on a different model keeps the ALLEN agent) PASS in both desk-MAC modes, real processes, CPU-reference, Linux host.
- The swap was tested between two CPU models on Linux. GB10 and native: NOT_RUN.
- Shown on main after CAND-4, not on the CAND-4 package itself.
- Sovereign-core #319 (first-line heading requirement) MERGED 2026-10-08 as `3eaa060`; the v2 request shape is now recognized and checked.

## 6. Recover from interrupted updates

Evidence:
- Host install path: `scripts/test-install-release.sh` case 12b ([receipt](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/docs/release/receipts/2026-10-07-final-switch-kill-and-offline-build.md), sovereign-core #308): kill -9 at pre-rename, after-links (install) and pre-rename, after-swap (rollback), each ends wholly old or wholly new and a rerun repairs it. PASS in a scratch prefix.
- [Receipt v2](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/docs/release/receipts/2026-10-06-install-upgrade-rollback-v2.md): kill -9 at mid-copy, after-copy, before-swap left the live release unchanged. [CAND-4 demo](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/docs/release/receipts/2026-10-06-cand4-release-demo.md) S5 to S8: kill mid-copy, rerun, upgrade, then `--rollback` twice between CAND-3 and CAND-4 digests, all rc 0.
- QEMU boot rollback: aienos #273 (merged `61bd76a`): the C kernel image as the one-time BootNext candidate, 37 checks PASS across normal, panic, CPU fault, hang, rejected and absent image lanes, BootNext consumed once, BootOrder unchanged. Environment: QEMU only. Older Rust-mock evidence: gate M0_NATIVE_ROLLBACK_QEMU.

Limits:
- Real power loss and filesystem-level crashes are NOT_RUN. kill -9 does not test unflushed data.
- Physical Spark rollback has NOT been run. The hardware rollback gate was recorded BLOCKED in the ROADMAP history (M0_NATIVE_ROLLBACK_MACHINE1).
- The hang lane uses a host-forced reset; there is no in-guest watchdog ([GATES.md row 44](https://github.com/aien-dev/aienux/blob/8641977/native/kernel/GATES.md)).
- The package demos used a "local" signing key; the throwaway-key v2 demo did not use the pinned key (receipt v2). The C loader A/B path is parked, and the `M0_ROLLBACK` row in the cb14 receipt is NOT_RUN because that receipt predates #273.
- The kill during the single rename was tested only at the pause points added in #308, not at the system call itself.

## 7. Refuse unauthorized effects

Evidence:
- Host, main after CAND-4 (not the CAND-4 source d5b78ff, which predates the minted-grant path and `minted_grant_test.rs`): the approved-effect path in [crates/aien-runtime/src/effects.rs](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/crates/aien-runtime/src/effects.rs). The ledger honours only grants the daemon wrote itself (approved or minted); a corrupt ledger record refuses the whole ledger; refusals are named (`EFFECT_REFUSED <name>`); stop is durable; one grant per desk-MAC nonce. Test: [minted_grant_test.rs](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/crates/aien-runtime/tests/minted_grant_test.rs).
- Main after CAND-4: the demo's v2 run ([RESULT-v2.md](https://github.com/aien-spark/aien-sovereign-core/blob/6bbe2ec269768c7c9b94b9484c757ca45f55f564/docs/campaigns/allen-e2e/RESULT-v2.md)) shows the runtime refusing a task whose requirement it cannot check, with no file written and no grant spent. That is a refusal of a task, not of an effect.
- QEMU: gate ARGUS1_REVOKE is PASS (revocation at the Store level) in the cb14 receipt.

Limits:
- Defect found during Campaign 2 on main, not in CAND-4: sovereign-core issue #320 (a stop and resume after a DONE effect let the same committed proposal get a second grant and a second DONE effect). Fixed by #321, MERGED 2026-10-08 as `05e9028` (independent review: no refusal on main weakened). CAND-4's source `d5b78ff` predates the daemon-minted grant path (`effects.rs` there has no `minted_by_commit`), so CAND-4 does not carry it. Follow-up question open: #323.
- Sovereign-core #307 (recovery matrix) MERGED as `2a83095`: 13/13 PASS with the desk MAC off and on (stale, spent, revoked and after-stop grants refused incl. no second grant after DONE; corrupted state refused; foreign identity refused; unreconcilable outcomes stay UNRESOLVED), at commit 5073656, Linux host, CPU-reference. This is main after CAND-4, not CAND-4 itself.
- No native or GB10 effect test. The effect membrane is a Linux process.

## 8. Operate without a mandatory external control service

Evidence:
- The CAND-4 demo, GB10 turn and NP1 workflow ran from the Spark with `file://` release URLs and a local daemon ([receipt](https://github.com/aien-spark/aien-sovereign-core/blob/f5ba66bf3a1bd064e6cd5cf7e323508a459d2e7a/docs/release/receipts/2026-10-06-cand4-release-demo.md)). No Headscale, hub or cloud service is named in the steps.
- Source scan on main: no `headscale` string in any sovereign-core Rust file. `crates/aien-cli/src/cortex.rs` uses `http://127.0.0.1:18080` (loopback) and reads `CORTEX_TOKEN` from a local vault. `crates/aien-cli/src/client.rs` has a loopback default endpoint and a test named `native_chat_uses_the_runtime_socket_not_http`.

Limits:
- UNVERIFIED: a full audit that no code path blocks when the internet is absent. The scan above is a search, not a proof. The string `aienos.com` appears in 15 Rust files of sovereign-core; I did not classify these (likely email addresses or fixtures, unconfirmed).
- The rule is "the internet may be used, never depended on". `crates/aien-cli/src/context7.rs` syncs to Cortex using the internet; whether it is optional was not checked.
- Cortex on loopback and the atlas-vault token are local dependencies that must be running. A session on a machine without them loses the Cortex commands.
- Native AIENOS network (M6) is QEMU and hosted only, with TEST keys (plan Lane 33 addendum).
- Release signing relies on a pinned public key in the repository; no online signing service is used.

## Essential paths that still depend on Linux or another external system

- Building and verifying the release: Linux, cargo, and a network fetch to fill the cache once. Offline is not enforced by the sandbox.
- The installed OS on the Spark is Linux. The C kernel has never booted on the Spark and no AIENOS storage, input, network or isolation result is physical.
- The install, upgrade and rollback script is a Linux shell script. The native boot rollback exists only as QEMU evidence.
- Real model inference and every demo of the working agent: Linux processes, CPU or GB10 through the Linux NVIDIA driver. Native inference (aienos #34) is open.
- Identity and data persistence for the working agent: Linux filesystem. The native Store runs on QEMU disks only and uses TEST keys.
- Effect refusal: a Linux daemon; the double-effect defect found on main (#320) is fixed (#321) and was not in CAND-4.
- Cortex: a local HTTP service and a local vault.
- Third-party inputs: the Llama 3.2 model weights and its licence (internal-only distribution), cargo crates, and GitHub for pinned sources.

## Operator-only steps (not done, not proposed here)

- Offline signing key ceremony for a production release key.
- Physical Spark rollback with the operator present.
- Attended boots of the C kernel on the Spark (the console, keyboard and recovery path need a person at the machine).
- NVMe on the Spark: native storage qualification on the real device.
- TRUST-1 hardware steps (owner key ceremony, TPM sealing), listed in aienos `docs/TRUST-1-OPERATOR-STEPS.md`.

## Where plans and code disagree (recorded, not resolved)

- NEXT-PHASE-3 header reads NOT STARTED while its status lines record merged QEMU work ([plan](../../CURRENT_EXECUTION_PLAN.md) addendum).
- Two native AIENOS orders (M5 to M6 to M7, versus NEXT-PHASE-3) are both recorded; the operator has not chosen ([plan](../../CURRENT_EXECUTION_PLAN.md) "Open conflict noted 2026-10-08").
- The newest ck_gates receipt on main (cb14, 20 gates) lists M0_ROLLBACK NOT_RUN, while aienos #273 merged later with QEMU PASS for the same gate family and GATES.md rows 42 to 46 say QEMU PASS; no newer committed gate receipt joins them.
- Two different keys are in play. An existing `aien-release` key is pinned in sovereign-core `docs/release/allowed_signers` (added by sovereign-core #186, `ffc5555`, 2026-10-04) and hand-signed the published GitHub releases v0.1.0 (2026-09-20) and v0.1.1 (2026-10-04); the CAND-4 demo was signed with "the local key whose public half is already in allowed_signers". The operator decision D1 (2026-10-06, [plan](../../CURRENT_EXECUTION_PLAN.md) addendum "operator decisions on public-release gates", aien-architecture #156) requires a dedicated offline signing key, generated only when preparing the first public release; that key does not exist yet. Both releases predate D1. Whether the existing `aien-release` key may count as the D1 key, and what happens to v0.1.0 and v0.1.1, is an operator decision, recorded here and not decided.
- The CAND-4 demo was run from a release branch at `d5b78ff`; main has since moved on, so main is not what was packaged.
