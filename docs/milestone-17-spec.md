# Specification: Milestone 17: OMEGA Blackwell Vector (`OMEGA_BLACKWELL_VECTOR`)

```text
Document ID:     SPEC-ACCEL-M17
Milestone:       Milestone 17 (OMEGA_BLACKWELL_VECTOR)
Classification:  Sovereign Machine Canonical Specification
Target Substrate: Physical Blackwell Vector Compute Realization on NVIDIA DGX Spark (GB10, sm_121)
Status:          RATIFIED / COMPLETE / SILICON QUALIFIED
Lineage:         SILICON -> ATLAS (M1) -> PHYSICS (M2/M3/M15/M16) -> OMEGA (M4-M14) -> M16 (Native Submission) -> M17 (Blackwell Vector)
```

---

## 1. Executive Summary & Foundational Boundary

Milestone 16 (`BLACKWELL_NATIVE_PATH_KNOWN`) discovered and empirically characterized the native submission architecture on NVIDIA DGX Spark (Grace Blackwell GB10): raw RM resource allocation, BAR0 usermode doorbell aperture at `+0x90`, GPFIFO ring formatting, pushbuffer command streams, and coherent memory semaphore completion without proprietary userspace runtimes (`libcuda.so`, `libcudart.so`).

Milestone 17 establishes **first verified native Blackwell vector compute**:

> **M16 DISCOVERS HOW THE ACCELERATOR IS COMMANDED.**
> **M17 EXECUTES THE FIRST SOVEREIGN COMPUTE REALIZATION ON BLACKWELL SILICON.**

Milestone 17 executes the pipeline:

$$\text{OMEGA semantic operation} \longrightarrow \text{Blackwell sm\_121 machine code} \longrightarrow \text{QMD v5.0 launch descriptor} \longrightarrow \text{M16 native submission path} \longrightarrow \text{physical GB10 execution} \longrightarrow C[i] = (A[i] + B[i]) \pmod{2^{32}} \longrightarrow \text{OMEGA exact verification}$$

### Strict Epistemic Scope
Milestone 17 is intentionally constrained to unsigned 32-bit vector addition ($C[i] = (A[i] + B[i]) \pmod{2^{32}}$). It does not expand into matrix multiplication, multi-dimensional tensors, persistent resident runtimes, or general CUDA runtime emulation. Those capabilities belong to subsequent milestones (M18, M19, M20).

---

## 2. Mathematical Semantic Contract & Oracle

The computation is defined by an immutable machine-independent semantic contract:

1. **Operation**: $C[i] = (A[i] + B[i]) \pmod{2^{32}}$ for $i \in [0, N-1]$.
2. **Element Type**: Unsigned 32-bit integer (`uint32_t`).
3. **Overflow Policy**: Strict modulo wrap (`OVERFLOW_WRAP`).
4. **Deterministic Input Generator**:
   - $A[i] = i \times 0\text{x01010101} + 0\text{x12345678}$
   - $B[i] = i \times 0\text{x10101010} + 0\text{x87654321}$
   - High-bit wrap test: Tail elements inject deliberate modulo boundary conditions ($0\text{xFFFFFFF0} + 0\text{x20} = 0\text{x10}$).
5. **Exact Oracle**: Bit-for-bit exact comparison between CPU mathematical reference evaluation and physical GPU output buffer. Zero floating-point tolerance, zero epsilon margin.

---

## 3. Four-Component Realization Identity

Realization on physical accelerator hardware binds four distinct components into a single canonical 32-byte identifier:

$$\text{REALIZATION\_ID} = \text{SHA-256}(\text{spec\_id} \parallel \text{machine\_id} \parallel \text{code\_digest} \parallel \text{sm\_arch})$$

### Bound Input Components (100 Bytes Total)
1. **`spec_id` (32 bytes)**: Canonical SHA-256 semantic identity of the machine-independent vector operation in $G_S$.
2. **`machine_id` (32 bytes)**: Machine graph identity representing the physical DGX Spark execution environment (`NVIDIA_DGX_SPARK_GB10_SM121`).
3. **`code_digest` (32 bytes)**: Bit-for-bit SHA-256 digest of the emitted sm_121 machine code artifact.
4. **`sm_arch` (4 bytes, little-endian `uint32_t = 121`)**: Target streaming multiprocessor microarchitecture version.

