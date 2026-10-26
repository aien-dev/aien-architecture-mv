# spark-rsi inventory (Milestone 0, read-only scout)

Repo: ~/workspace/adaptive/spark-rsi, commit 24f412f (PINS.txt confirms main). Nothing edited; no build/test run (reading only).
Note: every `.crumb` in this repo has empty `"role": ""` fields (src/.crumb, tests/.crumb), so the Crumb gave no role/invariant text. Evidence is source only.

## Classification

| Capability | Class | Key evidence |
|---|---|---|
| Daemon cycle (ledger, holdouts, signer, propose, jail build, judge, supervisor, ratify) | Implemented and integrated | src/daemon.rs:26-612 |
| Observation of the target repo | Experimental (weak) | src/observe.rs:168-186 (keyword scan + `cargo check`) |
| Capability graph / bottleneck ranking | Implemented but disconnected from real measurement | graph/mod.rs:171-210; daemon.rs:66-99 literals |
| Hypothesis contract | Implemented and integrated, fed by fake numbers | daemon.rs:112-130 |
| Isolated evaluation (BlindJudge, bwrap, holdouts) | Implemented and integrated | daemon.rs:359-383; actor/judge.rs |
| Signed promotion (receipt v2, exact-artifact binding) | Implemented and integrated | evaluator/mod.rs:58-257; promotion_gate.rs; daemon.rs:525-556 |
| Production canary observation admission | Implemented, integrated, but never fed (fail-closed) | canary_observation.rs; daemon.rs:445-449 |
| Measured execution feed (real canary traffic) | Missing | daemon.rs:437-439; no non-test sender of CanaryReport |
| Supervisor (in-repo) | Implemented but disconnected from the observation path | src/supervisor/*; daemon.rs:417-435 |
| Cortex client | Implemented and integrated, HTTP only | propose/cortex.rs:77-110 |
| Cortex store coupling (cortex-rs vs omega CxStore) | cortex-rs HTTP API; omega absent | see sec 4 |
| DUAL scarcity reader | Implemented but disconnected by design (diagnostic only) | daemon.rs:103-109 |
| Meta/tier governance, A/B fork | Experimental | src/meta/*; daemon.rs:210-270 |
| Soak runner | Experimental, duplicates daemon graph literals | soak/runner.rs:158-191 |

## 1. src/daemon.rs main loop
- `RsiEngine::run_cycle` (daemon.rs:26) is one cycle, not a long-running loop. A loop is outside (main.rs:645 logs cycle errors; UNVERIFIED how main.rs repeats, not read in detail, confidence 60%).
- Order: open ledger (:33), require holdouts dir (:41-52), require P-256 signing key (:55-61), observe (:64), build graph (:65-99), top bottleneck (:101), hypothesis (:112-130), Cortex recall (:132-139), proposals from MAX model + unslop scan (:142-182), per-candidate loop (:195-410): declared-target gate (:198), tier/operator check (:211-270), stage in sandbox (:272), bwrap `cargo build --release --offline` (:290-325), invariants (:327+), BlindJudge (:359-383), ledger append (:386), break on first admitted (:409).
- Observations enter in ONE place: `observe_codebase(repo_path)` (daemon.rs:64). It returns a TelemetrySnapshot of git state, crumbs, `cargo check` result and a keyword "soul tension" score (observe.rs:168-186; keyword lists observe.rs:6-58). It contains no latency, memory or throughput of the target.
- Production canary empty array, quoted (daemon.rs:437-449):
  ```
  // Production promotion counts measured observations only.
  // This cycle has no execution feed, so the quota fails closed.
  // A caller-supplied success and a fixed latency are not observations.
  ...
  let quota = crate::canary_observation::admit_production_quota(
      &[],
      &candidate_digest,
      config.canary_target,
  );
  ```
  Default `canary_target` is 5000 (models.rs:171, :152), so `&[]` always errors "received 0" (canary_observation.rs:94-98). Failure path: rollback + ledger rollback + Cortex lesson (daemon.rs:451-465). The `else` promotion branch (:466+) is therefore unreachable in the production daemon today.
- Test confirms: tests/test_no_synthetic_trust_inputs.rs:~300-329 asserts the cycle "must not promote on a synthetic canary quota" and active symlink absent.

## 2. src/canary_observation.rs
- Struct (lines 17-25): `observation_id: String`, `observed_at_ms: u64`, `candidate_digest: String`, `latency_us: u64`, `status: String`, `provenance: Measured|Synthetic` (enum :11-15).
- Identity/digest: `canonical_bytes` (:34-49) alphabetical-key JSON; `digest_hex` SHA-256 (:51-53). Timestamp field exists but is not validated (no freshness/monotonic check in :56-101; UNVERIFIED beyond this file, confidence 85%).
- Dedupe/replay: BTreeMap by observation_id; identical record counted once, different record under same id errors (:64,82-91). Candidate digest must equal (:73). Synthetic rejected (:76-80). Empty id/status rejected (:67-72).
- No source field naming who measured it (no signer, no worker/process identity, no signature). `Measured` is a self-declared label: any caller can set it. Biggest design gap for M5.
- Only caller: daemon.rs:445 (plus a path-listing in tests/test_dual_price_reader.rs:821). Unit tests at :116-166.

## 3. src/evaluator/ and the judge
- evaluator/mod.rs: `EvaluationReceipt` (:32-56) with `receipt_digest`, `signature`, version, optional `ReceiptBindingV2` (:58-73): subject path + SHA-256 of exact bytes (:63), `holdout_set_sha256` (:66), holdouts total/passed (:67-68), policy SHA-256 (:69).
- "Exact-artifact": a v2 receipt signs the SHA-256 of the exact bytes of one subject file in the candidate tree, the holdout set digest, and the policy digest (evaluator/mod.rs:58-70, :143-170). `verify_for_promotion` (:221-257) refuses v1, wrong key, wrong policy/holdouts, mismatched identity. daemon.rs:525-533 passes `content_sha256 = candidate_digest` and re-reads disk digest of the generation right before swap (:536-545). Docs: docs/RECEIPT-V2.md.
- Holdouts: `HoldoutSuite::load_strict` (actor/judge.rs:236-310) fails closed on missing/corrupt/empty/duplicate-id/non-json entries; set digest domain `spark-rsi.holdout-set.v1` (:86). Cases run through bubblewrap `CandidateJailRunner` (:413-419).
- Layers: evaluator/layers/{correctness,performance,resource_efficiency,security,style,longitudinal_replay}.rs. Real measurement exists inside the judge: getrusage and /proc statm (evaluator/metrics.rs:37-38, :110-121) and paired parent/candidate benchmarks of child processes (judge.rs:914-950). This is lab measurement of a candidate binary, not production traffic.
- Signing: P-256 ECDSA over receipt digest (evaluator/mod.rs:259-286); signature string prefix "tpm2-p256:" but key is a software key from `signing_key_hex` (daemon.rs:55-61); also SoftwareP256Signer for the envelope (daemon.rs:469-471). TPM use UNVERIFIED (confidence 70% it is software only).
- Note the daemon passes parent label "parent" (daemon.rs:370) and uses `scan_and_propose_unslop` text edits plus a MAX-model patch to `src/lib.rs` (daemon.rs:146).

## 4. src/propose/cortex.rs
- Not a store: an HTTP client (reqwest) to `{base_url}/api/cortex/search?q&space&limit` with bearer token (cortex.rs:77-90). Read-only recall; lessons are written in `Ratifier::record_cortex_lesson` (called daemon.rs:393, 458, 517; implementation in src/ratify.rs, not read in detail).
- Token: env CORTEX_TOKEN or `~/.config/cortex/token` (cortex.rs:56-75). Default URL http://127.0.0.1:18080 and space "atlas-memory" (models.rs:160-161; cortex.rs:40). AGENTS.md:47-49 names `cortex-rs` as the canonical memory at `/api/cortex/`.
- Verdict: legacy Rust cortex-rs HTTP API (service). It does NOT use omega's C CxStore. Cargo.toml has NO dependency on cortex-rs or omega (checked: grep for cortex-rs/CxStore/cx_store in Cargo.toml, src, docs, README, AGENTS.md gives only AGENTS.md:47). Space "atlas-memory" is the legacy area that AGENTS.md says not to use for new entries (root AGENTS.md); aien-lessons/aien-sources not referenced here. Failure of recall silently returns empty Vec (cortex.rs:108).
- Cargo.toml path deps: `../aien-protocols/crates/{aien-protocol-types,aien-evaluation-protocol,aien-probe}` (sibling dir exists in workspace), plus git deps spark-crumbs, crumb-spec.

## 5. Hardcoded capability-graph measurements
Graph nodes are the RSI pipeline's own stages, not the target system being improved.
| Where | Literal values (p95 us, RSS KB, error rate) | Real source? |
|---|---|---|
| daemon.rs:66-69 Observe | 50.0, 1024, 0.0 | None |
| daemon.rs:71-77 Propose | 400.0, 4096, 0.25 if drive_score>0.8 else 0.0 | error_rate derived from keyword count (observe.rs:64), not an error measurement |
| daemon.rs:78-81 BuildJail | 150.0, 2048, 0.0 | None |
| daemon.rs:82-85 JudgeEvaluation | 250.0, 8192, 0.0 | None |
| daemon.rs:86-89 SupervisorCanary | 100.0, 4096, 0.0 | None |
| daemon.rs:90-93 CortexCommit | 50.0, 1024, 0.0 | None |
| daemon.rs:95-99 edges | 400/150/250/100/50 us, freq 1.0 | None |
| soak/runner.rs:158-191 | same set plus Graph 120/2048, edges 120 | None |
| daemon.rs:420,422,423 supervisor budgets | memory 49152 MB, max latency 1_000_000 us, error rate 0.0 | policy limits, not measurements |
| tests (graph/mod.rs:260-272; tests/test_explain_evidence_graph.rs:31-49; fixtures/rsi_kv_cycle.evidence.json) | fabricated kv/scheduler numbers | synthetic by design |
Consequence: the top bottleneck and the hypothesis target `latency_us` with `b.latency_p95_us` and a 15.0 delta (daemon.rs:124-126) come from these literals. "Propose" is always the hot node unless drive_score changes. No production source feeds CapabilityNode (the only setter is `with_resource_metrics`, graph/mod.rs:28; no reader of telemetry produces latency). Score weights 0.4/0.4/0.2 are literal (graph/mod.rs:185).

## 6. Supervisor / executor feed
- In-repo supervisor: src/supervisor/{mod,daemon,ipc}.rs and bin `spark-rsi-supervisor` (src/bin/supervisor.rs, Cargo.toml). Host side receives `WorkerMessage::CanaryReport{generation_id, transaction_id, success, latency_us, error}` (ipc.rs:33; handled supervisor/daemon.rs:202-230) and does `record_canary_transaction` against `canary_target`, latency and error budgets. So the supervisor is a RECEIVER with a worker protocol.
- Senders: only tests and unit tests construct CanaryReport (daemon.rs:394,409,458,518; tests/test_host_supervisor_ipc.rs:81,94 with fixed latencies 1200, 1100). No production worker/executor process exists in this repo that sends reports (grep of `CanaryReport` in src shows only ipc.rs and supervisor/daemon.rs).
- Gap: the in-repo supervisor's own canary counter (supervisor/daemon.rs:202-230) is NOT connected to `admit_production_quota`; daemon.rs ignores it and passes `&[]` (:446). Two parallel canary notions: IPC counter vs CanaryObservation.
- spark-supervisor (archived on GitHub): no vendored copy and no dependency (Cargo.toml has none; `ls ..` shows no spark-supervisor dir; only `spark-inquisitor` sibling, role UNVERIFIED). The legitimate source would be a worker process embedded in the live inference/serving path (or the AIEN executor) reporting per-request latency/status over the supervisor socket, then converted to signed `CanaryObservation`s. Which crate that is: UNVERIFIED, no evidence in this repo (confidence 40% for "spark-inquisitor").

## 7. Tests
| File | Proves | Synthetic? |
|---|---|---|
| integration_tests.rs | balance kernel, soul tension, invariants, staging, fail-closed on missing holdouts/signer, end-to-end with candidate | Mixed |
| safety_envelope_tests.rs | wrong-key receipt never promotes | Synthetic keys |
| test_adversarial_containment.rs | holdout secrecy, net isolation, root-of-trust, forged receipt | Real jail |
| test_capability_graph_and_hypothesis.rs | graph topology on made-up numbers; live MAX tests | Synthetic graph; live MAX needs service |
| test_cryptographic_improvement_ledger.rs | hash chain, tamper detect, Merkle+ECDSA, daemon records provenance | Real ledger, synthetic cycle |
| test_dual_price_reader.rs | DUAL golden vectors, hostile inputs, "authority_paths" (diagnostic only) | Golden fixtures |
| test_explain_evidence_graph.rs | evidence graph, tampered receipt not a fact, matches tests/fixtures/rsi_kv_cycle.evidence.json | Synthetic kv graph |
| test_host_supervisor_ipc.rs | canary probation, rollback on defect/latency, unauthenticated worker rejected | Synthetic reports (fixed latencies) |
| test_max_inference_and_diagnosis.rs | MAX client, extraction, Cortex query | Needs live services |
| test_meta_improvement_governance.rs | tiers, operator signature, A/B fork | Synthetic |
| test_no_synthetic_trust_inputs.rs | jail blocks net, judge fails closed, paired benchmarks use real child-process metrics, daemon does NOT promote on synthetic canary | Real measurement for lab only |
| test_objective_evaluator.rs | rusage, latency stats, bootstrap, Fisher, six-layer | Real math |
| test_ratifier_branch_only.rs | ratifier writes review branch only, path/symlink/secret guards | Real git |
| test_receipt_v2.rs | v2 binding, promotion gate, holdout digest | Synthetic keys |
| test_soak_run.rs | quarantine after 3 failures, soak preflight | Synthetic |
- Separation by type: yes for canary evidence only: `ObservationProvenance::{Measured,Synthetic}` (canary_observation.rs:11-15) plus test `synthetic_rehearsal_cannot_fill_the_quota` (:138-143). No type-level separation elsewhere: the capability graph uses the same `CapabilityNode` for literals and (hypothetical) measurements; and `Measured` is a plain label with no authenticating field.

## Biggest blocker for Milestone 5
There is no authenticated, measured execution feed: `daemon.rs:446` passes `&[]` to `admit_production_quota`, nothing in the repo produces production `CanaryObservation`s, and the capability graph that drives hypothesis selection is built from hardcoded literals (daemon.rs:66-99). Both ends (what to improve, and proof it improved) lack real measurement.
