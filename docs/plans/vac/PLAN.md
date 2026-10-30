# VAC: Verifiable Autonomous Computing, implementation plan (2026-10-08)

**NOT A MASTER PLAN.** This is a finite workstream document under [PLAN_AUTHORITY.md](../../../PLAN_AUTHORITY.md) ("Component-local plans"). It does not change architecture, the milestone registry or the cross-project sequence. [doctrine/ARCHITECTURE.md](../../../doctrine/ARCHITECTURE.md), [doctrine/ROADMAP.md](../../../doctrine/ROADMAP.md) and [CURRENT_EXECUTION_PLAN.md](../../../CURRENT_EXECUTION_PLAN.md) win on any conflict. Implementation and evidence beat this text: where this text and a repository's merged code differ, the code is right and the difference is a defect here.

**Status:** record of one day of work, 2026-10-08, written after milestones M1, M2, M3a and M3b merged. M3b merged afterwards (IP#83 f43e53a64).

## How to read the citations

- `SC` = aien-spark/aien-sovereign-core, `IP` = aien-spark/interplane, `ARCH` = this repository. `path:line` was read by the author of this document at the named commit (SC 47f1014a1, IP f43e53a64 for main, which includes M3b (PR head c66be90362fe)).
- `PR #n + commit` is a merged pull request and its merge commit. `receipt <path>` is a file committed in a repository or a local log under `~/handoffs/vac/` on the Spark.
- `[scout]` means the fact was read by a read-only scout report on 2026-10-08 (`~/handoffs/vac/scout-A.md` to `scout-D.md`, local to the Spark, not committed) at the pins below, and was not re-read for this document. `UNVERIFIED` means nobody read it.
- Labels used in verdicts are exact strings the verifier prints: `PASS complete`, `PASS_LABELLED_INCOMPLETE missing=...`, `FAIL <code>`.

Pins (GitHub default branches, 2026-10-08 15:47Z unless noted): SC 9b5e6e82 then 47f1014a1 after #346; omega 2ae8677c; omega.lock in SC 6c6180cf; IP 01bc340d then 860065742 after #82; aienos 8928c427; ARCH e01b19c1 at start of the mission (this document branches from 60c92db); aien-protocols 66610096; aegis-runtime f4e87095; spark-rsi e5aab9ad; physics 9f96f255; benchmarks 8d4dfde8; waldo 0fd421ab; odysseus (branch dev) 2992bf6d. Source of the start pins: `~/handoffs/2026-10-08-vac-mission.md`.

## Rules that bind every claim here

- A scripted model turn is never `PASS complete`. All runs recorded below are scripted and end `PASS_LABELLED_INCOMPLETE` (receipt `IP adapters/aien/evidence/live-gate-2026-10-08/receipt.json`).
- Exported records are unsigned. The verifier cannot tell an export from a hand-written file (IP provenance/BINDING.md:73; receipts' `limits`).
- The desk MAC on the ordinary `ComposeAuthorize` path is default off. Drake decided on 2026-10-08 to preserve that default; it is not changed by this workstream (SC crates/aien-runtime/src/spine.rs:1792 `authorize_requires_desk: false`; issue sc#328 holds the question).
- The test run in the fix-the-test slice is harness evidence, not a daemon effect. The daemon only writes the file (IP provenance/BINDING.md "The test run is harness evidence", IP main f43e53a64).

## A. Current reality

Chain studied: INTERPLANE CapabilityRequest -> crossveil Pipeline -> `adapters/aien` (ApprovalBinding signed with the desk key) -> daemon socket `ComposeApprovedProposal` -> `approved.rs` (replay claim, MAC check) -> compose commit -> `approved_grant` -> `ComposeEffectIntent` -> client write -> `ComposeEffectAck` -> Cortex journal -> export -> IP `provenance` offline verify.

| Capability | State at the pins | Evidence |
|---|---|---|
| INTERPLANE lifecycle, JCS digest binding, crossveil Pipeline | implemented; conformance against a mock runtime | IP rust/crates/interplane-core/src/lifecycle.rs:6-20; crossveil/src/pipeline.rs:76-78 [scout] |
| `adapters/aien` approved `write_file` to the daemon socket | implemented, library only (no shipped binary); repinned to SC 9b5e6e82 by #82 | PR IP#82 860065742; IP adapters/aien/Cargo.toml:25-26, PINS |
| Adapter live-daemon rows (10 ledger rows + 4 attack rows) | `#[ignore]`, need `AIEN_BIN`, not in CI; run by the gate script `adapters/aien/scripts/test-live-daemon.sh` (5 required rows) | IP adapters/aien/tests/compose_ledger.rs:417; test-live-daemon.sh:64,159 |
| SC `ComposeApprovedProposal` (once-ever replay claim, mandatory MAC, accepted record before run) | implemented, reachable over the socket only; no CLI subcommand [scout] | SC crates/aien-runtime/src/approved.rs; approved_replay.rs:3-10; approved_auth.rs:50 (`aien.approval.v2`); server.rs:952 |
| Desk MAC on `ComposeAuthorize` | implemented, default OFF; env switch `AIEN_COMPOSE_AUTHORIZE_REQUIRES_DESK` | SC spine.rs:996-1004, 1792; daemon log "Authorize MAC: off" in receipt `~/handoffs/vac/M1-ledger-out/row10/daemon.log` |
| Effect ledger: intent, write, ack DONE / NOT_DONE / UNRESOLVED | implemented; only `write_file`; the client process performs the write | SC effects.rs:1592 (`open_intent`), 1629, 1662-1663 (`disk_sha256` in the ack) |
| Compose commit via native `librx_compose` | works only when linked; the stub returns `Unavailable` on every compose call | SC crates/aien-omega-compose/src/lib.rs:12,23,25,48 |
| Native vs stub visible to an operator or a receipt | CLOSED by #346: daemon prints `Compose: native (omega <sha>)` or `Compose: STUB`, and `ComposeRecallReport` carries `compose_native` and `omega_sha` | PR SC#346 47f1014a1; SC server.rs:267,271; control.rs:796-799; test recall_native_report_test.rs |
| Linked-compose CI gate | implemented (job `linked-compose`); status as a required check UNVERIFIED | SC .github/workflows/ci.yml:104 |
| IP `provenance` offline verifier | implemented; fixtures plus real live bundles after #82; unsigned | IP provenance/README.md, BINDING.md; PR IP#82 |
| Test-run evidence for an agent edit | implemented; `vac-test-run/1` on IP main | PR IP#83 f43e53a64 |
| `bash_eval` through the adapter | declared, not executed (`NOT_EXECUTED`) | IP adapters/aien/src/lib.rs:44,749 (IP main f43e53a64) |
| `aien-test` ADR 0033 slices D and G (identity, manifest v2, signed bundle, `verify-bundle`) | implemented, tool only | SC tools/aien-test/src/bundle.rs [scout] |
| ADR 0033 slices E (partial), F, H, `aien-receipts` repo | partial / proposed / absent | ARCH docs/adr/0033-aien-verification-pipeline.md (Status PROPOSED, 2026-10-04) |
| aien-mcp `ApprovalDesk` / `AuthorizedEffect` | merged and unused; the daemon rejects it as unverifiable | SC approved_auth.rs:20-22 [scout] |
| aien-cli REPL tools with `record_effect_receipt` | separate path: no grant, no journal, loose unsigned file | SC crates/aien-cli/src/tools.rs:431,443 |
| aegis-runtime | standalone; legacy vs canonical stack unresolved | aegis-runtime enforcement.rs [scout] |
| aien-protocols `action-protocol`, `evaluation-protocol` | implemented, not used by SC effect records | [scout] |
| spark-rsi | standalone; bounded proposer, blind judge, ratifier makes a branch only; Tier2 immutable list omits `src/meta`, `ratify.rs`, `daemon.rs` | spark-rsi meta/tier.rs:34-42; ratify.rs:11-24; daemon.rs:359 [scout] |
| Odysseus tool loop | not connected to AIEN | odysseus src/tool_execution.py:810 [scout] |
| Three receipt dialects (aien-proof BLAKE3, aien-test sha256 canonical JSON, WALDO `json.Marshal`) | implemented, inconsistent | SC aien-proof evidence.rs:294-345; tools/aien-test evidence.rs:16,100-138 [scout] |
| Ledger and journal records | unversioned | SC effects.rs:1206,1465,1628,1660 [scout; line 1629 and 1662 re-read] |

Stale text found, listed here and not rewritten: the module doc of `approved.rs:10` says the hook "never writes the workspace and never mints an" authority, while the path writes an `approved_grant` (read at 47f1014a1; the sentence continues past line 10). `tools/aien-test/src/lib.rs:1` says "Slices A to C" while slices D and G exist. Both are candidate issues, not changed here.

## B. Target product contract

**Product 1.** A small fixture repository holds a program and one deliberately failing test. An agent is given the task id and the repository pin and fixes the program. The fix is a `write_file` effect through the existing authority path; nothing else writes into the workspace. Qualification runs use a scripted model turn; a real model is a later row.

**Flow, each step with its existing owner.**
1. Task record: task id, fixture commit, test command (`vac-task`, `vac-source-pin`; implemented on IP main, IP provenance/BINDING.md).
2. Agent reads files through INTERPLANE `read_file` / `list_dir` (IP adapters/aien/src/lib.rs).
3. Agent emits `write_file` as a `CapabilityRequest`; crossveil returns `requires_approval`; a host-side approver approves; the binding `aien.approval.v2` is signed with the desk key (SC approved_auth.rs:50; IP adapters/aien/src/compose_ledger.rs).
4. Adapter sends `ComposeApprovedProposal`; the daemon claims replay keys once, runs compose, writes `approved_grant`.
5. Intent, client write, `ComposeEffectAck` with `DONE`, `NOT_DONE` or `UNRESOLVED` decided by daemon read-back (SC effects.rs:1592-1663).
6. Test run, after a `DONE` ack, by the harness, recorded as `vac-test-run/1` bound to the ack by the post-write blob digest (`disk_sha256`). It has no grant, no intent and no ack and is never given authority.
7. Export: ledger slice plus task, source pin, test run, native report, trace, load log and model file hashes, named in `COMPANION.json` by path, sha256 and size.
8. Offline `provenance verify <dir>` prints one line.

**What the verifier checks (implemented).** Retained files match their sha256 and size; INTERPLANE envelopes validate; request id, trace id and approval key recompute from the ledger slice; written path and bytes equal the approved bytes; claim, grant, intent and ack are present and consistent (IP provenance/src/lib.rs:898 compares the producer-reported `success`). On IP main it also checks: source pin against the grant's `prior_sha256`; the test-run record against the ack's `disk_sha256`; exit code 0 after and non-zero before; stdout and stderr digests against retained files; the native claim against the retained `compose_recall` report. Codes as implemented on IP main: `test_run_missing`, `unsupported_test_run`, `source_pin_mismatch`, `test_run_mismatch`, `native_claim_contradicted` (IP provenance/src/testrun.rs; BINDING.md checks 1 to 5).

**What it does not prove.**
- Authenticity of exported records: they are unsigned and daemon-written; a same-user process able to append to the compose ledger could forge them (IP provenance/BINDING.md:73).
- Which human approved: the MAC proves a holder of the desk key.
- Approval authenticity on the ordinary `ComposeAuthorize` path while the desk MAC default is off. The product path uses `ComposeApprovedProposal`, where the MAC is mandatory.
- That the test run happened as recorded. The harness writes the record. Re-running the pinned fixture is the independent check.
- That a model produced the proposal: scripted turns keep `link:model_turn` missing.
- That nothing else touched the workspace between the ack and the second test run (BINDING.md "Does not prove").
- That a native build was used when the field is absent: a daemon older than #346 reports nothing, and the verifier labels `link:native` missing.

**Failure boundaries (target behaviour; test coverage as in section E).**
- Ack `DONE`: verdict can reach the labelled-incomplete pass; `PASS complete` additionally needs a non-scripted model turn.
- Ack `NOT_DONE` or `UNRESOLVED`: the target-blob check fails against the ack, so no test run is trusted. UNVERIFIED as a dedicated live test; SC recovery tests cover the daemon side (M1 matrix, `~/handoffs/vac/M1-qualification.md` section 3, rows "interrupted operation").
- Replay of an approved submission: refused (SC approved_attacks_test c09 to c11, M1 matrix "duplicate submission").
- Stub build: every compose call is `Unavailable`; ComposeRecall returns an error rather than `compose_native=false` (finding in `~/handoffs/vac/M3a-report.md`).
- Test fails after a `DONE` write: UNVERIFIED. The verifier rejects `exit_code != 0` as `test_run_mismatch` for this slice, because the slice claims a fix; task failure and provenance are not yet separate verdicts. The earlier draft proposed separating them; that is not implemented.

## C. Gap matrix G1 to G6

| Gap | Required behaviour | Status 2026-10-08 | Evidence | What remains |
|---|---|---|---|---|
| G1 | Adapter and daemon agree at SC main; live-daemon rows runnable as a gate | CLOSED by #82 to the extent proven: pin 4d4dfd4 -> 9b5e6e82, gate runs 5 rows against a native daemon, verifies the bundle, runs 5 tamper checks | PR IP#82 860065742; receipt `IP adapters/aien/evidence/live-gate-2026-10-08/receipt.json`; M1 finding 1 (14 rows green at the old pin) | The gate is a host script, not a CI job; no CI job builds a native daemon. 9 of 14 live rows are not covered by the committed receipt (they passed in M1 only). |
| G2 | Test run recorded as evaluation evidence bound to the ack | CLOSED and merged to the extent proven by one live run and 24 synthetic tests | PR IP#83 f43e53a64; receipt `IP adapters/aien/evidence/fix-the-test-2026-10-08/receipt.json` (IP main) | A real model turn; sandboxing of the test command is not implemented. |
| G3 | One bundle carries task id, source pin, native/stub | Native/stub: CLOSED by #346 (daemon side) and #83 (verifier side). Task id and source pin: merged with #83. Model identity: carried as before (`model_generation` / `scripted_turn`) | PR SC#346 47f1014a1; PR IP#83 | Weights-to-text provenance stays at the existing `model_generation/2` limit. |
| G4 | Approval authenticity on every authority-minting path | OPEN, Drake decision: desk MAC default stays off | SC spine.rs:1792; issue sc#328 | Nothing in this workstream changes it. A bundle for a run that used the ordinary path cannot be treated as MAC-backed. |
| G5 | Versioned records where the bundle depends on them | PARTIAL: new records carry a schema string (`vac-test-run/1`, `aien.native` section, `COMPANION` binding strings). Ledger and journal records stay unversioned by design | IP provenance/BINDING.md (IP main f43e53a64); SC effects.rs:1628 [scout] | Receipt-id unification stays ADR 0033 / ARCH-0029 Decision 6 scope. |
| G6 | Reproducible scripted demo from a clean checkout | OPEN; assigned to M4a. The two gate scripts exist and are reproducible on the Spark but need a prepared native build | IP adapters/aien/scripts/test-live-daemon.sh, test-fix-the-test.sh (IP main f43e53a64) | A single `demo.sh run | verify | selftest` from a clean clone. |

## D. Execution graph

Order by dependency. Each milestone ends in a pull request and a row in section E.

| Milestone | Definition of done | State 2026-10-08 |
|---|---|---|
| M1 baseline | Matrix of the authorized path with commands, exit codes, binary hash, native/stub status; no repo edits | DONE. `~/handoffs/vac/M1-qualification.md`: linked gate 393 PASS; 47 in-process + 14 live adapter tests PASS; 84 provenance tests PASS; 11 of 12 matrix rows covered, stub-build row NOT RUN. |
| M2 live verified run (closes G1) | Verifier judges a real authorized run; negative checks refuse | DONE and merged: IP#82 860065742 (gate GATE PASS 18:16Z to 18:51Z). |
| M3a native report (part of G3) | Daemon reports native/stub | DONE and merged: SC#346 47f1014a1 (linked gate 401 PASS, CI 3 of 3 SUCCESS at 19bf64e per `~/handoffs/vac/M3a-report.md`; CI states re-read for this document: SUCCESS on all three checks). |
| M3b fix-the-test slice (G2, G3, G5) | Fixture with failing test, scripted fix through the real daemon, test-run record, source pin, verifier links, tamper tests | DONE and merged: IP#83 f43e53a64 (PR head c66be90362fe, all CI checks SUCCESS there, `gh pr view 83 -R aien-spark/interplane --json statusCheckRollup`). Review of #83: APPROVE (posted as a comment from the same account); two follow-ups tracked in IP#84. |
| M4a clean-checkout demo (G6) | One script from a clean clone prints the verdict; selftest mutates each retained file and the verifier refuses each | DONE: IP#85 26b746568 (demo script, run 11), clean-clone build mode reproduced in run 12 after README fix IP#87 04a05dc5e. Selftest scope as built: 6 tamper cases each refused with its own code (runs 9, 11, 12), not a mutation of every retained file. |
| M4b this document in ARCH | Plan, qualification record and change log in `docs/plans/vac/` | DONE: aien-architecture#168 fa0ec91fa. |
| M4d recovery verdicts (DoD 7) | The verifier tells a landed write from one that did not land, could not be resolved, or was interrupted, and refuses test results on top of any of them | DONE: IP#86 9d1b1ab32 (run 13). Synthetic and restamped bundles only; no live interruption. |
| M5 bounded RSI hookup | spark-rsi proposes a Tier1 change through the approved path; ratifier still makes a branch only; Tier2 gap reported, not changed | DONE 2026-10-08 (spark-rsi#34 merge 24f412f69, interplane#89 merge dc37ca3e5; gate `adapters/aien/scripts/test-m5-rsi.sh` PASS, evidence `adapters/aien/evidence/m5-rsi-2026-10-08/`). Status per item: (a) met by `test-m5-rsi.sh` (renamed); (b) met; (c) met, receipt version 2 signed by a separate judge account, 4 of 4 holdouts at a policy ratio of 1.0; (d) not exercised: promotion goes through the INTERPLANE approved path, not the ratifier, and spark-rsi's own daemon refuses self-promotion; (e) met; (f) met (proposals aimed at holdouts, policy or any other file refused; protected paths in the signed policy). Details and limits: `M5-DESIGN.md`, "Outcome". Original plan text follows. Stops at a design note if it needs a new protocol (action-protocol is unused by SC). Done when: (a) command `scripts/test-rsi-hookup.sh` (to be written in M5) exits 0; (b) `provenance verify` on its bundle prints `PASS_LABELLED_INCOMPLETE` for a spark-rsi Tier1 proposal; (c) a candidate is promoted only with a signed evaluation receipt and a holdout score at or above the threshold set in the M5 design note; (d) ratify makes a branch only (check: the target repository has no new commit on its default branch); (e) rollback test exits 0; (f) negative test: an RSI attempt to modify the holdout or policy files is refused. |

Stop conditions: a Drake decision (desk MAC default, sc#327 model default, releases, keys, reboots) stops the milestone and reports. No milestone changes GPU or chip code. `quietlock check` precedes every long run.

### Relation to ADR 0033

[ADR 0033](../../adr/0033-aien-verification-pipeline.md) (PROPOSED, 2026-10-04) defines the Check IR, exactness classes, signed `VerificationBundleV1` and the `receipt_id_scheme` field. This plan does not restate or change any of it. For this slice the verifier is `interplane/provenance`, and it checks the INTERPLANE-to-AIEN effect chain, not the ADR 0033 gate graph. The bundle formats are different objects: `COMPANION.json` is unsigned and VAC-specific, `VerificationBundleV1` is signed. Unifying the receipt id schemes and adopting the signed envelope stay ADR 0033 and ARCH-0029 scope. No new ADR is created here: nothing in this plan changes subsystem responsibility. If the `vac-test-run/1` and `COMPANION` test-run section become a normative cross-repo wire contract, that is a separate ADR (the next free number is 0036; 0035 is the highest present).

## E. Qualification record

All runs: host Spark (Linux 7.0.0-1019-nvidia aarch64, 20 cores), CPU only, GPU engine is the CPU stub (`Backend: NativeTransformerBackend/CPU-reference`), model unsloth Llama-3.2-1B-Instruct snapshot 5a8abab, model turn scripted. Native compose library linked from omega.lock `6c6180cf` in every row except the SC stub-build row, which was not run. Source of the environment: `~/handoffs/vac/M1-qualification.md` section 1; `~/handoffs/vac/M3b-report.md`.

| # | Run | Command | Binary sha256 (aien-cli, debug) | Result | Evidence |
|---|---|---|---|---|---|
| 1 | M1 linked gate | `scripts/test-linked-compose.sh omega-lock physics-lock aienos-lock` (SC 9b5e6e8) | script-built `cc3df20c...` (not the binary tested live) | exit 0, 393 tests, 0 failed, 54 binaries, 15:53Z to 15:57Z | `~/handoffs/vac/M1-linked-compose.log` |
| 2 | M1 adapter in-process | `cargo test` in IP adapters/aien (pin 4d4dfd4) | n/a | 47 passed, 0 failed, 14 ignored | `~/handoffs/vac/M1-adapter-test.log` |
| 3 | M1 live rows | `AIEN_BIN=... cargo test --test compose_ledger --test compose_ledger_attacks -- --ignored --test-threads=1` | `9704f29f68348097516ab45382852c70c1c22aec36d868cb2be564b8cd039c2f` | 14 passed (rows 1 to 8, 10, 11, x1 to x4; row 9 ran in run 2); wall time 3985 s + 1593 s | `~/handoffs/vac/M1-ledger-live.log`, `M1-ledger-out/` |
| 4 | M1 provenance tests and fixtures | `cargo test` in provenance; `verify` on 5 committed fixtures | n/a | 84 passed; fixtures: 1 `PASS complete` (`real-waldo-aien-chain`, candidate=none), 4 `PASS_LABELLED_INCOMPLETE`; the live run itself produced no COMPANION | `~/handoffs/vac/M1-provenance-test.log`, M1 section 2 |
| 5 | M2 live gate (5 rows) | `AIEN_BIN=aien-cli-m1 OUT=... LIVE_ROWS="row1_ x1_ x2_ x3_ x4_" scripts/test-live-daemon.sh`, 18:16:25Z to 18:51:47Z | `9704f29f...` | GATE PASS, exit 0; verdict `PASS_LABELLED_INCOMPLETE missing=link:model_turn effect=aien-ledger-slice/1:strong proposal=scripted_turn` | committed: `IP adapters/aien/evidence/live-gate-2026-10-08/receipt.json` (main, #82); logs `~/handoffs/vac/M2-gate.log` |
| 6 | M2 tamper checks (4 codes + control) | inside run 5 | `9704f29f...` | control same verdict; `digest_mismatch: interplane_trace`; `binding_mismatch: interplane.arguments.content`; `digest_mismatch: ledger_ack`; `binding_mismatch: ledger_ack.state`; `size_mismatch` (truncated intent) | same receipt, `negative_checks` |
| 7 | M3a linked gate | linked-compose script at SC branch `vac/m3a-compose-native-report` | not recorded here | 401 PASS, exit 0; CI at 19bf64e 3 of 3 SUCCESS | `~/handoffs/vac/M3a-linked.log`; PR SC#346 |
| 8 | M3b slice gate | `AIEN_BIN=aien-cli-m3b OUT=... scripts/test-fix-the-test.sh`, 19:11:39Z to 19:20:49Z, daemon built at SC 47f1014a1 | `a62a88b4a33b3805c3a95e6b56755a53aeb5cee22c60731a0bd8aef2632ee476`; verifier release `f4a0385dd9ba...` | exit 0 first try; `PASS_LABELLED_INCOMPLETE missing=link:model_turn effect=aien-ledger-slice/1:strong proposal=scripted_turn`; daemon printed `Compose: native (omega 6c6180cf...)`; task `fix-the-test/clamp-1`, test exit before 2 (GNU make), after 0 | committed on IP main: `IP adapters/aien/evidence/fix-the-test-2026-10-08/receipt.json`, `row-receipt.json`; log `~/handoffs/vac/M3b-slice-gate.log` |
| 9 | M3b tamper checks (6 codes + control) | inside run 8 | as run 8 | `test_run_mismatch` (changed exit code; swapped stdout digest; wrong target blob), `test_run_missing` (dropped section), `source_pin_mismatch` (tampered pin), `native_claim_contradicted` (forged native); control unchanged | `negative-verdicts.txt` on IP main |
| 10 | M3b synthetic tests | `cargo test` in IP provenance (`tests/fix_the_test.rs`) | n/a | 24 tests (M3b report; `#[test]` count in the file is 24) | IP main f43e53a64 |
| 11 | M4a demo (prebuilt daemon) | `AIEN_BIN=aien-cli-m3b OUT=... adapters/aien/scripts/demo-verified-fix.sh`, 19:38:52Z to 19:48:19Z | `a62a88b4...` (as run 8) | DEMO PASS, first try; `PASS_LABELLED_INCOMPLETE missing=link:model_turn`; build mode not exercised | IP#85 merge 26b746568, `adapters/aien/evidence/demo-2026-10-08/DEMO-RESULT.md`; `~/handoffs/vac/M4a-report.md` |
| 12 | M4c demo from fresh clones, build mode | `demo-verified-fix.sh` with SC_DIR, OMEGA_DIR, PHYSICS_DIR, AIENOS_REPO in `~/workspace/vac/clean-20261008T2007Z` (interplane HEAD 26b7465 = IP#85 merge as recorded in the run's DEMO-RESULT; the README fix was committed afterwards as 396e221. SC c58b6e0, not run 11's 47f1014; omega 6c6180c); attempt 2, 20:08:14Z to 20:18:01Z | `67d626a733e3157a1fc00cfbaf659894958de1da9ed82f629702e3dcee195259` (built in the run) | Attempt 1 FAILED in under a minute: README omitted `setup-siblings.sh` (fixed IP#87 04a05dc5e). Attempt 2 DEMO PASS; verdict, the 6 tamper codes, approved content sha256 `95bdc0c9...`, exit codes 2 then 0 and `Compose: native (omega 6c6180c...)` equal run 11. Expected differences: daemon and verifier hashes (built fresh), sovereign-core revision, fixture tree and source commits (fresh git init) and the approval key (fresh) | `~/handoffs/vac/M4c-report.md`; `out/DEMO-RESULT.md` in the clean dir |
| 13 | M4d recovery verdicts | `cargo test --locked` in IP provenance at the IP#86 head | n/a | 114 passed (counted by the session on the PR head; the worker report gives only the 6 new tests); NOT_DONE, UNRESOLVED and a missing ack give `effect_not_done`, `effect_unresolved`, `effect_interrupted`; a test run on any of them gives `test_run_on_unlanded_effect`; an unknown ack state stays `binding_mismatch` | IP#86 merge 9d1b1ab32, `provenance/tests/recovery_verdicts.rs` |
| 14 | Task scope check (gap R5) | `AIEN_BIN=aien-cli-m3b OUT=... scripts/test-fix-the-test.sh` at IP 633ff07 (pre-rebase commit of IP#88), 20:19:08Z to 20:28:26Z; `cargo test` in IP provenance | `a62a88b4...` (as run 8) | SLICE GATE PASS; 8 negative checks (control + 7), new `write_outside_task_scope` refused `task_scope_mismatch`; 116 provenance tests; both new tests fail on the old verifier | IP#88 merge c1e901870, `adapters/aien/evidence/task-scope-2026-10-08/` |

Known limits of this record, none softened:
- Runs 5, 6, 8 and 9 are scripted-model runs. None is `PASS complete`.
- `sovereign_core_rev` in the run 5 receipt is caller-asserted; the daemon does not print its revision (M2 report, Limits). Run 8 records the daemon commit the same way.
- Run 5 covers 5 of 14 live rows; the other 9 passed in run 3 only. The full `test-live-daemon.sh` (about 45 minutes) was not re-run after the M3b wiring change (M3b report, "Limits").
- A forged native claim on a real stub daemon was only tested on synthetic bundles, because a stub daemon returns an error to ComposeRecall (M3b report; M3a finding).
- The stub-build row of the M1 matrix was NOT RUN. The REPL tool path and crossveil's own tests were not run in M1.
- Debug builds were used; each live row spent about 6.5 minutes in daemon start in run 3.
- The linked gate was run with `AIEN_OMEGA_DIR` unset, so the GPU engine is the CPU stub. Nothing here is a GPU result.
- Run 13 uses restamped synthetic and real-fixture bundles. No live daemon was interrupted mid-write.
- Run 12 proves the demo reproduces from fresh clones in verdict and refusals; it is not a bit-reproducible build (daemon and verifier hashes differ from run 11).

## F. Change log

| Date (UTC) | Section | Change | Evidence | Author |
|---|---|---|---|---|
| 2026-10-08 | A, C | Native vs stub becomes visible: `compose_native`, `omega_sha`, startup line | SC#346, merge commit 47f1014a1aa0cf54b732132c6958bc142e91c20b | claude session (VAC lane) |
| 2026-10-08 | A, C, E | Adapter repinned to SC 9b5e6e82; live verified-run gate and COMPANION exporter added | IP#82, merge commit 8600657425a457b69234e768e95ee8ba435c6ec2 | claude session (VAC lane) |
| 2026-10-08 | A, C, E | Fix-the-test slice: fixture, task / source pin / test-run records, five verifier codes, native check, slice gate, committed receipt | IP#83, merge commit f43e53a649e752308c61e8a51a402cfa37a7bf30, head c66be90362fed3831c425786980bcf8a233f8911 | claude worker (Sonnet), brief checked by the VAC lane |
| 2026-10-08 | all | This document placed at `docs/plans/vac/PLAN.md` | this pull request | claude worker (vac-m4b) |
| 2026-10-08 | D, E | Reproducible demo script and recorded run (M4a) | IP#85, merge commit 26b746568 | claude session (VAC lane) |
| 2026-10-08 | B, E | Distinct verdicts for an effect that did not land, could not be resolved, or was interrupted (M4d) | IP#86, merge commit 9d1b1ab32 | claude worker (vac-m4d), verified by the session |
| 2026-10-08 | E | Clean-clone reproducibility run (M4c); README prerequisite fixed | IP#87, merge commit 04a05dc5e | claude worker (vac-m4c), verified by the session |
| 2026-10-08 | D | M5 design note added, status PROPOSED (`docs/plans/vac/M5-DESIGN.md`) | this pull request | claude session (VAC lane) |
| 2026-10-08 | B, E | The task record names its one allowed file; the verifier refuses a write elsewhere (`task_scope_mismatch`) | IP#88, merge commit c1e901870 | claude session (VAC lane), independent review by a separate session |
| 2026-10-08 | D | M5 feasibility probe and gaps R6 to R8 added to the design note | aien-architecture#170 | claude session (VAC lane) |
| 2026-10-08 | B, D, E | M5 DONE: judge-signed receipt version 2 bound to the exact change, parent, policy and holdouts; verifier `rsi-eval/2`; gate with 18 named refusals; spark-rsi `Cargo.lock` committed and enforced | spark-rsi#34 merge 24f412f699f1942861fac5afb632cc8deda31ad1, interplane#89 merge dc37ca3e5948945bf4619c015b6c817a0c0920a0 | claude session (VAC lane), three independent reviews by separate sessions |

### Superseded by code (record codes and bindings as implemented)

The 2026-10-08 draft (`~/handoffs/vac/PLAN-DRAFT.md`, local, not committed) proposed names that changed when the code was written. The implemented form wins:
- Proposed record `test_run/1`, binding `aien-test-run/1`: implemented as `vac-test-run` version 1 in `COMPANION.test_run.binding = "vac-test-run/1"`, with companion records `vac-task` and `vac-source-pin` (IP provenance/BINDING.md, IP main f43e53a64).
- Proposed refusal `not_native`: not implemented. Implemented as `native_claim_contradicted` for a claim the retained report does not support, and as the label `link:native` missing (verdict stays incomplete, not a FAIL) when the field is absent or `claimed: false`.
- Proposed schema bump of `COMPANION` from 0 to 1: not done. The `test_run` and `aien.native` members are optional additions; bundles without a `test_run` section are unchanged (BINDING.md, "Native claim").
- Proposed harness-side probe for native/stub (`aien --version` style): replaced by the daemon-side report in `ComposeRecallReport` (SC#346). Stub daemons return an error on recall, so they never emit `compose_native=false` (M3a report).
- Proposed bundle-level verdict `NOT_FIXED` separating task failure from provenance: not implemented. A non-zero exit after the write is `test_run_mismatch` today (section B).
- Proposed CI job that builds a native daemon in IP CI (G1): not implemented. The gate is a host script (`adapters/aien/scripts/test-live-daemon.sh`).
- The draft said the adapter pin was "31 commits behind" and that protocol drift was UNVERIFIED. Measured result: no drift observed in 14 live rows (M1 finding 1); crate diff 4d4dfd4 to 9b5e6e8 for `aien-capability` and `aien-mcp` is empty (M2 report, Commands).