### Compound Machine Tuple
Conceptually, `(machine_id, sm_arch)` forms a compound machine descriptor tuple where `machine_id` identifies the platform memory/bus topology and `sm_arch` identifies the execution unit microarchitecture. The realization digest deterministically locks all four inputs.

---

## 4. Machine Code Artifact & Epistemic Scope (Code Truth Audit)

### 4.1 Machine Code Artifact
The emitted machine code comprises 32 128-bit instructions (512 bytes), aligned to 128 bytes, with verified SHA-256:

```text
39f3dfdfc529a75a8274a27900acf4e7382b7f280a211e0412c51609f44b62a1
```

The instruction loop executes a grid-stride vector addition using Blackwell sm_121 native instructions:
- `LDC` / `LDCU`: Constant-bank parameter loading (buffer descriptors, element count $N$).
- `S2R`: Special register reading (`SR_CTAID.X`, `SR_TID.X`).
- `IMAD`: Global thread index computation ($i = \text{ctaid} \times \text{threads} + \text{tid}$).
- `ISETP.GE.U32.AND`: Boundary check against $N$ with predicate assignment (`P0`).
- `@P0 EXIT`: Early termination for out-of-bounds threads.
- `LDC.64`: 64-bit constant-bank pointer loading.
- `IMAD.WIDE.U32`: 64-bit byte offset calculation ($i \times 4$).
- `LDG.E`: Global memory loads with uniform buffer descriptor addressing (`desc[UR4][R2.64]`).
- `IADD3`: 3-input integer addition: $C[i] = A[i] + B[i] + 0$.
- `STG.E`: Global memory store of result.
- `EXIT` / `BRA`: Kernel termination and instruction bundle padding.

### 4.2 Code Truth Audit: Fixture vs Dynamic Synthesis
An adversarial code-truth audit distinguishes runtime dynamic synthesis from canonical constants:
- **Canonical Machine Code Artifact (Tier 2)**: In Milestone 17, the 512-byte sm_121 machine code is an immutable, bit-for-bit verified canonical artifact. The direct encoder serializes this verified sequence. It does not perform dynamic register allocation or dynamic AST-to-SASS instruction lowering at runtime.
- **Dynamic Descriptor & Submission Synthesis (Tier 3)**: The Queue Meta Data (QMD Version 05_00) launch descriptor, constant-bank parameter mapping ($A$, $B$, $C$ pointers, $N$), GPFIFO pushbuffer command stream, and semantic oracle verification are fully synthesized dynamically at runtime based on arbitrary vector lengths $N$.
- **Milestone Boundary**: Dynamic multi-kernel field synthesis and general register allocation are explicitly assigned to subsequent milestones (M18 MatMul and M20 Tensors). Milestone 17 validates the end-to-end silicon pipeline.

---

## 5. Queue Meta Data (QMD Version 05_00) Launch Descriptor

Blackwell compute dispatch utilizes the 384-byte (96-word) Queue Meta Data Version 05_00 layout:

1. **Two-Stage QMD Pipeline**:
   - **QMD 0 (`GRID_NULL`)**: Barrier synchronization setup with zero threads. Prepares execution queue state.
   - **QMD 1 (`GRID_CTA`)**: Active compute launch descriptor configuring:
     - `qmd_group_id = 0x3f` (word 0)
     - `sm_global_caching_enable = 1` (word 1)
     - `invalidate_texture_header_cache = 1`, `invalidate_texture_sampler_cache = 1`, `invalidate_texture_data_cache = 1` (word 2)
     - `program_address`: 64-bit IOVA pointing to machine code buffer (words 8-9)
     - `cta_raster_width = 1`, `cta_raster_height = 1`, `cta_raster_depth = 1` (words 12-14)
     - `cta_thread_dimension0 = 64`, `cta_thread_dimension1 = 1`, `cta_thread_dimension2 = 1` (words 16-18)
     - `constant_buffer_addr_lower`: 64-bit IOVA pointing to constant bank 0 (words 24-25)
     - `constant_buffer_size = 0x400` (1024 bytes, word 26)
     - `constant_buffer_valid = 1` (word 26)
     - `barrier_action = 0x11` (words 30, 31)
     - `release0_address`: 64-bit IOVA pointing to semaphore memory (words 38-39)
     - `release0_payload = 6` (word 40)
     - `shared_memory_size = 1024` (word 67)
