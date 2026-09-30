# Architecture Decision Records

Resolved architectural decisions are recorded here so implementation agents do not repeatedly reopen settled boundaries.

## Naming ADRs across repositories

`aien-architecture` and `aien-dev/aienos` number their ADRs independently, so the same number (for example 0012 or 0016) names two different decisions. In prose — docs, plans, issues, PRs, commit messages — cite an ADR with its repository prefix:

- `ARCH-00nn` — an ADR in this repository (`aien-architecture/docs/adr/`), e.g. ARCH-0016 is the resident reaction architecture.
- `OS-00nn` — an ADR in `aien-dev/aienos` (`docs/adr/`), e.g. OS-0012 is self-construction, capability growth and generations.

A bare "ADR 00nn" is acceptable only inside the repository that owns it. Files are not renamed: the prefix is a citation convention, and existing file names and historical references stay as they are.

Current ADRs:

- [0001 - Canonical composition root](0001-canonical-composition-root.md)
- [0002 - Hardware-neutral Machine identities](0002-hardware-neutral-machines.md)
- [0003 - Tools and Skills are distinct](0003-tools-vs-skills.md)
- [0004 - MCP is a compatibility layer](0004-mcp-compatibility-layer.md)
- [0005 - Irreversible effects require a broker](0005-effect-broker.md)
- [0006 - Production secrets are vault-only](0006-vault-only.md)
- [0007 - J-Space cannot externalize speculative effects](0007-jspace-effect-boundary.md)
- [0008 - Relational paths are first-class evidence objects](0008-relational-paths.md)
- [0009 - Names state implemented contracts](0009-names-state-implemented-contracts.md)
- [0010 - Canary observations are measurements](0010-canary-observations-are-measurements.md)
- [0011 - An inference context is model state](0011-inference-context-is-model-state.md)
- [0012 - One shell dispatch, then a landing split](0012-shell-dispatch-then-landing.md)
- [0013 - Machine Physics Lowering and AEGIS Invariant Verification Chain](0013-machine-physics-lowering-and-aegis-invariant-checker.md) — naming superseded by ADR 0014
- [0014 - Rename Machine Physics to FORGE](0014-rename-machine-physics-to-forge.md)
- [0015 - Resident Semantic Store Boundary, Object Identity, and Reconstruction Contract](0015-resident-semantic-store.md)
- [0016 - AIEN, Omega, and AEGIS are faculties of one resident reaction system](0016-resident-reaction-architecture.md)
- [0017 - ARGUS is the defensive plane; it observes, detects, and proposes, but never authorizes](0017-argus-defensive-plane.md) - Accepted by operator Drake Stapleton, 2026-09-29
- [0018 - Substrate-neutral physical realization](0018-substrate-neutral-physical-realization.md) - Accepted by operator Drake Stapleton, 2026-09-29
- [0019 - Mixed-algebra realization](0019-mixed-algebra-realization.md) - Accepted 2026-09-29
- [0020 - Belief / estimation layer](0020-belief-estimation-layer.md) - Accepted by operator Drake Stapleton, 2026-09-30
- [0021 - Four operating decisions of 2026-09-30: Physics pin, SSD block layout, admission receipts, R16 status](0021-four-operating-decisions-2026-09-30.md) - Recorded 2026-09-30 from the orchestrator brief
