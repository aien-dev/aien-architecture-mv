# ADR 0015: Resident Semantic Store Boundary, Object Identity, and Reconstruction Contract

**Status:** Accepted by operator, 2026-09-27
**Author:** AIEN Architecture Working Group
**Date:** 2026-09-27
**Target Repositories:** `aien-architecture`, `aienos`, `omega`, `physics` (FORGE), `aegis-runtime`, `cortex-rs`, `aien-sovereign-core`

---

## Context

AIEN is a sovereign artificial intelligence architecture built on the canonical principle:

> **"AIEN lives in memory. Hardware visits it. Storage remembers how to bring it back."**

In this architecture, the primary running intelligence is an in-memory semantic world (`ResidentWorld`) materialized in coherent volatile memory. Accelerators (GPUs) and host processors (CPUs) are execution resources that visit this resident world to perform perception, reasoning, and transformation. Persistent storage (NVMe / block devices) is not the runtime medium; storage exists solely for deterministic reconstruction, provenance, durable knowledge, and cold recovery.

Previous milestones established foundational primitives across isolated subsystems:
- **OMEGA** (M4, M19) proved hardware-neutral semantic calculus, canonical object encodings (`OMG0`), deterministic `SemanticId` derivation, and accelerator residency.
- **FORGE** (formerly Machine Physics, M2, M16; ADR 0014) proved physical machine lowering, DMA descriptors, and Blackwell GPU execution pipelines.
- **AIENOS Store v1** (ADR 0015 in `aienos`) proved an append-only, content-addressed, crash-safe 4096-byte unit object store over NVMe.
- **AIENOS Continuity** (ADR 0016 in `aienos`, Proposed) describes QEMU-qualified single-agent provisioning and resume; its durable object format is not yet frozen.
- **CORTEX** (M18) proved epistemic fact storage, vector similarity ranking, and evidence retrieval.

However, the complete contract connecting live volatile memory to durable block storage across reboots remains unratified. Without an unambiguous architecture contract:
1. Systems risk conflating semantic meaning (`SemanticId`) with storage container identity (`Store ObjectId`).
2. Implementations risk leaking machine-local, process-local, or chip-specific addresses into persistent records.
3. Storage engines risk introducing generic relational/key-value databases (SQLite, RocksDB) into formal semantic layers.
4. Cold recovery lacks a mathematically deterministic protocol to restore the in-memory graph from cold silicon.

This ADR ratifies the **Resident Semantic Store boundary**, establishing the authoritative rules, memory categories, object models, commit protocols, and cold reconstruction algorithms that every downstream builder must obey.

---

## Normative Specification

### 1. Authoritative State

1. **Live Operational Authority**:
   While AIEN is actively running, **the live resident state in coherent memory (`ResidentWorld`) is the sole authoritative operational world**. Dynamic goals, frontier reasoning, attention context, and evolving semantic relations exist authoritatively in volatile RAM. Accelerators compute directly over projections of this live state.
2. **Persistent Storage Role**:
   Persistent storage is **durable recovery material, historical evidence, and the immutable lineage anchor**. Disk is not the active working state. Storage does not become authoritative for live operations while the machine is running.
3. **Durability Authority Transition**:
   Persistent storage becomes canonical recovery material for a generation only after Store v1 writes the inactive superblock and its second hardware flush succeeds. The Store validates the complete root before selecting it on recovery.
4. **Crash Authority**:
   Following a crash, power loss, or kernel panic, all volatile memory is considered void. Store v1 classifies both superblocks and validates their referenced graphs and history. Only a completely valid selected root can supply the authoritative recovery material for a new `ResidentWorld`; degraded selection is read-only inspection.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        AIEN ResidentWorld                              │
│         (Sole Authoritative Operational World While Running)           │
└───────────────────▲────────────────────────────────▲───────────────────┘
                    │                                │
                    │ realizes / projects            │ semantic references
                    ▼                                ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│           FORGE Realization          │  │       CORTEX Epistemic       │
│  (Disposable CPU/GPU machine state)  │  │   (Durable fact memory)      │
└──────────────────────────────────────┘  └──────────────────────────────┘
                    ▲                                ▲
                    │ visits                         │ checkpoints
                    ▼                                ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        AIENOS System Store v1                          │