2. **SKEDCHECK05 Compliance**:
   - Local memory byte sizes (`local_memory_total_size`, `local_memory_max_size`) are set strictly to 0. Blackwell hardware scheduler checks reject non-zero unallocated local memory allocations.

---

## 6. Native Submission Path & M16 Dependency

Milestone 17 consumes the frozen M16 authority substrate (`aien-spark/physics` at commit `b64753d95bacb1114ba48decde48239f0c542e12`):

1. **Resource Allocation via NVRM**:
   - Dynamically allocates RM client, device, subdevice, coherent memory, and channel resources via `/dev/nvidiactl`, `/dev/nvidia0`, and `/dev/nvidia-uvm`.
   - Coherent unified memory allocations across NVLink-C2C map code, constant bank, input/output data buffers, and hardware semaphores.
2. **Pushbuffer Command Stream Encoding**:
   - Unified 481-word pushbuffer command stream.
   - **Method `0x01b4`**: Non-incrementing method type 6 (`6u << 28`) writing shader setup and constant-bank configuration. Using non-incrementing type 6 is mandatory to prevent incrementing to `0x01b8`, which triggers hardware exception `Xid 11: Cl 0000cec0 Off 000001b8`.
   - **Method `0x0318`**: Incrementing method type 2 (`2u << 28`) streaming inline QMD payloads across offsets `0x0318` through `0x049c`.
3. **Hardware Doorbell & Completion**:
   - BAR0 usermode doorbell aperture at `+0x90` (`NVC361_NOTIFY_CHANNEL_PENDING`).
   - Hardware completion verified by CPU polling memory marker `0x44444444` and progress semaphore value `6`.

---

## 7. Qualification Gates & Cumulative Accounting

The master qualification suite (`tests/run_m17_gates.sh`) evaluates all qualification and regression gates:

### 7.1 Milestone 17 Qualification Gates (18 / 18 PASS)
1. `OMEGA_BW_VECTOR_SEMANTIC_PASS`: Machine-independent vector addition specification validated.
2. `OMEGA_BW_VECTOR_MACHINE_BINDING_PASS`: Binding to Blackwell sm_121 architecture profile verified.
3. `OMEGA_BW_VECTOR_REALIZATION_PASS`: Four-component identity binds spec, machine graph, code digest, and sm architecture.
4. `OMEGA_BW_VECTOR_ENCODER_FIXTURE_PASS`: Direct encoder matches canonical 512-byte sm_121 SHA-256 fixture.
5. `OMEGA_BW_VECTOR_NATIVE_ENCODING_PASS`: Synthesizer emits bit-for-bit identical 32-instruction sequence.
6. `OMEGA_BW_VECTOR_QMD_PASS`: QMD v5.0 launch descriptor matches documented and observed fields.
7. `OMEGA_BW_VECTOR_PHYSICS_AUTHORITY_PASS`: Frozen M16 native submission dependency verified.
8. `OMEGA_BW_VECTOR_NATIVE_SUBMIT_PASS`: Submission completes with hardware return code 0.
9. `OMEGA_BW_VECTOR_DEVICE_OUTPUT_PASS`: Hardware output non-zero and populated in coherent memory.
10. `OMEGA_BW_VECTOR_COMPLETION_PASS`: Semaphore marker `0x44444444` and progress value `6` observed.
11. `OMEGA_BW_VECTOR_V1_PARITY_PASS`: Exact bit-for-bit numerical parity against OMEGA semantic oracle.
12. `OMEGA_BW_VECTOR_BOUNDARY_PASS`: Boundary sweep across $N \in \{1, 15, 63, 64, 65, 127, 128, 256, 1024\}$.
13. `OMEGA_BW_VECTOR_MUTATION_REFUSAL_PASS`: Tamper resistance: bit flips and corruptions rejected.
14. `OMEGA_BW_VECTOR_ZERO_LIBCUDA_LINK_PASS`: Zero dynamic linkage to `libcuda.so` or `libcudart.so`.
15. `OMEGA_BW_VECTOR_ZERO_CUDA_SYMBOL_PASS`: Zero undefined dynamic CUDA symbols (`nm -u`).
16. `OMEGA_BW_VECTOR_ZERO_LIBCUDA_RUNTIME_PASS`: Zero runtime libcuda mappings in `/proc/self/maps`.
17. `OMEGA_BW_VECTOR_EVIDENCE_DURABILITY_PASS`: Durable machine code and QMD hex dumps recorded.
18. `OMEGA_BW_VECTOR_RECEIPT_PASS`: Cryptographic qualification receipt generated.

