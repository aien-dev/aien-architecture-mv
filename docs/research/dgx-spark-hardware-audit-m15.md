# Hardware Discovery & Physical Audit: Milestone 15 (`PHYSICS_ACCELERATOR_LINK`)
## Empirical Characterization of NVIDIA DGX Spark Host, Blackwell GB10 Accelerator, and ARM SMMUv3 Substrate

```text
Document ID:     AUDIT-SPARK-M15
Milestone:       Milestone 15 (PHYSICS_ACCELERATOR_LINK)
Classification:  Sovereign Machine Physical Hardware Audit
Host Identity:   spark (host name redacted 2026-10-26; Linux 7.0.0-1019-nvidia aarch64)
Target Device:   NVIDIA GB10 (PCI 000f:01:00.0, Device ID 10de:2e12, rev a1)
IOMMU Substrate: ARM SMMUv3 (arm-smmu-v3.1.auto @ 0x13000000, IOMMU Group 20)
Date:            September 26, 2026
Audit Scope:     Empirical, Non-Destructive Hardware Verification
```

---

## 1. Executive Summary & Epistemic Doctrine

Milestone 15 (`PHYSICS_ACCELERATOR_LINK`) inaugurates **Phase C (Accelerator Cognition Substrate)** in the sovereign architectural roadmap. Where Phase B (Milestones 4–14) synthesized verified machine realizations directly onto host CPU execution pipelines ($G_S \times G_M \to G_R$), Phase C establishes the bounded, coherent interface between the sovereign CPU runtime and physical neural accelerator hardware.

To establish absolute epistemic ground truth prior to designing the hardware command queue abstraction and DMA sandboxing layers, this audit conducted a comprehensive, empirical, non-destructive physical discovery of the NVIDIA DGX Spark host (`spark`).

### Phase C Epistemic Classification Doctrine
Every factual finding in this audit is strictly classified under one of the five Phase C epistemic categories:
- **`DOCUMENTED`**: Explicitly certified by public architectural specifications, vendor manuals, or official technical documentation.
- **`OBSERVED`**: Empirically read and verified from physical registers, sysfs attributes, kernel message logs, ACPI firmware tables, or hardware query interfaces on the live host.
- **`REVERSE ENGINEERED`**: Derived from structural disassembly, source inspection of the open kernel modules (`nvidia.ko`, `nvidia-uvm.ko`), or kernel trace paths.
- **`INFERRED`**: Deduced via deductive mathematical or structural proof from verified observations.
- **`SPECULATIVE`**: Architectural hypothesis awaiting direct empirical confirmation or specialized test execution.

---

## 2. Host Platform & Compute Substrate Topology

### 2.1 Host SoC & Identification
- `[OBSERVED]` **Host Identity**: `spark`, running kernel `Linux spark 7.0.0-1019-nvidia #19~24.04.2-Ubuntu SMP PREEMPT_DYNAMIC Sun Sep 6 18:35:11 UTC 2026 aarch64`.
- `[OBSERVED]` **SoC Platform**: MediaTek MTKSGI / NVIDIA co-designed DGX Spark platform (`ACPI OEM ID: MEDTEK MTKSGI`, `BIOS: ALASKA AMI 20130221`).
- `[OBSERVED]` **NUMA Topology**: Single unified NUMA node (`node 0`) spanning all 20 CPU execution cores and 124,607 MB of accessible DRAM. Node distance is uniform (10).

### 2.2 Dual-Cluster Big.LITTLE CPU Pipeline
The host processor implements a 20-core heterogeneous ARMv9.2-A compute configuration divided into two symmetric 10-core clusters:

| Core Block | CPU Indices | Microarchitecture | ARM Part ID | Max Frequency | L1 I/D Cache | Private L2 | Shared Cluster L3 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Cluster 0 Efficiency** | 0 – 4 | ARM Cortex-A725 | `0xd87` (r0p1) | 2,808 MHz | 64K / 64K | 512 KiB | 8 MiB (CPUs 0–9) |
| **Cluster 0 Performance**| 5 – 9 | ARM Cortex-X925 | `0xd85` (r0p1) | 3,900 MHz | 64K / 64K | 512 KiB | 8 MiB (CPUs 0–9) |
| **Cluster 1 Efficiency** | 10 – 14 | ARM Cortex-A725 | `0xd87` (r0p1) | 2,808 MHz | 64K / 64K | 512 KiB | 16 MiB (CPUs 10–19) |
| **Cluster 1 Performance**| 15 – 19 | ARM Cortex-X925 | `0xd85` (r0p1) | 3,900 MHz | 64K / 64K | 512 KiB | 16 MiB (CPUs 10–19) |

- `[OBSERVED]` **ARM ISA Extensions**: `fp asimd aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma lrcpc dcpop sha3 sm3 sm4 asimddp sha512 sve asimdfhm dit uscat ilrcpc flagm sb paca pacg dcpodp sve2 sveaes svepmull svebitperm svesha3 svesm4 flagm2 frint svei8mm svebf16 i8mm bf16 dgh bti ecv afp wfxt`.
- `[INFERRED]` SVE2 and native BF16/I8MM instructions are present across all cores, ensuring vector operations synthesized under Milestones 5 and 14 execute natively on host CPUs with hardware float16/bfloat16 arithmetic.

---

