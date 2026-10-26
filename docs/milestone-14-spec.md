# Specification: Milestone 14 — Omega Realization Synthesis (`OMEGA_REALIZATION_SYNTHESIS`)

```text
Document ID:     SPEC-OMEGA-M14
Milestone:       Milestone 14 (OMEGA_REALIZATION_SYNTHESIS)
Classification:  Sovereign Machine Canonical Specification
Target Substrate: Automated $G_S \times G_M \to G_R$ Synthesis Targeting Declared Hardware Capabilities
Status:          COMPLETE / RATIFIED (aien-spark/aien-architecture#25, aien-spark/omega#19)
Lineage:         SILICON -> ATLAS (M1) -> PHYSICS (M2/M3) -> OMEGA (M4-M14) -> AIEN
```

---

## 1. Executive Summary & Foundational Doctrine

Milestone 13 established the formal machine hardware graph substrate (`OMEGA_MACHINE_GRAPH`), providing content-addressed, Physics-certified structural models of physical execution pipelines, functional compute units, register files, and cache/memory hierarchies.
Milestone 14 establishes automated machine-aware realization synthesis (`OMEGA_REALIZATION_SYNTHESIS`):

> **LOWERING IS NOT HARDCODED COMPILATION; REALIZATION IS SYNTHESIS: $G_S \times G_M \to G_R$. THE SOVEREIGN SYSTEM DISCOVERS THE OPTIMAL INSTRUCTION SCHEDULE AND REGISTER ASSIGNMENT UPON PHYSICAL HARDWARE WITHOUT COMPROMISING MATHEMATICAL PURITY.**

In the sovereign hierarchy:
- **Semantic Graph ($G_S$)** (Milestone 4 `OMEGA_SEMANTICS`, Milestone 8 `OMEGA_PROGRAM_CORE`): Defines pure mathematical meaning, abstract typed ASTs, and invariant envelopes without committing that meaning to any physical machine representation.
- **Machine Hardware Graph ($G_M$)** (Milestone 13 `OMEGA_MACHINE_GRAPH`): Formally describes physical execution pipelines, issue widths, unit latencies, register files, and memory hierarchies as reported and authorized by Physics.
- **Realization Graph ($G_R$)** (Milestone 5 `OMEGA_AARCH64`, Milestone 14 `OMEGA_REALIZATION_SYNTHESIS`): Synthesized through the formal mapping $G_S \times G_M \to G_R$, generating verified native machine code optimized for target hardware capabilities.

A conventional compiler relies on hardcoded lowering templates, fixed calling conventions, and hand-tuned heuristics that obscure hardware realities and introduce foreign runtime abstractions. Omega realization synthesis treats the machine hardware graph $G_M$ as a concrete constraint manifold. The synthesis engine searches over instruction selection, instruction scheduling, and register allocation to discover native machine code realizations that maximize throughput, fold issue slots, and eliminate pipeline bubbles while strictly preserving semantic equivalence.

Every synthesized realization is immutably bound through a cryptographic triple identity:
$$\text{REALIZATION\_ID} = \text{SHA-256}(\text{OMG0} \mid \text{KIND\_REALIZATION} \mid \text{profile} \mid \text{entry\_offset} \mid \text{code\_len} \mid \text{SEMANTIC\_ID} \mid \text{MACHINE\_ID} \mid \text{code\_bytes})$$

---

## 2. Core Doctrine & Invariants

As mandated by canonical roadmap doctrine (`DOCTRINE-ROADMAP`), the realization synthesis engine satisfies six foundational invariants:

