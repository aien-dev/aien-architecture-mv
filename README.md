# AIEN Architecture

The authority for how the AIEN project fits together: whole-system architecture, milestone status and what to do next. It holds documents and a few small checking tools, not product code.

AIEN is a sovereign computing stack being built in the open on an NVIDIA DGX Spark (Grace Blackwell GB10): its own operating system (AIENOS), its own reaction runtime and compiler (Omega), and its own machine realization layer (FORGE). Founding principle: closest to the metal, fastest wins. Build what is missing.

## Current state

Research-grade and pre-alpha. The AIENOS C kernel passes its emulator (QEMU) gates but is not physically qualified; it has never been booted on the real machine (only an earlier first-boot test of the previous Rust kernel has run natively). The Omega runtime's R1 to R16 ladder was first qualified on builds that predate the composition modules now in the living build. Requalification at omega `3108fc2` recorded R15 FAIL (14 of 16 gates) and R16 FAIL (omega `evidence/REQUAL-3108fc2/`). The ladder was rerun on candidate CAND-3 (omega `f816473`): R16 gates G1 to G8 PASS, and R15 passed 16 of 16 gates as a conditional pass, because Secure Boot was off for that run ([CAND-3 results](qualification/candidates/CAND-3.gates.md), [exception 0002](qualification/exceptions/0002-r15-secure-boot-off.md)). CAND-3 as a whole is not claimed qualified, and CAND-4 and later candidates have no R15 or R16 rerun. The R15 and R16 rows in [doctrine/ROADMAP.md](doctrine/ROADMAP.md) still carry the earlier wording. ARGUS-0 (the defensive plane's event substrate) is complete under documented limits and ARGUS-1 containment is in progress ([ADR 0017](docs/adr/0017-argus-defensive-plane.md)). Several other programs (Physics Zero, DIRAC-0, the Evolution Arena) are specifications or plans with no qualified code. Nothing is described here as qualified unless a receipt says so. The live numbers are not repeated in this file because they change daily; read [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) and [doctrine/ROADMAP.md](doctrine/ROADMAP.md).

## Start here

Read in this order:

1. [Plan authority](PLAN_AUTHORITY.md): which document wins
2. [Current execution plan](CURRENT_EXECUTION_PLAN.md): the one active cross-project plan, with receipts
3. [Canonical architecture](doctrine/ARCHITECTURE.md): what the system is and who owns what
4. [Canonical milestone registry](doctrine/ROADMAP.md): milestone IDs and status
5. [Architecture decision records](docs/adr/README.md)
6. [Implementation status snapshot](docs/02-implementation-status.md) and [repository map](docs/01-github-repository-map.md)
7. [Golden path](docs/13-golden-path.md)

Superseded plans are kept only under [docs/archive/plans](docs/archive/plans/README.md). If two documents disagree, do not write another master plan: record the discrepancy and fix the authority. Code and reproducible evidence beat any plan.

## How the repositories fit together

```text
ATLAS AWAKENS.  ALLEN INTENDS.  AIEN PROPOSES.  OMEGA DEFINES.  FORGE REALIZES.
AEGIS VERIFIES.  HARDWARE ACTS.  EVIDENCE TEACHES.
```

| Repository | Role |
| :--- | :--- |
| [aienos](https://github.com/aien-spark/aienos) | The trusted operating system: its own kernel replacing Linux on the DGX Spark |
| [omega](https://github.com/aien-spark/omega) | The C reaction runtime and compiler that defines computation |
| [physics](https://github.com/aien-spark/physics) | FORGE machine realization, plus historical Atlas/PHYSICS boot evidence |
| [aien-protocols](https://github.com/aien-spark/aien-protocols) | Versioned wire and state specifications |
| [aien-sovereign-core](https://github.com/aien-spark/aien-sovereign-core) | Earlier Linux-hosted Rust runtime, legacy and being migrated |

Historical `PHYSICS_*` milestone names stay unchanged in old milestones and evidence.

## Standing rules

- Language rule: Rust is scaffolding, Omega is the destination, C only where hardware-justified ([ADR 0024](docs/adr/0024-rust-scaffolding-omega-destination.md), which supersedes the old [Rust-to-C plan](docs/plans/RUST_TO_C_MIGRATION.md)).
- No Python, no CUDA toolkit, no systemd, no outside dependencies in the trusted base, offline builds.
- Verdict words: PASS, FAIL, NOT_RUN, BLOCKED_HARDWARE, BLOCKED_OPERATOR, MISSING_IMPLEMENTATION. Emulator, host simulation and documents never count as hardware qualification.

## Specifications and plans (not qualified code)

The [Physics Zero Atlas](docs/plans/physics-zero/PHYSICS_ZERO_LAW_ATLAS_V1.md), [DIRAC-0](docs/adr/0023-dirac-0-program.md) and the [Evolution Arena spec V1](docs/specs/EVOLUTION_ARENA_SPEC_V1.md) are documents. Finite workstream plans under `docs/plans/` must be marked NOT A MASTER PLAN ([PLAN_AUTHORITY.md](PLAN_AUTHORITY.md)); most are, but the `physics-zero` and `adaptive-intelligence` folders do not carry the marker yet.

The [necessary-work programme](docs/plans/necessary-work/README.md) (2026-10-18, PROPOSED) asks which work is unnecessary before making the chip faster; its feasibility research is [docs/research/necessary-work-program-feasibility.md](docs/research/necessary-work-program-feasibility.md).

## Building

There is no product to build here. The one program is the crumb tool in `tools/crumb` (a C11 program that compiles and verifies the `.crumb` files); `make -C tools/crumb test` builds and tests it, and the shell scripts in `scripts/` have `test_*.sh` companions. On `main` (protected as of 2026-10-01) a CI check named `r16` verifies the R16 status wording against omega evidence and is the only check required on `main`; the `Crumb compiler` and `AIEN Verification` checks also run on pull requests.

## Contributing

Open a pull request against `main` with docs-only or doctrine changes, cite the receipt or code you are relying on, and state the external review you obtained. `main` is protected: no direct pushes. Questions and design ideas are welcome as issues.

## License

Licensed under the GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later). See [LICENSE](LICENSE). Contact: aien@aienos.com.
