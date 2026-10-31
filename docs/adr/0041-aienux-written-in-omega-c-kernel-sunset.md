# ADR 0041: Aienux is written in Omega; the legacy C kernel is sunset

**Status:** ACCEPTED (2026-10-24) for the decision, decided by Drake Stapleton; the transition plan below is PROPOSED by the orchestrator (Claude Fable 5.1) for Drake's correction. Program ledger L802.
**Supersedes:** the C implementation of Aienux (aien-dev/aienos-mv `native/`) as the kernel of record.
**Related:** ADR 0038 (names); ADR 0024 (Rust/C/Omega course correction); ADR 0012 (self-construction); mind map note `2026-10-24-decision-aienos-kernel-is-omega-only-c-kernel-suns`; handoff `~/handoffs/2026-10-24-omega-kernel-only.md`; FR-9 x86-64 back end (lane L801).
**Evidence base:** recorded 2026-10-23 against `aien-dev/aienos-mv` `origin/main` f45d00ad (that repository was later renamed `aien-dev/aienux`; this count was not remeasured here): `native/` holds 405 C and assembly files, 5,049,354 bytes, of which `native/kernel/` is 271 files, 3,038,680 bytes, and 0 `.om` files. aien-dev/omega: aarch64 encoder and Blackwell codegen on main; the Omega-in-Omega compiler `omc` reaches a fixpoint (seed/omega-in-omega, 2026-10-22); no x86-64 back end yet (FR-9, funded 2026-10-24).

---

## Decision

Drake's words, 2026-10-24:

> "Omega. I wanted to be .om. Make it happen."
>
> "I want to sunset the legacy C kernel for AIENOS and go with only my kernel."

1. Aienux, the kernel, is written in Omega (`.om`). Omega is the only kernel language of record.
2. The C kernel in `native/` is legacy. It takes bug fixes and keeps the lab iMac booting while the Omega kernel is built; it takes no new features.
3. New probes, tools and experiments for the kernel and the hardware are written in Omega, not C or CUDA. C and CUDA remain comparison yardsticks only, kept outside the product tree.
4. The C kernel is retired (archive tag, out of the build) when the Omega kernel passes the full AienOS gate suite on QEMU and on the lab iMac.

This follows the 2026-10-23 decision that Allen is Omega only, and the rule of 2026-10-24: take the real path, no stand-ins because the job is big.

## Transition plan (PROPOSED)

1. Freeze: a `.crumb` note on `native/kernel` says FROZEN, bug fixes only, replaced under L802; the PR desk refuses new C-kernel feature PRs.
2. Compiler prerequisites, each with a red-then-green gate on the merge train: (a) freestanding output (flat binary or ELF, chosen entry, no runtime); (b) raw memory and device-register access; (c) privileged instructions, interrupt and exception entry as Omega intrinsics; (d) x86-64 back end (FR-9, L801) for the iMac; the existing aarch64 back end serves QEMU and the Spark.
3. Kernel in Omega, one subsystem per lane in dependency order, proven in QEMU first and then on the lab iMac: boot entry and console, memory and paging, interrupts and timer, keyboard (xHCI), disk (AHCI), Allen presence and window, network. The parity bar is the existing AienOS gate suite.
4. Retire as in point 4 above; update the repository READMEs and the organisation front page.

## Consequences

- Every kernel change from now on is Omega work; C kernel PRs that add features are closed with a pointer to this record.
- The compiler lanes (2a to 2d) are on the critical path of the Allen release; they are scheduled before any kernel subsystem lane that needs them.
- The C kernel stays readable as the reference for behaviour until the archive tag.

## What this does not decide

- The order of subsystem lanes beyond the dependency order above.
- Whether a C-to-Omega translation pass (seed/c2om) is used; it is used only where proven, hand-written otherwise.
