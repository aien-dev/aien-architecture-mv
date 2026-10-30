# Evidence chain inventory (Milestone 0, read-only scout)

Pins: aien-protocols 407487b7e163, interplane 667fbe811f78, spark-inquisitor 230d257199b7 (ARCHIVED), benchmarks 8d4dfde8f944.
Paths are relative to ~/workspace/adaptive/. Nothing was built or run; all claims are from reading source.

## Classification table

| Capability | Class | Key evidence |
|---|---|---|
| Evaluation plan/receipt types + P-256 signing (aien-evaluation-protocol) | Implemented but disconnected | aien-protocols/crates/aien-evaluation-protocol/src/lib.rs:510-602; only consumers are the archived inquisitor and spark-rsi per CONSUMERS.md:11-12 |
| TRN1 execution transcript (spec + C verifier + corpus) | Implemented but disconnected (spec: "Not yet produced by any runtime") | aien-protocols/specs/execution-transcript/TRN1_TRANSCRIPT_SPEC.md:3; no TRN1 mention in interplane or benchmarks (grep) |
| Signature over transcript / final chain digest | Missing | TRN1_TRANSCRIPT_SPEC.md:473-475 |
| Judge receipt `rsi-eval/2` verification (signature, subject, policy, holdout, threshold) | Implemented and integrated (inside interplane) | interplane/provenance/src/evaluation.rs:96,177,288-482; tests/evaluation.rs |
| Byte-compat with spark-rsi judge receipt | Implemented and integrated (one fixture) | interplane/provenance/tests/evaluation.rs:533,586 |
| One unified receipt format across repos | Missing: separate formats (EvaluationReceipt, rsi-eval/2, prime-race receipt v1; EvidenceReceiptV1 in sovereign-core) | sec. 1, 2, 4 |
| AIEN adapter evidence export (ledger slice, model turn, test run) | Implemented and integrated, but UNSIGNED | interplane/adapters/aien/src/provenance_export.rs:17; provenance/BINDING.md:195 |
| INTERPLANE conformance corpus + negative controls V1-V8 | Implemented and integrated | interplane/conformance/negative-controls.json:4-13 |
| spark-inquisitor protocol evaluators | Superseded (repo archived; protocol slice not carried to canonical copy) | spark-inquisitor/README.md:1-3; sec. 3 |
| benchmarks main harness (`src/harness`) | Experimental; cannot build standalone | benchmarks/Cargo.toml:18-22 |
| benchmarks prime-drag-race runner (content-addressed, no-overwrite receipts) | Implemented, standalone, own unsigned format | benchmarks/prime-drag-race/src/receipt.rs:20-40, src/lib.rs:15 |
| Longitudinal benchmark history / trend store | Missing | benchmarks/data holds two snapshot files; no history tooling found |
| Independent audit (separate party re-verifies whole chain) | Missing | judge key is operator-supplied (evaluation.rs:1-8), but nothing audits the operator or links receipt to transcript |

## 1. aien-protocols

Workspace members: aien-protocols/Cargo.toml:4-12. The `.crumb` at repo root has empty role strings for crates/ and specs/.

**aien-evaluation-protocol** (crates/aien-evaluation-protocol/src/lib.rs, 806 lines; path deps only on aien-protocol-types and aien-provenance, Cargo.toml:9-10):
- Types: EvaluationRequest :17 (request_id, subject ArtifactRef, parent, profile, claims, nonce); EvaluationPlan :36 (evaluation_id, subject, evaluators, baseline, sandbox_profile, policy_digest, evaluator_manifest_digest, plan_digest); EvaluatorOutcome :165 with `execution_digest` (computed :175); EvaluationReceipt :510; SignedEvaluationReceipt :583.
- Identities bound by the receipt digest (:525-555): protocol_version, evaluation_id, request_digest, subject_digest, plan_digest, evidence_root, outcomes_root, verdict, verifier principal/key_id/trust_epoch/trusted_build_digest/policy_bundle_digest, started_at, completed_at.
- NOT bound: no "world" field, no "generation" field, no separate "execution id". Nearest: `execution_digest` per evaluator outcome (:170), merged into outcomes_root via compute_merkle_root (:651). "Candidate digest" is `subject_digest`. (Checked by grep: world/generation absent from the file.)
- Signing: `VerifierSigner` trait :254; `SoftwareP256Signer` :262 (Tier2); `TpmP256Signer` :300 (Tier4, TPM code :309-445); `sign_with_signer` :557 (rejects key_id != fingerprint); `SignedEvaluationReceipt::verify(&VerifyingKey)` :591. Verify checks the signature over the recomputed digest only; it does not check the stored cryptographic_tier or key_fingerprint against the key (:591-601).
- Orchestration: `CanaryRollbackHarness::evaluate_and_enforce` :674-. Fails closed on plan-digest mismatch, duplicate, unexpected, missing, version-mismatched evaluator; runs rollback on hard-invariant failure.
- Tests (tests/evaluator_protocol_tests.rs, 382 lines): plan tamper -> digest invalid :84; frozen-invariant tamper -> PlanTamperingDetected :94; signer tier + signature verify + key-identity mismatch :109; missing evaluator fails closed :184; version mismatch :224; invariant violation triggers rollback :267; success admits :328.

