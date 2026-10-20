# Implementation Status

**Snapshot date:** 2026-09-23. Cortex and Fabric rows updated 2026-10-01 (Lane 33).  
This is a review snapshot, not a permanent truth source.

**Read this first (2026-10-16, aien-spark/aien-architecture#198 D5).** Rows below were last checked between 2026-09-23 and 2026-10-01. Code moved after that (ALLEN demo, NEXT-PHASE-2, approval desk required by default, OSH, Aienux native GB10 bring-up, removal of Modular MAX and Mojo on 2026-10-15). For current state per acceptance step read `docs/plans/release-readiness/GAP_ASSESSMENT.md` (mains read 2026-10-10, every claim tied to a commit, PR or receipt); where it and this table differ, the gap assessment wins. Rows touched on 2026-10-16 say so.

**Cross-repo update, 2026-09-30.** The J-Space, Cortex and Capability Graph rows below were re-checked against `main` of `aien-spark/omega` (`6d1ff1d`), `aien-spark/aienos` (`f0facc7`), `aien-spark/physics` (`f63a6ef`) and `aien-sovereign-core` (`0df7c32`). The other rows keep their 2026-09-23 basis. "Host reference" below means C code that builds and runs on Linux inside a named test target and is not on the production runtime path. Which implementation owns each concept is recorded in `doctrine/ARCHITECTURE.md` §2.8.

Reviewed `aien-sovereign-core` `main` at `8d5f837` (merge of #98). That history includes #99 at `9cec202` (runtime change `7af0715`: CPU bf16 KV decode, a real child fork with shared KV page checks, Cortex record for an allowed mail effect), #100 (architecture roadmap), #101 (`aien-capability` and `aien-mcp`), and #102 (experimental PEARL harness). AEGIS `main` includes #32 at `6272261` (closed local-shell catalog, unadvertised unavailable tools, production secret resolution fails closed unless `AIEN_DEV_SECRET_FALLBACK` is set). RSI measured-canary promotion is `spark-rsi` #27.

Legend:

- ✅ implemented in meaningful code
- 🟡 partial / fragmented / not yet canonical
- ⬜ target architecture / not yet first-class

| Area | Status | Notes |
|---|---:|---|
| In-process runtime spine | ✅ | scheduler, transformer, KV, streaming, branching composed |
| Physical prefix sharing / COW | ✅ | branch tests exist, including shared-page verification after a real child fork (#99) |
| World drafts / staged effects | ✅ | core data structures exist |
| Cortex entities/claims/evidence | ✅ | durable schema exists in sovereign-core `crates/cortex-rs` (the live Linux LLM-stack Cortex). 2026-09-30: two more Cortex implementations exist and no authoritative owner is recorded: omega `src/runtime/rx_cortex.{c,h}` (host reference, append-only, one in-memory tier, L1/L2/L3 tiers not implemented, built at the re-check only in the state-projection test, since omega#114 also in `test-cortex`, evidence `evidence/STATE_PROJECTION`) and aienos `crates/aienos-cortex` (Rust epistemic store). See `doctrine/ARCHITECTURE.md` §2.8. Update 2026-09-30: omega `rx_cortex` now has an append-only journal with verified replay, a single writer, typed recall, and World execution recording via `rx_cortex_record` (`aien-spark/omega#114`, `43dcb04`; `test-cortex` in rx-host CI). The PR declares it canonical; the §2.8 owner record is unchanged until an accepted ADR or R16 gate result. 2026-10-01: ADR 0022 (`aien-spark/aien-architecture#75`, `6c06e50`) records omega `rx_cortex` as the canonical Cortex owner (`doctrine/ARCHITECTURE.md` §2.8); `cortex-rs` and `aienos-cortex` are non-authoritative. 2026-10-16: ADR 0036 (accepted 2026-10-10) names `aien-allen-memory` with an engaged ALLEN identity as the memory the v1 release tests (step E4); ADR 0022 is unchanged |
| Signed evaluation receipts | ✅ | protocol layer includes signers and Merkle roots |
| RSI canary/rollback | ✅ | implemented in RSI path; production quota counts measured observations only (#27) |
| AEGIS pre-dispatch checks | ✅ | present |
| Rust MCP servers | ✅ | debugger + harness proofs exist |
| Canonical MCP broker | 🟡 | `aien-mcp` and `aien-capability` are workspace crates (#101): in-memory wire, speculative lane, effect lane, sealed `AuthorizedEffect`. rmcp transport and a single live broker are not there yet. `spark-debugger` and `spark-harness` remain separate servers |
| Vault-first resolution | 🟡 | AEGIS fails closed unless `AIEN_DEV_SECRET_FALLBACK` is explicitly on (#32). That rule is not yet every resolver |
| Tool/Skill semantic split | 🟡 | `SkillRegistry` still owns atomic handlers such as `bash_eval` and `read_file`. `cortex_recall` and `telemetry_ping` stay callable, are not advertised, and return unavailable. Local shell is a closed catalog of whole command forms |
| Long-context production native model path | 🟡 | evolving; verify branch/commit before claiming. 2026-10-16: real model inference runs on the GB10 through the native Omega engine (no CUDA), ALLEN demo `RESULT-v4-gb10.md` 10/10 in aien-sovereign-core; long-context production is not claimed |
| Effect Broker | 🟡 | mail can check policy and record an allow in Cortex. There is still no single broker that every irreversible effect must pass through. 2026-10-16: the compose path requires the approval desk by default and refuses startup without a desk key (aien-sovereign-core#342); single-use grants with reserve, commit and release (`crates/aien-mcp/src/approval.rs`); grants live in memory only and a restart forgets them |
| Signed World commits | 🟡 | provenance primitives exist; World commit is not yet universal signed envelope |
| Portable accelerator ABI | 🟡 | multiple backends exist; core still contains hardware-specific history |
| Capability Graph | 🟡 | `ToolDescriptor`, `ToolEffects`, and `CapabilitySnapshot` exist in `aien-capability` / `aien-mcp` (#101). This is not yet the runtime graph of providers, machines, credentials, and policy. RSI's `CapabilityGraph` is a different type. 2026-09-30: the capability authority root is aienos `native/capability/aienos_capability.c` (C, built hosted as `libaienos_capability.a` and linked into omega test targets through `AIENOS_CAP_LIB`; it does not yet run inside a natively booted Aienux kernel). omega `src/runtime/rx_capq.{c,h}` is a capability query IR only (the build refuses admin symbols); omega `src/runtime/rx_caproot.c` is a host reference root that does not claim R7. aienos `crates/aienos-capability` is the legacy Rust twin, still a dependency of `crates/aienos-kernel`. The canonical runtime Capability Graph (CEP F1) is missing. Update 2026-09-30: a host-level F1 graph now exists (credentials/references not yet modelled): `rx_capq` promoted to the canonical Capability Graph (`aien-spark/omega#115`, `135d1c2`; stable keys, availability/withdraw, 188-byte wire record, machines keyed by `AienMachineId`), tested in `test-capability-graph` (rx-host CI), not in the R13 living-system build |
| Skill Router | 🟡 | 2026-09-30: omega `src/runtime/rx_skillroute.{c,h}` (`aien-spark/omega#115`, `135d1c2`) routes a requirement to a digest-pinned local skill or a remote provider record and binds one `AG_SKILL` action-graph node; tested in `test-capability-graph` (rx-host CI); not in the R13 living-system build; remote execution needs Fabric |
| AIEN Fabric | ⬜ | target. 2026-09-30: still absent; the Capability Graph has a FABRIC-sourced record type but nothing feeds it. 2026-10-01: Fabric F5-0 host-only loopback slice merged (`aien-spark/omega#123` `a18ec6b`, format v2 `#137` `1299b19`, living-World phase `#132` `ff2af05`, R13 silicon build `#135` `80da85c`); one process, HMAC stand-in signatures, simulated second machine, no network transport, not qualified. aienos ADR 0010 (Fabric identity) is still Proposed |
| Machine identity / placement | 🟡 | 2026-09-30: identity done at host level: omega `src/runtime/aien_machine_id.{c,h}` canonical `AienMachineId` (`aien-spark/omega#113`, `16f8518`), byte-identical to Aienux ADR 0014 `machine_id_digest`; `test-machine-identity` in rx-host CI. Placement: not implemented (J-Space `JsHome` is a placeholder) |
| J-Space | 🟡 | 2026-09-30: host reference only. omega `src/runtime/rx_jspace.{c,h}` (semantic identity as a SHA-256 chain, realizations carry placement and cost) is built at the re-check only into the `rx_branch_reuse` test target, since omega#116 also in `test-jspace-prod`, evidence `evidence/BRANCH_REUSE`; it is not in the R13 living-system build. aienos `crates/aienos-aegis/src/world.rs` has a separate Rust `JSpaceWorld` sandbox that omega does not link (legacy). sovereign-core `aien-capability` has only `JNodeId` / `WorldId` identifiers. Missing: J-Space on the production reaction path (EST-7 planned). Update 2026-09-30: production J-Space for local branches merged (`aien-spark/omega#116`, `529ebfa`; generation-checked ids, limits, durable checkpoints, staged branches; `test-jspace-prod` in rx-host CI). Remote operations return `JS_ERR_REMOTE` (no transport); World commit does not yet call `js_branch_seal`; still not in the R13 living-system build |
| Relational Path Engine | ⬜ | PEARL-inspired target. #102 adds an experimental harness only. The example fixture cannot produce a pass, and production recall is unchanged |
| Content-addressed model distribution | ⬜ | target |
| Adaptive graph/path exploration | ⬜ | target |
| Universal observability schema | ⬜ | target |

## Rule for updating this table

Every status change to ✅ should point to implementation evidence and at least one test or runtime artifact.
