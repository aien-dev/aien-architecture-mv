# Release readiness, R1: gap assessment against the whole-system acceptance test

**NOT A MASTER PLAN.** Tracking issue: aien-spark/aien-architecture#190 (R1 deliverable). Authority stays with `PLAN_AUTHORITY.md`: this file assesses, it does not sequence or redefine anything. Written 2026-10-10 by the coordinating session (Claude Code 85679b2b) after Drake's redirect of 2026-10-10 (AT-1 closed as REVIEWED, principal effort on finishing AIEN as one usable system).

**Method.** Every "what runs" claim below names the live default-branch commit and the file, pull request or receipt that proves it, read on 2026-10-10. Plan wording was not used as evidence. Where a reading came from a read-only scout and was not re-opened by the author it is marked UNVERIFIED. Nothing is marked done because a document says so.

**Mains read (2026-10-10):** aienos `e90226ba`, aien-sovereign-core `2d5f2093`, omega `16e729b6`, physics `8b23e5a2`, aegis-runtime `f4e87095`, spark-rsi `24f412f6`, aien-protocols `66610096`, interplane `f1cc43cd`, aien-architecture `319b248b`.

## 1. The acceptance test this assesses

WHOLE-SYSTEM-E2E, as posted on aien-architecture#190: one installation, one run, six steps each with a receipt and a negative control. E1 install offline from a signed artifact. E2 an operator submits a real objective through an operator interface. E3 the runtime plans, routes capabilities, runs the local model, performs effects through the approval desk. E4 memory written during the run is recalled from durable storage after a full restart. E5 an independent verifier checks the outputs, same verdict on a second machine. E6 the runtime is killed mid-objective and finishes from durable state with no effect done twice. Status of the test as a whole today: **NOT_RUN**. No single run has yet chained all six steps.

## 2. What already exists, step by step

### E1 install

| what runs | proof |
|---|---|
| `install.sh` release mode: downloads asset, `SHA256SUMS.txt` and `.sig` over https only, verifies with `ssh-keygen -Y verify` against the pinned `docs/release/allowed_signers`, checks every file against `release.toml`, one-rename activation | aien-sovereign-core#118, reconciliation comment of 2026-10-10 against main `2d5f209`; `docs/release/RELEASE_SIGNING.md` |
| offline install test with six checks, including a tampered archive and a wrong-key signature both installing nothing, and a standalone `install.sh` with a clean HOME | `scripts/test-install-release.sh` header, checks 1 to 6 |
| release workflow builds three targets, enforces the release gate (candidate named, `omega.lock` and `Cargo.lock` equal the candidate pins), reproducible tarball, dry-run signing with a throwaway key | `.github/workflows/release.yml` steps "Release gate", "Build the candidate way", "Dry run: sign with a throwaway key and verify" |
| release candidate manifest | `release/candidate.toml`: CAND-4, omega `c0369e67`, sovereign-core `d5b78ff7`, aienos `b84c0a67`, physics `6d7cf0d4`, model `unsloth/Llama-3.2-1B-Instruct` with per-file sha256 |

