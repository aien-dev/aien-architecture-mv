# Release readiness, R2: prioritized integration plan

**NOT A MASTER PLAN.** Tracking issue: aien-spark/aien-architecture#190 (R2 deliverable). `CURRENT_EXECUTION_PLAN.md` owns cross-project sequencing; section 8 of this file is the text proposed for it, filed as its own pull request. This plan orders the lanes that close the gaps of `GAP_ASSESSMENT.md` (R1) so that WHOLE-SYSTEM-E2E can run once, end to end, on the Linux host, and then again from an installed signed artifact. Every lane names the acceptance step it unblocks; a lane that unblocks none is not in this plan.

Written 2026-10-10 by the coordinating session (Claude Code 85679b2b). Status words are NOT_RUN until a receipt exists; nothing below is a claim that a step passes.

## 1. Rules the lanes obey

1. **Pre-registered acceptance before code.** Each lane's acceptance rows are frozen in a document (with its commit) before the implementation PR opens, as NEXT-PHASE-2 did (`ACCEPTANCE-v2.md` frozen at `a564c61` before code). A row is PASS only if every repetition passes and its negative control fails as predicted; NOT_RUN is never PASS.
2. **Receipts chain to the objective.** Every receipt written during a run names the objective identity (lane L0 fixes the shape), so one run yields one chain, not six folders.
3. **No new store, no new daemon, no new language.** Shell plus `jq` for harnesses, Rust and C for code, no Python, no systemd, no network during a run, no CUDA (the native Omega engine is the GB10 path).
4. **Host rehearsal, native release.** The frozen WHOLE-SYSTEM-E2E v1 contract is a hosted rehearsal/reference. The release finish is the native Aienux workflow and physical N1-N7, following the governing native order and its separately frozen E1-E6 adaptation. Updated by Drake's 2026-10-14 direction, recorded in the execution plan; a hosted PASS does not finish the native release.
5. **Issue-first.** Each lane has a component issue; milestones are comments on #190; merged PRs and receipts are the only status.
6. **Owner decisions have explicit boundaries.** Independent preparation continues while an owner decision is pending. The affected physical boot, disk/firmware change, signing ceremony or recovery experiment waits for its required decision and attended authorization. Section 6 records the earlier rulings; later accepted decisions and the execution plan govern.

## 2. The lanes

