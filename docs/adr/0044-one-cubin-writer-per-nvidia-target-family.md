# ADR 0044: One cubin writer per NVIDIA target family, owned by CUDApp

**Status:** Accepted (Primate, 2026-10-30).
This ADR moves no code.
**Related:** ADR 0042 (ARCH-0042), ADR 0043 call 15 (open #343).
[CUDApp#108](https://github.com/aien-dev/CUDApp/issues/108) tracks consolidation.
[CUDApp#170](https://github.com/aien-dev/CUDApp/issues/170) rebases onto this layout.
[CUDApp#190](https://github.com/aien-dev/CUDApp/pull/190) is the inventory note.
[omega-mv#864](https://github.com/aien-dev/omega-mv/pull/864) holds `seed/sm80/cubin.om`.

---

## Context

Three cubin writers exist.

CUDApp `src/omega_cubin.c` (C) is today's sm_121 load path (ADR 0043 call 15). CUDApp
`om/cubin/cubin_elf.om` is an Omega body of the same sm_121 ABI 8 writer (CUDApp#190).
omega-mv `seed/sm80/cubin.om` exists only on closed draft omega-mv#864: it covers sm_80 to
sm_120, and its hardware load is NOT_RUN.

ADR 0042 (ARCH-0042) makes CUDApp the owner and leaves consolidation to Primate (its
Decision 7). ADR 0043 does not cover the sm_80 family.

## Options

- **A.** Keep all three.
- **B.** `cubin_elf.om` is canonical.
- **C.** `omega_cubin.c` is canonical.

## Decision

Option B. One cubin writer per NVIDIA target family, owned by CUDApp.

CUDApp owns all cubin writing, the sm_80 family included, under `backend/<target>/`. New
writer work goes only into `.om`. `omega_cubin.c` is frozen, and it is retired only after
the `.om` writer produces byte-identical sm_121 cubins and loads on GB10. That removal is
a later, separate PR.

omega-mv#864's ABI 8 and register-reserve findings are ported into CUDApp as new work. No
writer stays in omega-mv except a declared, pinned oracle (ADR 0042 Decision 4). CUDApp#170
rebases onto this layout.

## Consequences

CUDApp#108 tracks consolidation, and CUDApp#190's note becomes the inventory. Open items
become CUDApp issues: tkinfo on sm_121 ABI 8, which register count goes in the cubin
attributes, and the alu.s2 race. Hardware tiers stay NOT_RUN until an authorized window.
This ADR moves no code.

## Source

- ADR 0042, merged as #342.
- ADR 0043, open #343, call 15 (`ob_code_load`).
- CUDApp `src/omega_cubin.c` and `om/cubin/cubin_elf.om`.
- CUDApp#108, CUDApp#170, CUDApp#190.
- omega-mv#864, `seed/sm80/cubin.om` on `ck/cubin-om`.