**Gaps.** (a) No signed release exists for any current main: v0.1.0 carries only checksums, v0.1.1 is signed with the old key and both are internal test releases by Drake's decision of 2026-10-08 (`RELEASE_NOTES.md` status line). (b) The offline signing key is still open (aien-sovereign-core#118; memory "Public-release gates 2026-10-06": offline signing key and physical rollback mandatory). Drake's call. (c) CAND-4 pins are far behind every main (sovereign-core `d5b78ff7` vs `2d5f2093`, omega `c0369e67` vs `16e729b6`); no CAND-5 manifest exists under `qualification/candidates/`. A release today would ship code weeks older than what the demos below ran. (d) The candidate model is licence-restricted: "internal-only until an open-licence model passes" (`candidate.toml` `distribution`); SmolLM2 and Qwen3 qualification campaigns exist in `docs/campaigns/` but the Qwen3 v5 spec is a draft, not run (arch#164 open items). (e) No install path for the native Aienux target; E1 as written is a Linux-host install.

### E2 objective

| what runs | proof |
|---|---|
| `aien` CLI: `daemon`, `start`, `stop`, `status`, `cockpit`, `allen <sub>`, `compose`, `goal <text>`, `goal auto <id>`, `auto <goal>`, `cortex`; daemon control over a UNIX socket `/tmp/aien-runtime.sock`, mode 0600 | `crates/aien-cli/src/main.rs:41-130`, `crates/aien-runtime/src/client.rs:22-28`, `server.rs:169-178` (scout reading, call sites UNVERIFIED by the author) |
| the Aien end-to-end demo accepts a real objective (write a short document under stated requirements) under a resolved Aien identity, with a profile and a standing goal, and records it before work starts | `docs/campaigns/allen-e2e/DEMO-v2.md` steps S1 to S3; `RESULT-v3.md` PASS 10/10 real-CPU, `RESULT-v4-gb10.md` PASS 10/10 with S0 to S6 on the GB10 (native Omega engine, no CUDA), receipts `receipts-v3.jsonl`, `receipts-v4-gb10.jsonl` |
| cockpit HTTP on `127.0.0.1:18095` with `/api/goals`, `/api/approvals/{id}`, `/api/chat/stream`, `/api/action` | `crates/spark-cockpit-rs/src/main.rs` route table (scout) |
| OSH, the Omega shell: `osh -c`, scripts, `--caps` policy, `--journal`; capability-authorized platform ops SPAWN, CHDIR, OPEN_WRITE, OPEN_READ through one request record on both the Linux host and the Aienux test adapter | omega `src/osh/host/osh_main.c:4-12`, `osh_host.h:50,103-127`; aienos `native/kernel/core/osh_op.h:45-87` (omega#344 lane done, aienos#294) |

**Gaps.** (a) Three operator surfaces that do not meet: the cockpit's `/api/action` accepts only five fixed names and shells out to `aien`; its approvals are a hard-coded in-memory list (`spark-cockpit-rs/src/main.rs:924-935`, verified) that never reaches the real approval desk; OSH runs shell strings and scripts and has no objective or agent entry point (negative, UNVERIFIED exhaustively). (b) The objective in the demo is pre-declared in a spec; free-form objective entry exists only as `aien goal <text>` to the slash handler, whose execution path is not proven by any receipt found. (c) No operator interface exists on native Aienux beyond the OSH test adapter.

### E3 execute

| what runs | proof |
|---|---|
| compose path with approval desk REQUIRED by default; a missing desk key refuses startup | aien-sovereign-core#342 (merged 2026-10-08) |
| single-use approval grants, two-phase spend (reserve, commit, release), revoke; effect classes `EXTERNAL_WRITE`, `WORLD_MUTATION`, `SECRET_BEARING`, `SPAWN_PROCESS` require approval, `EXTERNAL_IRREVERSIBLE` and unknown tools are denied | `crates/aien-mcp/src/approval.rs`, `authority.rs:165-170`; #204, #260 |
| stated requirements of a composed document are checked before approval | #287 |
| real model inference on the Spark CPU and on the GB10 through the native Omega engine (no CUDA), with the GB10 reservation path the default on linked GB10 builds | `RESULT-v4-gb10.md` S0, S3; aien-sovereign-core#327 (Campaign 1 comment 2026-10-08) |
| golden path rerun on the GB10 at main `fefce80` on 2026-10-10: PASS, backend identity recorded, `gpu_executions > 0`, `fallback_count == 0` | aien-sovereign-core#94 last comment |
| provenance: a model commit names its generation record and the Aien agent; ledger links grant id, proposal sha256, content sha256, model digest and identity | #318; `RESULT-v4-gb10.md` S4 |
| PREFILL-E2E-0/1/2 (real checkpoint, shared prefill, N-branch fork, append-only revisions) | aien-sovereign-core#154, #163, #165 |

**Gaps.** (a) Approval grants live in memory only: "A restart forgets every grant" (`approval.rs:16-17`, verified). The desk MAC for approved proposals (#262) is restart-safe; the grant broker is not. (b) Planning and capability routing: the Skill Router and World commit binder exist in omega (COMPOSITION-2, omega#121) and the compose path drives approved proposals through verify and World commit (#244), but no receipt found shows a multi-step plan chosen by the runtime for a free-form objective; the demo's objective is a single compose. (c) Inference on native Aienux: NOT_RUN in every demo ("native-AIENOS: NOT_RUN" in all four RESULT files); aienos M7 native CPU inference is open (aienos#34) and the int8 kernel speed-up is a draft (aienos#300, kernel default stays f32 until Drake says go).

### E4 memory

| what runs | proof |
|---|---|
| Aien scoped memory store, a separate hash-chained record store under `<home>.allen-memory/`, encrypted per item, scopes enforced at recall, key-destroying forget, crash-safe appends, refusal of damaged or foreign stores | `crates/aien-allen-memory/src/lib.rs:1-13`; #303, #314 |
| recall survives graceful stop and restart on the same model and across a model change: identity, profile, notes and goal identical after restart; forgotten item absent everywhere | `RESULT-v4-gb10.md` S5, S6, S7 |
| omega `rx_cortex`: append-only journal replayed and verified on reopen, exclusive writer lock, torn-tail detection | omega `src/runtime/rx_cortex.h:54-55,145-167,187-190`; omega#114 |
| durable effect intents and acks in Cortex, reconcile at start | aien-sovereign-core#227 |
| `cortex-rs` HTTP memory service (SQLite WAL, FTS5), used by the agents on the Spark today | `crates/cortex-rs/`; `AGENTS.md` (Cortex at `127.0.0.1:18080`) |

**Gaps.** (a) Four memory stores with one declared owner: ADR 0022 makes omega `rx_cortex` the canonical Cortex; `cortex-rs/README.md` still calls itself "the canonical memory engine"; `aien-allen-memory` is a third store; `aienos-cortex` a fourth (`aienos/crates/aienos-cortex`). The acceptance test needs one answer to "which store must the recall come from". (b) The restart in S5 is a graceful stop (exit 0); E4 after an unclean stop is covered only by the fault harness rows in E6, not by a recall assertion. (c) Cortex persistence on native Aienux: aienos#35 open; QEMU store crash and reboot PASS (aienos#134, #136), native storage atomicity FAIL (`NATIVE_GB10_STORE_ROOT_ATOMICITY: FAIL`, `aienos/evidence/p3_nvme_atomicity_2026-09-25.md`), waits on TRUST-1 (aienos#32).

### E5 verify

| what runs | proof |
|---|---|
| document checker C1 to C5 as an independent check with a red control (hand-written bad document reports exactly C3 C5; good control reports none) | `scripts/allen_e2e_demo.sh` `check_doc`; `RESULT-v3.md`, `RESULT-v4-gb10.md` S3-red |
| campaign verifier crate and the NEXT-PHASE-2 receipt script with explicit NOT_RUN never counted as PASS | `crates/aien-campaign-verifier`; `docs/campaigns/next-phase-2/make-receipt.sh:10-44` |
| spark-rsi blind judge: receipt digest over length-prefixed fields, P-256 signature, `verify_for_promotion` requires format version 2 and matching subject, policy and holdout digests | `src/evaluator/mod.rs:124-262`, `src/actor/judge.rs:381-537`; spark-rsi#34 |
| AT-0 and AT-1 evaluators: separate code base, exact verdict identities compared across the Spark and the MacBook, withheld cases under commitment, mutants | omega `research/atemporal/at1/evaluator`, `evidence/AT1/` (omega#395, #396) |
| interplane provenance: a real model turn chained to a judged, approved, acknowledged record; retained output required for claimed test digests | interplane#89, #90, #91 |

**Gaps.** (a) The only verifier that has judged a whole-system run is the five-line document checker inside the demo driver; it is shell in the same script as the executor, not separate code. (b) spark-rsi's `judge`, `cycle` and `daemon` subcommands hard-code `policy_file: None` (`src/main.rs:344,383,416`, verified), so they emit version 1 receipts; version 2 is reachable only through the judge binary with a policy file. (c) Cross-machine verdict comparison exists for AT-1 only; nothing of the runtime has been verified on a second machine. (d) No shared verdict-identity contract across verifiers: AT-1 has `verdict_id`, spark-rsi has `receipt_digest`, the campaign verifier has its own JSON; `aien-protocols` has `specs/evaluation` and `specs/evidence-receipt/SUBSET.md` but nothing frozen there (only `osc-unit-artifact` is FROZEN).

### E6 recover

| what runs | proof |
|---|---|
| durable effect intent before write, ack after; lost ack reported `UNRESOLVED` (exit 3); reconcile at start; grants refused with named reasons `Stopped`, `NotAuthorized`, `AlreadySpent`, `ReconciliationRequired`, `Revoked`, `Stale`; durable stop; damaged `processed_operations.json` refuses startup | aien-sovereign-core#227 |
| fault harness against the real daemon (hold points behind a cargo feature; release binary carries 0 hold strings); ACCEPTANCE-v4 rows C7a PASS x3 (reconcile error: reads and controls served, every effect refused until an operator reconcile), C7c PASS x3 (reconcile panic: daemon stops before serving, nothing written, next start clears the socket), C6i PASS (`E_REPLAY` refused, `cortex.cx` byte-identical); every v2 and v3 row not replaced PASS | `docs/campaigns/next-phase-2/VERDICT-v4.md` sections 1 to 3 |
| graceful stop and restart with unchanged ledger, record count, document inode and mtime; replay reconcile 0 claims | `RESULT-v4-gb10.md` S5 |
| Aienux subject restart across two processes on a sealed Store image | `native/kernel: make test-continuity-subject-restart` PASS (`docs/plans/aien-continuity/CAMPAIGN-v0-PREREG.md` line 22) |

**Gaps.** (a) The acceptance step is a SIGKILL mid-objective followed by completion of the same objective. What exists proves refusal and non-duplication after faults; no receipt shows an interrupted objective being finished after restart. (b) Aien is not bound into the compose path: "MISSING_IMPLEMENTATION" (`CAMPAIGN-v0-PREREG.md` status table), so identity continuity and effect continuity are proven separately, not together. (c) Native Aienux recovery blocked on storage (E4 gap c).

## 3. Component findings outside the six steps

- **AEGIS (aegis-runtime `f4e87095`).** Last functional change 2026-10-01 (#35); the default inference backend returns a mock regardless of the model path given (`src/inference.rs:504-515`, verified); the heartbeat polls Modular MAX on port 18006 (`src/heartbeat.rs:109`, scout) although MAX was left by decision (2026-10-02); README states a 30 s heartbeat, code defaults to 60 s; README calls the vault a hardware TPM and also says "not a TPM". AEGIS as it stands is not on the path of any acceptance step; the interplane adapter links it only for `pre_dispatch_check` (scout).
- **RSI (spark-rsi `24f412f6`).** Daemon loop Observe, Propose, Verify, Balance, Ratify; ledger in SQLite; sandboxes via docker or bwrap; depends on MAX 18006 and Cortex 18080 in code (`src/main.rs:150-200`, scout); needs a sibling `../aien-protocols` checkout to build (`Cargo.toml:43-45`, scout) although the README says standalone; one Python script remains (`scripts/drive_aien_code.py`, scout). Judge receipts: see E5 gap (b).
- **FORGE (physics `8b23e5a2`).** The driver-layer lifecycle, submission and allocation API consumed by omega through `physics.lock`; host gates run six jobs, five chip jobs are SKIP-only in CI (chip time is local); evidence folders AR2, FORM0, M19R, PD0B, m15, m16; open issue physics#2 (physical frame authority, needs a boot). The GB10 out-of-memory root cause (forced-contiguous main context buffer, omega#327) is documented; the mitigation is the reservation path, not a driver fix.
- **Protocols (aien-protocols `66610096`).** Nine crates; only `osc-unit-artifact` is FROZEN; `evidence-receipt` has a SUBSET only; OSH Platform ABI v1 is an open DRAFT PR (#16, checks green). The acceptance test's receipt and verdict shapes have no frozen home yet.
- **INTERPLANE (interplane `f1cc43cd`).** 80 Python files and 74 Rust files in the tree; the AIEN adapter itself is Rust and pins aien-sovereign-core at `9b5e6e8` (scout); qualification runs on a self-hosted runner by hand. Drake's "no Python in any repo" rule and INTERPLANE's examples disagree; INTERPLANE is declared to belong to neither side. Recorded, not resolved.
- **Aienux (aienos `e90226ba`).** All 24 QEMU CK gates PASS at `7f0de7e` (#295); native GB10 bring-up B4 to B7a merged 2026-10-10 (#296 to #299), B7b hardware boot needs a machine window; M4 storage native atomicity FAIL waits on TRUST-1 (#32); M5, M6, M7, M8 open (#32 to #35). Native Aienux is NOT_RUN for every acceptance step.
- **Omega (omega `16e729b6`).** Substrate, numerics, GPU engine, OSH, `rx_cortex`, the AT evaluators; 0 open PRs; open issues are research tracking (#358, #371), OSH follow-ups (#344) and two GB10 performance and memory items (#327, #328).

## 4. Discrepancy register (plan or document wording versus code)

| # | document says | code or receipt says | where |
|---|---|---|---|
| D1 | `cortex-rs/README.md`: "the canonical memory engine" | ADR 0022 (accepted 2026-09-30): canonical Cortex owner is omega `rx_cortex` | aien-sovereign-core `crates/cortex-rs/README.md`; aien-architecture `docs/adr/0022-canonical-cortex-owner.md` |
| D2 | `RELEASE_NOTES.md` and `TEST_READY.md` describe live Modular MAX inference (port 18006) and ONNX encoders as part of the release | decision "leave MAX, no CUDA" (2026-10-02); the qualified path is the native Omega engine; `spark-max-rs`, `spark-max-cabi` still in the workspace | aien-sovereign-core root docs and `crates/` |
| D3 | `aegis-runtime/README.md`: in-process native inference, 30 s heartbeat, TPM vault | mock backend by default, 60 s, "not a TPM" in the same README | aegis-runtime `src/inference.rs:504-515`, `src/main.rs:181` |
| D4 | `release/candidate.toml` CAND-4 is "the candidate this tree is allowed to be released as" | every main is weeks past the CAND-4 pins; the demos that PASS ran on code CAND-4 does not contain | `qualification/candidates/CAND-4.toml` vs mains above |
| D5 | `docs/02-implementation-status.md` snapshot 2026-09-23 (rows updated 2026-10-01); `docs/11-gap-analysis.md` undated | code moved through 2026-10-10 (Aien demo, NEXT-PHASE-2, approval desk default, OSH, Aienux B7a) | aien-architecture `docs/` |
| D6 | `CURRENT_EXECUTION_PLAN.md` last addendum 2026-10-08 | merges of 2026-10-09 and 2026-10-10 in every repo are not reflected; the plan does not name the whole-system acceptance test | aien-architecture `CURRENT_EXECUTION_PLAN.md` (`60c92db`) |
| D7 | spark-rsi README: standalone build; evidence receipt cites CI "Test & Invariant Verification" | needs `../aien-protocols` sibling; workflow is "Sovereign CI" | spark-rsi `Cargo.toml:43-45`, `.github/workflows/ci.yml` |
| D8 | physics driver header: "shared by M16 qualification and M17" | no M17 directory | physics tree |
| D9 | `DEMO-v1.md` requires a restart step | the restart receipts exist only from v3 onward (S5), and are graceful stops | aien-sovereign-core `docs/campaigns/allen-e2e/` |
| D10 | interplane README: "no model, no GPU, no network" offline example | the example is `python3 examples/offline/run_offline.py`; the org rule is no Python | interplane `README.md` |

Correction (2026-10-16, #198): the D9 row overstates the gap. In aien-sovereign-core `docs/campaigns/allen-e2e/`, S5 in v1 and v3 is a `kill -9` restart (exit 137, `receipts-v1.jsonl`, `receipts-v3.jsonl`, both PASS; v2 S5 is NOT_RUN). Only the v4-gb10 S5 is a graceful stop, by the chip safety rule, and `DEMO-v4-gb10.md` already says so and points to the CPU legs for `kill -9` evidence. No demo document needs a change for D9.

## 5. The gap list, ranked by what blocks the acceptance test

1. **No single run chains the six steps.** The pieces exist on the Linux host for E2 to E6 in separate campaigns (Aien demo, NEXT-PHASE-2, golden path). The first integration lane is a harness that runs them as one objective with one receipt chain, and the acceptance contract (R3) that fixes receipt and verdict shapes.
2. **E6 as specified is unproven.** SIGKILL mid-objective then completion of the same objective has no receipt; today's proofs are refusal and non-duplication. Needs durable objective state plus a resume path, and the grant broker to survive restart or to re-issue grants deterministically.
3. **Memory ownership.** One store must be named for the E4 recall (ADR 0022 says omega `rx_cortex`; the demos recall from `aien-allen-memory`). Either an ADR amendment or a binding of the Aien store onto the canonical journal.
4. **Independent verifier for whole-system runs.** Separate code from the executor, a frozen receipt and verdict identity (aien-protocols `evaluation` or `evidence-receipt`), and a second-machine run. The AT-1 evaluator is the pattern that already works.
5. **Release artifact for current mains.** A CAND-5 manifest, a signed release from it, and the offline signing key (Drake). Until then E1 can only be rehearsed with the throwaway-key dry run.
6. **Operator surface.** One entry point that takes a free-form objective and reaches the real approval desk; the cockpit's placeholder approvals either wired to the desk or removed.
7. **Native Aienux.** Every step NOT_RUN; blocked on TRUST-1 and storage atomicity (aienos#32, #31), native inference (#34), Cortex persistence (#35), and a machine window for B7b. The acceptance test's first PASS will be on the Linux host; the native target is a second lane, not a reason to wait.
8. **Dead or stale components.** AEGIS runs a mock model and polls MAX; spark-rsi depends on MAX and Cortex HTTP; both need a decision: bring onto the native path, or declare out of the release and say so in the docs.

## 6. Drake's call (collected, non-blocking)

1. Offline release-signing key (aien-sovereign-core#118). Without it there is no public release; with it the release lane can run.
2. Release model: stay internal-only on Llama 3.2, or run the SmolLM2 or Qwen3 qualification to the end for an open-licence release.
3. AEGIS and spark-rsi: in the release (then they move to the native inference path) or out (then the docs say so).
4. Machine window for Aienux B7b hardware boot and the memory-map capture (physics#2 step 1).
5. The int8 kernel default (aienos#300, plan on aienos#34).

## 7. What this file does not claim

It does not claim that any acceptance step passes. It does not grade the research programs (AT-0, AT-1, Brownian), which are closed or on record elsewhere. Where a scout's reading is the only source, the row says UNVERIFIED and the next reader should open the file before relying on it.