| id | lane | unblocks | depends on | repo | done when |
|---|---|---|---|---|---|
| L0 | Acceptance contract: `ACCEPTANCE_E2E.md` frozen (objective identity, receipt chain shape, verdict identity, refusal codes, the six negative controls) | all | none | aien-architecture, aien-protocols | contract file with its freeze commit and digest; `aien-protocols` evaluation spec amended from Draft to name the verdict identity (R3) |
| L1 | One chained harness: `whole_system_e2e.sh` runs E2 to E6 as one objective on the host, reusing the Aien demo steps and the NEXT-PHASE-2 fault harness, writing one receipt chain | E2, E3, E4, E6 (chain) | L0 | aien-sovereign-core `scripts/` | harness merged; a dry run on CPU writes a complete chain with every row NOT_RUN or PASS as measured (no PASS claim yet) |
| L2 | Interrupt and finish: durable objective record, `resume` that completes unspent steps after a SIGKILL, grant broker state that survives restart or is re-issued deterministically after reconcile; SIGKILL rows added to the fault harness | E6 | L0 | aien-sovereign-core `crates/aien-runtime`, `crates/aien-mcp` | SIGKILL mid-objective, restart, same objective finished, no effect twice, receipt chain unbroken, 3 repetitions; negative: restart without durable state gives a named refusal |
| L3 | Memory owner for E4: ADR amendment naming the store the E4 recall must come from (default assumption: the Aien scoped store is a scoped view whose records are journaled into the canonical omega `rx_cortex` journal, ADR 0022 unchanged); `cortex-rs` README corrected (D1) | E4 | none | aien-architecture `docs/adr/`, aien-sovereign-core | ADR merged; recall in the chained run reads from the named store from durable files after an unclean stop |
| L4 | Independent verifier: a separate binary (extend `aien-campaign-verifier` or a new `aien-verify`) that reads only receipts and outputs, emits a verdict with the L0 identity, carries red controls (corrupted output rejected); built from a clean checkout on the MacBook for the second-machine verdict | E5 | L0, L1 | aien-sovereign-core, run on Spark and MacBook | same verdict identity on both machines for the same chain; red control rejected on both |
| L5 | Release for current mains: CAND-5 manifest, `release/candidate.toml` updated, release dry run green, `test-install-release.sh` run on a second machine; signed release when the offline key exists | E1 | none (key: Drake) | aien-architecture `qualification/candidates/`, aien-sovereign-core | dry-run release from CAND-5 passes the release gate; installed from the artifact, the chained run (L1) starts |
| L6 | One operator entry: `aien objective "<text>"` (or the existing `goal <text>` made real) creates the objective record and routes it to compose proposals through the required approval desk; cockpit placeholder approvals wired to the desk or removed | E2 | L0 | aien-sovereign-core `crates/aien-cli`, `crates/aien-runtime`, `crates/spark-cockpit-rs` | free-form objective recorded with its identity before any work; forbidden effect refused before execution; cockpit no longer shows approvals that do not exist |
| L7 | Documents tell the truth: D1 to D10 of the gap assessment fixed (release notes without MAX, AEGIS README, spark-rsi README and CI name, implementation-status refresh, physics header note, interplane README wording) | none directly; removes false status | none | each repo | every D row closed by a merged PR or by an explicit "kept, because" note |
| L8 | Stale components: spark-rsi `judge`, `cycle`, `daemon` accept a policy file so v2 receipts are the default; AEGIS and spark-rsi marked "not part of WHOLE-SYSTEM-E2E v1" in their READMEs (Drake rulings 3 and 4, section 6) | E5 (RSI receipts) | none | spark-rsi, aegis-runtime | v2 receipt from the CLI path with a test; README status lines merged |
| L9 | Native Aienux: unchanged NEXT-PHASE-3 order (operator input and recovery, boot selection and rollback, storage, trust and identity, native CPU inference, native GB10, GPU inference); the acceptance test's version 2 is written when step 5 closes | all, on the native target | machine window (Drake), TRUST-1 | aienos, physics | not in version 1; reported on #190 only when a step closes |
| L10 | Public model qualification: frozen qualification campaign for Qwen3-4B-Instruct-2507 (Apache-2.0) on the existing qualification harness; PASS or FAIL recorded; FAIL blocks the public bundle | E1, E3 (public bundle) | none (internal runs use CAND-4) | aien-sovereign-core, aien-architecture `qualification/` | frozen rows, receipts, verdict; CAND-5 names the model only after PASS |

## 3. Order

```text
L0 contract (R3)
  -> L1 harness, L2 interrupt-and-finish, L6 operator entry   (parallel; L3 beside them)
  -> L4 verifier
  -> RUN-1: whole test on the host, CPU model                   (R5)
  -> RUN-2: same on the GB10 (native Omega engine)              (R6)
  -> second-machine verdict (MacBook)                           (R7)
  -> L10 public model qualification (Qwen3-4B-Instruct-2507), PASS required for the public bundle
  -> L5 release rehearsal, then RUN-3 from the installed artifact (R8; signed only after the key ceremony)
L7 docs and L8 stale components run beside everything from day one.
L9 native follows its own decided order.
```

Why this order. L0 first because every receipt and every verifier needs the identity shapes; building the harness before the contract would freeze accidental shapes. L1, L2 and L6 are independent code lanes in the same repository and can run in parallel without touching the same files (harness script, runtime resume path, CLI entry). L4 needs real chains to verify. The first run is on CPU because the GB10 needs a quiet window and the CPU path is already PASS in the Aien demo; nothing in E2 to E6 depends on the accelerator. The release lane is last among the version-1 lanes because a release of code that cannot yet pass the test proves nothing, but its manifest and dry run can be prepared any time.

## 4. Milestones on #190

| id | milestone | evidence |
|---|---|---|
| R3 | L0 contract frozen | `ACCEPTANCE_E2E.md` commit and digest; protocols spec PR merged |
| R4 | L1 harness merged, first dry run recorded | chain folder with every row's measured status; no PASS claim |
| R5 | RUN-1 verdict (host, CPU) | verifier verdict identity, chain, negative controls, limits |
| R6 | RUN-2 verdict (host, GB10) | same, with the backend identity line |
| R7 | second-machine verdict agrees | MacBook verifier output with identical verdict identity |
| R8 | RUN-3 from an installed artifact | install receipt, chain, verdict; signed release only after the key ceremony and with the L10-qualified model, else dry-run artifact and the gaps stated |

Each milestone comment carries OBSERVED, INFERRED and NOT CLAIMED lines and a limits list, as the AT-1 reports did.

## 5. What is not in this plan

