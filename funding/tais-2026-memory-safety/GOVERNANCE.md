# Grant controls, source evidence and financial reporting

This research program is an **unfunded proposal**. No Manifund grant or outside funding is claimed by these files. No external research institution, security firm, named auditor or supplier has agreed to participate.

## Stage-gated funding

- **M1 $250K cumulative:** scoped proof and security foundations, independent assessment and first hardware lab.
- **M2 $1M cumulative:** only after evidence for M1, add $750K for new C frontend and safe-profile verification.
- **M3 $4M cumulative:** only after M2 acceptance, add $3M for scaled team, cross-vendor CI and external validation.
- **M4 $10M cumulative:** only after M3 acceptance, add $6M for maintenance, proofs, research infrastructure and broader integration.

Actual releases follow donors' and grant administrators' contracts; GitHub commits never authorize external spending by themselves.

## Procurement and fiscal controls

Before purchasing: publish item rationale, measured research need, exact device SKU, **dated written quote**, supplier, warranty, power, shipping/tax, driver availability, alternatives including cloud rental, expected utilization and approved budget phase. Independent large-purchase approvals require at least two authorized humans once governance is constituted. Keep a private original invoice; publish safe accounting totals and equipment inventory IDs without exposing card, bank, address or security details.

Each month report **budget / approved / committed / invoiced / paid / refundable**, funding sources, equipment inventory, payroll burn, deliverables and risks. Preserve receipts; move dollar amounts out of the contingency category only with public variance notes and approval under grant terms. Plan lines remain **PROPOSED / not quoted** until updated.

## Research controls

- Independent adversarial review of AI-assisted code and any claimed formal theorem.
- Qualified compiler receipts state exact property and trusted computing base, unsupported external pointers, C UB boundaries, GPU firmware limits and residual timing/race/resource risks.
- Mutant and fault-injection controls must be detected. Publish all failed and NOT_RUN tests.
- Memory bugs relevant to active exploitation follow coordinated security disclosure; high-level funding reports remain public.
- Release hardware and model benchmarks with same-model/precision comparator, raw commands, driver revisions, timing/energy methods, CPU fallback counters and variance.

## Budget change procedure

[budget.json](budget.json) contains authoritative numeric allocations. [BUDGET.md](BUDGET.md) carries the same numbers with purpose and procurement context. A PR changing one must update the other and include tested sum checks: (1) line item quantities × rates sum to category totals; (2) each category total equals that category's sum across four tranches; (3) tranches total **$10M**, with cumulative 250K / 1M / 4M / 10M. Publish the reason for every revision and the impact on research gates and cash runway.

This public research and budget directory is stewarded in [aien-architecture-mv](https://github.com/aien-dev/aien-architecture-mv), which coordinates the multi-repository plan. It is not a substitute for an approved fiscal sponsor, donor agreement or nonprofit compliance review.
