# ADR 0042: Omega owns computation. CUDApp owns GPU execution. Omega Bridge owns compatibility.

**Status:** Accepted (Drake, 2026-10-30; merged as #342). Proposed 2026-10-26.
Records the boundary rule in an outside assessment of aien-dev/omega-bridge that Drake Stapleton
forwarded on 2026-10-27, endorsing it by forwarding. Recorded by BridgeBoundary.
**Related:** ADR 0024 (Omega is the destination language), ADR 0018 (substrate-neutral realization),
ADR 0039 (typed construction), ADR 0040 (identities). Does not change FORGE (ADR 0014).

---

## Context

Three repositories touch the path from an Omega program to a running GPU kernel, and before this ADR
no accepted decision said which one owns what:

- **aien-dev/omega-mv**: the Omega language, the seeded compiler `seed/out/omc`, semantics, IR.
- **aien-dev/CUDApp** (CUDA++): the GPU toolchain and runtime, split out of omega-mv on 2026-10-21.
- **aien-dev/omega-bridge**: `src/toc.om` emits C and Python from a checked, bounded `.om` subset;
  `src/native.om` generates bindings so C, C++, Python, Rust, Zig and Go call compiled Omega units;
  `src/gpu_adapter.om` negotiates and admits GPU artifacts and does not execute kernels.

The assessment Drake forwarded states the rule in three sentences: "Omega owns computation. CUDApp owns
GPU execution. Omega Bridge owns compatibility." It also says the bridge is an adoption mechanism: it
should make existing ecosystems optional, not constrain Omega to them. Its named next priority is a real
PyTorch or llama.cpp attachment with independently verified execution on the DGX Spark.

An audit of the three default branches on 2026-10-26 (omega-mv `e5b32567`, CUDApp `780a0af1`,
omega-bridge `358c5051`) found the rule already broken in places; see Consequences.

## Decision

1. **Omega owns computation** (omega-mv). The language, its semantics and identities, the seeded
   compiler and its seed chain, the compiler pin that every other repository consumes, the IR, the
   CPU code generators, and the declared contract of what a kernel computes (shapes, dtypes, the
   independent oracle it is judged against).
2. **CUDApp owns GPU execution.** Everything from GPU instruction words to a completed launch: the
   instruction encoders and their ISA tables, GPU code generators and kernel libraries, the register
   allocator and scheduling bits, the cubin/artifact writer and exporter, artifact admission (parsing
   and checking a cubin), the disassembler, the driver client (`nvrm`), command lists, submission,
   sessions and the GPU runtime, and GPU device qualification.
3. **Omega Bridge owns compatibility.** Every attachment between Omega and something that is not
   Omega: emitting C/Python from the bridge subset, native-call bindings for foreign callers, framework
   attachments (a PyTorch backend, a llama.cpp/GGML backend, MAX interop), foreign-format intake when
   it is built (PTX, fatbin, framework graphs), and GPU artifact negotiation through
   `gpu_adapter.om`. The bridge never encodes instructions, never launches a kernel and never ships a
   compiler; it consumes omega-mv's compiler and CUDApp's execution at pinned commits.
4. **Direction of dependency.** CUDApp and omega-bridge consume omega-mv at a pin. omega-mv consumes
   CUDApp at a pin for GPU execution. omega-bridge consumes CUDApp at a pin when an attachment must run
   on a GPU. No repository gains a new copy of another's owned code; a copy kept for a bootstrap or an
   oracle is declared as such, pinned and checked against the owner.
5. **Ecosystems are optional.** An attachment exists so an existing program can adopt Omega without
   rewriting, never as a requirement on Omega's own design. A bridge limit (an unsupported dtype, a
   framework's ABI) is not a reason to narrow the language or the GPU path.
6. **Out of scope.** physics-mv (FORGE) keeps realization policy and its historical receipts. Where it
   carries a GPU driver client, that copy is a duplication of a CUDApp responsibility (Consequences).
7. **Existing code stays; new components get connected repos** (Drake, 2026-10-27: "embrace the Unix
   philosophy and keep everything in their own repos. We can keep the repos we've got, but then we
   make new repos that are connected to the bigger repos."). The copies listed under Consequences are
   not moved, split or rewritten by this ADR; consolidating any of them needs a separate decision by
   Drake. Ownership governs where **new** work goes. A new standalone component (a server, kit, bench,
   library or app) goes in its own aien-dev repository that pins its parent (omega-mv, CUDApp or
   omega-bridge) by tag or sha, names the parent in its `.crumb`/`.goals.json`, and is linked from the
   parent README's "Connected repos" line. Each tool does one job: stdin or files in, plain text or
   JSONL on stdout, diagnostics on stderr, meaningful exit codes.

## Consequences

Under Decision 7 these copies stay where they are; the table fixes who owns new work on each, and
each issue is where any later consolidation decision would be recorded.

Duplicated responsibilities found by the 2026-10-26 audit, each with its single owner and an issue in
the owning repository:

| Responsibility | Copies | Owner | Issue |
|---|---|---|---|
| sm_121 encoder, codegen, QMD, submission, GPU session/runtime, kernel APIs (C) | omega-mv `src/omega_blackwell_*`, `src/omega_gpu_*`, `src/runtime/rx_resident_gpu.c`; CUDApp `src/` (58 identical, 39 diverged, 27 only in omega-mv; new work lands in omega-mv) | CUDApp | [CUDApp#106](https://github.com/aien-dev/CUDApp/issues/106) |
| GPU driver client (`nvrm/`, `m16/`) | CUDApp `nvrm/nvrm.c`; physics-mv `nvrm/nvrm.c` at omega-mv's `physics.lock` (newer: extra channels) | CUDApp | [CUDApp#107](https://github.com/aien-dev/CUDApp/issues/107) |
| Cubin writer | CUDApp `src/omega_cubin.c`; omega-mv `seed/sm80/cubin.om` (draft omega-mv#864) | CUDApp | [CUDApp#108](https://github.com/aien-dev/CUDApp/issues/108) |
| sm_121 disassembler | omega-mv `src/omega_sm121_disasm.c`, `tools/sm121dis/`; CUDApp D13 not built | CUDApp | [CUDApp#10](https://github.com/aien-dev/CUDApp/issues/10) (comment) |
| Seed bootstrap and compiler pin | omega-mv `seed/omega-from-seed.sh`; omega-bridge `tools/bootstrap.sh` (own recipe, older compiler); CUDApp takes its compiler from omega-bridge | omega-mv | [omega-mv#870](https://github.com/aien-dev/omega-mv/issues/870) |
| Omega front end (lexer, type tables) | omega-mv `seed/omc/omc.om`; omega-bridge `src/toc.om` | omega-mv | [omega-mv#871](https://github.com/aien-dev/omega-mv/issues/871) |

Checked and not duplicated: omega-bridge `gpu_adapter.om` admits by manifest fields and does not parse
cubins (CUDApp does); omega-bridge `tools/run-device-window.sh` runs CUDApp's `cubin_probe` rather than
a loader of its own.

- Repository READMEs state their own role and the other two (linked PRs).
- A proposal that would put a compiler, a launch path or an encoder in omega-bridge, or a language
  front end in CUDApp, needs an amendment to this ADR first. CUDApp#74 (an unmodified-CUDA path: PTX
  reader, fatbin reader, `cu*` entry points) is PROPOSED and splits along this rule: intake of foreign
  formats is compatibility, translation into instruction words uses CUDApp's code generator, and the
  launch is CUDApp's.
- Nothing here is implementation or qualification evidence. The issues above are open; the GPU tiers
  of each stay NOT_RUN until an authorized window.

## Source

- The forwarded assessment of aien-dev/omega-bridge (Drake Stapleton, 2026-10-27), held by the operator.
- Audit commands and per-file comparison: the issues linked above record their inputs and pins.
