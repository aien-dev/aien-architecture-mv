# AIEN Architecture

The authority for how the AIEN project fits together: whole-system architecture, milestone status and what to do next. It holds documents and a few small checking tools, not product code.

AIEN is a sovereign computing stack (one its owner builds, runs and controls end to end) being built in the open on an NVIDIA DGX Spark (Grace Blackwell GB10): its own operating system (AIENOS), its own reaction runtime and compiler (Omega), and its own machine realization layer (FORGE). Founding principle: closest to the metal, fastest wins. Build what is missing.

Part of [Aienix](https://github.com/aien-dev/aienix), the core tree of AIEN. Aienix is the front door for newcomers; this repository is where the design decisions and the status of record are kept.

**Status 2026-10-19: research-grade, pre-alpha.** Nothing in AIEN is described as qualified unless a receipt says so. Details follow.

## Current state

Research-grade and pre-alpha. The live numbers are not repeated in this file because they change daily; read [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) and [doctrine/ROADMAP.md](doctrine/ROADMAP.md). What follows is a summary, with the source for each point.

- **AIENOS kernel.** The C kernel passes its emulator (QEMU) gates but is not physically qualified, and it has not been booted on the DGX Spark. Only an earlier first-boot test of the previous Rust kernel ran there, on 2026-09-24 (see the [aienos README](https://github.com/aien-dev/aienos-mv#readme)). Its first runs on real hardware were on a Raspberry Pi 5 on 2026-10-13 (same README). An x86_64 build of it starts on a 2017 Intel iMac used as a test computer ([aienos-mv#405](https://github.com/aien-dev/aienos-mv/pull/405), merged 2026-10-17, and the follow-up pull requests #406 to #408). The aienos README does not yet describe the iMac runs.
- **Omega runtime, R1 to R16 ladder.** The ladder was first qualified on builds that predate the composition modules now in the living build. Requalification at omega `3108fc2` recorded R15 FAIL (14 of 16 gates) and R16 FAIL (omega [`evidence/REQUAL-3108fc2/`](https://github.com/aien-dev/omega-mv/tree/main/evidence/REQUAL-3108fc2)). The ladder was rerun on candidate CAND-3 (omega `f816473`): R16 gates G1 to G8 PASS, and R15 passed 16 of 16 gates as a conditional pass, because Secure Boot was off for that run ([CAND-3 results](qualification/candidates/CAND-3.gates.md), [exception 0002](qualification/exceptions/0002-r15-secure-boot-off.md)). CAND-3 as a whole is not claimed qualified, and CAND-4 has no R15 or R16 rerun ([CAND-4 results](qualification/candidates/CAND-4.gates.md)). The R15 and R16 rows in [doctrine/ROADMAP.md](doctrine/ROADMAP.md) still carry the earlier wording (they stop at CAND-0 and CAND-1).
- **ARGUS** (the defensive plane, which watches for attacks and proposes responses but never authorizes them). ARGUS-0, its event substrate, is complete under documented limits and ARGUS-1 containment is in progress ([ADR 0017](docs/adr/0017-argus-defensive-plane.md)).
- **Specifications only.** Physics Zero, DIRAC-0, the Evolution Arena and the necessary-work programme are documents or plans with no qualified code (see [Specifications and plans](#specifications-and-plans-not-qualified-code) below).

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

## What is in this repository

| Path | What it holds |
| :--- | :--- |
| `PLAN_AUTHORITY.md`, `CURRENT_EXECUTION_PLAN.md` | Which plan wins, and the one active plan |
| `doctrine/` | The canonical architecture and the milestone registry |
| `docs/adr/` | Architecture decision records (37 on `main`, listed in the [index](docs/adr/README.md)) |
| `docs/plans/` | Finite workstream plans (not master plans) |
| `docs/research/` | Research notes, for example the [repository layout note](docs/research/repo-topology-unix-vs-monorepo-vs-hybrid.md) and the [Hermes Agent note](docs/research/hermes-agent-prior-art.md) |
| `docs/archive/` | Superseded plans, kept for history only |
| `qualification/` | Release candidates (`candidates/CAND-*.toml` and their gate results) and recorded exceptions |
| `formal/invariants/` | Invariants written down for formal checking ([ADR 0027](docs/adr/0027-formal-oracle-lean-bootstrap.md)) |
| `tools/crumb/` | The crumb tool (C11), which compiles and checks the `.crumb` files |
| `tools/ops/` | The Spark's shared measurement base: build once, one measurement window at a time, per-window calibration and 27B baseline ([how to use it](docs/ops/MEASUREMENT_WINDOWS.md)) |
| `scripts/` | Small shell tools (doctrine check, candidate and pin checks, R16 status wording, the pull request gate, crumb rebase helper) and their `test_*.sh` tests |
| `tests/gates/` | The gate manifests the Spark runs on every pull request |

`AIEN_COMPLETE_SYSTEM_ARCHITECTURE.md` and `AIEN_MASTER_ARCHITECTURAL_PLAN.md` at the root are superseded pointers; the old versions are in `docs/archive/plans/`. The second one is stored in Git as a symbolic link whose target is the pointer text, so it does not open as a normal file; read [docs/archive/plans](docs/archive/plans/README.md) instead.

## How the repositories fit together

```text
ATLAS AWAKENS.  ALLEN INTENDS.  AIEN PROPOSES.  OMEGA DEFINES.  FORGE REALIZES.
AEGIS VERIFIES.  HARDWARE ACTS.  EVIDENCE TEACHES.
```

| Repository | Role |
| :--- | :--- |
| [aienos-mv](https://github.com/aien-dev/aienos-mv) | The trusted operating system: its own kernel replacing Linux on the DGX Spark |
| [omega-mv](https://github.com/aien-dev/omega-mv) | The C reaction runtime and compiler that defines computation, and the native GB10 GPU engine |
| [physics-mv](https://github.com/aien-dev/physics-mv) | FORGE machine realization, plus historical Atlas/PHYSICS boot evidence |
| [aien-protocols-mv](https://github.com/aien-dev/aien-protocols-mv) | Versioned wire and state specifications |
| [aien-sovereign-core-mv](https://github.com/aien-dev/aien-sovereign-core-mv) | The Rust host runtime on Linux (the `aien` command line, inference ABI, KV cache, scheduler) and the verification pipeline that judges every repository; Rust here is scaffolding that Omega replaces piece by piece (ADR 0024) |
| aien-architecture-mv (this repository) | Architecture, decision records, milestone status and the execution plan |

These six are the core of [Aienix](https://github.com/aien-dev/aienix). They still live in separate repositories and will move into the one Aienix tree one at a time; the research note on the layout is in [docs/research](docs/research/repo-topology-unix-vs-monorepo-vs-hybrid.md). Signed test results for all of them are published to [aien-receipts](https://github.com/aien-dev/aien-receipts). Historical `PHYSICS_*` milestone names stay unchanged in old milestones and evidence. Older documents link to `aien-spark/<name>` or `aien-dev/<name>`; those addresses are the same repositories under earlier names.

## Standing rules

- Language rule: Rust is scaffolding, Omega is the destination, C only where hardware-justified ([ADR 0024](docs/adr/0024-rust-scaffolding-omega-destination.md), which supersedes the old [Rust-to-C plan](docs/plans/RUST_TO_C_MIGRATION.md)).
- No Python, no CUDA toolkit, no systemd, no outside dependencies in the trusted base, offline builds.
- Verdict words: PASS, FAIL, NOT_RUN, BLOCKED_HARDWARE, BLOCKED_OPERATOR, MISSING_IMPLEMENTATION. Emulator, host simulation and documents never count as hardware qualification.

## Specifications and plans (not qualified code)

The [Physics Zero Atlas](docs/plans/physics-zero/PHYSICS_ZERO_LAW_ATLAS_V1.md), [DIRAC-0](docs/adr/0023-dirac-0-program.md) and the [Evolution Arena spec V1](docs/specs/EVOLUTION_ARENA_SPEC_V1.md) are documents. Finite workstream plans under `docs/plans/` must be marked NOT A MASTER PLAN ([PLAN_AUTHORITY.md](PLAN_AUTHORITY.md)); most are, but the `physics-zero` and `adaptive-intelligence` folders do not carry the marker yet.

The [necessary-work programme](docs/plans/necessary-work/README.md) (2026-10-18, PROPOSED) asks which work is unnecessary before making the chip faster; its feasibility research is [docs/research/necessary-work-program-feasibility.md](docs/research/necessary-work-program-feasibility.md). None of its experiments has run.

## Building and testing

There is no product to build here. The one program is the crumb tool in `tools/crumb`. It needs only a C11 compiler and `make`. Build it, run its tests, and check that every `.crumb` file matches what the tool produces now:

```sh
make -C tools/crumb test
./tools/crumb/crumb verify .
```

The Spark runs five gates on every pull request. Each manifest in `tests/gates/` calls `tests/gates/run.sh` with one step word, so you can run the same steps yourself (the script needs `bash`; plain `sh` stops at `set -o pipefail`):

```sh
bash tests/gates/run.sh crumb-verify          # gate CRUMB-VERIFY: the crumbs are current
bash tests/gates/run.sh crumb-tool-test       # gate ARCH-CRUMB-TOOL-TEST: the crumb tool tests
bash tests/gates/run.sh script-tests          # gate ARCH-SCRIPT-TESTS: tests of the four checked scripts
bash tests/gates/run.sh doctrine              # gate ARCH-DOCTRINE: doctrine consistency
bash tests/gates/run.sh qualification-status  # gate ARCH-QUALIFICATION-STATUS: R16 status wording
```

`qualification-status` reads omega evidence, so it needs an omega checkout beside this one at `../omega`.

## How a pull request is judged

Since 2026-10-16 the DGX Spark is the only test judge for pull requests ([ADR 0033](docs/adr/0033-aien-verification-pipeline.md)). On 2026-10-18 the hosted test workflows were removed (pull request #270); the one workflow left in `.github/workflows/` is `aien-verification.yml`. The Spark runs the five gates above and signs the result. `main` is protected and requires only the `AIEN Verification` check, which confirms that the signed bundle is in [aien-receipts](https://github.com/aien-dev/aien-receipts). The verdict of record is the commit status "AIEN Verification (Spark)". [docs/PIPELINE.md](docs/PIPELINE.md) explains the flow.

The crumb tool on `main` can now compute the generated part of each `.crumb` file on demand instead of storing it (RFC-0003 amendment 1, pull request #271, merged 2026-10-18; [docs/CRUMB_PROTOCOL_RFC_0003.md](docs/CRUMB_PROTOCOL_RFC_0003.md)). This repository switched on 2026-10-19 (pull request #272): its `.crumb` files no longer store that data, and `crumb verify .` computes it when it checks.

## Where the evidence lives

- Release candidates and their gate results: [qualification/candidates](qualification/candidates) and [qualification/exceptions](qualification/exceptions).
- Receipts for runs: in the repository that ran them, mostly omega [`evidence/`](https://github.com/aien-dev/omega-mv/tree/main/evidence), cited from [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) and [doctrine/ROADMAP.md](doctrine/ROADMAP.md).
- Signed pull request verdicts from the Spark: [aien-receipts](https://github.com/aien-dev/aien-receipts).

## Contributing

Open a pull request against `main` with docs-only or doctrine changes, cite the receipt or code you are relying on, and state any outside review you obtained. `main` is protected: no direct pushes. A pull request merges only after the Spark judge passes it and a maintainer adds the `ready-to-merge` label. Questions and design ideas are welcome as issues. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under the GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later). See [LICENSE](LICENSE) and [LICENSE-NOTICE.md](LICENSE-NOTICE.md). Contact: aien@aienos.com.