1. **Realization is Synthesis, Not Hardcoded Compilation**: Lowering searches over machine scheduling, instruction selection, and register assignment to match $G_M$. The system does not emit static instruction boilerplate; it formulates lowering as an optimization problem constrained by the target machine graph's pipeline dimensions and functional unit counts.
2. **Triple Identity Binding**: $REALIZATION_ID$ deterministically incorporates $SEMANTIC_ID$ ($G_S$), $MACHINE_ID$ ($G_M$), and machine code bytes. A realization is valid only when paired with both the semantic intent it implements and the physical machine profile for which it was generated. Modifying semantic intent, machine topology, or machine code changes the cryptographic identity.
3. **Machine-Aware Scheduling & Optimization**: Synthesizes instruction schedules optimized for target machine issue width (4-wide on DGX Spark Grace V2 vs 2-wide on QEMU virt), functional unit concurrency, and execution latencies. The scheduler reorders independent operations and eliminates write-after-read (WAR) or write-after-write (WAW) hazards to maximize multi-issue slot occupancy.
4. **Strict Semantic Preservation**: Native execution of the synthesized realization produces identical outputs to semantic evaluation across all test domains. Parity is absolute: for every input in the domain envelope, executing native machine code emits the exact bitwise value computed by interpreting the semantic AST.
5. **Zero Foreign Toolchain**: 0 LLVM, 0 GNU as, 0 GCC inline asm, 0 JIT, 0 Python. All native machine instructions are generated via direct AArch64 machine byte encoders (`aarch64_encoder.c`) without invoking external compilers, assemblers, linkers, or foreign runtimes.
6. **Mandatory M7 Verification**: Every synthesized realization passes Milestone 7 (`OMEGA_VERIFY`) $V_0$ structural, $V_1$ differential, and $V_2$ property verification before admission. No realization is stored or deployed without passing the full verification ladder.

---

## 3. Synthesis Engine Architecture & Machine Scheduling

### 3.1 Synthesis Pipeline

```text
+-------------------------------------------------------------------------------+
|                       OMEGA_REALIZATION_SYNTHESIS PIPELINE                    |
+-------------------------------------------------------------------------------+
| 1. Task Ingress        : Semantic Graph (G_S) x Machine Hardware Graph (G_M)  |
| 2. Instruction Search  : Select candidate machine instructions for AST nodes  |
| 3. Schedule Search     : Machine-aware scheduling over target issue slots     |
|                          - Unit latency avoidance (RAW stall elimination)     |
|                          - Structural hazard resolution (ALU/MUL/LSU bounds)  |
|                          - Multi-issue packing (issue_width: 4 vs 2)          |
| 4. Register Allocation : GPR assignment maximizing operand independence       |
| 5. Direct Byte Emit    : Sovereign AArch64 machine code generation            |
| 6. Triple Identity     : SHA-256(OMG0 | G_S | G_M | code_bytes) -> REAL_ID   |
| 7. Verification Ladder : M7 V0 Structural -> V1 Differential -> V2 Property   |
| 8. Receipt & Admission : Emit qualification receipt and admit Realization     |
+-------------------------------------------------------------------------------+
```

### 3.2 Machine Scheduling & Instruction Selection

The realization synthesis engine searches the lowering space using target pipeline metrics from $G_M$:

- **Functional Unit Modeling**: The engine references `units` in $G_M$ (`UNIT_ALU`, `UNIT_MULTIPLIER`, `UNIT_LOAD_STORE`, `UNIT_BRANCH`, `UNIT_VECTOR`) to schedule operations only on available hardware ports without exceeding cycle throughput limits.
- **Latency-Aware Interleaving**: For multi-cycle operations (e.g., multiplication with 3-cycle latency), the scheduler interleaves independent operations (such as subsequent immediate loads or address calculations) into the latency bubble, preventing pipeline stalls.
- **Dual-Issue and Quad-Issue Packing**:
  - On **NVIDIA DGX Spark Grace V2** (ARM Neoverse V2, 4-wide dispatch, 4x ALU, 2x Branch, 2x Multiplier, out-of-order execution), synthesis generates schedules that pre-load independent operands into separate registers (e.g., `X1`, `X2`), enabling multiple instructions to be dispatched in the same cycle without anti-dependencies.
  - On **QEMU Virt AArch64 Baseline** (generic AArch64, 2-wide dispatch, 2x ALU, 1x Multiplier, in-order execution), synthesis prioritizes minimal register pressure, sequential dependency resolution, and compact footprint.

