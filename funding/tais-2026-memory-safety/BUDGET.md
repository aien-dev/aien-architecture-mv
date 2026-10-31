# Full program budget — AIEN Omega memory-safety research

**Status: UNFUNDED PLANNING PROPOSAL (2026-10-27). USD.** All rates are **illustrative unquoted estimates**, not vendor-confirmed offers, staffing commitments or money already spent. Minimum viable funding **$250,000**, total proposed 24-month program **$10,000,000**. This document matches the machine-readable [budget.json](budget.json).

## Expenditure allocation by research milestone

| Tranche | Personnel | Hardware | Independent audits | Infrastructure | Contingency | Incremental | Cumulative |
|---|---:|---:|---:|---:|---:|---:|---:|
| M1 — Months 0-3 | $150,000 | $35,000 | $35,000 | $15,000 | $15,000 | **$250,000** | **$250,000** |
| M2 — Months 4-6 | $500,000 | $115,000 | $65,000 | $45,000 | $25,000 | **$750,000** | **$1,000,000** |
| M3 — Months 7-12 | $1,950,000 | $350,000 | $280,000 | $250,000 | $170,000 | **$3,000,000** | **$4,000,000** |
| M4 — Months 13-24 | $3,990,000 | $735,000 | $540,000 | $435,000 | $300,000 | **$6,000,000** | **$10,000,000** |
| **Total** | **$6,590,000** | **$1,235,000** | **$920,000** | **$745,000** | **$510,000** | **$10,000,000** | **$10,000,000** |

The **$250K**, **$1M**, **$4M**, and **$10M** figures are *cumulative targets*; the increments are respectively **$250K**, **$750K**, **$3M**, and **$6M**. They must not be added as if they were independent awards. No tranche is unlocked automatically.

## Detailed line items

### personnel — $6,590,000

| Line item | Quantity | Unit planning allowance | Extended cost | Purpose |
|---|---:|---:|---:|---|
| Programming language/formal verification specialists | 110 person-month | $18,000 | $1,980,000 | Typed memory model, compiler verification, constrained source translation |
| GPU compiler and runtime systems engineers | 104 person-month | $15,000 | $1,560,000 | CUDApp, CPU/GPU ownership, buffers and cross-vendor validation |
| AI agent security/adversarial researchers | 60 person-month | $16,000 | $960,000 | Tool containment, fault injection, isolation and threat models |
| Framework integration and test engineers | 52 person-month | $15,000 | $780,000 | GGML, PyTorch, numerical and memory regression comparisons |
| OSS maintenance, release and CI engineers | 42 person-month | $15,000 | $630,000 | Reproducible release process and upstream interoperability |
| Program management and research operations | 28 person-month | $15,000 | $420,000 | Procurement, fiscal control, open reporting |
| Independent research fellowships | 26 person-month | $10,000 | $260,000 | Replication and specialized methods |
| **Subtotal** | | | **$6,590,000** | |

### hardware — $1,235,000

| Line item | Quantity | Unit planning allowance | Extended cost | Purpose |
|---|---:|---:|---:|---|
| Additional DGX Sparks | 10 system | $5,000 | $50,000 | Three initial Sparks proposed; independent reproduction and destructive tests |
| Discrete NVIDIA GPU development systems | 12 system | $9,000 | $108,000 | Separate CPU/device address spaces and driver coverage |
| Data-center NVIDIA accelerator host allowances | 4 system | $75,000 | $300,000 | Multi-GPU isolation, subject to target support and utilization |
| AMD CPU and ROCm-oriented GPU workstations | 12 system | $10,000 | $120,000 | AMD heterogeneous memory, driver and porting tests |
| AMD high-memory server configurations | 4 system | $35,000 | $140,000 | Large workloads and memory pressure tests |
| Intel discrete GPU workstations | 10 system | $7,000 | $70,000 | Intel memory mapping and runtime semantics |
| Intel accelerator server allowances | 4 system | $40,000 | $160,000 | Larger target experiments contingent on compatibility |
| Shared storage, racks, network, RAM, CI servers | 1 lot | $140,000 | $140,000 | Lab orchestration and durable reproducibility |
| Power, thermal, UPS, measurement and fault-injection tools | 1 lot | $70,000 | $70,000 | Adversarial hardware testing and reliable energy readings |
| Spares, shipping, maintenance pool | 1 lot | $77,000 | $77,000 | Availability, repairs and replacements |
| **Subtotal** | | | **$1,235,000** | |