│     (Authoritative Recovery Material & Historical Evidence Anchor)     │
├────────────────────────────────────────────────────────────────────────┤
│ ContinuityManifest ──► OmegaResidentRoot ──► Canonical Semantic Objects │
└────────────────────────────────────────────────────────────────────────┘
```

The ContinuityManifest-to-OmegaResidentRoot binding is a required future extension of proposed AIENOS ADR 0016, not a field in its current durable format.

---

### 2. Memory Categories

Every object, buffer, and descriptor within AIEN belongs to exactly one of five canonical memory categories. Mixing categories or persisting disallowed categories is a critical safety violation that causes immediate fail-closed termination.

| Property | `DURABLE` | `RECONSTRUCTIBLE` | `DERIVED` | `EPHEMERAL` | `DEVICE_LOCAL` |
|---|---|---|---|---|---|
| **Owner** | AIENOS Store v1 / Continuity | AIEN ResidentWorld | Runtime / Cache Manager | AIEN Reasoning Loop | FORGE / Hardware Driver |
| **Identity** | Store `ObjectId` & `SemanticId` | Canonical `SemanticId` | Derived Content Hash | Session-local ID / Index | Chip Handle / Hardware VA |
| **Lifetime** | Permanent (survives reboot) | Lifespan of Generation | Recomputed or Cached | Single Turn / Step | Active Device Session |
| **Mutability** | Immutable once committed | Immutable view; versioned | Invalidate and replace | Mutable scratch space | Volatile register/VRAM state |
| **May be persisted?** | **YES** (Mandatory) | NO (Rebuilt from Durable) | NO (Cached/discarded) | NO (Prohibited) | **NEVER** (Strictly Prohibited) |
| **Must be persisted?** | **YES** | NO | NO | NO | NO |
| **Reconstructed after reboot?** | Read directly from Store | Reconstructed from Durable | Re-evaluated on demand | Discarded on reboot | Re-initialized on silicon |
| **May contain machine addresses?** | **NEVER** | NO | NO | NO | YES (Device-only) |
| **Failure behavior** | Fail closed to Recovery Core | Re-derive from Store | Invalidate and recompute | Drop current turn | Reset device context |
| **Recovery behavior** | Validated via SHA-256 | Deterministically rebuilt | Lazy recomputation | Fresh initialization | Fresh allocation & binding |

---

### 3. Semantic Identity vs Runtime Realization

1. **The Invariance Principle**:
   Permanent semantic identity must **never depend on transient process, operating system, or hardware values**. A semantic object must have the exact same identity regardless of what CPU, GPU, memory address, or operating system instance executes it.
2. **Transient Realization State**:
   The following entities are explicitly classified as `DEVICE_LOCAL` or `EPHEMERAL` realization state and **must never appear in persistent storage**:
   - Host CPU pointers and virtual addresses (`*mut T`, `uintptr_t`, `void*`)
   - Accelerator / GPU virtual addresses (`gpu_va`)
   - Driver and resource manager handles (`RM_HANDLE`, NVRM allocations, channel handles)
   - Hardware queue IDs, ring buffer head/tail pointers, and doorbells
   - Channel generations and synchronization semaphore values
   - Operating system memory map addresses (`mmap`, page frame numbers)
   - File descriptors (`fd`), socket descriptors, and IPC pipe handles
   - Temporary allocation IDs and scratchpad addresses
   - Operating system process IDs (`PID`), thread IDs (`TID`), or core pinning masks
3. **Reconstruction Law**:
   Cold recovery reconstructs fresh hardware realizations rather than deserializing stale hardware or process identities. If any persistent record is found to contain a physical memory address or driver handle, the verifier MUST reject the record as corrupted.

---

### 4. Persistent Object Model

1. **Canonical Semantic Bytes**:
   Omega semantic objects are serialized strictly using the canonical Omega wire encoding (`OMG0` wire format):
   - Fixed header: Magic `OMG0` (`0x4F, 0x4D, 0x47, 0x30`), `version = 0x01`, `kind: u8`.
   - Lexicographically sorted attributes by key string.
   - Lexicographically sorted relations by `(kind, target_id)`.
   - Lexicographically sorted constraints by `(kind, payload)`.
   - Bounded payload bytes.
2. **Content Identity (`SemanticId`)**:
   `SemanticId` identifies semantic meaning:
   ```text
   SemanticId = SHA256(canonical_omega_encoded_bytes)
   ```
3. **Storage Container Identity (`Store ObjectId`)**:
   AIENOS Store v1 packages canonical semantic objects into storage application objects. `Store ObjectId` identifies a persistent storage container under AIENOS Store-domain hashing per AIENOS ADR 0015:
   ```text
   Store ObjectId = SHA256(
     ASCII("AIENOS-STORE-OBJECT-V1\0")
     || kind:u16le || version:u16le || byte_length:u64le
     || semantic_bytes[byte_length]
   )
   ```
4. **Identity Separation**:
   `SemanticId != Store ObjectId`. Even when wrapping identical canonical bytes, the Store envelope domain separation guarantees that the digests diverge. An explicit translation mapping connects them.
5. **Store Application Object Kinds**:
   Store v1 core format (ADR 0015) is frozen. New persistent semantic types are allocated within the application kind range:
   - `KIND_OMEGA_OBJECT = 24`: Holds the canonical Omega object wire bytes.
   - `KIND_OMEGA_RESIDENT_ROOT = 25`: Holds the resident graph root manifest and index.
6. **Immutability & Deduplication**:
   Once written to the Store append arena, objects are strictly immutable. If an object with an identical `ObjectId` already exists in the Store catalog, the write path deduplicates it by referencing the existing extent, provided its content digest is independently verified.
7. **Corruption Detection**:
   Every object read from persistent media must undergo two-level cryptographic verification:
   1. The Store envelope must match `Store ObjectId = SHA256(domain || header || bytes)`.
   2. The canonical payload must match `SemanticId = SHA256(bytes)`.
   Any mismatch constitutes immediate corruption.

---

### 5. Canonical Resident Root (`OmegaResidentRoot`)

The recoverable entry point for an Omega semantic world is the **`OmegaResidentRoot`** (Store v1 application kind 25).

#### 1. Fields and Bindings:
An `OmegaResidentRoot` minimally and normatively binds:
1. **Magic & Version**: Magic `OMGROOT1`, `format_version = 1`, `omega_schema_version: u16`.
2. **Generation Context**: Monotonic logical generation counter (`generation: u64`), logical epoch timestamp (`epoch: u64`).
3. **Agent Binding**: `logical_agent_id: [u8; 32]`, binding this graph to the provisioned agent.
4. **Lineage Reference**: `parent_resident_root_id: Option<ObjectId>`, pointing to the prior durable resident root (or zero for genesis).
5. **Semantic Graph Roots**: A bounded array of root `SemanticIds` representing the active entry points into the semantic DAG.
6. **Manifest Mapping Table**: A sorted array of tuples `(SemanticId: [u8; 32], store_object_id: ObjectId)`. Sorted in strictly increasing lexicographic order by `SemanticId` to allow $O(\log N)$ binary search during resolution.
7. **Cortex Checkpoint Reference**: `cortex_checkpoint_id: Option<ObjectId>`, binding the epistemic fact checkpoint.
8. **Capability Policy Root**: `policy_root_digest: [u8; 32]`, binding the durable security policy.
9. **Evidence Root**: `evidence_root_digest: [u8; 32]`, binding the signed evidence and receipt tree.
10. **Model State Reference**: `model_state_root_id: Option<ObjectId>`, binding the persistent learned weights and optimizer state.

#### 2. Strict Exclusion:
`OmegaResidentRoot` **must never contain** accelerator context handles, GPU virtual addresses, runtime queue pointers, or transient allocation identifiers.

---

### 6. Generation & Commit Model

Durability is an explicit Store v1 transaction barrier. The Store v1 commit protocol is fixed by accepted AIENOS ADR 0015; this ADR does not define a different storage transaction or ContinuityManifest byte layout.

#### The Ordered Commit Protocol:
1. **Freeze and preflight in memory**: Freeze the candidate `ResidentWorld` changeset; derive canonical `SemanticId` and Store `ObjectId` values; validate deduplication targets. Check all sizes, counts, arithmetic, catalog limits, transaction geometry, and bounded-region capacity before the first persistent write. A failed preflight writes nothing.
2. **Write new application objects**: Append every new Store application object contiguously, beginning at the predecessor's committed high-water. This includes canonical Omega objects and `OmegaResidentRoot`. A ContinuityManifest that binds the root is written here only after the proposed ADR 0016 durable format has been extended and accepted; this ADR does not assign it new binary fields.
3. **Write the complete new Catalog**: Append one immutable full Catalog after the application objects, sorted by Store `ObjectId`. It describes the complete committed application-object set.
4. **Write the CommitRecord**: Append the one-unit CommitRecord immediately after the Catalog, binding the catalog, predecessor identities, generation, and exclusive committed high-water.
5. **First hardware flush**: Flush the new application objects, complete Catalog, and CommitRecord to durable media.
6. **Write the inactive superblock slot**: Write the updated Store v1 superblock to the slot that is inactive for the predecessor generation. Do not rewrite the currently authoritative older superblock as part of this transaction.
7. **Second hardware flush — commit point**: Flush the newly written inactive superblock. **Successful completion of this second flush is the Store v1 durability commit point.**

```text
new application objects → complete new Catalog → CommitRecord → hardware flush
    → write INACTIVE superblock slot → hardware flush → COMMIT / DURABILITY POINT
