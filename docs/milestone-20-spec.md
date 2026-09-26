# Milestone 20 Preparatory Stage 1: OMEGA_SHARED_WORLD — Coherent Shared World + Cross-Processor Publication

```text
Document ID:      SPEC-OMEGA-SHARED-WORLD-M20-S1
Classification:   Draft milestone preparatory specification (branch-only)
Target Substrate: NVIDIA DGX Spark (Grace Blackwell GB10, sm_121, 128 GiB unified LPDDR5x)
Status:           STAGED ON BRANCH (M19 ratification and M20 opening pending)
Roadmap binding:  M20 remains OMEGA_TENSOR. OMEGA_SHARED_WORLD is a preparatory
                  substrate stage, not a replacement milestone identifier.
```

## 1. Purpose and scope

This preparatory stage tests whether the CPU (where AEGIS executes) and the GPU
(where AIEN will execute) can safely communicate through **one persistent
PHYSICS-owned coherent allocation** using a **pointer-free OMEGA ABI** and
**explicitly qualified cross-processor publication/consumption ordering**.

Stage 1 is intentionally narrower than the full Shared World architecture and
does not satisfy the M20 `OMEGA_TENSOR` milestone gate. Tensor semantics,
multi-dimensional array types, strides, and memory layouts remain required by
the canonical roadmap before M20 can be ratified. It does **not** implement
AIEN residency, AEGIS effect mediation, autonomous tool
execution, persistent cognition, branch-native inference, shared KV state, or an
end-to-end sovereign operating environment. Those are Stages 2–4 and later
milestones.

## 2. Pass condition (the single claim)

> A persistent native GPU worker and a CPU participant exchange **1,000,000**
> bounded messages through a PHYSICS-owned coherent shared-memory world using a
> canonical pointer-free OMEGA ABI (`OMEGA_SHARED_WORLD_V1`) and explicitly
> qualified cross-processor publication semantics **on GB10 silicon**, with zero
> stale, torn, duplicated, reordered-as-valid, or replayed messages.

If the hardware evidence does not support this exact claim, this preparatory
stage **fails** rather than weakening the test. Passing it alone does not close M20.

## 3. Architecture

```text
                     OMEGA SHARED WORLD (one coherent region)
        ┌──────────────────────────────────────────┐
        │ SharedWorldHeader (offsets, epoch)         │
        │ CPU_TO_GPU_RING  (128-byte descriptors)    │
        │ GPU_TO_CPU_RING  (128-byte descriptors)    │
        │ FAULT_MAILBOX                              │
        │ OBJECT_TABLE (logical id/gen/offset/len)   │
        │ reserved: EFFECT/EFFECT_RESULT/PROOF/      │
        │           EVIDENCE rings, agent_state      │
        └──────────────────────────────────────────┘
                  │                       │
             CPU mapping             GPU mapping
                  │                       │
                AEGIS                    AIEN(worker)
                  │                       │
                 CPU                     GPU
                  └──────── PHYSICS ──────┘
```

- **PHYSICS** owns the coherent region (`PhysicsCoherentRegion` over NVRM/UVM),
  and realizes the ring mechanics + CPU acquire/release (`omega_shared_world.*`).
- **OMEGA** defines the ABI (`OMEGA_SHARED_WORLD_V1`) and owns the Blackwell
  resident-worker codegen + qualification harness.
- The resident GPU worker is a **qualification worker**, not AIEN. It performs a
  trivial deterministic transform (`out = in XOR arg_a`) to prove the substrate.

## 4. Publication semantics (the core requirement)

- **CPU side:** C11 atomics with explicit memory orders; on AArch64 an acquire
  load lowers to `LDAR` and a release store to `STLR` (verified by disassembly).
- **GPU side:** the mechanical equivalent, via Blackwell system-scope ordering
  instructions validated against the sm_121 SASS oracle (nvdisasm):
  - acquire load → `LDG.E.STRONG.SYS` (+ `CCTL.IVALL` to force re-fetch),
  - release store → `MEMBAR.ALL.SYS` then `STG.E.STRONG.SYS`,
  - sequential consistency → `MEMBAR.SC.SYS`,
  - system atomics → `ATOMG.E.{ADD,EXCH}.STRONG.SYS`.
  These are implemented as new native Blackwell IR opcodes with encoder
  fixtures; nothing depends on libcuda/libcudart or a CUDA compiler intrinsic.

Publication is never based on `volatile` alone.

## 5. Qualification gates

- G1  ABI structural invariants (128-byte descriptor, offsets, power-of-two).
- G2  Coherent region: allocate / resolve CPU+GPU / bounds / generation / revoke.
- G3  Ring protocol host proof: empty / single / full / many wraps.
- G4  Hostile input: stale gen, stale epoch, ABA reuse, replay, malformed,
      OOB logical reference, bad checksum — all rejected, worker continues.
- G5  CPU acquire/release lowers to `LDAR`/`STLR` (disassembly evidence).
- G6  Blackwell ordering opcodes match the sm_121 SASS oracle (encoder fixtures).
- G7  Persistent resident worker: one launch for the whole campaign; the CPU
      communicates only through coherent memory after launch; bounded give-up.
- G8  1,000,000 CPU→GPU→CPU exchanges on GB10 with variable producer/consumer
      delays, bursts, generation changes, and full-wrap boundaries.
- G9  Integrity ledger: sent == received; zero duplicate / missing / stale /
      torn / replayed; every response tied to its originating sequence.
- G10 CPU-authority boundary: shared descriptors cannot encode or obtain a CPU
      function pointer, host syscall, arbitrary host VA, kernel VA, RM handle, or
      physical address; PHYSICS/AEGIS resolution rejects any such value.
- G11 Zero libcuda/libcudart linkage, symbols, or runtime mappings.
- G12 Evidence receipt with strict claim tiers and cryptographic manifest.

## 6. Evidence discipline

Every claim is tagged with exactly one tier: `implemented`, `host-tested`,
`QEMU-tested`, `GB10-silicon-observed`, `derived`, `assumed`, or
`not-yet-claimed`. The Stage 1 silicon claim (§2) is made only if
`GB10-silicon-observed` evidence supports it; otherwise the milestone is reported
FAILED for that gate, never weakened.

## 7. After Stage 1

- Stage 2: persistent AIEN-side GPU event loop using the Shared World.
- Stage 3: GPU → `EFFECT_RING` → AEGIS/CPU verification → PHYSICS execution →
  `EFFECT_RESULT_RING` → GPU.
- Stage 4: Agent State ABI — branch state, resident model state, KV/cache
  references integrated into the Shared World.