## 3. Accelerator Substrate: NVIDIA GB10 Physical Audit

### 3.1 Device Identity & Topology
- `[OBSERVED]` **PCI Bus/Device/Function (BDF)**: `000f:01:00.0`.
- `[OBSERVED]` **Vendor & Device ID**: `10de:2e12` (Vendor: NVIDIA Corporation, Device: GB10).
- `[OBSERVED]` **Revision & Class**: Revision `0xa1`, Class Code `0x030000` (VGA Compatible Controller, Prog-IF 0x00).
- `[OBSERVED]` **Subsystem ID**: `10de:0000`.
- `[OBSERVED]` **Board ID & Part**: Board ID `0xf0100`, GPU Part Number `2E12-275-A1`, VBIOS Version `9A.0B.2D.00.00`.
- `[OBSERVED]` **Parent PCIe Bridge**: `000f:00:00.0` (NVIDIA Corporation Device `22d1`, IOMMU group 19).
- `[OBSERVED]` **PCI Segment / Domain**: Segment `15` (`0x000f`), Bus `01`, Device `00`, Function `0`.

### 3.2 BAR0 Configuration & Memory Aperture
- `[OBSERVED]` **BAR0 Base Address**: `0x24000000` (Physical System Bus Address).
- `[OBSERVED]` **BAR0 Size**: `67,108,864 bytes` (64 MiB, address range `0x24000000 - 0x27ffffff`).
- `[OBSERVED]` **BAR0 Properties**: 64-bit prefetchable memory (`resource0` flags `0x0014220c`). Lower nibble in PCI configuration register 0x10 is `0xc` (`0b1100`: Memory space = 0, 64-bit BAR = 10b, Prefetchable = 1).
- `[OBSERVED]` **BAR0 In-Kernel Mapping**: Claimed exclusively by the host `nvidia` kernel driver (`24000000-27ffffff : nvidia` in `/proc/iomem`).
- `[OBSERVED]` **BAR Exclusivity Invariant**: Direct userspace memory mapping (`mmap` on `/sys/bus/pci/devices/000f:01:00.0/resource0` or `/dev/mem`) is rejected with `EPERM` (`Operation not permitted`) due to kernel `CONFIG_STRICT_DEVMEM=y` driver isolation.
- `[REVERSE ENGINEERED]` **BAR0 Internal Layout**:
  - `0x00000000 - 0x00000004`: `NV_PMC_BOOT_0` / `NV_PMC_BOOT_1` (Master device architecture & revision registers).
  - `0x00000100 - 0x00000140`: `NV_PMC_INTR_0` / `NV_PMC_INTR_EN_0` (Hardware interrupt routing).
  - `0x00820c1c`: `NV_FUSE_STATUS_OPT_GPC` (GPC fuse enabling mask read during driver probe).
  - `0x00b90000`: MSI-X Vector Table (9 vectors, 16 bytes per entry = 144 bytes).
  - `0x00ba0000`: MSI-X Pending Bit Array (PBA, 64-bit bitmap).
  - `0x01000000 - 0x03ffffff`: Engine register spaces (Falcon microcontrollers, GPC work distributors, NVLink endpoints).

### 3.3 The Absence of Discrete VRAM BARs (BAR1–5)
- `[OBSERVED]` **BAR1–BAR5 Status**: PCI configuration registers `0x14`, `0x18`, `0x1c`, `0x20`, and `0x24` are strictly `0x00000000`.
- `[OBSERVED]` **Sysfs Resource Mask**: Only `resource0` and `resource0_wc` exist under `/sys/bus/pci/devices/000f:01:00.0/`.
- `[OBSERVED]` **`nvidia-smi` Diagnostics**:
  - `FB Memory Usage`: `N/A`
  - `BAR1 Memory Usage`: `N/A`
- `[INFERRED]` Unlike discrete desktop/datacenter GPUs (e.g. RTX 4090, H100) which allocate a 32-bit or 64-bit BAR1 aperture to expose on-board GDDR/HBM VRAM to host PCIe accesses, the Blackwell GB10 has **no discrete framebuffer**. The GPU possesses zero dedicated VRAM memory chips. The entire physical memory store is unified LPDDR5x DRAM shared directly between CPU and GPU.

### 3.4 PCI Configuration Space & Extended Capabilities
Traversing the 4,096-byte PCIe Extended Configuration Space exposed at ECAM address `0x29000000` revealed the following capability chains:

```text
PCI Standard Capabilities (0x00 - 0xff):
  [0x40] ID 0x01 : Power Management (v3, D0 active, NoSoftRst+)
  [0x48] ID 0x05 : MSI (64-bit, Maskable, Disabled Count=1/16)
  [0x60] ID 0x10 : PCI Express (v2 Endpoint, MaxPayload 256B, MaxReadReq 512B)
  [0x9c] ID 0x09 : Vendor Specific (Len=14)
  [0xb0] ID 0x11 : MSI-X (Enabled, Count=9, Table BAR0@0x00b90000, PBA BAR0@0x00ba0000)

PCIe Extended Capabilities (>= 0x100):
  [0x100] ID 0x0019 : Secondary PCI Express (v1)
  [0x12c] ID 0x0018 : Latency Tolerance Reporting (LTR, v1, Snoop/No-snoop 0ns)
  [0x14c] ID 0x0025 : Data Link Feature (v1)
  [0x158] ID 0x0026 : Physical Layer 16.0 GT/s (v1, PCIe Gen4 capable)
  [0x188] ID 0x002a : Physical Layer 32.0 GT/s (v1, PCIe Gen5 capable)
  [0x1b8] ID 0x0001 : Advanced Error Reporting (AER, v2)
  [0x200] ID 0x0027 : Lane Margining at Receiver (v1)
  [0x248] ID 0x000e : Alternative Routing-ID Interpretation (ARI, v1)
  [0x290] ID 0x001e : L1 PM Substates (v2)
  [0x2a4] ID 0x000b : Vendor Specific Extended Capability (VSEC, v1)
  [0x2e0] ID 0x000f : Address Translation Services (ATS, v1, ATSCtl=0x8000 -> Enabled)
  [0x2e8] ID 0x001b : Process Address Space ID (PASID, v1, Width=20 bits, Enabled)
  [0x2f0] ID 0x0003 : Device Serial Number (v1: 00-00-00-00-00-2d-b0-48)
```

- `[OBSERVED]` **ATS Enablement**: Offset `0x2e0`, Control register = `0x8000` (Bit 15 = 1, ATS actively enabled in hardware; Smallest Translation Unit = 0).
- `[OBSERVED]` **PASID Enablement**: Offset `0x2e8`, Capability = `0x1400` (Max PASID Width = 20 bits = $2^{20} = 1,048,576$ concurrent address spaces), Control = `0x0001` (Bit 0 = 1, PASID actively enabled).
- `[OBSERVED]` **Absence of PCIe PRI**: The PCIe extended capability list contains ATS (`0x000f`) linked directly to PASID (`0x001b`), which links to Device Serial Number (`0x0003`). The PCIe Page Request Interface capability (`0x0013`) is omitted from the PCI config space of `000f:01:00.0`. Page faults are handled internally via coherent interconnect protocols and SMMUv3 IOPF.

### 3.5 Hardware Interrupt Routing & GICv3 ITS
- `[OBSERVED]` **Legacy INTx Routing**: ACPI `_PRT` routes INTx Pin A to GSI `642` (mapped to Linux IRQ 427). However, PCI Command register bit 10 is set (`DisINTx+`), disabling legacy line interrupts in favor of message-signaled interrupts.
- `[OBSERVED]` **MSI-X Allocation**: 9 vector slots declared in hardware. 8 vectors (IRQs 429–436) are actively mapped to the ARM GICv3 Interrupt Translation Service (ITS):
  ```text
  IRQ 429: ITS-PCI-MSIX-000f:01:00.0  Vector 0  [nvidia]
  IRQ 430: ITS-PCI-MSIX-000f:01:00.0  Vector 1  [nvidia]
  IRQ 431: ITS-PCI-MSIX-000f:01:00.0  Vector 2  [nvidia] -> 1,020,881 interrupts serviced on CPU 13
  IRQ 432: ITS-PCI-MSIX-000f:01:00.0  Vector 3  [nvidia]
  IRQ 433: ITS-PCI-MSIX-000f:01:00.0  Vector 4  [nvidia]
  IRQ 434: ITS-PCI-MSIX-000f:01:00.0  Vector 5  [nvidia]
  IRQ 435: ITS-PCI-MSIX-000f:01:00.0  Vector 6  [nvidia]
  IRQ 436: ITS-PCI-MSIX-000f:01:00.0  Vector 7  [nvidia]
  ```
- `[OBSERVED]` **Hot Interrupt Path**: Vector 2 (IRQ 431) is the primary command completion and work notification interrupt, routed to Core 13 (Cortex-A725).

### 3.6 Microarchitectural Specifications (Compute Capability 12.1)
Direct empirical query of the CUDA 13.0 driver interface (`libcuda.so`) revealed the following hardware dimensions:

```text
Compute Capability            : 12.1 (Blackwell Architecture)
Streaming Multiprocessors (SM): 48 SMs
Max Threads per SM            : 1,536 threads
Max Threads per Block         : 1,024 threads
Warp Size                     : 32 threads
Registers per SM              : 65,536 (32-bit registers) -> 3,145,728 total (12 MiB register file)
Total Constant Memory         : 65,536 bytes (64 KiB)
L2 Cache Capacity             : 25,165,824 bytes (24 MiB dedicated GPU L2 cache)
Integrated Accelerator Flag   : 1 (True integrated SoC device)
Memory Bus Width              : 256 bits
Memory Clock / Data Rate      : 8,533 MT/s (LPDDR5x)
Theoretical Memory Bandwidth  : 273.056 GB/s
Unified Addressing Mode       : 1 (Unified Virtual Addressing active)
Concurrent Managed Access     : 1
Pageable Memory Access        : 1
Host Page Table Walk Support  : 1 (GPU hardware page walker resolves host OS page tables)
Host Native Atomic Support    : 1 (Hardware-coherent atomics across CPU and GPU caches)
```

---

## 4. ARM SMMUv3 Translation & Sandboxing Substrate

### 4.1 SMMUv3 Instance Topology
The host system incorporates three discrete ARM SMMUv3 instances managing distinct IO physical address zones:

| SMMU Instance | Physical Base Address | Size | Primary Managed Domain | Features Mask |
| :--- | :--- | :--- | :--- | :--- |
| `arm-smmu-v3.0.auto` | `0x13800000` | 128 KiB | Low platform devices & Segments 0–14 | `0x0196dfbf` |
| `arm-smmu-v3.1.auto` | `0x13000000` | 128 KiB | **PCI Segment 15 (`PCIF`, GB10 GPU)** | `0x0196dfbf` |
| `arm-smmu-v3.2.auto` | `0x14900000` | 128 KiB | High system peripherals (`NVDA2861:00`) | `0x0196dfbf` |

- `[OBSERVED]` **Target Instance**: `arm-smmu-v3.1.auto` at `0x13000000` governs the GB10 GPU (`000f:01:00.0`), the root port (`000f:00:00.0`), and platform device `NVDA2014:00`.
- `[OBSERVED]` **PMCG Performance Counters**: 7 PMCG performance counter blocks (`arm-smmu-v3-pmcg.10.auto` through `pmcg.16.auto`) are mapped between `0x13002000` and `0x130f2000`, providing hardware telemetry over translation cache hits and latency.

### 4.2 Feature Mask & OAS Bitwise Decoding
`arm-smmu-v3.1.auto` reports feature mask `0x0196dfbf` and 40-bit OAS. Decoding this mask against the ARM SMMUv3 architecture specification establishes the following capabilities:

```text
SMMUv3 Feature Bitmask: 0x0196dfbf (Binary: 0000 0001 1001 0110 1101 1111 1011 1111)

Bit 0  : 1 (ARM_SMMU_FEAT_2_LVL_STRTAB) -> 2-level Stream Table supported
Bit 1  : 1 (ARM_SMMU_FEAT_2_LVL_CDTAB)  -> 2-level Context Descriptor Table supported
Bit 2  : 1 (ARM_SMMU_FEAT_TT_LE)        -> Little-endian translation tables supported
Bit 3  : 1 (ARM_SMMU_FEAT_TT_BE)        -> Big-endian translation tables supported
Bit 4  : 1 (ARM_SMMU_FEAT_PRI)          -> Page Request Interface supported
Bit 5  : 1 (ARM_SMMU_FEAT_ATS)          -> Address Translation Services supported
Bit 6  : 0 (Reserved / SEV absent)
Bit 7  : 1 (ARM_SMMU_FEAT_MSI)          -> MSI interrupt generation supported
Bit 8  : 1 (ARM_SMMU_FEAT_COHERENCY)    -> Hardware Coherent Page Table Walks (DVM/CCIX/Coherent Fabric)
Bit 9  : 1 (ARM_SMMU_FEAT_TRANS_S1)     -> Stage 1 Virtual Address -> Intermediate Physical Address
Bit 10 : 1 (ARM_SMMU_FEAT_TRANS_S2)     -> Stage 2 Intermediate Physical Address -> Physical Address
Bit 11 : 1 (ARM_SMMU_FEAT_STALLS)       -> Memory stall model supported for faulting accesses
Bit 12 : 1 (ARM_SMMU_FEAT_HYP)          -> Hypervisor Stage 2 translation regime
Bit 13 : 0 (ARM_SMMU_FEAT_STALL_FORCE)  -> Stall force not asserted
Bit 14 : 1 (ARM_SMMU_FEAT_VAX)          -> 52-bit Virtual Address Extension supported
Bit 15 : 1 (ARM_SMMU_FEAT_RANGE_INV)    -> Range Invalidation commands (CMD_TLBI_EL2_ALL / CMD_CFGI_ALL)
Bit 16 : 0 (ARM_SMMU_FEAT_BTM)          -> Broadcast TLB Maintenance via SMMU absent
Bit 17 : 1 (ARM_SMMU_FEAT_SVA)          -> Shared Virtual Addressing fully enabled
Bit 18 : 1 (ARM_SMMU_FEAT_ECMDQ)        -> Enhanced Command Queue (Virtual Command Queues CMDQ-V)
Bit 19 : 0 (ARM_SMMU_FEAT_HA)           -> Hardware Access flag update
Bit 20 : 1 (ARM_SMMU_FEAT_HD)           -> Hardware Dirty bit management supported
Bit 23 : 1 (ARM_SMMU_FEAT_ATTR_TYPES_OVR)-> Memory Attribute Type Override
Bit 24 : 1 (ARM_SMMU_FEAT_S2FWB)        -> Stage 2 Forced Write-Back cache attribute enforcement
```

- `[OBSERVED]` **Output Address Size (OAS)**: 40 bits ($2^{40} = 1,099,511,627,776 \text{ bytes} = 1 \text{ TiB}$). Physical addresses emitted by SMMUv3 are bounded to 40 bits, matching the 128 GiB physical DRAM boundary.
- `[OBSERVED]` **Hardware Coherency (`Bit 8 = 1`)**: Page table walks by the SMMUv3 are fully coherent with CPU cache hierarchies. Modifications to translation tables by the CPU do not require manual software cache cleaning (`dc cvac`).

### 4.3 Hardware Ring Buffer Dimensions
The kernel initializes three distinct hardware circular ring buffers for `arm-smmu-v3.1.auto`:

```text
+-----------------------+---------------+------------------+---------------------+
| Hardware Ring Buffer  | Entry Count   | Descriptor Size  | Total Ring Capacity |
+-----------------------+---------------+------------------+---------------------+
| Command Queue (CMDQ)  | 65,536        | 16 bytes         | 1,048,576 B (1 MiB) |
| Event Queue (EVTQ)    | 32,768        | 32 bytes         | 1,048,576 B (1 MiB) |
| Page Request Q (PRIQ) | 65,536        | 16 bytes         | 1,048,576 B (1 MiB) |
+-----------------------+---------------+------------------+---------------------+
```

- `[OBSERVED]` **Command Queue (CMDQ)**: Base register `0x13000090`. 65,536 entries ($\text{LOG2SIZE} = 16$). Commands submitted: `CMD_CFGI_STE`, `CMD_TLBI_EL2_VA`, `CMD_SYNC`.
- `[OBSERVED]` **Event Queue (EVTQ)**: Base register `0x130000a0`. 32,768 entries ($\text{LOG2SIZE} = 15$). Records asynchronous translation faults, permission violations, and address bounds aborts.
- `[OBSERVED]` **PRI Queue (PRIQ)**: Base register `0x130000b0`. 65,536 entries ($\text{LOG2SIZE} = 16$). Records page requests from PCIe ATS requesters for demand paging.

### 4.4 Stream ID Architecture & Mappings
In ARM SMMUv3, inbound PCIe transactions are tagged with a **Stream ID (SID)** derived from the transaction's Requester ID (PCI BDF):

1. `[OBSERVED]` **2-Level Stream Table**:
   - The SMMUv3 hardware allocates a 2-level Stream Table covering 25 bits of SID space ($2^{25} = 33,554,432$ Stream IDs).
   - In accordance with the Linux ARM SMMUv3 driver, `STRTAB_SPLIT` is 8 bits (256 Stream Table Entries per L2 leaf).
   - The Level 1 table encompasses $25 - 8 = 17$ bits ($131,072$ pointers, each 8 bytes = 1 MiB L1 table).
   - Each individual Stream Table Entry (STE) is 64 bytes.

2. `[INFERRED]` **Stream ID Formulation**:
   - ACPI IORT Node 29 (PCI Root Complex Segment 15, `PCIF`) defines a 1:1 ID mapping with `Input Base = 0x00000000`, `Number of IDs = 65,536`, and `Output Base = 0x00000000` referencing Node 2 (`SMMUv3 @ 0x13000000`).
   - For any PCI device under Segment 15, the 16-bit BDF maps directly to:
     $$\text{Stream ID} = \text{Output Base} + (\text{BDF} - \text{Input Base}) = \text{BDF}$$
   - **NVIDIA GB10 GPU (`000f:01:00.0`)**:
     - $\text{Bus} = 0x01$, $\text{Device} = 0x00$, $\text{Function} = 0x00$.
     - $\text{BDF} = (1 \ll 8) | (0 \ll 3) | 0 = \mathbf{0x0100} \text{ (256)}$.
     - **$\text{Stream ID}_{\text{GB10}} = \mathbf{0x0100}$ (256 decimal)**.
   - **PCIe Root Port (`000f:00:00.0`)**:
     - $\text{Bus} = 0x00$, $\text{Device} = 0x00$, $\text{Function} = 0x00$.
     - $\text{BDF} = \mathbf{0x0000}$.
     - **$\text{Stream ID}_{\text{RootPort}} = \mathbf{0x0000}$ (0 decimal)**.

3. `[OBSERVED]` **IOMMU Group Isolation**:
   - SMMUv3 isolates the GB10 GPU into **IOMMU Group 20** (`/sys/kernel/iommu_groups/20`).
   - Group 20 contains exclusively `000f:01:00.0`.
   - Access Control Services (ACS) on root port `000f:00:00.0` prevents peer-to-peer transaction bypass, ensuring all DMA and ATS requests are strictly validated by the SMMUv3.

### 4.5 SMMU CMDQ-V (Virtual Command Queues)
- `[REVERSE ENGINEERED]` **Base Offset**: In accordance with the NVIDIA UVM driver (`uvm_ats_sva.c`), the hardware features ARM SMMUv3 Command Queue Virtualization (CMDQ-V):
  $$\text{CMDQV\_BASE} = \text{SMMU\_BASE} + 0x200000 = 0x13000000 + 0x200000 = \mathbf{0x13200000}$$
- `[REVERSE ENGINEERED]` **Direct Queue Submission**: The host driver initializes Virtual Interface 63 (`VINTF 63`) and allocates Virtual Command Queue 127 (`VCMDQ 127`).
- `[REVERSE ENGINEERED]` **Bypass Mechanism**: When user memory pages undergo protection updates (e.g. read-only to read-write upgrade in unified memory), the UVM driver directly submits `CMDQ_OP_TLBI_EL2_VA` (0x22) and `CMDQ_OP_CMD_SYNC` (0x46) commands into VCMDQ 127, completely bypassing OS kernel locks and providing microsecond-level hardware TLB invalidation.

---

## 5. Unified Memory Envelope, Physical Layout & Cache Coherency

