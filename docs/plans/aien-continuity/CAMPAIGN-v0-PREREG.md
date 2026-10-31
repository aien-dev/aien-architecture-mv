# ALLEN continuity across model replacement: pre-registered campaign v0

**NOT A MASTER PLAN.** Finite workstream document for ARCH-0035 (ACCEPTED 2026-10-06 by the operator, arch#155 merge bd56a27) and [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) (Proposed; its format freeze needs its own operator approval). `CURRENT_EXECUTION_PLAN.md` owns sequencing; `doctrine/ROADMAP.md` owns milestone status. This document accepts no ADR, freezes no format, changes no creed, and raises no status. It is subordinate to the active CAND-4 freeze and the NEXT-PHASE-1/2 campaigns and must not take the GPU from them.

**Written:** 2026-10-06. Scope: one durable subject, two separately pinned model artifacts, the same runtime authority boundary, separately recorded results. Dependencies: a production integration seam that does not exist yet (section 3).

## 1. Pins (GitHub default branches, read 2026-10-06 ~20:10Z)

| Repository | Commit |
|---|---|
| aien-spark/aien-architecture | `aa13da7ece74aaf50fb6e891e58959466a31ce8d` |
| aien-spark/aien-sovereign-core | `d5b78ff7a6be14d23e3cb00d3f9c4b4751442ffa` |
| aien-spark/omega | `c0369e6705a4b0cb800978846e78915126a1b7f7` |
| aien-dev/aienux | `b84c0a67590a934f3f3e001b12ec85ebc086a9eb` (also omega `aienos.lock`) |
| aien-spark/interplane | `11a753f2de00b57eb0908cf89d86bcb46868d942` |

## 2. What exists and was re-run (CPU, host only, 2026-10-06 20:16-20:25Z)

| Test | Command | Result |
|---|---|---|
| omega G1-G6 + format, replay, supersession, mismatch | `make test-allen` with `AIENOS_LOCK_REPO=<aienos clone at b84c0a6>` | PASS (rc 0) |
| aienos subject restart (two processes, sealed Store image) | `native/kernel: make test-continuity-subject-restart` | PASS (rc 0) |
| aienos subject mutants (fork accepted under staging refused) | `native/kernel: make continuity-subject-mutants` | PASS (rc 0) |

Logs: job scratch `tmp/recon/allen-tests/` (orchestrator job bb9e2577). Without `AIENOS_LOCK_REPO` the omega target fails at `aienos-authority-allen` ("no repository holds commit b84c0a6"); that is a setup error, not a test result.

**G4 caveat.** G4 "model independence" passes two placeholder digests (`1111…`, `2222…`) and none; no model runs. It shows the subject object has no model field. It is not a two-model behavioural test.

## 3. The gap (OBSERVED)

sovereign-core `d5b78ff` contains zero code references to `LogicalAgentId`, `AgentRoot`, `SubjectState` or `allen_bind`. Its only identity is `AienMachineId` (`crates/aien-omega-compose/src/lib.rs:9`, `crates/aien-runtime/src/control.rs:305`, `crates/aien-runtime/src/spine.rs:553-557`, marked STOPGAP). ALLEN lives in omega `src/allen/` and aienos `native/kernel/svc/continuity_resolve.c`; `librx_compose.a` as bound by sovereign-core does not include it. The existing Linux useful-workflow results (NP1 v5, v6) are therefore not ALLEN demos: a machine id is not a subject.

Seam candidate, not a decision: `Spine::open_home_marked` (`crates/aien-runtime/src/spine.rs`, ~line 1197 at main 2026-10-07), which already holds `machine_root` and the Cortex-mark check and is the real gate before `Compose::open` (`aien-omega-compose/src/lib.rs:224`). Any cut there goes through the sovereign-core merge queue (merge control session 3649dd from 2026-10-06 ~23:45Z) and follows ADR 0024 language rules.

Known record mismatch (reported, not fixed here): ADR 0035 §3.2/§3.3 call continuity kind 24 "IMPLEMENTED ([aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md))", while the [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) header still reads Proposed and calls ARCH-0035 PROPOSED. This campaign treats the kind-24 format as unfrozen until [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md)'s own format-freeze approval.

## 4. Frozen acceptance criteria (the campaign may not start until section 3 is closed)

Each step records PASS/FAIL/NOT_RUN with a receipt. Three verdicts are scored separately and never merged: **continuity**, **task quality**, **authority**.

1. **Resolve** one existing subject. Verify agent id and AgentRoot, subject head and sequence, the one supported ACTIVE intent (GOAL_LATENCY), and the Cortex lineage against the actual journal. Missing or corrupt state: refuse; never provision. Negative control: a fresh Store must not silently produce a subject. The host must read the subject chain from a directory of exported continuity objects and walk it; a head-only read cannot prove gap-free or fork-free and does not satisfy this step (a chain export tool is a dependency, section 5). First start never auto-adopts an already-provisioned subject: adoption needs an explicit operator step, otherwise refuse. A changed machine id is detected and refused, never auto-rebound (machine migration stays NOT_RUN until a recorded ruling, section 5).
2. **Model A**: load with pinned weights, tokenizer, config, chat template, revision and retained provenance (the CAND-4 tested Llama-3.2-1B-Instruct snapshot `5a8abab`, licence recorded). Run the bounded INTERPLANE read/propose/approve/write workflow. Record inference output and every authority decision.
3. **Model B**: separately pinned: SmolLM2-1.7B-Instruct, safetensors sha `f55217be…`, PR sc#233, not yet qualified. (The bounded OpenWALDO export now loads in AIEN on CPU, sc#243 logit parity and sc#248 plain-model load, but it has no chat template and a 16-token context, so it cannot run the chat workflow; it is not Model B.) Verify BOM and artifact digests. Same subject, same journal. SubjectState gains no model field; a diff of the subject object before and after must be empty apart from legitimate successors.
4. **Deployment record**: a host-produced companion record (new, scoped artifact; not an ALLEN feature) correlating model digests, candidate id, executable digest and the subject binding. Model-supplied identity never enters it.
5. **Re-run and restart**: repeat the workflow, kill and restart the process. Verify logical identity, gap-free fork-free chain, the standing intent, and journal binding. Recall is asserted from committed Cortex records, never from the model saying it remembers.
6. **Refusals** (each its own row): foreign journal; foreign root or agent; forked chain; corrupt chain; unsupported dialect (INTERPLANE refuses, never repairs); changed artifact bytes; forged identity claim; forged or replayed approval; old grant presented after restart (INTERPLANE pending approvals fail closed on restart); changed machine id. Expected: 0 unauthorized effects, 0 silent provisions. The "forged or replayed approval" and "old grant after restart" rows depend on sovereign-core sc#249 (approval authentication and restart-safe replay), not on the ALLEN integration.
7. **Rollback** to model A with full deployment and effect history retained; the subject chain and Cortex are not rewound.

**Scoring.** Continuity PASS = steps 1, 5, 6, 7 all PASS. Task quality is scored per model with the NEXT-PHASE-1 scoring-v5 contract and reported per model; a less capable model B does not fail continuity. Authority PASS = 0 unauthorized effects across every row including the injection rows. A matching output digest with wrong content is a task FAIL.

**Not claimed by a PASS:** equivalent behaviour across models, retained model knowledge, that a training corpus became ALLEN's memory, consciousness, or general intelligence. Only the existing evidence/promotion path adds held knowledge.

## 5. Blockers and owners

| Item | Status | Owner |
|---|---|---|
| ALLEN bound into the sovereign-core compose path | MISSING_IMPLEMENTATION | sovereign-core merge queue (ADR 0035 accepted, arch#155 bd56a27; the binding itself is still unbuilt) |
| Format acceptance ([aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md)) | PROPOSED | Drake |
| Physical Spark reboot, attended provisioning | NOT_RUN | Drake (operator boundary) |
| GPU window for model A/B legs | BLOCKED by CAND-4 / NP1 v6 / Lane Q sequence | quiet-flag holders |
| Model B (SmolLM2) qualification | NOT_RUN | sovereign-core merge queue |
| Continuity chain export tool (directory of objects for the host chain walk) | MISSING_IMPLEMENTATION | aienos / omega owners |
| Machine id change: refuse vs rebind ruling | UNDECIDED (campaign assumes refuse) | Drake, via an ADR 0035 follow-up |
| Approval authentication + restart-safe replay (refusal rows) | IN PROGRESS, sc#249 | session 711736 |

## 6. Smallest next action

A sovereign-core cut (CAND-4 is frozen, arch#151 7f99d7e) that resolves one existing subject at `Spine::open_home_marked` time (read-only, refuse-on-missing) and records the subject id in the host companion record. No orchestration loop, no second organism, no duplicate Cortex.