Research programs (AT-0, AT-1, Brownian, Physics Zero) are on record and closed or parked; they do not consume this program's lanes. Networking (Aienux M6) stays outside the native prerequisite chain by the 2026-10-08 decision. Phone agent and voice stay PARKED. The public model qualification is lane L10 (Drake ruling 2, section 6).

## 6. Drake's rulings of 2026-10-10 (these replace the earlier default assumptions)

Recorded on #190 (comment of 2026-10-10). Decisions, not claims that any has been carried out.

| item | ruling | effect on the lanes |
|---|---|---|
| 1. offline release-signing key (sc#118) | new dedicated offline Ed25519 key; private key never on GitHub, CI or production machines; witnessed generation ceremony, verified backup, public-key verification test before release; the internal-test key is not reused; a CI secret does not qualify | L5 gains an offline-signing handoff in the release workflow (sign offline, publish signature and public key only); until the ceremony has happened RUN-3 installs a dry-run artifact and says so; a dry-run signature is never a public-release signature |
| 2. release model | Qwen3-4B-Instruct-2507 (Apache-2.0) is the selected public candidate, conditional on a frozen qualification PASS; Llama 3.2 (CAND-4) is internal-test only; a failed qualification blocks the public bundle, no silent substitution | new lane L10 (model qualification) ahead of the public bundle in L5; RUN-1 and RUN-2 may use the internal model, RUN-3 public needs the qualified one |
| 3. AEGIS | standalone AEGIS out of v1; capability checks, approval desk, effect authorization and fail-closed behaviour stay in the runtime | L8 README status lines state it; no AEGIS lane on the critical path |
| 4. RSI engine | out of v1 active runtime; development and evaluation continue independently; no unattended self-modification or automatic promotion | L8 README status lines state it; the v2-receipt fix still lands as component work |
| 5. Aienux hardware boot (B7b) | preparation authorized, no unattended boot; first operator-confirmed two-hour attended window after recovery media, rollback, trust and preflight checks pass | L9 adds the attended-window prerequisites checklist; the boot itself waits for Drake in the room |
| 6. int8 kernel default (aienos#300) | promotion approved for supported GB10 hardware, subject to native qualification: CPU-feature detection, numerical parity, rollback, native regression tests; f32 fallback retained | aienos#300 proceeds as a gated promotion; no effect on version 1 of the test |

AT-1 C10 is deferred (INCONCLUSIVE); it takes no main engineering capacity and may be run later by an independent operator with separate credentials.

Governing instruction (Drake): execute WHOLE-SYSTEM-E2E through a qualified public release; continue all independent engineering while human-controlled prerequisites wait; never treat a dry-run signature as a release signature, a failed qualification as a pass, or an unattended hardware operation as authorized; no speculative subsystems on the release critical path.

## 7. Risks named now

- **Shape drift.** If L1 starts before L0 freezes, the chain shapes will be whatever the demo already writes. Mitigation: L0 is one document and one spec amendment, days not weeks; L1 waits.
- **Two definitions of "memory".** Until L3 lands, E4 could be claimed from the Aien store while ADR 0022 names another; the verifier would then check the wrong thing. Mitigation: L0 names the store the recall is read from, L3 makes it true.
- **The GB10 window.** RUN-2 and the reservation path need a quiet hold; the Spark serves other agents. Mitigation: RUN-1 on CPU carries every logical check; RUN-2 adds only the backend identity.
- **Second machine drift.** The MacBook has a different libc, compiler and shell (AT-1 G7 experience: bash 3.2, no `llvm-nm`). Mitigation: the verifier is std-only Rust built by `rustc` directly, as the AT-1 oracle is.

## 8. Proposed addendum to `CURRENT_EXECUTION_PLAN.md` (filed as its own PR)

> ## Addendum 2026-10-10: release-readiness program and the whole-system acceptance test
>
> Drake's decision of 2026-10-10: AT-1 is closed as REVIEWED, no AT-2 is chartered, and the principal effort is finishing AIEN as one usable system. The program runs issue-first on aien-spark/aien-architecture#190 with a finite plan under `docs/plans/release-readiness/` (NOT A MASTER PLAN).
>
> The stage "INTEGRATED AIEN + CORTEX + RSI" of section 3 gains a gate on the host path: WHOLE-SYSTEM-E2E (E1 install, E2 objective, E3 execute, E4 memory, E5 verify, E6 recover; receipts and negative controls per step; `docs/plans/release-readiness/ACCEPTANCE_E2E.md` once frozen). Status 2026-10-10: NOT_RUN. The native Aienux order of the 2026-10-08 (late) addendum is unchanged; the native target takes version 2 of the test after its step 5.
>
> Current baseline corrections (code and receipts, read 2026-10-10): Aien demo v3 PASS 10/10 (CPU) and v4-gb10 PASS 10/10 (GB10, native Omega engine, no CUDA) at aien-sovereign-core `docs/campaigns/allen-e2e/`; NEXT-PHASE-2 ACCEPTANCE-v4 PASS (`docs/campaigns/next-phase-2/VERDICT-v4.md`); approval desk required by default (sc#342); golden path PASS on the GB10 at `fefce80` (sc#94). No signed release of any current main exists; CAND-4 is the only candidate manifest. The ten discrepancies of `GAP_ASSESSMENT.md` section 4 stand until closed by lane L7.

## 9. Delivery control on #190 (Drake, 2026-10-14)

This section implements the owner direction recorded in the 2026-10-14 addendum of `CURRENT_EXECUTION_PLAN.md`. It is a delivery aid within the existing release program, not another master plan. Native v1 and physical N1-N7 are the release finish. The original hosted E1-E6 contract remains frozen and supplies the reference/rehearsal; the native adaptation must be frozen separately before native acceptance.

### One candidate and one ledger

The current authorized native pins are RC-1 from the execution plan's 2026-10-12 pin entry. New work targets its controlled successor. The successor is not frozen by this section: open PR heads and live default branches do not replace RC-1. Source, consumed dependencies, builds, models, policy, firmware and acceptance artifacts must first be reconciled into the immutable candidate manifest described by the execution plan.

#190 records each workstream's owner/claim, target gate, actual inputs, next packet and disposition. Component issues own implementation and store their evidence. A delivery from newer component code can be accepted as readiness evidence, but receives no whole-system gate credit until the integrated path runs on the designated frozen candidate. Candidate mismatch, skipped cases, failed controls or unproved independence keep the gate unresolved.

More than half of active implementation capacity goes to the critical-path rows below, which receive first claim on shared hardware and qualification windows. Synapse, Atlas evaluation and RSI each carry one active bounded deliverable within the remaining capacity. Each owner records a resource request before starting a shared build/model/device run, so parallel work cannot silently contaminate a qualification window.

### Owning workstreams and required packets

| Workstream | Owning issue(s) and proposed work | Next packet to #190 | Release relationship |
| --- | --- | --- | --- |
| Required verification | sovereign-core #518 / PR #520; aienos #382 / PR #385; omega #424 / merged PR #427; Synapse #66 / PRs #71 and #73 | Candidate-specific required-check matrix, real execution logs, pinned sibling identities, negative controls and actual branch-protection readback. Record missing/disabled tests and unresolved local-gate defects explicitly. | P0 freeze prerequisite. A green report without executed controls cannot promote. |
| Trusted execution and approval | aienos #383 / PR #384; Omega independent checker; accepted ADR 0037 | Production image and public authority identities; authorized launch; named refusal for forgery, corruption, stale/revoked/missing evidence, wrong code/target and approval bypass; independent verification. Slot image signing follows ADR 0037 Option A; receipt/checker authority is documented separately. | Critical path, E1/E3 and native trust prerequisites. A realization receipt grants no capability. Source-to-executable semantic equivalence is a separate milestone. |
| Native operator, storage and CPU workflow | aienos #31, #34, #35 and #336 | One production image with operator input, bounded real-model response, exact artifact approval, cancellation, durable memory/artifact recall after cold boot; build/staging packet and backup/recovery prerequisites. | Critical path, N1-N3 and E2-E4. Storage preparation precedes its attended change. |
| Real-model 30B and persistent KV | omega PR #439; sovereign-core PRs #510/#514 and issues #507-#509 | #507 token-identical uninterrupted/restored continuations and fail-closed corruption/stale/identity controls; then #508 disabled/warm/genuine cold-NVMe at 1/2/4/8 conversations with raw latency/TTFT/throughput/memory/I/O/encryption evidence; then #509 safe opt-in, monitoring, recovery, disabling and rollback. | Critical inference qualification/reference. All three gates precede default enablement. Linux-hosted evidence never closes N4/N5. |
| Native GB10 and FORGE | aienos #286, then #327; existing Omega platform and FORGE dependencies | Cold-state provenance; bounded device ownership and confinement; known integer-vector output verified in full; failure and clean resource release. After N3/N4, one frozen native model with declared backend and no silent fallback. | Critical path, N4 then N5; existing physical prerequisites and attended windows apply. |
| Native recovery and installation | aienos #333; sovereign-core #118 for hosted release tooling | Signed update/install identities; interrupted update/execution cases; invalid-signature refusal; known-good native recovery with preserved approved state and no duplicated effects; offline recovery procedure and double-build hashes. | Critical path, E1/E6 and N7. Linux return is a development safety net, not N7 recovery. |
| Atlas independent evaluation | architecture #222; reuse sovereign-core #403 for CTRL-E5 and `tools/aien-verify/` for E1–E6 (the separate `crates/aien-campaign-verifier/` judges C1 campaigns) | Frozen held-out ambiguity/clarification/refusal/escalation cases; per-case outcomes; evaluator/executor separation; real-chain and corrupted-output verdicts, including the required second-machine comparison. | Bounded parallel preparation for E5/N6; evaluation grants no authority. This role does not redefine the `atlas` bootstrap-seed repository. |
| Synapse coordination and migration | Synapse #66, #60 and #8; security PRs #69/#70/#72; CI PRs #71/#73 | Publication/trust/delegation refusals, service-API coordination and group-commit recovery, interrupted writes, bounded reads, preserved conflicts, backup/restore and independent verification; Git interop and rollback evidence before cutover. | One bounded parallel delivery at a time. No whole-agent migration until #8 gates pass; no diversion of critical hardware windows. |
| RSI controlled improvement | spark-rsi #54; existing `src/promotion_gate.rs`, `src/ratify.rs` and v2 receipt tests | One independent v2 CLI evaluation binding exact subject/hold-outs/policy/judge; refusal of stale/altered/self-judged evidence; review branch and patch only, with unchanged protected/default branches. | Bounded parallel work, outside the native v1 runtime. No unattended self-modification or automatic promotion; no prerequisite on recursive improvement. |

References in this table are ownership/delivery links, not PASS claims. Execution owners and claims are recorded on those issues; newly scoped Atlas and RSI tasks start unassigned rather than implying a worker is running.

### Evidence delivery record

Each owner posts this record on #190 with links to immutable component evidence. These fields wrap or accompany existing receipts; they do not change a frozen signed format.

```text
Owner / owning issue / PR:
Target gate and frozen acceptance contract (revision + sha256):
Candidate id / manifest revision / manifest sha256:
Actual source revisions and consumed lock/vendor/protocol/tool pins:
Image / executable / model / tokenizer / config / firmware / public-authority hashes:
Machine and evidence class (host CPU, Linux-hosted GB10, QEMU, Pi, physical native Spark):
Exact build/run commands or attended actions, declared inputs and resource window:
Per-case results, repetition counts and every negative-control outcome:
Objective/run identity and receipt-chain or delivery-manifest digest:
Immutable raw-evidence location, artifact checksums and independent verdict:
Verifier build/authority and evidence of separation from executor:
Unresolved defects, limitations, dependency/owner blockers and next action:
```

Before successor freeze, the candidate field explicitly says `successor NOT_FROZEN` and identifies the development inputs; readiness records cannot masquerade as candidate acceptance. Private keys, unlock secrets and tokens never enter this record.

The coordinator checks the manifest and consumed inputs, verifies evidence checksums and controls, and obtains the independent verdict before crediting a gate. Missing cases remain NOT_RUN; failed controls remain FAIL; unavailable independence is recorded INCONCLUSIVE/UNISOLATED. A signed receipt alone does not turn a component demonstration into an integrated PASS.

### Integration and freeze sequence

1. Repair and enforce the required verification gates, including the evidence-immutability and missing mutation/portable CI controls. Preserve same-commit/pinned-input receipt identity and existing requirements.
2. Reconcile the proposed engine/server/KV and signed-execution changes with the merged production native workflow and recovery path. Deliver component readiness evidence in the dependency order above.
3. Resolve consumed pins and exact build/model/policy/authority identities; freeze the native E1-E6 adaptation, resource limits and controls. Assemble the reviewed successor manifest and clean double-build/recovery packet. Record the new pins in the execution plan and the immutable manifest on #190.
4. Run the acceptance campaign on that candidate, preserving the native prerequisite order and separate attended approvals. Qualify 30B/KV correctness before performance and operations; qualify first native integer computation before native-model execution.
5. Independently judge the complete E1-E6/N1-N7 evidence against the same candidate. A candidate change starts a successor and reruns affected and integrated gates. Release approval waits for the complete reproducible and recoverable native result and the existing public-release gates.

No physical boot, disk change, owner ceremony, firmware action, default KV enablement, agent migration or release publication is authorized by this delivery document. Those actions retain their governing prerequisites and owner decisions. Independent preparation continues while they are pending.