### 3.3 Target Specialization Comparison

Consider the affine arithmetic transformation $f(x) = 3x - 2$:

- **DGX Spark Grace V2 (4-Wide Dispatch)**:
  ```text
  Cycle 0, Slot 0: MOVZ X1, 3, LSL 0       ; Port 0 (ALU 0) - Pre-load multiplier
  Cycle 0, Slot 1: MOVZ X2, 2, LSL 0       ; Port 1 (ALU 1) - Pre-load subtrahend (disjoint reg)
  Cycle 1, Slot 0: MUL  X0, X0, X1         ; Port 2 (Multiplier 0) - Compute 3 * x
  Cycle 4, Slot 0: SUB  X0, X0, X2         ; Port 0 (ALU 0) - Immediate subtract using pre-loaded X2
  Cycle 4, Slot 1: RET                     ; Port 1 (Branch 0) - Return
  ```
  Operand pre-loading eliminates register hazards and leverages multi-issue capability across distinct execution units.

- **QEMU Virt Generic (2-Wide Dispatch)**:
  ```text
  Cycle 0, Slot 0: MOVZ X1, 3, LSL 0       ; ALU 0 - Load multiplier
  Cycle 1, Slot 0: MUL  X0, X0, X1         ; Multiplier - Compute 3 * x
  Cycle 5, Slot 0: MOVZ X1, 2, LSL 0       ; ALU 0 - Reuse temporary X1 (low register pressure)
  Cycle 6, Slot 0: SUB  X0, X0, X1         ; ALU 0 - Subtract
  Cycle 7, Slot 0: RET                     ; Branch - Return
  ```
  Sequential schedule minimizing register allocation footprint to match constrained in-order execution pipelines.

### 3.4 Verification Ladder Integration

Before any synthesized realization is accepted, it must pass all three tiers of the Milestone 7 (`OMEGA_VERIFY`) verification engine:

1. **$V_0$ Structural Verification**: Confirms alignment, valid instruction boundaries, non-zero code length within safe buffer bounds, safe entry offset, and mandatory legal termination (`RET`).
2. **$V_1$ Differential Verification**: Executes the realization in a memory-isolated execution page across boundary test vectors and compares observed results against high-level semantic evaluation:
   $$\forall x \in \text{TestDomain}, \quad \text{Exec}(G_R, x) == \text{Eval}(G_S, x)$$
3. **$V_2$ Property Verification**: Enforces calling convention invariants (AAPCS64), ensuring callee-saved registers (`X19`-`X28`) are preserved, stack balance is strictly maintained, and execution terminates deterministically without traps.

---

## 4. Data Model & C API Declarations

