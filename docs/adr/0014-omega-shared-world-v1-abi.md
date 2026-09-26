# ADR 0014: OMEGA_SHARED_WORLD_V1 — Coherent CPU↔GPU Shared-State ABI

**Status:** Proposed (M20 preparatory Stage 1, branch-only)

## Context

The proposed M20 preparatory stage builds a CPU↔GPU coherent shared-state
substrate for AIEN on DGX Spark / Grace Blackwell GB10. The architectural target
is that AIEN executes
on the GPU and AEGIS executes on the CPU side, and the two communicate **only**
through a persistent PHYSICS-owned coherent-memory world — never by giving AIEN
CPU execution authority, CPU pointers, or host syscalls.

The existing doctrine (`OMEGA.md` §9, `ARCHITECTURE.md`) already names the ring
buffers (`INTENT_RING`, `RESULT_RING`, `EFFECT_RING`, `PROOF_RING`,
`EVIDENCE_STORE`), mandates 64-byte cacheline alignment, and specifies `stlr`
(release) / `ldar` (acquire) publication. But it contains an unresolved
contradiction and several under-specified points that a real ABI must settle.

### The 64-byte contradiction

`OMEGA.md` §9.1 prose describes the intent descriptor as a "64-byte descriptor"
containing `target_semantic_id` (32 bytes) + `realization_id` (32 bytes) +
`input_tensor_handles` (array) + `generation` (64-bit). Appendix A's
`omega_intent_entry_t` is exactly 64 bytes and holds *only* the two 32-byte IDs.
The two IDs alone consume the entire 64 bytes; the sequence, epoch, generation,
tensor handles, and length the prose also demands cannot fit. The descriptor is
therefore over-specified: as written it cannot carry what a correct cross-processor
queue entry needs (message type, sequence, world epoch, producer generation,
object references, payload length, flags, integrity).

## Decision

### 1. A 128-byte explicit descriptor (two cache lines)

`OMEGA_SHARED_WORLD_V1` defines a **128-byte** message descriptor
(`OmegaSharedWorldDesc`), exactly two 64-byte cache lines:

- **Line 0 (control):** `magic`, `abi_version`, `msg_type`, `sequence` (64-bit),
  `world_epoch`, `producer_generation`, logical object reference
  (`object_id`, `object_generation`, `object_offset`, `object_length`),
  `payload_len`, `flags`, `xform`, `arg_a`, `arg_b`, and a `checksum` (CRC32C).
- **Line 1 (payload):** 64 bytes of inline payload, which is also where the
  doctrinal 64-byte identity pair (`semantic_id[32]` + `realization_id[32]`)
  lives when a real INTENT is carried.

This is a proposed **superset** of the doctrinal 64-byte intent entry: the identity
pair still occupies one 64-byte line, and 64-byte alignment (Cacheline
Sovereignty) is preserved. On adoption, `OMEGA.md` §9.1 must describe the
64-byte `omega_intent_entry_t` as the *identity payload* carried on line 1 of
the 128-byte transport descriptor, resolving the contradiction without
discarding the doctrinal struct.

### 2. Little-endian, fixed-width, directly interpreted (not canonical serialization)

The shared-world ABI is host-native **little-endian** fixed-width integers
(GB10 is little-endian on both the Arm CPU and the Blackwell GPU). This is the
doctrine's **Zero Serialization** contract: data is structured in memory exactly
as the consuming execution unit expects, so both processors interpret it with no
marshalling.

This is a **different concern** from OMEGA canonical *semantic* serialization
(`SPEC-OMEGA-CANON-M4`), which is big-endian and exists only to derive
content-addressed `SEMANTIC_ID`s by hashing. The two must never be conflated:
32-byte id fields embedded in the shared world are raw digests (byte arrays,
endian-neutral); the ring's numeric control fields are little-endian scalars.

### 3. Pointer-free logical references only

No field in the shared world ever holds a host virtual address, GPU virtual
address, RM object handle, kernel pointer, or physical address. Every reference
to memory is a logical `{object_id, object_generation, offset, length}` tuple
resolved internally by PHYSICS against a trusted object table, exactly as the
M19 capability handle (`accelerator-world.md` §2.3) carries no GPU VA or size.
This is the memory-level foundation of the invariant: *AIEN can communicate with
CPU-side authority without ever possessing CPU execution authority* — the GPU
cannot even name a host/kernel VA or RM handle, because the ABI has no field for
one and resolution rejects any reference outside a current, valid object window.

### 4. Generation + epoch + free-running sequence protection

- **World epoch** (32-bit) guards the whole world; bumped on rebuild.
- **Object generation** (32-bit per object) guards each logical reference (ABA).
- **Sequence** is the free-running 64-bit ring counter; the per-slot `sequence`
  must equal the consumer's expected index, which defeats ABA slot reuse and
  replay of a stale entry. 64-bit counters never wrap in the machine's lifetime.

### 5. CRC32C is optional defense-in-depth

The primary torn/stale/duplicate/replay guarantees come from release/acquire
ordering plus `sequence == index`. The CRC32C `checksum` is optional
defense-in-depth, gated by `OMEGA_SW_FLAG_CHECKSUM`, so a GPU worker need not
implement CRC32C in SASS while the CPU↔CPU path stays fully checksummed.

### 6. SHA-256, not BLAKE3 (noted tension)

`OMEGA.md` §5.2 names BLAKE3 for `*_ID` digests, but the shipped, silicon-
qualified precedent (M19, `canonical-encoding.md`, `machine.md`) uses SHA-256.
M20 uses **SHA-256** for consistency with shipped code and does not introduce
BLAKE3. The doctrinal BLAKE3/SHA-256 tension is recorded here for a future ADR.

### 7. Placement (no duplication)

- The **proposed semantic definition** is recorded in this ADR and the M20
  preparatory spec (`docs/milestone-20-spec.md`). The canonical OMEGA doctrine
  must be revised before the ABI is ratified.
- The **canonical ABI C header**, when adopted, lives once in
  `aien-dev/physics:shared_world/omega_shared_world_abi.h`. OMEGA already
  includes PHYSICS headers, so both repos compile against one definition with
  zero duplication.
- **PHYSICS realizes** the coherent memory (`coherent/physics_coherent.*`) and
  the ring/publication mechanics (`shared_world/omega_shared_world.*`).
- **OMEGA** owns the Blackwell resident-worker codegen and the qualification
  harness (Blackwell codegen already lives in `aien-dev/omega`).

## Consequences

- Doctrine's ring names, alignment, and `stlr`/`ldar` publication are preserved;
  only the descriptor width is corrected (64 → 128 bytes) and documented as a
  superset.
- `AIEN PROPOSES. OMEGA DEFINES. PHYSICS REALIZES. AEGIS VERIFIES. HARDWARE ACTS.
  EVIDENCE TEACHES.` is preserved: OMEGA defines the ABI semantics, PHYSICS
  realizes the coherent memory and mechanics, AEGIS (CPU side) verifies authority
  and bounds at resolution, and no layer performs another's duty.
- Reserved offset slots for `EFFECT_RING`, `EFFECT_RESULT_RING`, `PROOF_RING`,
  `EVIDENCE_RING`, `SEMANTIC_STORE`, and `agent_state` freeze future ABI space
  without implementing those systems in Stage 1.