### 5.1 Physical DRAM Envelope
- `[OBSERVED]` **DRAM Technology**: 128 GB Unified LPDDR5x DRAM (SK Hynix, synchronous, soldered on-package).
- `[OBSERVED]` **Data Rate**: `8533 MT/s` (`Speed: 8533 MT/s`, `Configured Memory Speed: 8533 MT/s` in SMBIOS Type 17).
- `[OBSERVED]` **Bus Geometry**: 256-bit wide memory interface to SoC interconnect.
- `[INFERRED]` **Bandwidth Derivation**:
  $$\text{Throughput} = \frac{256 \text{ bits} \times 8,533 \times 10^6 \text{ transfers/sec}}{8 \text{ bits/byte}} = \mathbf{273.056 \text{ GB/s}}$$
- `[OBSERVED]` **Memory Capacity Allocation**:
  - Raw DRAM Envelope: 128.00 GB ($137,438,953,472$ bytes).
  - Usable System Memory (`MemTotal`): 121.69 GB ($130,660,888,576$ bytes).
  - Firmware / TrustZone / SCP Reservations: ~6.31 GB ($6,778,064,896$ bytes).
  - `CmaTotal` (Contiguous Memory Allocator): **0 kB**. The host allocates zero static CMA carveouts; all unified accelerator buffers are dynamically paged via SMMUv3.

### 5.2 System Physical Memory Map (`/proc/iomem`)
The physical address space is structured into specific MMIO, ECAM, and contiguous DRAM segments:

```text
Physical Address Range          Size        Attributed Entity
-----------------------------------------------------------------------------------------
0x0000000012e30000 - 0x0000000012e30fff      4 KiB       MediaTek / NVDA System Controller
0x0000000013000000 - 0x000000001301ffff    128 KiB       arm-smmu-v3.1.auto (GPU SMMU)
0x0000000013002000 - 0x00000000130f2000    960 KiB       arm-smmu-v3-pmcg.10 - 16 (PMCGs)
0x0000000013800000 - 0x000000001381ffff    128 KiB       arm-smmu-v3.0.auto (Platform SMMU)
0x0000000014900000 - 0x000000001491ffff    128 KiB       arm-smmu-v3.2.auto (High SMMU)
0x0000000024000000 - 0x0000000027ffffff     64 MiB       000f:01:00.0 (NVIDIA GB10 BAR0)
0x0000000029000000 - 0x00000000291fffff      2 MiB       PCI ECAM (Segment 15 Config Space)
-----------------------------------------------------------------------------------------
0x0000000080080000 - 0x0000000083d5ffff     60.8 MiB     System RAM (Kernel Code & Boot)
0x0000000083d70000 - 0x000000008655ffff     39.9 MiB     System RAM
0x0000000087020000 - 0x000000008707ffff    384.0 KiB     System RAM (ACPI Tables / IORT)
0x00000000d5a00000 - 0x00000000ddffffff    134.0 MiB     System RAM
0x00000000e0020000 - 0x00000000f9ffffff    415.8 MiB     System RAM
0x00000000fa002000 - 0x00000000ffcfffff     92.9 MiB     System RAM
0x00000000ffd20000 - 0x000000027fffffff    6.002 GiB     System RAM (Low 32-bit/40-bit Window)
0x0000000323800000 - 0x000000207df6ffff  115.006 GiB     System RAM (High Unified Memory Store)
```

- `[OBSERVED]` **Upper Memory Limit**: Maximum physical RAM address is `0x000000207df6ffff` (~130 GiB). This fits within a 38-bit address boundary, well within the 40-bit SMMU OAS envelope ($2^{40} = 0x10000000000$).

### 5.3 ACPI Firmware Specification of Coherency
Firmware tables confirm hardware-level cache coherency across the CPU and GPU interconnect:
- `[OBSERVED]` **ACPI SSDT1 (`PCIF` Node)**:
  - `_HID`: `PNP0A08`
  - `_SEG`: `0x000f` (PCI Segment 15)
  - `_CCA`: **`0x01`** (Cache Coherency Attribute).
  - In ACPI specification §6.2.17, `_CCA = 1` mandates that the device conducts bus transfers with hardware-enforced cache coherency. Software does not need to perform cache maintenance or invalidate CPU L1/L2/L3 lines to synchronize memory with the accelerator.
- `[OBSERVED]` **ACPI IORT Node 29**:
  - Memory Access Properties field = `0x00000001` (Cache Coherent Access).
  - ATS Attribute = `0x00000003` (ATS supported).
- `[OBSERVED]` **Hardware Atomics**:
  - CUDA Driver property `CU_DEVICE_ATTRIBUTE_HOST_NATIVE_ATOMIC_SUPPORTED = 1`.
  - The GPU and CPU execute atomic read-modify-write primitives (e.g. `LDADD`, `SWP`, `CAS`) directly across shared physical memory addresses with mutual exclusion guaranteed in hardware.

---

## 6. Shared Virtual Addressing (SVA) & Kernel Driver Realities

### 6.1 Process Address Space ID (PASID) & ATS Negotiation
- `[OBSERVED]` The GB10 PCIe endpoint advertises 20-bit PASID width ($1,048,576$ PASIDs) and ATS support.
- `[OBSERVED]` The Linux kernel activates ATS (`ATSCtl: Enable+`) and PASID (`PASIDCtl: Enable+`).
- `[OBSERVED]` When CUDA initializes, `nvidia_uvm` invokes:
  ```c
  iommu_sva_bind_device(&pci_dev->dev, current->mm);
  pasid = iommu_sva_get_pasid(handle);
  ```
