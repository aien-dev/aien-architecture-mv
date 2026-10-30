# ADR 0045: Aienix retired; sovereign-intelligence is the center of AIEN

**Status:** Accepted (Drake, 2026-10-30; relayed by Aien).
**Supersedes in part:** [ADR 0038](0038-names-aienux-kernel-aienos-system.md) line 23 (the Means cell and the Today cell) and the ADR 0038 lines listed under Decision (c) that use AienOS for the whole system. The rest of ADR 0038 stands. The spelling cell on line 23, Exactly `AienOS`, stands. Aienux remains the kernel.
**Related:** ADR 0042 (ARCH-0042) and ADR 0044 (CUDApp owns GPU execution and the cubin writer). [sovereign-intelligence#31](https://github.com/aien-dev/sovereign-intelligence/issues/31).

---

## Context

Drake retired the repository role of aien-dev/aienix and named aien-dev/sovereign-intelligence the center. What that repository publishes about itself was read from its default-branch README at commit `907e0b0dd625f6bfd4c5516fea8858392dc41f91` (2026-10-30). This ADR does not invent a scope beyond that README and Drake's words below.

Sovereign (the owner of sovereign-intelligence) stated the product in one line. That original wording is the source, and it is not in the README:

> "Sovereign Intelligence: one command turns a DGX Spark into your own AI — Aien, Omega and science tools, with no NVIDIA user-space software. Alpha."

The one-liner used here hedges that wording for the alpha:

> "Sovereign Intelligence: one command turns a DGX Spark into your own AI, with Omega and science tools and no NVIDIA user-space software. Alpha; Aien comes in a later release."

The hedge is README line 41 at `907e0b0`: "The Aien experience is not in this release yet." ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L41)). The release that Install section names is `alpha-20261026.2` (lines 30 and 33). Line 41 does not itself contain the tag. It is also README line 59 at the same commit: "Today NVIDIA's open kernel module 580.173.02" ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L59)).

The README's own lines, quoted from that commit:

- Line 5: "My own AI, on hardware I own, with every layer open to read, rebuild and change." ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L5))
- Line 7: "Sovereign Intelligence, built on AienOS" with the link `aien-dev/AienOS-nv`. ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L7))
- Line 41: "installer EXERCISED (host 33/33 under read-only root, container 6/6 with a canary control)." The same line says a fresh GB10 install and first token through the installer, and the 3x physical qualification, are NOT_RUN, and "The Aien experience is not in this release yet." ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L41))
- Line 57: the CUDA++ row, "with no NVIDIA user-space software," attributed to CUDApp. Line 58: "SI alpha still runs on the Spark's own Linux." Line 59: the GPU kernel driver today is NVIDIA's open kernel module. ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L57-L59))
- Line 98: aienix is "Older front door that pins the main components as submodules." ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L98))
- Line 190: "This repo: the front door, the one-command installer and signed releases." ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L190))

Where those texts differ, the difference is recorded here and neither text is stretched to cover the other.

Sovereign's original one-liner names Aien in the command. The hedged line puts Aien in a later release, which is line 41. The hedged line's "no NVIDIA user-space software" is the phrase on the CUDA++ row (line 57, CUDApp). Line 59 keeps NVIDIA's kernel module. README line 7, "built on AienOS," matches Decision (c): AienOS is the operating-system layer inside Sovereign Intelligence. README line 190 is the repository's own description (front door, installer, signed releases). Decision (b) is that description plus Drake's answer of 6:53 AM CT: releases are assembled there, install starts there, and the Spark test runs there, while other repositories keep their own parts. README line 51 says "The installer is Omega you can read before you run it." ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/README.md#L51)). `installer/install.sh` says it is not written in Omega. This ADR follows the script and the bootstrap exception, not line 51.

## Decision

Drake, 2026-10-30 at 6:45 AM CT, relayed by Aien:

> "Aienix is supposed to be retired."
>
> "Sovereign intelligence is the new center"

Drake, 2026-10-30 at 6:53 AM CT, relayed by Aien:

> "Yes: sovereign-intelligence is where releases come together, install starts and the Spark test runs; the other repos keep their own parts"
>
> "AienOS is simply the operating system part of a bigger whole of Sovereign Intelligence (SI)"

(a) aien-dev/aienix is retired; it is no longer the core tree or the entry point.

(b) aien-dev/sovereign-intelligence is the center: the whole-system integration and release tree (release candidates are assembled and pinned there), the newcomer and install entry point, and where the signed whole-system Spark test runs on one frozen candidate.

(c) The whole system is called Sovereign Intelligence (SI), and AienOS names only the operating-system layer. This corrects ADR 0038 wherever it uses AienOS for the whole system.

Checked on `aien-architecture-mv` main `0dcaa29`. ADR 0038 line 23 is the AienOS table row, not a one-cell line. The Today cell is exactly "The core tree repository aien-dev/aienix." The Means cell on that same line is "The whole operating system: Aienux + Omega + runtime (sovereign core) + Aien." Both of those cells are superseded. The spelling cell, Exactly `AienOS`, is not.

Lines in `docs/adr/0038-names-aienux-kernel-aienos-system.md` that use AienOS for the whole system, or that tell a reader to read the old core-tree name as AienOS:

- Line 23, Means: "The whole operating system: Aienux + Omega + runtime (sovereign core) + Aien."
- Line 23, Today: "The core tree repository aien-dev/aienix."
- Line 27: "Write Aienux when the kernel is meant and AienOS when the whole system is meant."
- Line 34: read "Aienix" as "AienOS."
- Line 44: "aien-dev/aienix to aien-dev/aienos." The requested rename gives the core tree the OS name.
- Line 46: "reach the AienOS tree instead of the kernel."
- Line 50: "the front page, profile and website say AienOS."

ADR 0038's title ("AienOS is the operating system") and the Aienux row stand. So do the retirement of the word Aienix, the rule that history is not rewritten, the rule that code names stay until their own change, and the spelling `AienOS`. Line 4 uses the old spelling AIENOS for "the whole system in prose." Under (c) that whole system is Sovereign Intelligence, not AienOS. The index entry for ADR 0038 is marked superseded in part for line 23 and for this whole-system naming. The body of ADR 0038 is not edited. The same index-only mark is how ADR 0013 records "naming superseded by ADR 0014."

(d) The Non-claims section and the bootstrap exception below are part of this decision.

## Non-claims

sovereign-intelligence does not own any of the following.

- Runtime. Inference scheduling, paged KV, the aien CLI, serving, and Spark verification tooling stay in aien-sovereign-core-mv and are consumed by pin.
- GPU execution and cubin writing. Those belong to CUDApp under ARCH-0042 and ADR 0044.
- The language and the compiler. Those belong to omega-mv.
- ADRs and canonical facts. Those stay in aien-architecture-mv.

There is no GB10 performance claim and no qualification claim without a committed receipt. Alpha evidence on the README line cited above is host and container only: installer EXERCISED (host 33/33, container 6/6). A fresh GB10 install, first token through the installer, and the 3x physical qualification are NOT_RUN on that line.

## Bootstrap exception

