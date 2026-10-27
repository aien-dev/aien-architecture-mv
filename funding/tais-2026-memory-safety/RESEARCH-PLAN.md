# AIEN technical AI safety: memory-safe agent-generated code research

**Status:** proposed research, October 27, 2026. [Full budget](BUDGET.md). Scope: 24 months, first independently useful stage at $250K, optional expansion to $10M.

## Research question

Can an AI-writer-oriented Omega language, checked conversion from existing software, and carefully bounded GPU execution materially reduce **out-of-bounds access, stale-pointer use, double frees, memory disclosure, and unsafe lifetime transitions** in code generated and executed by AI agents? Can those reductions be *proven* for an explicitly defined subset and *independently reproduced* on physical hardware? Memory safety does not guarantee correct answers, alignment, authorization, constant-time behavior or zero memory leaks in arbitrary programs.

## Baseline as of publication

- **[Omega](https://github.com/aien-dev/omega-mv):** seeded .om compiler, bounded language features and experimental AI-oriented Omegese. General memory-safety and compiler-correctness proof not yet established; C migration remains unfinished.
- **[Omega Bridge](https://github.com/aien-dev/omega-bridge):** checked **Omega → C and Python** conversion in a restricted profile plus C/Python callable functions; **general C → Omega and Python → Omega input conversion not implemented**. The current bridge subset explicitly refuses heap/free, concurrency, GPU and external-call features. See [CAPABILITIES.md](https://github.com/aien-dev/omega-bridge/blob/main/docs/CAPABILITIES.md), [ABI.md](https://github.com/aien-dev/omega-bridge/blob/main/docs/ABI.md). Arbitrary C pointers crossing the ABI are not proven live or large enough.
- **[CUDApp](https://github.com/aien-dev/CUDApp):** independent user-space GB10 native GPU execution built around NVIDIA open kernel modules and signed firmware. Not a general CUDA replacement; other NVIDIA architectures, AMD and Intel are independent work.
- **[ggml-omega](https://github.com/aien-dev/ggml-omega):** adapter candidate for memory movement, correctness and tracing tests. GPU op test coverage does not establish full-model GPU residency.

## Research packages / code ownership

1. **omega-mv:** define safe profile, type and lifetime contract, checked array sizes, initialized memory, alias restrictions, traps, host/GPU buffer ownership and explicit refusals. Formalize narrow theorems with trusted computing base and assumptions; seek independently checked proof artifacts.
2. **omega-bridge:** design a *new restricted C input frontend*, with defined-behavior semantics, pointer alias/ownership inference, allocation and cleanup paths, checked C → Omega lowering and explicit refusal on unsupported C. Differential test original C vs translated results with mutation/negative controls. Separate **leak prevention** from memory-corruption safety, resource exhaustion and reachable-but-growing retention.
3. **CUDApp:** specify GPU mapping, buffer bounds, CPU and GPU virtual addresses, DMA visibility, pinning, asynchronous operation lifetimes, stale handles, failure/timeout/reset, OOM containment and command descriptors. Audit driver/firmware assumptions and fail closed on invalid requests.
4. **ggml-omega / omega-bridge attachments:** extend existing optional framework bridges, count **real GPU kernel launches**, CPU fallbacks, actual transfer bytes and faults; demand complete model correctness under pinned dependencies, not mere backend registration or dummy SUCCESS.
5. **cross-vendor lab:** validate new NVIDIA discrete, AMD ROCm and Intel target implementations separately. Compare memory safety and correct fault handling, synchronized accesses, address reuse, context isolation, driver upgrades and reset behaviors.
6. **agent safety and auditing:** least-privilege tool capabilities, sandboxing (VM-backed for hostile workloads where appropriate), evidence logs outside agent control, revoke/stop pathways and independent adversarial tests. No assertion that compiler checking alone stops unsafe agent choices.

## Funding and acceptance gates

| Cumulative tranche | Period | Work | Evidence required before expanding |
|---|---|---|---|
| **$250,000** | 0–90 days | Safe-subset threat model, capability inventory, reference test corpus, first independent audit, initial DGX+AMD+Intel lab procurement (subject to price quotes) | Public negative controls, command/host evidence and reviewer findings; unsupported cases explicitly labelled |
| **$1,000,000** | months 4–6 | Restricted C importer prototype, static memory conditions, defined-behavior differential suite, GPU handle/lifetime design | Unsafe C constructs refuse; valid translations pass differential tests; memory bugs are deliberately injected and detected |
| **$4,000,000** | months 7–12 | Independent proof review, hardware CI expansion, framework evidence, independent red team | Third-party reproduction and proof-scope review; clear device-by-device results and unresolved defects |
| **$10,000,000** | months 13–24 | Open-source verified-subset artifacts, stable cross-vendor evaluation suite, maintainers, upstream interfaces and long-term disclosure | Public reproducible evidence and independently reviewed guarantees for specified supported operations only |

If a gate fails, publish the failure and halt expansion pending remediation or a revised independently reviewed objective. Baseline claims must include code commit, hardware, OS/driver/firmware, test inputs, negative-control outputs, current pass/fail/NOT_RUN, independent reviewer, and any hardware/host assumptions. **No performance superiority claim** is accepted without matched baselines and numerical correctness constraints.

## Dissemination

Quarterly technical research reports; monthly spending and test dashboard; responsible vulnerability disclosure; accepted algorithms and adapters contributed upstream where technically suitable. Owners cannot self-certify their own AI-generated safety proof without independent checking.