```c
#ifndef OMEGA_REALIZE_SYNTH_H
#define OMEGA_REALIZE_SYNTH_H

#include "omega_types.h"
#include "omega_program.h"
#include "omega_machine.h"
#include "omega_realize.h"
#include "omega_verify.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define OMEGA_REALIZE_MAX_SCHEDULE_SLOTS 128

/* Individual scheduled instruction slot */
typedef struct {
    uint32_t cycle;
    ComputeUnitType unit_type;
    uint32_t instruction_word;
    uint8_t dest_reg;
    uint8_t src_reg1;
    uint8_t src_reg2;
    uint8_t latency_cycles;
} RealizationScheduleSlot;

/* Complete machine-aware instruction schedule */
typedef struct {
    uint32_t total_cycles;
    uint32_t slot_count;
    uint32_t issue_width;
    RealizationScheduleSlot slots[OMEGA_REALIZE_MAX_SCHEDULE_SLOTS];
} RealizationSchedule;

/* Synthesis task parameters binding semantic intent and target machine */
typedef struct {
    const OmegaProgram *program;
    const OmegaMachineGraph *machine;
    bool optimize_latency;
    uint32_t max_unroll_factor;
} RealizationSynthesisTask;

/* Complete synthesis output object with verification receipt */
typedef struct {
    bool solved;
    RealizationObject realization;
    SemanticId realization_id;
    uint32_t estimated_cycles;
    uint32_t code_bytes_len;
    RealizationSchedule schedule;
    VerifyReport verify_report;
} RealizationSynthesisResult;

typedef RealizationSynthesisResult OmegaRealizationSynthesisResult;

/* Task Initialization */
void omega_realize_task_init(RealizationSynthesisTask *task,
                             const OmegaProgram *prog,
                             const OmegaMachineGraph *mg);

/* Cryptographic Triple Binding:
 * REALIZATION_ID = SHA-256(OMG0 | KIND_REALIZATION | profile | entry_offset | code_len |
 *                          SEMANTIC_ID | MACHINE_ID | code_bytes)
 */
int omega_realize_compute_triple_id(const SemanticId *semantic_id,
                                    const SemanticId *machine_id,
                                    const RealizationObject *real,
                                    SemanticId *out_id);

/* Machine-Aware Schedule Construction & Validation */
int omega_realize_build_schedule(const OmegaProgram *prog,
                                 const OmegaMachineGraph *mg,
                                 RealizationSchedule *schedule);

int omega_realize_validate_schedule(const RealizationSchedule *schedule,
                                    const OmegaMachineGraph *mg,
                                    char *err_msg,
                                    size_t err_msg_len);

/* Core Realization Synthesis Entrypoint (G_S x G_M -> G_R) */
int omega_synthesize_realization(const RealizationSynthesisTask *task,
                                 RealizationSynthesisResult *result);

/* Target Specialization Entrypoints */
int omega_synthesize_for_dgx_spark(const OmegaProgram *prog,
                                   RealizationSynthesisResult *result);

int omega_synthesize_for_qemu_virt(const OmegaProgram *prog,
                                   RealizationSynthesisResult *result);

#endif /* OMEGA_REALIZE_SYNTH_H */
```

---

## 5. The 10 Qualification Gates

Milestone 14 qualification requires 100% pass across 10 canonical gates:

1. `OMEGA_REAL_SYNTH_INIT_PASS`: Synthesis task initializes cleanly with valid semantic program ($G_S$), target machine hardware graph ($G_M$), and optimization parameters.
2. `OMEGA_REAL_SYNTH_TRIPLE_ID_PASS`: Cryptographic triple binding deterministic SHA-256 identity incorporates $SEMANTIC_ID$, $MACHINE_ID$, and raw machine code bytes.
3. `OMEGA_REAL_SYNTH_SCHEDULE_OPT_PASS`: Machine-aware schedule search generates valid instruction schedules avoiding structural hazards and matching pipeline constraints.
4. `OMEGA_REAL_SYNTH_DGX_SPARK_PASS`: Realization specialized for 4-wide DGX Spark Grace Neoverse V2 pipeline synthesizes multi-issue instruction layout.
5. `OMEGA_REAL_SYNTH_QEMU_VIRT_PASS`: Realization specialized for 2-wide QEMU virt baseline synthesizes compact sequential schedule.
6. `OMEGA_REAL_SYNTH_SEMANTIC_PARITY_PASS`: Native execution of synthesized realization achieves exact bit-for-bit output equivalence with semantic evaluation across all test vectors.
7. `OMEGA_REAL_SYNTH_V0_STRUCTURAL_PASS`: Synthesized realization passes Milestone 7 (`OMEGA_VERIFY`) $V_0$ structural verification (valid entry point, aligned code bounds, legal instruction boundaries).
8. `OMEGA_REAL_SYNTH_V1_DIFFERENTIAL_PASS`: Synthesized realization passes Milestone 7 (`OMEGA_VERIFY`) $V_1$ differential verification against reference semantic evaluation across boundary inputs.
9. `OMEGA_REAL_SYNTH_V2_PROPERTY_PASS`: Synthesized realization passes Milestone 7 (`OMEGA_VERIFY`) $V_2$ property verification (register preservation, stack neutrality, deterministic termination).
10. `OMEGA_REAL_SYNTH_RECEIPT_PASS`: Master qualification test harness executes all assertions and produces an immutable cryptographic receipt recording machine identity, semantic identity, and realization gates.