```

#### Crash Semantics Around the Commit Point:
- **Before the inactive-slot write**: The older superblock remains untouched. Appended bytes beyond its exclusive high-water are uncommitted and may be reused after recovery.
- **During the inactive-slot write or second flush**: No physical 4096-byte write atomicity is assumed. Recovery reads both slots, verifies CRC32C and every referenced Store object and history relationship, then applies the Store v1 classification rules in Section 8. A torn or graph-invalid slot cannot become authoritative. A valid older root may be exposed read-only as `DegradedRecovery` under the specified conditions.
- **After the second flush succeeds**: The new generation has crossed the Store v1 durability commit point. Recovery still validates its complete root and history before selecting it; I/O errors and corruption have their own fail-closed classifications.

---

### 7. Storage Crash Consistency & Fault Tolerance

1. **Store unit and device geometry**: A Store v1 unit is 4096 bytes; supported physical logical-block sizes are 512 and 4096 bytes. A 4096-byte superblock write is **not** assumed physically atomic on either device. The Store uses two superblock slots, CRC32C, CommitRecord and Catalog SHA-256, application `ObjectId` checks, full graph validation, and generation/history validation to select a root after a crash.
2. **Ordered publication**: New application objects, the complete Catalog, and the CommitRecord are appended and flushed before the inactive superblock is written. The older authoritative slot is never rewritten by that transaction. The second flush is the commit point.
3. **Failure classification**: A torn slot, malformed root, corrupt object, inconsistent history, and I/O error have distinct Store v1 outcomes. Fallback to a valid peer is read-only `DegradedRecovery` where ADR 0015 requires it; a checksum-valid but graph-invalid root never becomes authoritative. The mount path neither repairs nor formats media implicitly.
4. **Replay boundary**: Store generations and predecessor links establish crash-consistent history. Store v1 alone does not detect a malicious full-device replay; the M5 off-disk `AntiRollbackSource` provides that freshness authority.
5. **Capacity failure**: Insufficient space for the whole transaction is a preflight failure with zero persistent writes. Volatile dirty state remains uncommitted.

---

### 8. Deterministic Cold Recovery Algorithm

When AIENOS boots on physical silicon or within a virtual machine, cold recovery executes strictly as follows:

```text
1. Open the bounded Store v1 region without writing or repairing it
   ↓
