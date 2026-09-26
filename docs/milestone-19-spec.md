# Specification: Milestone 19: OMEGA Accelerator Resident Substrate (`OMEGA_ACCELERATOR_RESIDENT`)

```text
Document ID:     SPEC-ACCEL-M19
Milestone:       Milestone 19 (OMEGA_ACCELERATOR_RESIDENT)
Classification:  Sovereign Machine Canonical Specification
Target Substrate: Persistent Omega Execution Substrate in Coherent Memory on NVIDIA DGX Spark (GB10, sm_121)
Status:          SILICON QUALIFIED
Opened:          2026-09-26
Qualified:       2026-09-26 (candidate beaa118, evidence 5a85079, omega PR #29 merged ae2476d, Cortex 8b150b10)
Authority:       aien-dev/physics M16 (commit b64753d), aien-dev/omega M18 (commit 7273c37)
Lineage:         SILICON -> ATLAS (M1) -> PHYSICS (M2/M3/M15/M16) -> OMEGA (M4-M14) -> M16 (Native Submission) -> M17 (Blackwell Vector) -> M18 (Blackwell MatMul) -> M19 (Accelerator Resident)
```

---

## 1. Executive Summary & Sovereignty Boundary

Milestones 16, 17, and 18 established native Blackwell hardware interaction on physical NVIDIA DGX Spark silicon without foreign userspace runtimes (`libcuda.so`, `libcudart.so`):
- M16 characterized and verified the native submit path (MMIO, GPFIFO queues, doorbells, completions).
- M17 executed a verified canonical machine-code artifact for vector addition via dynamic QMD and parameter synthesis.
- M18 established dynamic Blackwell code generation, instruction selection, bounded register allocation, 128-bit machine word encoding, and tensor-core MMA execution with FP32 accumulation.

In Milestones 16 through 18, execution followed an ephemeral lifecycle: each operation or test suite invocation performed a full sequence of RM client creation, device allocation, VAS aperture binding, GPFIFO channel initialization, pushbuffer dispatch, completion wait, and teardown.

Milestone 19 transitions Omega from an ephemeral execution model to a **persistent accelerator resident substrate** (`OmegaAcceleratorWorld`):

> **EPHEMERAL DISPATCH INITIALIZES AND TEARS DOWN SUBSYSTEMS PER OPERATION.**
> **ACCELERATOR RESIDENCY MAINTAINS PERSISTENT CHANNELS, APERTURES, CODE REGISTRIES, AND BUFFERS ACROSS CONTINUOUS HETEROGENEOUS DISPATCH LOOPS.**

### The Core Architectural Invariant: `resident != immortal`
Residency provides persistent operational availability without incurring per-operation channel initialization latency. Residency does not confer unrevocable authority or perpetual resource retention:
1. **Explicit Generation Counters**: Every registered buffer, code object, and channel handle binds to a strictly monotonic generation counter.
2. **Capability-Bounded Handles**: Handles declare explicit bounds and access permissions. Ambient or untracked access to coherent memory apertures is prohibited.
3. **Fail-Closed Stale Handle Refusal**: Access attempts using invalidated, expired, or out-of-generation handles are rejected with explicit error codes before submission.
4. **Deterministic Capability Revocation**: Buffers and code modules can be dynamically revoked and purged from the resident substrate without tearing down the parent world.
5. **Deterministic Teardown**: The entire resident substrate terminates deterministically, releasing all NVRM allocations, coherent mappings, and doorbells without leaking host or GPU resources.

---

## 2. Persistent Substrate Architecture (`OmegaAcceleratorWorld`)

The resident substrate resides in accelerator-accessible coherent memory and host memory on Grace Blackwell GB10 (128 GiB unified LPDDR5x RAM, `sm_121`):