### audits — $920,000

| Line item | Quantity | Unit planning allowance | Extended cost | Purpose |
|---|---:|---:|---:|---|
| Formal-methods proof audits | 8 review | $50,000 | $400,000 | External proof and trusted-computing-base scrutiny |
| Adversarial security/red-team audits | 6 review | $50,000 | $300,000 | Attempt to break host/GPU/agent protections |
| Driver/runtime binary and source audits | 4 review | $30,000 | $120,000 | Unsafe interfaces, memory protection and firmware boundaries |
| Independent experiment replication awards | 5 award | $20,000 | $100,000 | External reproduction or falsification |
| **Subtotal** | | | **$920,000** | |

### infrastructure — $745,000

| Line item | Quantity | Unit planning allowance | Extended cost | Purpose |
|---|---:|---:|---:|---|
| Rented GPU compute and experiments | 24 month | $13,000 | $312,000 | Flexible capacity where buying hardware is premature |
| Power, networking and hosting | 24 month | $7,000 | $168,000 | Running the test lab |
| CI artifact storage, provenance and secure observability | 24 month | $5,000 | $120,000 | Source/build/evidence retention |
| Research workshops and upstream collaboration | 24 month | $3,000 | $72,000 | Cross-project verification and dissemination |
| Compliance, publication, essential services | 1 lot | $73,000 | $73,000 | Grant and research operations |
| **Subtotal** | | | **$745,000** | |

### contingency — $510,000

| Line item | Quantity | Unit planning allowance | Extended cost | Purpose |
|---|---:|---:|---:|---|
| Controlled reserve | 1 lot | $510,000 | $510,000 | Disbursed only with transparent approvals |
| **Subtotal** | | | **$510,000** | |


## Staffing and pricing assumptions

The projected total covers **422 fully loaded researcher/engineer person-months**, equivalent to **17.6 average full-time positions over 24 months** if the complete program is funded, with hiring staged to actual awards. Monthly allowances are placeholders including benefits, contracting cost and overhead where relevant. No named institution, external reviewer or qualified researcher is represented as already engaged. Quotes, ranges and contractual costs must replace these allowances before binding commitments.

## First 90 days: minimum $250,000

- **$150,000 personnel:** compiler/systems capability audit, memory-safety threat model, safe subset definition, adversarial C corpus, and experiment design.
- **$35,000 hardware:** proposed purchase of **3 DGX Sparks at $5,000 each** ($15K), **1 AMD CPU/ROCm GPU workstation** ($10K), **1 Intel GPU workstation** ($7K), and first instrumentation ($3K). Every amount here is a planning allowance subject to real quotes. Existing personal Spark is excluded; all initial purchases count within the larger hardware budget.
- **$35,000 audits:** independent, paid security/semantics review without conflict of interest.
- **$15,000 infrastructure:** independent build runners, evidence receipts, secure storage.
- **$15,000 controlled reserve:** cannot be silently spent outside approved scope.

## Procurement decisions

The hardware allocation funds research **only when an associated test plan exists**. More Sparks allow replication and disruptive GPU reset tests. Discrete NVIDIA tests address memory-model assumptions that GB10 unified memory alone cannot answer. AMD and Intel are **new port targets requiring development**; buying the devices does not make the current GB10 CUDApp runtime compatible. Data-center-class units are ceilings **conditional** on confirmed software feasibility, quotations and expected use; rent or defer when sensible. Report dated SKU quotes, quantities, taxes, warranty, power and safety requirements before ordering.

## Independent accountability

Publish monthly allocation-vs-paid ledgers, hardware assets, audit scopes, source SHAs, failure logs and qualification receipts. Large hardware and personnel decisions require reviewer/fiscal approval under [governance](GOVERNANCE.md). The full research program is described in [RESEARCH-PLAN.md](RESEARCH-PLAN.md). Estimates will change as engineering evidence, procurement and reviewer availability improve; every such change must update this table and budget.json together.
