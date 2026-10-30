# ALLEN personalization: audit v1

Part of the finite workstream in `README.md` (not a master plan). Issue: aien-spark/aien-architecture#159. Written 2026-10-08.

Commits read (GitHub `main` on 2026-10-08, local fresh clones): aien-architecture `6b25403`, aien-sovereign-core `d6990e5`, aienos `c63d6db`, omega `b980783`, interplane `a14a1c3`. Open pull requests are proposed work, not current behaviour. Anything below without a cited source is labelled UNVERIFIED.

## 1. Dependency map: who owns what today

| Concern | Owner (repo, file) | What it does today | Source read |
|---|---|---|---|
| Decision | aien-architecture `docs/adr/0035-persistent-cognitive-entity-boundary-aien.md` | ACCEPTED 2026-10-06. AIEN is the organism, ALLEN the durable subject. | header of the ADR |
| Host identity gate | aien-sovereign-core `crates/aien-allen/src/{lib,resolve,subject_v0,binding,deployment}.rs` | RESOLVE ONLY. Reads a kind-24 SubjectState exported by AIENOS, decodes it (`subject_v0::decode`), checks lineage against Cortex journal record 1, keeps a host pin `<home>.allen-binding` and a hash-chained deployment record `<home>.allen-deployments`. Opt-in via `AIEN_ALLEN_SUBJECT`; refusal exits 78. `crates/aien-allen/tests/refusal_rows_test.rs` scans the source for banned names (`fn encode_subject`, `fn provision`, `cs_provision`, ...) so this crate can never write a subject. | `lib.rs` header, `refusal_rows_test.rs` |
| Gate engagement | aien-sovereign-core `crates/aien-runtime/src/spine.rs`, `allen_gate()` (about line 630), called on every compose-home open (about line 1884) | Engaged: prints `ALLEN: engaged agent=... head_sequence=... chain_verified=...`. Refused: fatal. Not engaged: one log line, no identity claim. The `Resolved` value is printed and then dropped; no later code receives the identity. | `spine.rs` 622-676 |
| Request path | `crates/aien-cli/src/compose.rs` (`aien compose propose|authorize|execute ...`) to `ControlCommand::RunComposeTask` (`control.rs`, `server.rs`) to `ComposeBridge` and `task_prompt()` / `task_decision()` / `propose_task_checked` (`spine.rs`) to the model to `ComposeTaskReport` (`control.rs`) | The product path. Writes need S4 `authorize` then S5 `execute`. The prompt is a fixed template; nothing from a profile enters it. | grep of the three files |
| Native subject format | [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) (Status: Proposed), `native/kernel/svc/continuity_subject.{h,c}` | Continuity kind 24 (`CC_KIND_SUBJECT`). Only intent kind is `CS_INTENT_GOAL_LATENCY` (1). Format not frozen. | `continuity_subject.h` lines 49-81 |
| Native provisioning | aienos `native/kernel/svc/continuity_subject_provision.{h,c}` (`cs_provision`), `continuity_boot.c` | `continuity_boot.c` is TEST-ONLY: empty unless `CK_TEST_CONTINUITY=1`. Only the TEST continuity image provisions a subject; the default image provisions none. | `continuity_boot.c` lines 1-20, 521-522 |
| Omega bindings | omega `spec/allen.md`, `src/allen/allen_bind.{c,h}` | Three bindings: identity, memory lineage, intent. Header says "ARCH-0035 PROPOSED" (stale, see PR 2). | `spec/allen.md` lines 1-25 |
| Memory | Cortex journal (ARCH-0022; omega `rx_cortex`, sovereign-core `cortex-rs`) | Owner of memory. Typed, append-only (`omega/spec/state-projection.md` line 32). The subject only holds a lineage reference. | grep |
| INTERPLANE | aien-spark/interplane | No ALLEN code at `a14a1c3` (recursive case-insensitive grep for "allen" found nothing). | grep |
| Shell (OSH) | issue aien-architecture#158 | Not built. | issue title only; no code searched beyond the five clones |
| Deployment record callers | `aien-allen::deployment::append` | No caller in `aien-runtime` or `aien-cli` at `d6990e5` (grep for "deploy" returned nothing). The model-swap record exists as a library only. | grep |
| Authorization | sovereign-core S4 `authorize` (approver key / approval desk) | Real permission gate for writes. Not influenced by any profile today because no profile exists. | `compose.rs` header lines 8-37 |

Open pull requests elsewhere that this work must not touch: sovereign-core #301, #294, #283, #278; interplane #76 (from the handoff; UNVERIFIED by this audit, not re-listed on 2026-10-08).

## 2. Status matrix: issue section 1 (concepts)

Status words: IMPLEMENTED-IN-PR means built in the **sovereign-core persona profile PR (pending)** and not on `main`; NOT STARTED; BLOCKED with the named blocker.