`installer/install.sh` in sovereign-intelligence is a reviewed bootstrap exception, because a fresh Spark has no omc. [sovereign-intelligence#31](https://github.com/aien-dev/sovereign-intelligence/issues/31) records that exception: install.sh and build.sh stay as bootstrap scripts and are allowed shell entry points. The script header at the same commit says it is not an Omega program ([permalink](https://github.com/aien-dev/sovereign-intelligence/blob/907e0b0dd625f6bfd4c5516fea8858392dc41f91/installer/install.sh#L5-L6)):

> "This is the only part of AienOS that is not written in Omega. It is a host dependency, kept small on purpose"

Nothing in this ADR treats `installer/install.sh` as Omega. README line 51, which calls the installer Omega, is the difference noted in Context.

## Consequences

Follow-up PRs update the files below. This ADR does not edit them. It does not touch aien-dev/aienix.

Still naming aien-dev/aienix as the core tree or the entry point, in this repository:

- `README.md:7`: "Part of AienOS, the whole system and core tree of AIEN" (link `aien-dev/aienix`), and "AienOS is the front door for newcomers."
- `README.md:81`: "These six are the core of AienOS" (link `aien-dev/aienix`), and "the one AienOS tree."
- `docs/01-github-repository-map.md:10`: "AienOS, the whole-system tree and newcomer entry point."

Side-repository READMEs that name Aienix, or the aienix URL, as the core tree or the place to start. Read from each repository's default-branch README on 2026-10-30. `.github` and `edk2-non-osi` had no README at `main` or `master`. `aien-sovereign-core-mv` `README.md:32` mentions `aienix#4` and does not call that repository the center, so it is not listed.

- `aien-dev/agent-archive` `README.md:8`: "Supports Aienix, the core tree of AIEN."
- `aien-dev/aegis-runtime-mv` `README.md:7`: "an attachment of AienOS" (link `aien-dev/aienix`), "the core tree of AIEN."
- `aien-dev/aien-edge` `README.md:18`: "Supports Aienix, the core tree of AIEN."
- `aien-dev/aien-protocols-mv` `README.md:5`: "Part of AienOS" (link `aien-dev/aienix`), "the core tree of AIEN."
- `aien-dev/aien-receipts` `README.md:10`: "Supports Aienix, the core tree of AIEN."
- `aien-dev/aienos.com` `README.md:8`: "Part of Aienix, the core tree of AIEN."
- `aien-dev/atlas` `README.md:5`: "start at Aienix, the core tree of AIEN."
- `aien-dev/benchmarks-mv` `README.md:13`: "AienOS" (link `aien-dev/aienix`) "is the core tree of AIEN."
- `aien-dev/interplane-mv` `README.md:43`: "an attachment of AienOS" (link `aien-dev/aienix`), "the core tree of AIEN."
- `aien-dev/interplane.io` `README.md:6`: "Part of Aienix, the core tree of AIEN."
- `aien-dev/mobhub` `README.md:5`: "start at Aienix, the core tree of AIEN."
- `aien-dev/open-humanity` `README.md:5`: "An attachment of Aienix, the core tree of AIEN."
- `aien-dev/physics-mv` `README.md:5`: "Part of Aienix, the core tree of AIEN."
- `aien-dev/pi-register` `README.md:5`: "Supports AienOS" (link `aien-dev/aienix`), "the whole AIEN system."
- `aien-dev/readings-window` `README.md:5`: "Supports Aienix, the core tree of AIEN."
- `aien-dev/rpi5-uefi` `README.md:1`: "AIEN itself starts at Aienix, the core tree of AIEN."
- `aien-dev/spark-rsi-mv` `README.md:9`: "an attachment of AienOS" (link `aien-dev/aienix`), "the core tree of AIEN."
- `aien-dev/t3code` `README.md:1`: "AIEN itself starts at Aienix, the core tree of AIEN."

Docs in this repository that call AienOS the whole system, also left for a follow-up. Historical prose that still says AIENOS under ADR 0038 rule 2 is not in this list.

- `README.md:7` and `README.md:81`, quoted above.
- `README.md:9`: "AienOS is in alpha testing; the rest of the stack is research-grade and pre-alpha."
- `CONTEXT.md:10`: "The whole operating system: Aienux plus Omega plus the runtime (sovereign core) plus Aien."
- `CONTEXT.md:3`: "AienOS is becoming a native AI runtime architecture" and "It is not yet an operating system." That sentence does not say "whole system." It still names AienOS as the runtime architecture and denies that it is an operating system, which (c) corrects.
- `docs/01-github-repository-map.md:10`, quoted above.
- `docs/qualification/CANDIDATE.md:73`: "not the AienOS whole system."

## Source

- Drake Stapleton, 2026-10-30, 6:45 AM CT and 6:53 AM CT, relayed by Aien. The words are quoted in Decision.
- Sovereign, owner of sovereign-intelligence: the one-liner quoted in Context.
- aien-dev/sovereign-intelligence `907e0b0dd625f6bfd4c5516fea8858392dc41f91`, `README.md` and `installer/install.sh`, and issue 31.
- ADR 0038 as on aien-architecture-mv `0dcaa29`, line numbers above.