2. Read both superblock slots; any referenced-object or slot read error is MountError::Io
   ↓
3. Validate each candidate root in the frozen Store v1 trust order:
   Bounded Region → Superblock CRC32C → CommitRecord SHA-256 → Catalog SHA-256
   → sorted/bounded/non-overlapping descriptors → application ObjectIds
   → generation/history relationship
   ↓
4. Apply Store v1 root classification; only a completely valid root may be selected
   ↓
5. Count AgentRoot objects (0 = Stop/Unprovisioned, >1 = Stop/Conflict, 1 = Continue)
   ↓
6. Trace the supported ContinuityManifest chain to its unique tip (verify sequence, links, and ObjectIds)
   ↓
7. Resolve the OmegaResidentRoot ObjectId through the accepted future ADR 0016
   Continuity-format extension; without that extension, resident recovery is blocked
   ↓
8. Read & verify OmegaResidentRoot (Check magic, format_version, agent binding)
   ↓
9. Verify Object Closure:
   For each SemanticId reachable from root_semantic_ids:
     a. Lookup SemanticId in mapping_table to obtain Store ObjectId
     b. Read Store v1 object from media
     c. Verify Store envelope: SHA256 == ObjectId
     d. Decode OmegaObject from canonical bytes
     e. Verify recomputed SemanticId == expected SemanticId
     f. Enumerate relation SemanticIds; verify presence in mapping_table
   ↓
10. Reconstruct in-memory ResidentWorld graph (allocate fresh volatile nodes)
   ↓
11. Restore Cortex references: Bind EpistemicRef handles to Cortex database
   ↓
12. Rebuild transient CPU state: Allocators, task rings, scheduler queues
   ↓
13. Rebuild transient GPU realizations: FORGE compiles fresh pushbuffers/QMDs; allocates new GPU VAs
   ↓
14. Re-establish capabilities: Evaluate durable policy against physical hardware ID; mint runtime tokens
   ↓
15. On a normal writable mount, commit a new incarnation manifest before observation;
    a DegradedRecovery mount permits read-only inspection only
   ↓