```text
+-----------------------------------------------------------------------------------+
|                           OmegaAcceleratorWorld                                   |
|                                                                                   |
|  +--------------------+  +--------------------+  +-----------------------------+  |
|  | RM Client & Device |  | VAS Virtual Space  |  | Persistent GPFIFO Channel   |  |
|  | - Client handle    |  | - Coherent aperture|  | - Channel group & GPFIFO ring|  |
|  | - Subdevice handle |  | - SMMUv3 mappings  |  | - USERD & Doorbell (+0x90)  |  |
|  +--------------------+  +--------------------+  +-----------------------------+  |
|                                                                                   |
|  +--------------------+  +--------------------+  +-----------------------------+  |
|  | Code Registry      |  | Buffer Registry    |  | Coherent Scratch Arena      |  |
|  | - Cached kernels   |  | - Persistent memory|  | - Zero-allocation scratch   |  |
|  | - Code digests     |  | - Generation tags  |  | - Dynamic sub-arenas        |  |
|  +--------------------+  +--------------------+  +-----------------------------+  |
|                                                                                   |
|  +--------------------+  +--------------------+  +-----------------------------+  |
|  | Semaphore Ring     |  | Monotonic Gen Id   |  | Rolling State Digest        |  |
|  | - WFI completions  |  | - Object lifetimes |  | - SHA-256 rolling execution |  |
|  | - State progression|  | - Invalidation     |  |   integrity trace           |  |
|  +--------------------+  +--------------------+  +-----------------------------+  |
+-----------------------------------------------------------------------------------+
```

### Persistent Components Maintained Across Operations
The resident world maintains eleven persistent state components across continuous execution:
1. **RM Client & Root**: A single persistent NVRM client (`m16_native_open`) initialized once and preserved across operations.
2. **GPU Device & Subdevice Objects**: Established device object hierarchy bound to Grace Blackwell GB10 (`sm_121`).
3. **Virtual Address Space (VAS)**: A unified, coherent memory aperture avoiding per-operation virtual address space construction and teardown.
4. **Channel Group & GPFIFO Channel**: A persistent compute channel with configured methods, work submission structures, and engine bindings.
5. **USERD & Hardware Doorbell Mapping**: Direct MMIO aperture mapping for doorbell triggers (`offset +0x90`) held open across dispatches.
6. **Completion Mechanism & Semaphore Ring**: Coherent memory semaphore tracking task completion markers (`0x44444444`) and monotonic completion counters.
7. **Code Registry**: In-memory registry of compiled and verified sm_121 machine code artifacts (Vector Add, MatMul INT32, MatMul FP16, MatMul BF16) with deduplication by SHA-256 code digest.
8. **Buffer Registry**: Registered persistent input/output tensors and scratch regions tracked with generation identifiers and memory bounds.
9. **Coherent Scratch Arena**: Pre-allocated, reusable coherent memory buffer eliminating heap fragmentation and dynamic memory allocations on the hot dispatch path.
10. **Monotonic Generation Counter**: Process-wide monotonic counter incremented on buffer allocation, reallocation, and revocation to invalidate dangling references.
11. **Rolling State Digest**: Cryptographic SHA-256 hash chaining all dispatched operations, kernel digests, parameter hashes, and completion markers into an immutable execution trace.

---

## 3. Sustained Heterogeneous Execution & Queue Wraparound

Milestone 19 requires continuous execution across varied compute primitives to demonstrate true substrate residency rather than a single looped microbenchmark.

### Heterogeneous Workload Specification
The resident substrate must execute continuous mixed workloads consisting of:
1. **Unsigned 32-bit Vector Addition** (`OMEGA_BLACKWELL_VECTOR`, M17 semantic contract).
2. **Integer Matrix Multiplication** (`OMEGA_BLACKWELL_MATMUL` INT32 intermediate contract).
3. **Tensor Core Matrix Multiplication FP16** (`HMMA.16816.F32` with FP32 accumulation).
4. **Tensor Core Matrix Multiplication BF16** (`HMMA.16816.F32.BF16` with FP32 accumulation).