### 7.2 Cumulative Regression Accounting (121 / 121 PASS)
- M4 (`OMEGA_SEMANTICS`): 12 gates
- M5 (`OMEGA_AARCH64`): 9 gates
- M6 (`OMEGA_SELF_HOST`): 10 gates
- M7 (`OMEGA_VERIFY`): 10 gates
- M8 (`OMEGA_PROGRAM_CORE`): 10 gates
- M9 (`OMEGA_SYNTHESIS_V0`): 10 gates
- M10 (`OMEGA_LIBRARY_V1`): 10 gates
- M11 (`OMEGA_LIBRARY_DISCOVERY`): 10 gates
- M12 (`OMEGA_LIVING_MATVEC`): 10 gates
- M13 (`OMEGA_MACHINE_GRAPH`): 10 gates
- M14 (`OMEGA_REALIZATION_SYNTHESIS`): 10 gates
- M15 (`PHYSICS_ACCELERATOR_LINK`): 10 gates

$$\text{Total Gates Evaluated} = 18 \text{ (M17 gates)} + 121 \text{ (M4-M15 regression gates)} = 139 \text{ total gates passed (0 failures, 0 regressions).}$$

---

## 8. Zero Foreign Userspace Runtime Verification

The executable binary (`build/omegatool`) operates strictly without proprietary userspace runtimes:
- `ldd build/omegatool`: Zero dynamic linkage to `libcuda.so`, `libcudart.so`, or any NVIDIA proprietary userspace shared library. Links strictly against standard `libc.so.6`.
- `nm -u build/omegatool`: Zero undefined dynamic symbols matching `cu*` or `cuda*`.
- `/proc/self/maps`: Zero runtime virtual memory mappings matching `cuda`.

---

## 9. Canonical Repository & Silicon Bindings

1. **Implementation Commit**: `aien-spark/omega@27971cda951800c6c6d42201890de67dea0d532e` (PR #22).
2. **Final Evidence Receipt Commit**: `aien-spark/omega@43f725e24bcf84b55364177eb0c7a52233f27ae5` (PR #23).
3. **M16 Authority Substrate Dependency**: `aien-spark/physics@b64753d95bacb1114ba48decde48239f0c542e12` (PR #11).
4. **Physical Silicon Verification**: NVIDIA DGX Spark, Grace Blackwell GB10 (sm_121, 128 GiB unified LPDDR5x RAM).
5. **Clean-Clone Verification**: Executed from scratch in isolated `/tmp/omega-clean-m17` on DGX Spark silicon with 18 / 18 M17 gates and 121 / 121 regression gates passing.
6. **Cortex Memory Receipt**: Space `atlas-memory`, receipt ID `dea831e3-33c8-480c-bff3-2f170bf9b3b0`.

**Milestone 17 is RATIFIED as COMPLETE / SILICON QUALIFIED.** Milestone 18 (`OMEGA_BLACKWELL_MATMUL`) remains **PLANNED**.
