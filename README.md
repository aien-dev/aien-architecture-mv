# AIEN Architecture

The authority for how the AIEN project fits together: whole-system architecture, milestone status and what to do next. It holds documents and a few small checking tools, not product code.

AIEN is a sovereign computing stack being built in the open on an NVIDIA DGX Spark (Grace Blackwell GB10): its own operating system (AIENOS), its own reaction runtime and compiler (Omega), and its own machine realization layer (FORGE). Founding principle: closest to the metal, fastest wins. Build what is missing.

Part of [Aienix](https://github.com/aien-dev/aienix), the core tree of AIEN. Aienix is the front door for newcomers; this repository is where the design decisions and the status of record are kept.

**Status 2026-10-18: research-grade, pre-alpha.** Nothing in AIEN is described as qualified unless a receipt says so. Details follow.

## Current state

Research-grade and pre-alpha. The AIENOS C kernel passes its emulator (QEMU) gates but is not physically qualified, and it has not been booted on the DGX Spark (only an earlier first-boot test of the previous Rust kernel ran there, on 2026-09-24). Its first runs on real hardware were on a Raspberry Pi 5 (2026-10-13), and an x86_64 build of it starts on a desktop test computer (2026-10-17); see the [aienos](https://github.com/aien-dev/aienos) README for what those runs did and did not show. The Omega runtime's R1 to R16 ladder was first qualified on builds that predate the composition modules now in the living build. Requalification at omega `3108fc2` recorded R15 FAIL (14 of 16 gates) and R16 FAIL (omega `evidence/REQUAL-3108fc2/`). The ladder was rerun on candidate CAND-3 (omega `f816473`): R16 gates G1 to G8 PASS, and R15 passed 16 of 16 gates as a conditional pass, because Secure Boot was off for that run ([CAND-3 results](qualification/candidates/CAND-3.gates.md), [exception 0002](qualification/exceptions/0002-r15-secure-boot-off.md)). CAND-3 as a whole is not claimed qualified, and CAND-4 and later candidates have no R15 or R16 rerun. The R15 and R16 rows in [doctrine/ROADMAP.md](doctrine/ROADMAP.md) still carry the earlier wording. ARGUS-0 (the defensive plane's event substrate) is complete under documented limits and ARGUS-1 containment is in progress ([ADR 0017](docs/adr/0017-argus-defensive-plane.md)). Several other programs (Physics Zero, DIRAC-0, the Evolution Arena) are specifications or plans with no qualified code. Nothing is described here as qualified unless a receipt says so. The live numbers are not repeated in this file because they change daily; read [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) and [doctrine/ROADMAP.md](doctrine/ROADMAP.md).

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
| [aienos](https://github.com/aien-dev/aienos) | The trusted operating system: its own kernel replacing Linux on the DGX Spark |
| [omega](https://github.com/aien-dev/omega) | The C reaction runtime and compiler that defines computation, and the native GB10 GPU engine |
| [physics](https://github.com/aien-dev/physics) | FORGE machine realization, plus historical Atlas/PHYSICS boot evidence |
| [aien-protocols](https://github.com/aien-dev/aien-protocols) | Versioned wire and state specifications |
| [aien-sovereign-core](https://github.com/aien-dev/aien-sovereign-core) | The Rust host runtime on Linux (the `aien` command line, inference ABI, KV cache, scheduler) and the verification pipeline that judges every repository; Rust here is scaffolding that Omega replaces piece by piece (ADR 0024) |
| aien-architecture (this repository) | Architecture, decision records, milestone status and the execution plan |

These six are the core of [Aienix](https://github.com/aien-dev/aienix). They still live in separate repositories and will move into the one Aienix tree one at a time; the research note on the layout is in [docs/research](docs/research/repo-topology-unix-vs-monorepo-vs-hybrid.md). Historical `PHYSICS_*` milestone names stay unchanged in old milestones and evidence.

## Standing rules

- Language rule: Rust is scaffolding, Omega is the destination, C only where hardware-justified ([ADR 0024](docs/adr/0024-rust-scaffolding-omega-destination.md), which supersedes the old [Rust-to-C plan](docs/plans/RUST_TO_C_MIGRATION.md)).
- No Python, no CUDA toolkit, no systemd, no outside dependencies in the trusted base, offline builds.
- Verdict words: PASS, FAIL, NOT_RUN, BLOCKED_HARDWARE, BLOCKED_OPERATOR, MISSING_IMPLEMENTATION. Emulator, host simulation and documents never count as hardware qualification.

## Specifications and plans (not qualified code)

The [Physics Zero Atlas](docs/plans/physics-zero/PHYSICS_ZERO_LAW_ATLAS_V1.md), [DIRAC-0](docs/adr/0023-dirac-0-program.md) and the [Evolution Arena spec V1](docs/specs/EVOLUTION_ARENA_SPEC_V1.md) are documents. Finite workstream plans under `docs/plans/` must be marked NOT A MASTER PLAN ([PLAN_AUTHORITY.md](PLAN_AUTHORITY.md)); most are, but the `physics-zero` and `adaptive-intelligence` folders do not carry the marker yet.

## Building

There is no product to build here. The one program is the crumb tool in `tools/crumb` (a C11 program that compiles and verifies the `.crumb` files); `make -C tools/crumb test` builds and tests it, and the shell scripts in `scripts/` have `test_*.sh` companions. Since 2026-10-16 the DGX Spark is the only test judge for pull requests ([ADR 0033](docs/adr/0033-aien-verification-pipeline.md)). It runs the gate manifests in `tests/gates/` (the crumb check, the crumb tool tests, the script tests, the doctrine check and the R16 status-wording check) and signs the result. `main` is protected and requires only the `AIEN Verification` check, which confirms the signed bundle on GitHub. The verdict of record is the commit status "AIEN Verification (Spark)". [docs/PIPELINE.md](docs/PIPELINE.md) explains the flow.

## Contributing

Open a pull request against `main` with docs-only or doctrine changes, cite the receipt or code you are relying on, and state any outside review you obtained. `main` is protected: no direct pushes. A pull request merges only after the Spark judge passes it and a maintainer adds the `ready-to-merge` label. Questions and design ideas are welcome as issues.

## License

Licensed under the GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later). See [LICENSE](LICENSE). Contact: aien@aienos.com.