Each operation runs dynamically through the persistent GPFIFO channel, referencing resident buffers or dynamically bound inputs, without tearing down or reconstructing the accelerator world.

### Queue Wraparound Management Invariant
The GPFIFO submission channel uses a circular ring buffer of finite entries:
1. As dispatches accumulate (reaching and exceeding 1,000 operations), the GPFIFO put/get indices wrap around the ring boundary modulo the ring capacity.
2. The submission driver must advance the put index across the ring boundary without pipeline stalls, race conditions, or pushbuffer corruption.
3. Completed entries must be acknowledged via semaphore progress before overwrite.

### The 1,000-Operation Benchmark
Qualification requires continuous execution of at least 1,000 heterogeneous dispatches:
- Total dispatches: $\ge 1,000$.
- Workload: Alternating sequence across all four compute classes.
- Zero Context Recreations: `m16_native_open` and channel construction invoked exactly once at world initialization.
- Exact Parity: Every operation verified against its CPU reference oracle or mathematical bounds.
- Memory Consumption: Resident heap and coherent memory consumption must remain bounded and flat (zero memory leak across 1,000 operations).

---

## 4. Capability Lifecycle, Invalidation, and Fault Recovery

### Object Registration & Capability Tokens
When buffers or code modules are registered in `OmegaAcceleratorWorld`, the caller receives a capability handle:

$$\text{Handle} = \langle \text{handle\_id}, \text{object\_type}, \text{generation}, \text{base\_addr}, \text{size\_bytes}, \text{permissions} \rangle$$

Dispatch validation requires:
1. $\text{generation}_{\text{handle}} == \text{generation}_{\text{current}}$
2. Requested dispatch bounds fall strictly within $[\text{base\_addr}, \text{base\_addr} + \text{size\_bytes})$.
3. Operation requirements match granted permissions (read, write, execute).

### Fail-Closed Stale Handle Refusal
If an operation references a handle whose generation does not match the active registry state (for example, after buffer reallocation or revocation), the dispatch path rejects the request immediately:
- Refusal occurs on the host driver side before pushbuffer generation or doorbell ringing.
- An explicit error code (`OMEGA_ERR_STALE_HANDLE`) is returned.
- Hardware state and channel integrity remain unaffected.

### Fault Recovery Protocol
If an operation encounters an intentional or accidental fault (such as a timeout or illegal instruction injection):
1. The fault is contained within the resident channel.
2. The substrate executes an isolated channel reset and state resynchronization.
3. The root RM client, GPU device, and VAS remain intact.
4. Subsequent valid operations resume execution successfully.

---

## 5. Zero Foreign Userspace Runtime Verification

Strict execution invariant:
1. `ldd <binary>`: Must show zero dynamic dependency on `libcuda.so*` or `libcudart.so*`.
2. `nm -u <binary>`: Must show zero undefined symbols containing `cu` or `cuda`.
3. `/proc/self/maps`: During persistent execution on DGX Spark, memory maps must confirm no loaded CUDA userspace drivers.

---

## 6. Qualification Gates & Cumulative Accounting

Milestone 19 qualification requires passing 18 Milestone 19 gates in addition to the 157 cumulative regression gates established through Milestone 18. Total evaluated gates: 175.