**aien-provenance** (src/lib.rs): SourceGrant for data-source licences (verify_signature :124, validity :140, permission :149, licence :160). Source-licence provenance, not run provenance.

**Execution transcript contract** (specs/execution-transcript/):
- TRN1_TRANSCRIPT_SPEC.md: 48-byte header with `run_id` (root causal id, bytes 8-40, table near :56); hash-chained records; refusal codes MAGIC..TRUNCATED in vectors/expected.txt:3-5; capability generations appear inside records (BRANCH_CREATE :115, CAP_TRANSITION :120, EFFECT_INTENT :122). Status :3 "Not yet produced by any runtime". Planned producers named at :9 (omega tools/replay, sovereign-core aien-replay).
- Reference verifier tools/trn1_verify.c (500 lines); corpus of 106 files in vectors/; tools/check-corpus.sh, test-check-corpus.sh, mutate-verifier.sh (disables each check in turn and fails on any survivor, mutate-verifier.sh:30).
- Candidate digest and world identity are NOT in the transcript header. Join to receipts is by `run_id` plus "join rules" that are not verifier rules (spec :470).

**Other specs**: specs/evaluation/SPEC.md (not read in depth, content UNVERIFIED). specs/evidence-receipt/SUBSET.md:3 says it is a PARTIAL extraction and "the full extraction is owed". specs/verified-crumb/SPEC.md plus golden/r01..r08 refusal vectors.

## 2. interplane

**provenance/src/evaluation.rs** (482 lines). Header :1-8: no change may be promoted unless its exact identity matches a valid, independently signed evaluation; judge key comes from the operator, never from the bundle; it reads and compares, authorizes nothing.
- `receipt_digest_v2` :96-175 covers cycle_id, candidate_id, parent_id, evaluated_at, evaluator_version, evaluator_binary_sha256, subject_path, subject_sha256, holdout_set_sha256, policy_sha256, holdout counts, admitted and hard-invariant/statistical flags, per-layer results, metrics_summary.
- `verify_signature` :177-197: P-256, optional `tpm2-p256:` prefix, message is the 32 raw digest bytes.
- `check` (:288-482) refusal codes: evaluation_v1_insufficient, unsupported_evaluation, evaluation_malformed, evaluation_signature_bad, evaluation_untrusted, evaluation_subject_mismatch, evaluation_parent_mismatch, evaluation_policy_mismatch (several), evaluation_holdout_mismatch, evaluation_below_threshold.
- This is the spark-rsi judge format (tests/evaluation.rs:533 "written and signed by spark-rsi's own judge binary"), NOT aien-evaluation-protocol. grep for aien_evaluation / EvaluationReceipt / aien_protocol across interplane returned nothing.
- Entry points: `verify`/`verify_with` provenance/src/lib.rs:139-143; calls `evaluation::check` at :439. Trust statements: BINDING.md:137, :352; :195 "unsigned exports; the verifier cannot tell a harness export from a hand-written file".