| Concept | Status | Note |
|---|---|---|
| Durable identity | EXISTING on main (resolve only, v0) | `aien-allen` as above. Not changed by this work. |
| Persona profile (display name, tone, verbosity, plain-language) | IMPLEMENTED-IN-PR (sovereign-core persona profile PR (pending)) | Contract in `CONTRACT-v1.md`. |
| Persona profile: avatar and voice selection | NOT STARTED, deliberately out of v1 | No facility exists to bind; status reports them "unsupported" rather than showing inert controls. |
| Persona profile: accessibility preferences | NOT STARTED | Only `plain_language` is in v1. |
| Working preferences (scoped key/value, provenance, revisions) | IMPLEMENTED-IN-PR (sovereign-core persona profile PR (pending)) | |
| Standing intent (general goals) | BLOCKED | Needs an [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) amendment (new intent kinds, lifecycle) and a `cs_provision` change, because host code cannot write SubjectState (the `aien-allen` source scan forbids it). v0 supports only `GOAL_LATENCY`. |
| Memory: scoped contexts, inspection | NOT STARTED | Cortex owns memory; needs a scope design. |
| Memory: correction, forget, export | BLOCKED | Needs a retention, redaction and encryption design against append-only Cortex. A tombstone is not erasure. Restores must not resurrect forgotten content. |
| Permissions | EXISTING (approval desk, S4/S5) | Contract states profile never grants. IMPLEMENTED-IN-PR includes a test that a permission-looking key is rejected and compose writes still require `authorize`. |
| User account/session | NOT STARTED | v1 is one local operator per compose home; no authenticated multi-user session. |

## 3. Status matrix: issue section 7 (stages)

| Stage | Status | Blocker or note |
|---|---|---|
| 1 Audit, dependency map, stale text | This PR (documents). Stale text: omega `spec/allen.md` (omega PR `allen159/spec-status`), architecture `doctrine/AIEN.md` line 629 (this PR) | |
| 2 Contracts and storage ownership | This PR (`CONTRACT-v1.md`) | Contract is a proposal for review, not an accepted ADR. |
| 3 Authoritative profile persistence, revisions, crash safety | IMPLEMENTED-IN-PR (sovereign-core persona profile PR (pending)) | Fixture and hosted tests only. |
| 4 Onboarding/attach and personalization controls in the supported interface | IMPLEMENTED-IN-PR for the host CLI (`aien allen ...`) | Attach-existing only. Create/provision is BLOCKED: native default-image provisioning is absent and host code must not synthesize a subject. |
| 5 Typed context assembly in production inference | IMPLEMENTED-IN-PR (RunComposeTask path) | Real-model effect NOT_RUN: needs a GPU slot. |
| 6 General standing-goal kind | BLOCKED | [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) amendment plus `cs_provision` change. |
| 7 Scoped memory inspect/correct/forget/export | BLOCKED | Retention/redaction/encryption design vs append-only Cortex. |
| 8 Shared presentation across interfaces | NOT STARTED | INTERPLANE has no ALLEN code; OSH (#158) not built. Needs an explicit versioned extension. |
| 9 Continuity, model-change, authorization, isolation, failure tests | PARTIAL: fixture tests for items 1, 2, 9, 10, 11, 12 of issue section 6 in the pending PR. Real-model and model-replacement behaviour: BLOCKED on a GPU slot (owned by another lane). Restart with the model swapped through the supported path: NOT STARTED (no deployment-append caller). | Existing synthetic digest tests do not establish behavioural continuity. |
| 10 Reproducible instructions, evidence, reviewable PRs | PARTIAL: this audit and the pending PRs. | Native, QEMU and physical runs: NOT_RUN. |

Environment tags used by the pending PR's tests: fixture-based host tests only. No real-model, QEMU or physical run is claimed.

## 4. Stale status text found

| Where | Text | Verdict |
|---|---|---|
| omega `spec/allen.md` line 3-4 | "ARCH-0035 ... PROPOSED" | Wrong against ADR 0035 (ACCEPTED 2026-10-06). Fixed in the omega PR with a dated note. |
| aien-architecture `doctrine/AIEN.md` line 629 | "ARCH-0035 ..., PROPOSED" | Wrong. Fixed in this PR (one word, plus date). |
| [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) line 3 | "ARCH-0035 ... PROPOSED"; [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) itself Proposed | The "Proposed" status of [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) is correct (format not frozen). Its ARCH-0035 label is stale. Not changed here: other repo. Already recorded in `docs/plans/aien-continuity/CAMPAIGN-v0-PREREG.md`. |
| `docs/adr/README.md` line 47, ADR 0035 header, `CAMPAIGN-v0-PREREG.md` | ACCEPTED | Correct. Untouched. |

Historical evidence and receipts were not edited.