16. Resume AIEN sovereign execution loop
```

Store v1 preserves these distinct classifications: `Unformatted`, `ForeignOrUnknown`, `UnsupportedVersion`, `Corrupt/RecoveryRequired`, `DegradedRecovery`, `ConflictingRoots`, and `InconsistentHistory`. Both all-zero slots mean `Unformatted`; foreign nonzero slots without Store magic mean `ForeignOrUnknown`; a CRC-valid unsupported version or feature means `UnsupportedVersion` without fallback. Two fully valid equivalent roots at the same generation are redundant; non-equivalent roots at that generation are `ConflictingRoots`. Fully valid adjacent roots require matching Store UUID and region geometry and an exact predecessor generation, CommitRecord ID, and Catalog ID relationship; otherwise they are `InconsistentHistory`. Nonadjacent valid generations are also `InconsistentHistory`.

If one root is fully valid and its peer is invalid, apply ADR 0015's exact cases: a newer graph-invalid peer or a structurally invalid peer yields read-only `DegradedRecovery`; a fully valid newer root may be selected over a graph-invalid older peer; an all-zero peer with one valid root is a valid Store. A graph-invalid peer at the same generation does not silently become a writable fallback. CRC-valid unsupported format does not fall back. `MountError::Io` remains an I/O error, not corruption. No checksum-only generation ranking is permitted.

#### Anomaly Resolution Rules:
- **Store Root Failure**: Apply Store v1 classification before Continuity inspection. A permitted `DegradedRecovery` root is read-only; corruption, unsupported format, conflicting roots, inconsistent history, and I/O errors do not resume normal operation.
- **Continuity or Resident Root Failure**: If the selected Store root is valid but its Continuity manifest or Omega root fails semantic validation, fail closed to **Recovery Core** (`CONTINUITY: CORRUPT`). Never attempt heuristic salvage.
- **Missing Object**: If any object in the transitive closure of the root set is missing from the Store, fail closed (`CONTINUITY: CORRUPT`). Never run with a partial semantic graph.
- **Historical Parent Valid**: Recovery Core may inspect an older committed generation and, after offline operator authorization under ADR 0006, initiate the forward rollback described in Section 9. This is distinct from Store v1 automatic crash fallback.
- **No Valid Generation**: If no valid `AgentRoot` exists, halt with `CONTINUITY: UNPROVISIONED`. Never mint an automatic replacement identity.
- **Unverified Evidence**: If an evidence receipt claims a generation that cannot be reconstructed from storage, mark the receipt as unverified and halt in Recovery Core.

---

### 9. Rollback Architecture

1. **Automatic crash fallback and degraded inspection**: Before the second Store v1 flush succeeds, recovery may select the prior completely valid committed root under ADR 0015. A damaged peer may instead yield read-only `DegradedRecovery`. Neither event is an operator-requested historical rollback, and degraded inspection cannot make new in-band commits.
2. **Operator-authorized historical rollback**: Selecting an earlier committed semantic state after a later generation was committed is an exceptional Recovery Core action. ADR 0006 requires local, offline operator authentication. Store v1 structural validity and M5 freshness/authentication checks still apply; a malicious disk replay is not authorized by a high or low generation number alone.
3. **Forward-only history rule**: An authorized historical selection does not rewrite or truncate generations $K..N$. After validating the selected historical state and authorization, the system must produce a **new forward Store generation** after $N$ whose resident semantic root represents the selected state, preserving the intervening history for audit. The normal running world resumes only after this forward generation and its required security/freshness commitments are durable.
4. **Continuity-format prerequisite**: Proposed ADR 0016 has no `rollback_parent_id` field and its durable format is not frozen. Before implementation, ADR 0016 / the Continuity format **MUST be extended and accepted** to bind the selected historical root, its source generation, authorization evidence, and new forward continuity view. This ADR sets the semantic requirement without assigning on-disk offsets, field names, or binary encoding.

---

### 10. Cortex Epistemic Memory Boundary

1. **Separation of Concerns**:
   - **Resident Semantic Store (`ResidentWorld`)**: Active, operational semantic state, reasoning graphs, goals, and transient attention context.
   - **Cortex**: Durable epistemic memory containing settled facts, world knowledge, dense vector embeddings, full-text indexes, and empirical evidence.
2. **Prohibition of Database Replacement**:
   Cortex durable memory must not become the live runtime scheduler database, and Omega must not embed Cortex's SQLite/vector database internals.
3. **Cross-Boundary References**:
   Active semantic objects reference Cortex knowledge exclusively through immutable, typed reference handles:
   ```text
   struct EpistemicRef {
       fact_id: [u8; 32],        // Unique immutable fact identifier in Cortex
       evidence_hash: [u8; 32],  // Cryptographic digest of supporting evidence
       schema_epoch: u32,        // Epistemic schema generation
   }
   ```
4. **Promotion Lifecycle**:
   Knowledge moves strictly forward through a verified lifecycle:
   ```text
   Ephemeral Reasoning (RAM)
       ↓ evaluated and supported by empirical evidence
   Candidate Knowledge (J-Space)
       ↓ verified by AEGIS contract checker
   Cortex Admission (Signed Admission Receipt)
       ↓ committed to Cortex WAL / Checkpoint
   Durable Epistemic Fact (Referenced by ResidentWorld via EpistemicRef)
   ```
5. **Cold Recovery Parity**:
   On cold restart, resolving an `EpistemicRef` from the reconstructed `ResidentWorld` retrieves the identical committed Cortex fact and evidence receipt.

---

### 11. Model & Learned State

1. **Structured Semantic Representation**:
   Learned weights, model architectures, optimizer states, training steps, and RNG states must be represented as structured, content-addressed semantic objects, **not opaque third-party binary blobs** (e.g. PyTorch pickles or unverified binary dumps).
2. **Deconstruction into Semantic Objects**:
   - **Weights**: Chunked into immutable, content-addressed memory blocks (`KIND_MEMORY = 0x06` or `KIND_VALUE = 0x01`), indexed by tensor descriptor metadata.
   - **Model Architecture**: Formal Omega operation DAG (`KIND_OPERATION = 0x03`, `KIND_TYPE = 0x02`).
   - **Execution Context**: Checkpoint metadata binding current training step (`u64`), learning rate schedule, and cryptographic RNG seed (`[u8; 32]`).
3. **Portability**:
   Model state represented in this manner can be reconstructed onto any supported accelerator (Blackwell, Grace CPU, or generic AArch64) without format conversion.

---

### 12. GPU & FORGE Machine Reconstruction (The Reboot Theorem)

> **The Reboot Theorem**: *Semantic identity survives reboot; physical hardware realizations do not.*

1. **Disposable Projections**:
   All GPU memory allocations, command buffers, page tables, and hardware queues are disposable projections of the underlying `ResidentWorld`.
2. **Reconstruction Pipeline**:
   After cold recovery restores the logical `ResidentWorld`, the accelerator state is reconstructed through a four-stage lowering chain:
   ```text
   Persistent Semantic Object (Durable)
       ↓
   Omega Realization Request (Hardware-neutral intent)
       ↓
   FORGE Target Realization (Physical machine lowering: compiles kernels, plans VRAM layout)
       ↓
   AEGIS Verification (Validates alignment, bounds, and security invariants)
       ↓
   New Accelerator-Resident State (Fresh GPU VAs, new RM channels, new doorbell bindings)
   ```
3. **Zero Address Leakage**:
   The newly assigned GPU virtual addresses, NVRM channel handles, and doorbell addresses are completely independent of the addresses used prior to the reboot. The logical `SemanticId` remains bit-for-bit identical.

---

### 13. Capability & Security State Reconstruction

1. **Persistent ownership**:
   - `AgentRoot` (Continuity kind 16) carries persistent logical agent continuity identity. It does **not** contain secret key material or reusable authorization state.
   - `KeySlotManifest` (M5 kind 21) carries wrapped `K_vol` for boot and recovery keyslots. Persistent storage may hold this wrapped key material according to the M5 security contract, never plaintext live `K_vol` in `AgentRoot`.
   - `SecurityManifest` (M5 kind 22) authenticates the logical commit roots under the M5 key hierarchy.
   - `AntiRollbackSource` is the off-disk or hardware freshness authority. Store v1 generations alone do not provide malicious replay protection.
2. **Boot validation order**: First validate the Store v1 structure and history; then apply M5 keyslot unwrap and authenticated security-root checks; then compare the off-disk freshness anchor. A failed security or freshness check halts in Recovery Core before resident execution.
3. **Fresh runtime authority**: FORGE observes current physical hardware; AEGIS evaluates durable policy against that verified hardware. Runtime capabilities and slot generations are freshly derived and minted after boot. Persistent records must never contain reusable live capability handles, authorization booleans such as `is_authorized = true`, or hardware addresses.

---

### 14. Evidence & Provenance Lifecycle

Every state transition must generate machine-readable, verifiable evidence. Evidence records must distinguish five distinct lifecycle states:

```text
PROPOSED ──► WRITTEN ──► DURABLE ──► RECOVERED (or REJECTED)
```

1. **`PROPOSED`**: Candidate generation constructed in RAM; contains list of modified `SemanticIds`.
2. **`WRITTEN`**: Objects written to Store append arena; contains Store extent descriptors and calculated `ObjectIds`.
3. **`DURABLE`**: Generation committed via Superblock flush; contains `CommitRecord` hash, Superblock index (A or B), and monotonic generation number.
4. **`RECOVERED`**: Cold recovery successfully completed; contains reconstructed graph digest, execution timestamp, and new incarnation number.
5. **`REJECTED`**: Validation failure receipt; contains exact failing offset, mismatched cryptographic hash, missing object ID, and reason for fail-closed termination.

---

### 15. Comprehensive Failure Matrix

| Failure Event | Detection Mechanism | Safe State | Fallback Action | Operator Evidence |
|---|---|---|---|---|
| **Crash before inactive-slot write** | Full Store v1 root validation finds the older root | Prior committed generation intact | Ignore uncommitted append tail beyond its high-water | `RECOVERY_PRIOR_GENERATION_RESUMED` |
| **Crash during inactive-slot write or second flush** | Dual-slot CRC32C, object graph, and history validation | Only a fully valid root may be selected | Apply ADR 0015 normal or read-only degraded classification; never trust a torn slot | `RECOVERY_SUPERBLOCK_TORN_FALLBACK` |
| **Power loss after successful second flush** | New root passes full graph and history validation | New committed generation is selectable | Resume only after Continuity and M5 checks also pass | `RECOVERY_NEW_GENERATION_RESUMED` |
| **Truncated object** | Store envelope length != read length | Fail closed to Recovery Core | Halt; require operator inspection | `RECOVERY_OBJECT_TRUNCATED_REFUSED` |
| **Corrupted object bytes** | `SHA256(bytes) != ObjectId` | Fail closed to Recovery Core | Halt; refuse dirty state | `RECOVERY_OBJECT_CHECKSUM_MISMATCH` |
| **Missing root object** | `OmegaResidentRoot` not in catalog | Fail closed to Recovery Core | Halt; never guess root | `RECOVERY_ROOT_OBJECT_MISSING` |
| **Missing child object** | Traversal encounters missing ID | Fail closed to Recovery Core | Halt; reject partial graph | `RECOVERY_GRAPH_CLOSURE_INCOMPLETE` |
| **SemanticId mismatch** | Canonical decode digest != SemanticId | Fail closed to Recovery Core | Halt; refuse invalid semantics | `RECOVERY_SEMANTIC_ID_DIVERGENCE` |
| **Conflicting or inconsistent Store roots** | Same-generation non-equivalence or invalid predecessor/history relationship | `ConflictingRoots` or `InconsistentHistory` | Halt normal resume; require Recovery Core inspection | `RECOVERY_ROOT_HISTORY_REFUSED` |
| **Degraded Store root** | One fully valid root and a peer matching ADR 0015 degraded cases | Read-only `DegradedRecovery` | Permit inspection; prohibit in-band commits and normal resident execution | `RECOVERY_DEGRADED_READ_ONLY` |
| **Unsupported Store format** | CRC-valid unsupported version or features | `UnsupportedVersion` | Halt; do not fall back to another root | `RECOVERY_UNSUPPORTED_FORMAT` |
| **Invalid capability state** | Policy validation fails during boot | Recovery Core minimal privilege | Refuse execution grants | `SECURITY_CAPABILITY_REISSUANCE_FAILED`|
| **GPU reconstruction failure** | FORGE kernel compilation error | Degraded CPU-only resident state | Alert operator; no GPU ops | `FORGE_REALIZATION_GPU_FAILED` |
| **Cortex unavailable/corrupt** | Cortex database integrity check fail | Epistemic read-only recovery | Halt learning; allow inspection| `CORTEX_CHECKPOINT_INTEGRITY_FAILED` |
| **Storage full** | Pre-write arena capacity check | Prior committed generation intact | Abort commit; keep live state | `STORAGE_APPEND_ARENA_EXHAUSTED` |
| **Hardware I/O error** | NVMe driver returns error code | Report `MountError::Io` | Never treat I/O error as corrupt | `STORAGE_HARDWARE_IO_FAULT` |

---

### 16. Subsystem Boundaries (Owner / Boundary / Failure / Evidence)

#### 1. AIEN ResidentWorld
- **Owner**: `aien-sovereign-core`
- **Boundary**: Operates entirely in coherent volatile memory; issues commit barriers to AIENOS; never performs direct disk I/O.
- **Failure Behavior**: On crash or panic, all volatile state is abandoned; recovery uses only a fully validated selected Store root and resumes normally only from a writable valid mount.
- **Evidence**: Emits `RESIDENT_WORLD_EPOCH_ADVANCED` and `RESIDENT_GENERATION_PROPOSED`.

#### 2. Omega Semantic Calculus
- **Owner**: `omega`
- **Boundary**: Pure formal semantic encoding, `SemanticId` computation, and graph reachability; no knowledge of storage, hardware, or filesystems.
- **Failure Behavior**: Returns error codes on malformed structures; fails closed without mutating state.
- **Evidence**: Known-answer test evaluation suites and deterministic `SemanticId` logs.

#### 3. AIENOS System Store v1
- **Owner**: `aienos` (Kernel Store subsystem)
- **Boundary**: Fixed 4096-byte unit append-only block storage over NVMe; content-addressed `ObjectId` hashing; owns Superblocks, Catalogs, and CommitRecords.
- **Failure Behavior**: Read errors yield `MountError::Io`; Store v1 preserves `Unformatted`, `ForeignOrUnknown`, `UnsupportedVersion`, `Corrupt/RecoveryRequired`, `DegradedRecovery`, `ConflictingRoots`, and `InconsistentHistory`; never auto-formats or repairs.
- **Evidence**: Superblock transaction receipts and Store unit extent maps.

#### 4. AIENOS Continuity Subsystem
- **Owner**: `aienos` (Kernel Continuity subsystem)
- **Boundary**: Tracks `AgentRoot` and `ContinuityManifest` chains; manages single-agent identity and incarnation progression.
- **Failure Behavior**: Unprovisioned halts with `UNPROVISIONED`; multi-root halts with `CONFLICT`; broken chains halt with `CORRUPT`.
- **Evidence**: `CONTINUITY: RESUMED agent=<id> incarnation=<n> sequence=<s>`.

#### 5. FORGE Machine Realizer
- **Owner**: `physics` (FORGE)
- **Boundary**: Lowers abstract Omega programs to concrete hardware schedules (CPU / Blackwell GPU); owns VRAM allocation and DMA channels.
- **Failure Behavior**: If physical allocation fails, emits alternative realization constraints back to Omega or reports realization failure.
- **Evidence**: `FORGE_REALIZATION_SUCCESS` receipts with verified machine fact digests.

#### 6. AEGIS Invariant Verifier
- **Owner**: `aegis-runtime`
- **Boundary**: Continuous verifier spanning all state transitions; verifies reachability, bounds, non-persistence of hardware addresses, and policy compliance.
- **Failure Behavior**: Immediately blocks invalid state transitions; issues deterministic refusal receipts.
- **Evidence**: Signed verification receipts (`AEGIS_VERIFY_PASS` / `AEGIS_VERIFY_FAIL`).

#### 7. Cortex Durable Memory
- **Owner**: `cortex-rs`
- **Boundary**: Durable epistemic database; manages entity facts, vector similarity search, and evidence logs; referenced via `EpistemicRef`.
- **Failure Behavior**: Database corruption stops epistemic updates; falls back to read-only historical search.
- **Evidence**: Cryptographic fact admission receipts and vector index integrity digests.

---

### 17. Implementation Ownership Across Repositories

Future implementation work is strictly partitioned across existing repositories without introducing new repositories:

| Stage / Component | Repository | Primary Deliverables |
|---|---|---|
| **Architecture Contract** | `aien-architecture` | ADR 0015 (this document) and master plan alignment. |
| **Semantic Persistence API** | `omega` | Pure C API for canonical object validation, reachability traversal, and determinism tests. |
| **Store Bridge & Kinds** | `aienos` | Implementation of Store v1 kinds 24 & 25, write/read paths, and deduplication. |
| **Continuity Integration** | `aienos` | Extension of `ContinuityManifest` to bind `OmegaResidentRoot`, cold boot restore in kernel. |
| **Independent Verifier** | `aegis-runtime` | Implementation of `verify_resident_generation` and refusal receipts. |
| **Physical Realization** | `physics` (FORGE) | Verification of disposable GPU projections and hardware address non-persistence. |
| **Epistemic Integration** | `cortex-rs` | `EpistemicRef` handle definitions and fact promotion lifecycle. |
| **Runtime Residency** | `aien-sovereign-core` | `ResidentWorld` continuous execution lifecycle and checkpoint barriers. |
| **Store Compaction** | `aienos` | Two-region live-set migration implementation for long-lived continuous execution. |
| **Destructive Qualification** | `aien-harness` / `spark-inquisitor` | 20-step fault injection qualification suite (`AIEN_RESIDENT_CONTINUITY`). |

---

### 18. No-Premature-Implementation Rule

> **Normative Restriction**:
> **No downstream Resident Semantic Store implementation begins in any repository until ADR 0015 is formally ratified and merged into `aien-architecture`.**
> 
> Downstream builders (Builders 2 through 10) must implement strictly against the boundaries, types, and invariants frozen by this document. No builder may invent ad-hoc storage formats, alter frozen Store v1 bytes, or introduce external database dependencies.

---

### 19. Acceptance Gates for ADR 0015

This accepted architecture boundary answers 15 core questions; proposed Continuity-format additions remain prerequisites for implementation:
1. **What lives only in RAM?** Dynamic goals, active reasoning state, scratchpad buffers, compiled kernel caches, and physical hardware addresses.
2. **What can survive reboot?** Immutable `DURABLE` Store v1 objects (`AgentRoot`, `ContinuityManifest`, `OmegaResidentRoot`, canonical semantic objects, Cortex checkpoints, and M5 security objects). The Continuity binding to OmegaResidentRoot awaits an accepted ADR 0016 format extension.
3. **What is immutable?** All committed Store v1 objects, historical generations, and canonical semantic bytes.
4. **What is mutable?** Active `ResidentWorld` working memory in volatile RAM (prior to commit freeze).
5. **What identifies a semantic object?** `SemanticId` = SHA-256 of canonical Omega wire encoding (`OMG0`).
6. **What identifies a durable generation?** A fully validated Store v1 CommitRecord `ObjectId` and generation, with matching Catalog and superblock fields; the ContinuityManifest identifies the agent continuity view within that generation.
7. **What is the single durability commit point?** Successful completion of the second hardware flush after writing the inactive superblock slot.
8. **What happens on power loss at every stage?** Sections 6, 8, and 15 define full validation, read-only degraded cases, and fail-closed errors; a torn 4096-byte write is never presumed atomic.
9. **How is a root selected?** Both slots pass through bounded-region, CRC32C, CommitRecord, Catalog, descriptor, application-object, and generation/history validation. ADR 0015 classifications determine normal, degraded, or refused recovery.
10. **What is reconstructed rather than restored?** Graph adjacency indexes, lookup tables, runtime task queues, memory allocators, GPU VAs, and device channels.
11. **What authority must be re-derived after reboot?** All runtime capabilities, hardware access rights, and execution tokens are re-issued by AEGIS from durable policy.
12. **How does Cortex relate to resident state?** Distinct epistemic store referenced via immutable, typed `EpistemicRef` handles.
13. **How does GPU state get reconstructed?** Freshly compiled and allocated by FORGE as disposable projections with new hardware addresses.
14. **What evidence proves successful recovery?** Bit-for-bit `SemanticId` recalculation across all reachable objects and valid `CONTINUITY: RESUMED` log receipt.
15. **Can any stale pointer/handle cross reboot?** **NO.** Strictly prohibited without exception.

---

## Consequences

### Positive Consequences
- **Complete Decoupling**: AIEN's intelligence is formally liberated from physical silicon placement.
- **Crash Consistency**: Store v1 can reject torn or invalid roots and select a fully valid history according to its normal or degraded recovery rules.
- **Clear Boundary**: Builders 2 through 10 have a defined semantic contract; Continuity-format amendments must be accepted before resident-state implementation.

### Negative Consequences / Tradeoffs
- **Catalog Bound**: Store v1's 4,096-entry catalog requires future live-set migration (Builder 9) before long-running continuous deployments exhaust entries.
- **Serialization Overhead**: Every state commit requires canonical sorting and cryptographic hashing of all reachable objects.

### Downstream Builders Blocked on Ratification
- **Builder 2**: Omega Semantic Persistence Builder (`aien-spark/omega`)
- **Builder 3**: AIENOS Omega Store Bridge (`aien-dev/aienux`)
- **Builder 4**: AIENOS Continuity / Resident World (`aien-dev/aienux`)
- **Builder 5**: AEGIS Resident-State Verifier (`aien-spark/aegis-runtime`)
- **Builder 6**: FORGE Machine Realization (`aien-spark/physics`)
- **Builder 7**: Cortex Integration (`aien-dev/cortex-rs`)
- **Builder 8**: AIEN Runtime Residency (`aien-spark/aien-sovereign-core`)
- **Builder 9**: Long-Lived Store / Compaction (`aien-dev/aienux`)
- **Builder 10**: Destructive Qualification (`aien-dev/aien-harness`, `aien-dev/spark-inquisitor`)