- `[INFERRED]` This operation programs the SMMUv3 Context Descriptor (CD) table with the process's page directory base pointer (`TTBR0_EL1`). The GPU is granted direct hardware translation access to the process's virtual address space.

### 6.2 Zero-Copy Unified Memory Architecture
The combination of hardware cache coherency (`_CCA = 1`), SMMUv3 ATS/SVA, and unified LPDDR5x DRAM establishes the following operational reality for Phase C:

```text
+-----------------------------------------------------------------------------------+
|                        UNIFIED LPDDR5x PHYSICAL DRAM (128 GB)                     |
+-----------------------------------------------------------------------------------+
             ^                                                   ^
             | Hardware Cache Coherent                           | Hardware Cache Coherent
             v Interconnect                                      v Interconnect
+--------------------------+                               +--------------------------+
|  ARM Cortex-X925 / A725  |                               |     NVIDIA GB10 GPU      |
|  (20 Cores, Host CPU)    |                               |    (48 SMs, CC 12.1)     |
+--------------------------+                               +--------------------------+
             |                                                   |
             | MMU (TTBR0_EL1)                                   | ATC (Translation Cache)
             v                                                   v
   [ Virtual Address: VA ] ----------------------------> [ Virtual Address: VA ]
                                     PCIe ATS
                               (Tagged with PASID)
                                         |
                                         v
                         +-------------------------------+
                         |      ARM SMMUv3.1.auto        |
                         |   (Base: 0x13000000, GID: 20) |
                         +-------------------------------+
```

1. **Zero Data Movement**: Any memory buffer allocated via standard OS memory allocators (`malloc`, `mmap`, `posix_memalign`) or CUDA unified memory (`cudaMallocManaged`) resides in the exact same physical LPDDR5x DRAM chips.
2. **Pointers are Identical**: Pointers generated by host C/Rust code and pointers referenced by Blackwell GPU kernels share the identical 64-bit virtual address (`VA_CPU == VA_GPU`).
3. **No PCIe Bottleneck**: While `lspci` reports a 2.5 GT/s x1 PCIe link internally for the control interface, bulk memory traffic flows directly over the internal coherent SoC memory interconnect at up to **273 GB/s**.
4. **Hardware Page Walks**: `CU_DEVICE_ATTRIBUTE_PAGEABLE_MEMORY_ACCESS_USES_HOST_PAGE_TABLES = 1`. If the GPU accesses a page not yet present in its local Address Translation Cache (ATC), the GPU issues an ATS translation request over the internal fabric to `arm-smmu-v3.1.auto`. The SMMU walks the host OS page table directly from LPDDR5x DRAM without CPU intervention.

---

## 7. Epistemic Verification Matrix

In accordance with Phase C doctrine, every verified finding from this audit is categorized in the matrix below:

| Architectural Component | Finding / Parameter | Epistemic Status | Empirical Source / Artifact |
| :--- | :--- | :--- | :--- |
| **Host Identity** | `spark`, Ubuntu 24.04.2 LTS, Kernel 7.0.0-1019-nvidia | `OBSERVED` | `uname -a`, `/etc/os-release` |
| **CPU Architecture** | 10x Cortex-X925 (`0xd85`, 3.9GHz) + 10x Cortex-A725 (`0xd87`, 2.8GHz) | `OBSERVED` | `/proc/cpuinfo`, sysfs `cpuinfo_max_freq` |
| **Vector Engine** | SVE2, BF16, I8MM hardware execution support | `OBSERVED` | `/proc/cpuinfo` flags |
| **GPU Identification**| NVIDIA GB10, PCI `000f:01:00.0`, Device `10de:2e12`, Rev `a1` | `OBSERVED` | `lspci -vvv -s 000f:01:00.0` |
| **GPU Architecture**  | Blackwell, Compute Capability 12.1, 48 SMs | `OBSERVED` | CUDA Driver API (`libcuda.so`), `nvidia-smi` |
| **GPU Register File** | 65,536 registers per SM (3,145,728 total, 12 MiB) | `OBSERVED` | `CU_DEVICE_ATTRIBUTE_REGISTERS_PER_MULTIPROCESSOR` |
| **GPU L2 Cache**      | 25,165,824 bytes (24 MiB dedicated L2) | `OBSERVED` | `CU_DEVICE_ATTRIBUTE_L2_CACHE_SIZE` |
| **BAR0 Physical Base**| `0x24000000` (Size: 64 MiB, flags: 64-bit prefetchable) | `OBSERVED` | PCI config space offset 0x10, `/proc/iomem` |
| **BAR0 Exclusivity**  | Userspace mmap rejected with EPERM (`CONFIG_STRICT_DEVMEM=y`) | `OBSERVED` | Live syscall test, `/boot/config-7.0.0-1019-nvidia` |
| **BAR0 Internal Layout**| PMC boot @ 0x0, Fuses @ 0x820c1c, MSI-X Table @ 0xb90000 | `REVERSE ENGINEERED` | `nvidia-580.173.02/nvidia/nv-pci.c`, PCI caps |
| **BAR1–5 Absence**    | Zero secondary BARs; no discrete framebuffer aperture | `OBSERVED` | PCI config space registers 0x14–0x24 = 0 |
| **PCIe Capabilities** | PM v3, MSI-X (9 vectors), AER v2, ARI, ATS, PASID (20-bit) | `OBSERVED` | PCIe 4 KiB ECAM parse (`0x29000000`) |
| **PCIe PRI Status**   | Absent from PCIe capability linked list | `OBSERVED` | PCIe extended capability chain traversal |
| **Interrupt Routing** | MSI-X IRQs 429–436 via ARM GIC ITS; Vector 2 (IRQ 431) hot | `OBSERVED` | `/proc/interrupts` |
| **SMMUv3 Instances**  | 3 instances (`0x13800000`, `0x13000000`, `0x14900000`) | `OBSERVED` | `/proc/iomem`, kernel boot log |
| **Target SMMUv3**     | `arm-smmu-v3.1.auto` @ `0x13000000`, controls IOMMU Group 20 | `OBSERVED` | `/sys/bus/platform/devices/arm-smmu-v3.1.auto` |
| **SMMUv3 OAS**        | 40 bits (1 TiB physical address limit) | `OBSERVED` | `dmesg`, SMMUv3 probe string |
| **SMMUv3 Feature Mask**| `0x0196dfbf` (Coherency, ATS, PRI, SVA, ECMDQ, 2-lvl strtab) | `OBSERVED` | `dmesg`, bitwise architectural decode |
| **SMMUv3 Ring Buffers**| CMDQ: 65,536 (1MB), EVTQ: 32,768 (1MB), PRIQ: 65,536 (1MB) | `OBSERVED` | `dmesg`, SMMUv3 log output |
| **Stream ID Mapping** | Segment 15 1:1 BDF mapping; GB10 `01:00.0` -> `SID = 0x0100` (256) | `INFERRED` | ACPI IORT Node 29 & Node 2 math |
| **SMMU CMDQ-V**       | Direct user/driver queue @ `0x13200000`, VINTF 63, VCMDQ 127 | `REVERSE ENGINEERED` | `nvidia-uvm/uvm_ats_sva.c` lines 61–195 |
| **Physical DRAM**     | 128 GB LPDDR5x (SK Hynix, 8533 MT/s, 256-bit bus, 273 GB/s) | `OBSERVED` | SMBIOS DMI Type 17, `CU_DEVICE_ATTRIBUTE_*` |
| **Physical Address Max**| `0x000000207df6ffff` (38-bit physical address) | `OBSERVED` | `/proc/iomem` System RAM bounds |
| **Firmware Coherency** | `_CCA = 0x01` on Root Complex `PCIF`; IORT CCA = 1 | `OBSERVED` | ACPI SSDT1 (`0x5444`), ACPI IORT (`0x072c`) |
| **Hardware Atomics**  | Native atomic operations supported across CPU and GPU | `OBSERVED` | `CU_DEVICE_ATTRIBUTE_HOST_NATIVE_ATOMIC_SUPPORTED` |
| **Page Table Sharing** | GPU directly walks host OS CPU page tables via SMMUv3 | `OBSERVED` | `PAGEABLE_MEMORY_ACCESS_USES_HOST_PAGE_TABLES = 1` |
| **DMA Sandboxing Model**| Stage 1 process SVA + Stage 2 hypervisor SMMUv3 domain | `DOCUMENTED` | ARM SMMUv3 Architecture Specification |
| **Native Blackwell SM**| SM 12.1 dual-issue instruction scheduling & tensor pipeline | `SPECULATIVE` | To be characterized in Milestone 16 |

---

## 8. Strategic Implications for Milestone 15 & Roadmap Execution

The empirical discoveries of this audit yield decisive architectural constraints and opportunities for Milestone 15 (`PHYSICS_ACCELERATOR_LINK`) and downstream milestones:

1. **No Separate Buffer Management Subsystem Required**:
   Because the system implements unified LPDDR5x memory with hardware cache coherency (`_CCA = 1`) and shared host page table walks (`PAGEABLE_MEMORY_ACCESS_USES_HOST_PAGE_TABLES = 1`), the sovereign platform **does not need to implement a synthetic PCIe DMA staging ring or CPU-to-GPU memory copy pipeline**. Buffers synthesized in host RAM by Milestone 14 realizations are instantly addressable by accelerator hardware at the identical virtual pointer.

2. **SMMUv3 DMA Sandboxing via Stream ID `0x0100`**:
   The sovereign hardware link must enforce DMA bounds at the ARM SMMUv3 level. By binding to Stream ID `0x0100` (`arm-smmu-v3.1.auto`), the sovereign runtime can establish isolated Stage 1 address spaces (or utilize the kernel's existing SVA context descriptor infrastructure) to guarantee that rogue accelerator writes cannot corrupt host kernel code or invariant ledgers.

3. **Hardware Ring Buffer Interaction**:
   Low-latency invalidation and barrier synchronization can leverage the SMMU CMDQ-V extension at physical base `0x13200000` (or the driver's UVM interface), allowing sovereign realizations to flush SMMU TLB entries in microsecond timescales without tripping kernel scheduling latencies.

4. **Blackwell Microarchitecture Foundation (Milestone 16 Transition)**:
   The empirical confirmation of Compute Capability `12.1`, 48 Streaming Multiprocessors, 24 MiB L2 cache, and 12 MiB total register file establishes the concrete pipeline parameters for the machine hardware graph ($G_M$) in Milestone 16 (`BLACKWELL_NATIVE_PATH_KNOWN`) and native vector/matmul realization synthesis in Milestones 17 and 18.
