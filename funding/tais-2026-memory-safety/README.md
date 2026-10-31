# AIEN / Omega technical AI safety research funding program

**Status: PROPOSAL — no funding awarded, no equipment ordered, no researchers retained.** Initial publication: October 27, 2026.

This is the public financial and technical plan for a **24-month, $10,000,000** research program investigating **memory safety in AI-generated systems code**, including Omega's checked AI-oriented language, Omega Bridge interoperability, and CUDApp GPU memory lifetimes.

**Minimum viable first phase:** $250,000 (90 days). Expansion through **$1M**, **$4M**, and **$10M cumulative** requires separate reviewed milestones. All unit costs are *illustrative planning allowances*, not vendor quotes or contractual commitments.

- [Itemized budget and phase arithmetic](BUDGET.md)
- [Machine-readable budget](budget.json)
- [Research workstreams, scope and milestone gates](RESEARCH-PLAN.md)
- [Funding controls, evidence and independent verification](GOVERNANCE.md)

## Honest technical baseline

[Omega](https://github.com/aien-dev/omega-mv) has a seeded compiler and AI-oriented language experiments. [Omega Bridge](https://github.com/aien-dev/omega-bridge) currently supports a **checked Omega → C/Python** subset and callable bindings, **not a general C → Omega importer**; that is proposed research. [CUDApp](https://github.com/aien-dev/CUDApp) has an experimental native NVIDIA **DGX Spark / GB10** GPU runtime, not cross-vendor parity, and still uses NVIDIA kernel modules and firmware. Memory safety for formally defined subsets is the research target; it cannot by itself prove model alignment, eliminate every memory leak, or make all programs infallible.

## Fundraising context

Designed for a proposed [Manifund Technical AI Safety](https://manifund.org/causes/tais?tab=grants) application and potential additional funders. Placement in this public repository does not signify approval, endorsement or committed funds from Manifund or others. The architecture repository owns whole-program planning; no new standalone repository was created.

## Transparency

Every stage must produce source revisions, test commands, compatible hardware/driver information, negative controls, numerical outcomes, independent review conclusions and a spending report. Failed and unrun tests remain visible. See [GOVERNANCE.md](GOVERNANCE.md).