**adapters/aien/** (no `.crumb` file in this directory). Evidence crosses as an exported bundle, not as a shared type crate. `export_bundle` provenance_export.rs:199 writes the daemon's raw ComposeRecall views (claim, settlement, grant, intent, ack), daemon-run.json from /proc, the load log, the INTERPLANE trace, model files, and COMPANION.json (path, size, SHA-256) (:1-8). A scripted turn can never be `PASS complete` (:12-15). "No record is signed" (:17). Judge path: src/rsi_m5.rs (`propose_and_judge` :60, `judge_model_proposal` :73), scripts/m5-*.sh, evidence/ dirs dated 2026-10-08/09.
- Approval binding uses HMAC-SHA256 with a shared desk key, not a public-key signature: compose_ledger.rs `ApprovalBinding` :94, `DeskKey` :132, `mac` :190.
- Tests (adapters/aien/tests/): approval.rs, bridge.rs, compose_ledger.rs (2042 lines), compose_ledger_attacks.rs (558), demo_workflow.rs, exposure.rs, pipeline.rs, t4_corpus.rs.

**conformance/**: 27 required fixtures plus injection, approval and lifecycle sets (README.md:5-7). negative-controls.json defines V1-V8: each is a deliberately defective runner variant that must fail named fixtures (:4-13). TRUST-DIGEST.txt freezes the corpus. runners/validate_fixtures.py is Python (README.md:11).

## 3. spark-inquisitor (ARCHIVED)

- README.md:1-3: archived; canonical home is aien-sovereign-core/crates/spark-inquisitor.
- src/protocol_evaluator.rs (199 lines): `InquisitorDiffEvaluator` :9 and `InquisitorConstitutionalEvaluator` :118, both implementing `Evaluator` (:32, :143). src/probe_audit.rs (288 lines) uses aien-probe.
- Cargo.toml:14-16: unpinned path deps on ../aien-protocols/crates/{aien-protocol-types, aien-evaluation-protocol, aien-probe}.
- Tests: tests/protocol_integration.rs: clean pass :44, telemetry/unslop rejection :69, constitutional :109, canary rollback integration :132-182 (asserts Verdict::Fail and `receipt.verify(&verifying_key)` :178-181). Other test files (constitutional_rules.rs, diff_auditor_edge_cases.rs, issue_triage_evaluator.rs, cli_exit_code_contracts.rs, probe_audit_tests.rs) check diff-content rules (dashes, buzzwords, secrets, .env), not evidence tampering.
- Live dependents: grep of Cargo.toml/lock/yml for "inquisitor" in aien-protocols, interplane, benchmarks found none. Only mention is aien-protocols/CONSUMERS.md:11 (stale doc row).
- Canonical copy (aien-sovereign-core/crates/spark-inquisitor, outside the four repos, checked locally): src/ has no protocol_evaluator.rs and Cargo.toml has no aien-protocols dependency (uses spark-crumbs and crum-spec git deps). The evaluator-protocol adapter exists only in the archived repo.
- Class: Superseded.

## 4. benchmarks

- Root crate `aien-benchmarks` (Cargo.toml:1-22) depends on ../canonical-branch-native-runtime/crates/{aien-platform, aien-platform-linux, aien-kv-cache, aien-scheduler, aien-inference-abi}. That sibling is absent from the adaptive workspace, so the root crate cannot build from a fresh clone. prime-drag-race/Cargo.toml:10-11 says the same.
- No dependency on aien-protocols or any evaluation crate. Own formats only.
- src/harness/: mod.rs (437 lines; `MeasurementConfig` :12, `run_measurement_suite` :34), inference_bench.rs, http_bench.rs, memory.rs, smaps.rs, system.rs, standalone.rs, workloads.rs. Output model `BenchmarkData` src/models.rs:4. Only 3 unit tests (src/main.rs:400,408,425: math, SVG, markdown); none test tampering.
- artifacts/gb10_canonical_1789907893_4d762/: manifest.json (run_id, runtime_git_sha, benchmarks_git_sha, hardware), SHA256SUMS (unsigned checksum list). scripts/verify_manifest.py (Python) checks token hashes and weight file hashes.
- data/benchmarks_20260919.json and benchmarks_latest.json are snapshots; no history or trend tooling.
- prime-drag-race (standalone, 1683 lines): receipt schema `aien-prime-race/receipt/v1` (src/lib.rs:15); receipt stored as `<sha256>.json`, mode 0444, no overwrite (receipt.rs:20-40); content-addressed blobs for stdout, stderr, report, bitmap (runner.rs:95-102); receipt carries runner commit + binary sha256, hardware, quiet-flag, governors, loadavg, per-trial records (runner.rs:209-235). No signature. Independent Miller-Rabin reference (CONTRACT.md:14-21); `verify` subcommand main.rs:89.
- Negative tests (tests/negative.rs, 327 lines): wrong_bit :109, missing_prime :118, extra_composite :127, tail_garbage :136, truncated_bitmap :145, all_zero_and_all_ones :153, audit stale :179, exit_code_2 :188, no_stdout_line :195, two_lines :202, malformed_line :210, passes_zero :217, elapsed_below_min :225, line_report_mismatch, label_mismatch, failed_status_rejected, run_failure_keeps_evidence, audit_rejects_stdout_line. These attack the benchmarked program's output. I found no test that edits a stored receipt and expects rejection (confidence medium; verify_subcommand test body only partly read).
- No `.crumb` in benchmarks root.

## 5. Dependency pinning graph

- aien-protocols: only intra-workspace path deps (crates/*/Cargo.toml); no other aien-dev repo. CONSUMERS.md:3-4 says consumers pin "v0.1.0" by path (no rev).
- interplane: adapters/aien/Cargo.toml:26-27 git dep aien-capability + aien-mcp at aien-sovereign-core rev 9b5e6e82359f4ad6b6f03042e83ef6411c5f15ce; :32 optional path dep `aegis` -> ../../../interplane-audit/aegis-runtime. adapters/aien/PINS: aegis-runtime f4e870953a46, aien-protocols 3a4cdbe8d360 (not current 407487b7e163), sovereign-core 9b5e6e82. provenance/Cargo.toml: path deps inside interplane only. No direct dependency on aien-evaluation-protocol (transitive via aegis-runtime UNVERIFIED).
- spark-inquisitor: unpinned path deps on ../aien-protocols/crates/{protocol-types, evaluation-protocol, probe}.
- benchmarks: unpinned path deps on ../canonical-branch-native-runtime/crates/* (repo not in workspace).
- Workspace heads are in adaptive/PINS.txt; how far interplane's 3a4cdbe pin lags aien-protocols main is UNVERIFIED.

## 6. Existing negative tests (bad artifact in, rejection expected)

Modified receipt / signature:
- interplane/provenance/tests/evaluation.rs: substituted_scores_break_the_signature :232; wrong_keys_are_refused :276; version_1_receipts_are_insufficient :212; malformed_and_unsupported_receipts_are_refused :410; spark_rsi_receipt_with_any_field_changed_fails :586; a_genuine_receipt_for_other_bytes_is_a_substituted_change :301; a_receipt_judged_from_another_commit_is_refused :438.
- aien-protocols evaluator_protocol_tests.rs: plan digest tamper :84; frozen-invariant tamper :94; key-identity mismatch inside :109.
Altered policy file:
- interplane evaluation.rs: altered_policies_are_refused :327; holdout_set_other_than_pinned :361; the_operator_can_pin_the_policy :448; protected-path subject :465. aien-protocols policy_digest frozen-invariant :94.
Missing record:
- interplane real_chain.rs a_missing_generation_record_is_an_absent_claim_not_a_pass :223; model_turn_link.rs a_missing_model_turn :178; effect_binding.rs ledger_record_removed_from_the_manifest :285; fix_the_test.rs dropped_test_run_section/record :170,:179; aien-protocols missing required evaluator :184.
Reordered events:
- effect_binding.rs records_out_of_ledger_order :274; model_turn_link.rs times_out_of_order_or_after_the_request :141; real_chain.rs a_generation_record_must_precede_the_effect :260. TRN1 corpus covers GAP/CHAIN/DIGEST/TRUNCATED refusals (vectors/expected.txt:3-5); mutate-verifier.sh proves each verifier check is exercised.
Altered records of each type: real_chain.rs :364, :382, :399; effect_binding.rs altered_claim/committed/grant/intent/ack :192-244; altered_record_without_restamp :263.
Substitution: effect_binding.rs ledger_for_another_request :101, ledger_from_another_trace :114, other daemon process/executable/socket :140-168.
Other: adapters/aien/tests/compose_ledger_attacks.rs (individual tests not enumerated, UNVERIFIED); conformance negative controls V1-V8; specs/verified-crumb/golden r01-r08.

## 7. Gaps

1. No receipt binds candidate digest + world + generation + execution id + transcript digest together. aien-evaluation-protocol binds subject_digest and evaluation_id only; TRN1 binds run_id and capability generations but is unsigned and has no candidate digest; rsi-eval/2 binds candidate_id and subject_sha256 but no transcript.
2. No adapter exists between aien-evaluation-protocol and rsi-eval/2, or between benchmark receipts and either.
3. interplane adapter exports are unsigned and forgeable by a same-user process (BINDING.md:195; provenance_export.rs:17).
4. aien-evaluation-protocol verify ignores the stored tier and fingerprint fields (lib.rs:591-601).
5. benchmarks main harness cannot build standalone; no history store.