### Milestone 19 Qualification Gates
- **Gate 1: `OMEGA_ACCEL_RESIDENT_WORLD_CREATE_PASS`**: Creation and deterministic initialization of persistent `OmegaAcceleratorWorld` substrate in coherent memory.
- **Gate 2: `OMEGA_ACCEL_RESIDENT_CONTEXT_REUSE_PASS`**: Successful dispatch of successive distinct compute tasks reusing the same persistent RM client, GPU device, and VAS aperture without re-initialization.
- **Gate 3: `OMEGA_ACCEL_RESIDENT_CHANNEL_REUSE_PASS`**: Successful reuse of GPFIFO channel, USERD, and doorbell mapping across successive pushbuffer submissions.
- **Gate 4: `OMEGA_ACCEL_RESIDENT_CODE_REGISTRY_PASS`**: Resident code registry registration, lookup, deduplication, and execution of distinct sm_121 kernels (VecAdd, MatMul INT32, MatMul FP16, MatMul BF16).
- **Gate 5: `OMEGA_ACCEL_RESIDENT_BUFFER_REGISTRY_PASS`**: Resident buffer registry managing persistent coherent memory buffers with handle tracking and bounds checking.
- **Gate 6: `OMEGA_ACCEL_RESIDENT_MIXED_WORKLOAD_PASS`**: Alternating execution of mixed workloads (Vector Add, INT32 MatMul, FP16 MatMul, BF16 MatMul) on the shared resident channel.
- **Gate 7: `OMEGA_ACCEL_RESIDENT_QUEUE_WRAP_PASS`**: GPFIFO pushbuffer ring buffer wraparound verified under continuous dispatch without channel stalls or pushbuffer corruption.
- **Gate 8: `OMEGA_ACCEL_RESIDENT_1000_OP_PASS`**: Sustained continuous execution of $\ge 1,000$ heterogeneous operations on physical GB10 silicon without context teardown or re-initialization.
- **Gate 9: `OMEGA_ACCEL_RESIDENT_GENERATION_PASS`**: Monotonic generation counters on resident objects correctly incrementing upon lifecycle transitions and updates.
- **Gate 10: `OMEGA_ACCEL_RESIDENT_STALE_HANDLE_REFUSAL_PASS`**: Fail-closed refusal and error reporting when attempting dispatch with expired or stale capability handles from prior generations.
- **Gate 11: `OMEGA_ACCEL_RESIDENT_REVOCATION_PASS`**: Deterministic capability revocation immediately invalidating registered buffers or code handles, with subsequent access rejected.
- **Gate 12: `OMEGA_ACCEL_RESIDENT_FAULT_RECOVERY_PASS`**: Isolated channel reset and deterministic recovery upon fault injection without leaking system resources or corrupting device state.
- **Gate 13: `OMEGA_ACCEL_RESIDENT_MEMORY_BOUND_PASS`**: Flat, bounded resident memory consumption with zero heap or coherent memory leaks measured across 1,000 operations.
- **Gate 14: `OMEGA_ACCEL_RESIDENT_STATE_DIGEST_PASS`**: Deterministic rolling SHA-256 state digest verifying cumulative execution integrity across all completed operations.
- **Gate 15: `OMEGA_ACCEL_RESIDENT_ZERO_LIBCUDA_PASS`**: Zero foreign userspace runtime verification (`ldd`, `nm -u`, `/proc/self/maps`) throughout resident substrate lifecycle.
- **Gate 16: `OMEGA_ACCEL_RESIDENT_CLEAN_CLONE_PASS`**: Clean-clone isolated reproduction on DGX Spark silicon from scratch.
- **Gate 17: `OMEGA_ACCEL_RESIDENT_REGRESSION_PASS`**: Cumulative regression parity: 157 / 157 prior milestone gates passing (M4 through M18).
- **Gate 18: `OMEGA_ACCEL_RESIDENT_RECEIPT_PASS`**: Milestone 19 cryptographic qualification receipt generation with hardware trace evidence.

---

## 7. Deliverables & Acceptance Criteria

1. **Architecture & Specification**: Canonical specification `docs/milestone-19-spec.md` ratified in `aien-dev/aien-architecture`.
2. **Substrate Implementation**: Complete `OmegaAcceleratorWorld` implementation in `aien-dev/omega`.
3. **Silicon Proof**: Physical execution receipts recorded on NVIDIA DGX Spark (Grace Blackwell GB10, `sm_121`).
4. **Zero-Libcuda Audit**: Verification receipts confirming zero proprietary userspace CUDA runtime linkage or symbols.
5. **Cortex Memory Commit**: Milestone qualification receipt committed to Spark Cortex space `atlas-memory`.