---

## 6. Provenance & Qualification Evidence

Milestone 14 is qualified and ratified. All 10 canonical qualification gates passed with 100% compliance and zero regression across cumulative milestones M4 through M14 (101/101 cumulative gates).

- **Implementation Commit**: `c0c8102ecc7f36cb86ab8686e5f1ee08eb59762d` (`aien-spark/omega#19`)
- **Qualification Receipt Commit**: `03fbcb9` (`aien-spark/omega`)
- **Qualification Receipt File**: [`evidence/omega_realization_synthesis_qualification_receipt.json`](https://github.com/aien-dev/omega-mv/blob/main/evidence/omega_realization_synthesis_qualification_receipt.json)

```json
{
  "milestone": "MILESTONE 14 — OMEGA_REALIZATION_SYNTHESIS",
  "status": "QUALIFIED / PASS",
  "contract_id": "CONTRACT-OMEGA-REALIZATION-SYNTHESIS-M14",
  "source_parent_commit": "db066d9b4dbce19069bc92025aa0fae7401d413e",
  "qualified_implementation_commit": "c0c8102ecc7f36cb86ab8686e5f1ee08eb59762d",
  "receipt_commit": "7c07acae88ebeb32e62608bb30bc659a61297943",
  "gates": {
    "OMEGA_REAL_SYNTH_INIT_PASS": "PASS",
    "OMEGA_REAL_SYNTH_TRIPLE_ID_PASS": "PASS",
    "OMEGA_REAL_SYNTH_SCHEDULE_OPT_PASS": "PASS",
    "OMEGA_REAL_SYNTH_DGX_SPARK_PASS": "PASS",
    "OMEGA_REAL_SYNTH_QEMU_VIRT_PASS": "PASS",
    "OMEGA_REAL_SYNTH_SEMANTIC_PARITY_PASS": "PASS",
    "OMEGA_REAL_SYNTH_V0_STRUCTURAL_PASS": "PASS",
    "OMEGA_REAL_SYNTH_V1_DIFFERENTIAL_PASS": "PASS",
    "OMEGA_REAL_SYNTH_V2_PROPERTY_PASS": "PASS",
    "OMEGA_REAL_SYNTH_RECEIPT_PASS": "PASS"
  },
  "cumulative_qualification": {
    "cumulative_gates": 101,
    "cumulative_passed": 101,
    "zero_regression": true
  }
}
```

---

## 7. Future Horizons & Accelerator Coupling

Milestone 14 completes the core CPU realization synthesis pipeline ($G_S \times G_M \to G_R$). This synthesis engine forms the direct foundation for downstream accelerator milestones:
- **Milestone 15 (`PHYSICS_ACCELERATOR_LINK`)**: Bounded coherent memory interfaces and SMMUv3 DMA translation, extending $G_M$ to model CPU-accelerator interconnects.
- **Milestone 16 (`BLACKWELL_NATIVE_PATH_KNOWN`)**: Empirical microarchitectural characterization of Blackwell streaming multiprocessors, command queues, and MMIO doorbells, providing the machine graph for sovereign GPU hardware.
- **Milestone 17 (`OMEGA_BLACKWELL_VECTOR`)**: Extending $G_S \times G_M \to G_R$ synthesis to target native Blackwell SIMD/vector execution units.
- **Milestone 18 (`OMEGA_BLACKWELL_MATMUL`)**: Synthesizing tensor matrix multiply kernels directly into tensor core pipelines under mathematical invariant preservation.
