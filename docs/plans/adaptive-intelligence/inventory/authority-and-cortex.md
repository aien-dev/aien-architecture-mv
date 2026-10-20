# Authority and Cortex ownership inventory (Milestone 0)

Scout: read-only. Repos at pins in /home/drakestapleton/workspace/adaptive/PINS.txt (omega 16e729b6d844, aienos 3b2004b692a7, aegis-runtime 1eba7a7223ba, aien-sovereign-core 00e7ef05302c, cortex-rs 0606636f110d). Paths are relative to /home/drakestapleton/workspace/adaptive/. Claims without a source are marked UNVERIFIED.

## 1. Classification table

| Capability | Where | Class |
|---|---|---|
| Canonical Cortex store (C CxStore, single writer, journal) | omega/src/runtime/rx_cortex.h:2-29 | Implemented and integrated (called by rx_projection.c per header :8-10; reached by sovereign-core via aien-omega-compose, crates/aien-omega-compose/src/lib.rs:1-9) |
| Cortex HTTP memory service (:18080) | aien-sovereign-core/crates/cortex-rs | Implemented and integrated (live), but declared NON-authoritative and slated for deletion (rx_cortex.h:12-29) |
| Standalone cortex-rs repo | cortex-rs/README.md:1-3 | Superseded or deprecated (ARCHIVED; canonical home is the sovereign-core copy) |
| aienos-cortex Rust epistemic store | aienos/crates/aienos-cortex | Implemented, integrated into host-side aienos-aegis/aienos-explain only; declared non-authoritative (rx_cortex.h:18-20) |
| Operator emergency stop (world level) | omega/src/runtime/rx_world.h:805-830 | Implemented and integrated (tests: omega/tests/r16_qualify/run.sh, tests/runtime/rx_operator_mutants.sh, rx_r12_resident.c) |
| Capability authority, kernel-native | aienos/crates/aienos-capability/src/lib.rs | Implemented (7 unit tests), consumed by aienos-kernel caps.rs:9; not on Linux path |
| Resource admission + budgets, kernel | aienos/crates/aienos-kernel/src/{admission,budget}.rs | Implemented (native only; Aienux is not what runs on this Spark today, per memory) |
| Priority classes (Background/Normal/Latency) | aienos/crates/aienos-kernel/src/scheduler.rs:8-12 | Implemented (native only) |
| Host effect broker: intent, token, operator grant | aienos/crates/aienos-aegis/src/{effect,broker,capability,evaluator}.rs | Implemented but disconnected (only crate depending on it is itself; grep of crates/*/Cargo.toml) |
| aegis-runtime ExecutionAuthority trait | aegis-runtime/src/execution/broker.rs:15-18 | Implemented but disconnected (zero `impl ExecutionAuthority` in src or tests) |
| aegis-runtime RunBudget / SessionBudget | orchestration/budget.rs:3-9, sessions/session.rs:34-38 | Implemented but disconnected (no enforcement site; only constructed and serialized) |
| aegis-runtime DoctrineDecision / ContainmentLevel::EmergencyStop | defense/decision.rs:7-21 | Implemented but disconnected (type only; no producer found) |
| aegis-runtime dispatch allowlist membrane + probe gate | src/enforcement.rs:14-80, skills.rs:131-163 | Implemented and integrated (used by every dispatch path, enforcement.rs:73 comment) |
| sovereign-core approval desk + durable effect ledger | aien-runtime/src/{spine,approved,approved_auth,approved_replay,effects}.rs | Implemented and integrated (daemon path, many attack tests) |
| sovereign-core compose run (bounded experiment entry) | control.rs:89 RunComposeTask, aien-omega-compose Compose::run lib.rs:332 | Implemented and integrated |
| Inference interface | aien-abi-core AienInferenceBackend (lib :587) ; aegis-runtime InferenceEngine inference.rs:79 | Implemented and integrated (two separate traits, see section 4) |
| Serve-path observation snapshot (queue, KV, batch) | aien-dual-observation/src/lib.rs:118-158 | Implemented but disconnected (only dev-dependency users found: aien-scheduler tests) |
| Typed resource-condition state (latency, contention, memory pressure, deadline risk) as one type | none | Missing (pieces only, section 5) |
| Legacy ALLEN scoped memory | aien-allen-memory/src/lib.rs:1-16 | Implemented, separate store, not Cortex |

## 2. Cortex ownership table

Quoted migration plan, omega/src/runtime/rx_cortex.h:2-3 "Cortex, AIEN's durable typed memory. CANONICAL (M20)." and :4-10 AUTHORITY paragraph. Lines 22-29 verbatim: "Their records are not AIEN memory until they enter this store, and they enter only as CX_K_IMPORTED claims whose tag names the source (CX_SRC_*): never as facts and never by writing a journal directly. ... both are retired, not ported. (1) No new caller may be added to either. (2) Whatever is worth keeping is imported as CX_K_IMPORTED records through cx_append_as. (3) The crates are deleted. Until step 3 nothing may treat them as a source of truth."

| Consumer | Which Cortex implementation | Authoritative? | Migration state |
|---|---|---|---|
| Live HTTP service on 127.0.0.1:18080 | cortex-rs binary ~/.local/bin/cortex-rs (built Sep 18, 9974712 bytes), process pid 4773 listening on 18080, `--db-path ~/.config/cortex/cortex.db` (ss and ps output this session). Routes /api/cortex/{write,search,recall,get,traverse} match aien-sovereign-core/crates/cortex-rs/src/main.rs:109-116. Which source tree built the binary: UNVERIFIED (high confidence sovereign-core copy, since the standalone repo is archived) | No (rx_cortex.h:12-16) | Step 1 stated by header; no import into CxStore found by this scout (UNVERIFIED, not searched in omega beyond headers) |
| MCP "cortex" tools (lessons memory) | ~/workspace/cortex-mcp/lib.js:12 BASE = CORTEX_URL or http://127.0.0.1:18080; calls /api/cortex/search (:81), /recall (:85), /get (:91), /write (:179, :204). README says "stored in the local cortex-rs server" | No (HTTP client of the non-authoritative service) | Not migrated. Not a Rust crate caller, so "no new caller to the crates" does not cover it |
| aien-cli | HTTP :18080 via crates/aien-cli/src/cortex.rs:5, :39, :66 | No | Header names this caller (rx_cortex.h:15-16); still live |
| spark-mail-rs | Library link: Cargo.toml:27 cortex-rs path dep; src/effect.rs:8 `use cortex_rs::{...Database...}`; also cortex_sync.rs (HTTP client, :9-15) | No | Not migrated |
| cortex-path-m1 (read-only experiment) | Library link: Cargo.toml:21; tests/m1.rs:7, src/run.rs:7 | No | Experimental consumer, not migrated |
| aien-runtime (compose daemon) | Declares `cortex-rs = { path = "../cortex-rs" }` at crates/aien-runtime/Cargo.toml:18 but NO `cortex_rs` use in any aien-runtime .rs file (grep). Its real Cortex is omega C CxStore through aien-omega-compose (crates/aien-omega-compose/src/lib.rs:1-9 "recorded in the Cortex journal <dir>/cortex.cx"; aien-runtime/src/cortex_mark.rs:1-14, effects.rs:1-30, approved_replay.rs use it) | Yes (CxStore) | Already on canonical store; the Cargo.toml dependency on cortex-rs looks like a leftover (unused dependency; build.rs/cfg use UNVERIFIED) |
| spark-rsi (Cargo.toml only) | NO dependency on cortex-rs or any cortex crate (grep -i cortex of spark-rsi/Cargo.toml returned nothing; deps at lines 21-37 are clap, serde, spark-crumbs, crumb-spec, tokio, reqwest etc.). reqwest is present, so HTTP to :18080 is possible but UNVERIFIED (src not read, per scope) | n/a | n/a |
| aienos-aegis, aienos-explain, aienos-kernel continuity | aienos/crates/aienos-cortex (aienos-aegis/Cargo.toml:13, aienos-explain/Cargo.toml:12; kernel continuity.rs:260 holds a `cortex_wal` ObjectId list only) | No (rx_cortex.h:18-20) | Not migrated; aegis uses it as a dependency but src/*.rs had no `aienos_cortex` reference in grep (dependency possibly unused: UNVERIFIED) |
| omega runtime (rx_projection.c, rx_world.c, compose) | omega C CxStore, rx_cortex.h / rx_cortex_record.h | YES, only one | Canonical (M20, 2026-09-30) |
| AEGIS runtime (aegis-runtime) | No Cortex implementation. `cortex.search` and `cortex_recall` are in ALLOWED_SKILLS but "Registered but unconnected; their handlers only report Unavailable" (src/enforcement.rs:20-24) | n/a | Disconnected |
| ALLEN memory | Separate store `<home>.allen-memory/` (aien-allen-memory/src/lib.rs:1-5) | Not Cortex | Separate by design |

Reading: three live stores coexist (CxStore, cortex-rs SQLite at ~/.config/cortex/cortex.db, aienos-cortex in-process). The header declares only CxStore authoritative, yet all agent-memory traffic on this Spark (MCP, aien-cli, mail) goes to cortex-rs. Step 3 (delete) is far from done because step 2 (import as CX_K_IMPORTED) has no evidence of existing in what this scout read.

## 3. aegis-runtime: execution authority and enforcement

Public types (aegis-runtime/src/lib.rs:18-63 re-exports):
- Intent and capability: `ActionRequest { session_id, run_id, capability: String, intent: String, target, params }` execution/broker.rs:5-12; `Action` execution/action.rs:42-54 (capability and intent are free strings).
- Admission: trait `ExecutionAuthority::authorize(&ActionRequest) -> Result<DoctrineDecision,String>` broker.rs:15-18. `DoctrineDecision { Allow, AllowRestricted(Vec<String>), RequireApproval, Deny(String), Contain(ContainmentLevel) }` defense/decision.rs:15-22. `DefenseReceipt` defense/receipt.rs. `Approval/ApprovalStatus` defense/approval.rs:4-46.
- Emergency stop: only `ContainmentLevel::EmergencyStop` (decision.rs:7-12), as a decision value. No handler that acts on it was found (grep EmergencyStop: only the definition).
- Budget: `RunBudget { max_steps, max_inference_calls, max_actions, max_wall_time_secs }` orchestration/budget.rs:3-9; `SessionBudget { max_total_tokens, max_wall_time_secs }` sessions/session.rs:34-38. Used only to construct and map to AgentState ABI (session.rs:155-157). No enforcement site found.
- Grant: no type named grant exists in aegis-runtime. `WorkspaceCapability` security.rs:31 is a path-confinement object.
- What actually enforces: `enforcement::pre_dispatch_check` (enforcement.rs:31-58: exact-match ALLOWED_SKILLS, bash_eval only through `admit_local_command`, security.rs:326) then `probe_gate` (enforcement.rs:73-80, ProbePolicyGuard policy_guard.rs:54-111, threshold can only be raised by env, enforcement.rs:60-69). Called in SkillRegistry::execute (skills.rs:162) and dispatch_classified (skills.rs:131-143).

Tests that show enforcement independent of the caller:
- tests/gateway_auth_tests.rs:263 `skill_allowlist_holds_behind_the_token`: an authenticated caller still cannot run exec, shell, "Bash_eval", "bash_eval ", spawn_process (loop at :266, assertion contains "allowlist" at :278).
- tests/failure_provenance_tests.rs:2 "allowlist dispatch. Each test is a bypass attempt" (header comment; per-test content not read in full).
- src/enforcement.rs:80+ unit tests: destructive_shell_refused with forms the old blocklist let through.
- tests/aegis_tests.rs (skills.execute unknown skill refused with "not on the dispatch allowlist", ~line 480 area from grep of agent.rs:482 comment).
- tests/policy_guard_tests.rs:3-14 (reference backend; strict threshold fails closed).

Gap: the "grant, budget, emergency stop" the Adaptive Intelligence loop needs exist as unenforced data types here. The enforced path is allowlist plus probe, with no per-experiment grant or budget accounting.

## 4. aienos: native authority, capability, kernel (public interface only)

- aienos-capability (crates/aienos-capability/src/lib.rs, 1001 lines, 7 tests). Capability references are index plus generation (CapRef :119), `Entry` (subject, rights, 64-bit resource, epoch, lease_expiry, parent, :132-146), `Mint` (:149), `AuthorityState::{validate :256, mint :407, revoke :528 (cascades to descendants, :499), reclaim, advance_clock, bump_epoch}`. Checking and changing are split: `AuthorityView` (:615) can only inspect/validate; its `cognition_attempt_mint/revoke/reclaim/clock/epoch` (:640-656) exist to prove cognition cannot mutate; mutation needs `AuthorityAdmin` holding a 32-byte office token (:662-681). Error codes ERR_STALE_GEN/REVOKED/EPOCH/SUBJECT/RESOURCE/RIGHTS/EXPIRED/AMPLIFY (:19-30). Tests: forged_stale_subject_resource_and_rights_fail_closed :734, amplification_lease_epoch_and_revoked_ancestor_fail :790, generation_wrap_restarts_and_cognition_cannot_mint :899.
- aienos-kernel admission (crates/aienos-kernel/src/admission.rs): `AdmissionLimits :35`, `AvailableResources :78`, `AdmissionPolicy :91` with `evaluate :192` returning `GrantedAdmission :299` / `GrantedCapability :291`. Header :1-5: decides what a verified artifact may receive, does not reserve or execute. 7 unit tests.
- aienos-kernel budget (budget.rs): `ResourceEnvelope :7` (cpu ticks per period, memory frames, DMA bytes, max_runtime_ticks), `BudgetError :24`, `WorldState {Active, Quarantined} :34`, `BudgetMode {Active, Idle, Urgent} :40`, `BudgetManager::{admit :114, charge_cpu :178, charge_frames :192, pet :228, check :235, restore :254}`. Watchdog "pet/check" gives deadline policy. 6 tests.
- aienos-kernel scheduler (scheduler.rs:8-12): `TaskPriority { Background, Normal, Latency }`; `place :68`, `enqueue :93`; background starvation guard around :156-168. 9 tests.
- aienos-aegis (host-side crate, std + serde, not no_std kernel code): `EffectIntent { id, agent_id, action, parameters, claimed_capability_id, is_reversible, world_id }` effect.rs:12-19; `OperatorGrant`; `AegisDecision { Approved, RequiresOperatorApproval, Rejected }` evaluator.rs:9-13; `EffectBroker::dispatch` broker.rs:114 with `EffectAuditRecord :12`; `CapabilityGraph` HMAC-signed tokens, issue_root_token :230, derive_child_token :265, validate_token :340. Test: tests/phase_3_to_5_integration.rs (one file) plus broker.rs unit tests (:211, :331, :386). Doc comment lib.rs:3-4 "intelligence proposes; deterministic authority disposes". Disconnected: no other crate depends on it.
- aienos-cortex (src/store.rs `CortexStore` :19; record_observation :31, record_verified_fact :53, record_operator_decision :77): see section 2.

Relevance: this is the only place with unforgeable, revocable, leased capabilities plus resource envelopes, but it targets native Aienux, not the Linux Spark path used today (memory note aienos-local-copy-stale does not apply; the repo is a fresh clone). UNVERIFIED whether any of it runs on this machine.

## 5. aien-sovereign-core: Worlds, inference, spine, desk, entry point

- World implementations: (a) `WorldStore` aien-runtime/src/world.rs:67 with `WorldManifest { id, parent, object_root, filesystem_root, token_root, memory_root, capability_set, effect_log, created_at }` and an `EffectIntent` enum (WriteFile, ExecuteCommand, SendMessage, PublishGit) world.rs:10-22 — path-copying persistent worlds, effect journals; (b) the omega `RxWorld` (C) which is the authoritative world for compose (Compose::run, aien-omega-compose lib.rs:332) ; (c) aienos-aegis `JSpaceWorld` (aienos, copy-on-write, rollback/promote, world.rs:14-75). Three Worlds exist; the compose daemon uses the omega one for commit.
- Inference: `trait AienInferenceBackend` aien-abi-core/src/lib.rs:587 (load_model, execute_step -> StepMetrics, fork_sequence :607), used by the spine (aien-runtime/src/spine.rs:5-12, :20). `StepMetrics { prefill_tokens_processed, decode_tokens_emitted, step_latency_us, active_kv_blocks }` lib.rs:579-584. aegis-runtime has its own `InferenceEngine` trait (aegis-runtime/src/inference.rs:79) — duplicate interface, UNVERIFIED whether they are bridged.
- Spine (one line): `AienRuntimeSpine` aien-runtime/src/spine.rs:19-ff, the single-process runtime that unifies the sequence arena, scheduler, KV manager, WorldStore, context composer and swarm (spine.rs:1-3). CONTEXT.md:30 also uses "spine" for the daemon/compose bridge.
- Desk (one line): the "approval desk", the operator's approval step for effects; required by default, needs a desk key created by `aien compose desk-key --create 1` before the daemon starts (CONTEXT.md:13-14; code approved_auth.rs, spine.rs; header approved.rs:1-26: HMAC-authenticated approvals, replay claimed durably in the Cortex journal).
- Legacy memory consumers: cortex-rs library/HTTP callers (section 2); `aien-allen-memory` separate scoped store; spark-mail-rs; cortex-path-m1.
- Enforcement independent of caller, sovereign-core: effects.rs:25-30 "The ledger honours only grants the daemon wrote itself ... A caller-written authorization note ... is read but never honoured"; tests approved_attacks_test.rs c01-c08 (forged approver :210, invalid MACs :220-254, changed ids/path/content :268-318, desk key permissions :334); desk_required_server_test.rs :88, :108 (daemon refuses to start without desk). Durable stop: effects.rs:18-19 "stop ... A grant older than the newest stop is stale forever."
- Entry point for a bounded experiment through real authority: the aien-runtime control socket, command `ControlCommand::RunComposeTask { goal, workspace, context }` (control.rs:89-98), which runs the omega compose path (Skills compete on J-Space branches, AEGIS verify callback, winner commits via World, recorded in Cortex journal; aien-omega-compose lib.rs:1-9). An external effect then needs approval desk path (`ProposerHook`, approved.rs) -> `ComposeEffectIntent` -> ack (effects.rs, spine.rs:409-413). The emergency stop beneath that is omega `rx_world_emergency_stop` (rx_world.h:824) requiring caller credential plus a control capability with RX_WORLD_RIGHT_HALT, and refusing any reaction subject (rx_world.h:805-822). Operator-level `stop/resume/revoke` records exist in effects.rs:18-19.

## 6. Existing resource-condition observation

Pieces exist, no single typed condition state:
- omega/src/runtime/rx_world.h: `RxResourceNeed { memory_bytes, deadline, energy_cost, latency_class (recorded only) }` :241-249; `RxResourceBudget` :256-265; `RxStats` counters `blocked_resource :429`, `deadline_overdue :442`, `deferred_peak`, `deadline_cancelled :492` (HD-09). These are counters of past events, not a typed state of current latency/contention.
- aien-sovereign-core/crates/aien-dual-observation/src/lib.rs:118-158: `ServeObservationSnapshot` (waiting, preempted, running, KV blocks, batch limits) and `ObservationDelta`, a read-only snapshot of the serve path. Closest existing candidate; look at it before building anything. Consumers: only tests found (UNVERIFIED completeness).
- aien-abi-core `StepMetrics` lib.rs:579 (step_latency_us, active_kv_blocks).
- aien-runtime/src/spine.rs:478-479: KV "memory pressure" percentage, self-described "honest proxy until the GB10 telemetry hook lands".
- aienos-kernel budget.rs `WorldState`, `BudgetMode` (native only).
- Deadline risk: Missing as a derived value. Only the post-hoc overdue/cancelled counters (rx_world.h:442, :492) exist.
Classification: latency/memory-pressure raw observations Implemented but disconnected; contention and deadline risk typed state Missing.

## 7. Ownership conflicts and duplication risks

1. Biggest: Cortex has two live authorities in practice. rx_cortex.h declares C CxStore canonical and the crates retired, but every agent memory path on this Spark (MCP lessons, aien-cli, mail) writes to cortex-rs on :18080 with no import path observed. A new Adaptive Intelligence memory must write via omega CxStore (cx_append/cx_append_as, single writer) and NOT add a new caller to cortex-rs (rx_cortex.h:27-28 rule 1).
2. aegis-runtime has authority-shaped types (ExecutionAuthority, RunBudget, EmergencyStop) with no implementation. Do not build a new "budget" or "grant" type on them without deciding whether to implement them or use omega/aienos primitives. Three candidates for the same job: aegis-runtime types (unenforced), aienos-capability/aienos-aegis (native, strong, disconnected from Linux path), omega RxWorld authority and halt (enforced, C).
3. Three World implementations (sovereign-core WorldStore, omega RxWorld, aienos JSpaceWorld) and two inference traits (AienInferenceBackend, aegis InferenceEngine).
4. Stale dependency edges: aien-runtime -> cortex-rs and aienos-aegis -> aienos-cortex appear unused (grep), which will block step 3 deletion tracking unless cleaned.
