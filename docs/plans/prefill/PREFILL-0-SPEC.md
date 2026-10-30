# PREFILL-0 Specification (shared prefill qualification campaign)

**Status:** PROPOSED. Written 2026-10-01. Docs only. Nothing in this file has run on any tier (host, QEMU or GB10 hardware). Every gate below is **not claimed passed**.
**Authority:** operator material of 2026-10-01 (Drake Stapleton), recorded in the queen handoff `~/handoffs/2026-10-01-prefill-artifact-idea.md`. Pasted operator material is pre-approved. Where this text and that material differ, the material wins and the difference is a defect in this text. Cases, measurements and gates in sections 6 to 8 are copied from it without addition or loosening.
**Not a master plan and not a milestone.** `CURRENT_EXECUTION_PLAN.md` owns sequencing and `doctrine/ROADMAP.md` owns milestone status (`PLAN_AUTHORITY.md`, finite workstream plans under `docs/plans/`). PREFILL-0 is a finite qualification campaign for the existing aien-sovereign-core runtime. It changes no model architecture.
**Layout copied from:** `docs/plans/dirac/DIRAC-0-SPEC.md` (status / authority / not-a-master-plan header, snapshot line, numbered sections, gates, real gaps).

Snapshots used for every fact below: aien-sovereign-core `cfd9982` (`cfd99827ca5483c08d549ca32c7ee3d3bde6f2d8`, existence confirmed with `gh api repos/aien-dev/aien-sovereign-core/commits/cfd9982` on 2026-10-01), read-only by the PREFILL-SCOUT lane (`~/handoffs/2026-10-01-PREFILL-SCOUT-scout.md`); aien-architecture `origin/main` `fa46a26`. Outside references were fetched by the PREFILL-REFS lane (`~/handoffs/2026-10-01-PREFILL-REFS-scout.md`). All sovereign-core paths are relative to that repository and line numbers are for `cfd9982`.

---

## In plain words (read this first)

When an agent reads a long document, the model first has to "digest" the whole text once (this is called prefill) before it can start writing an answer. Many AIEN agents often read the same document. The idea here is simple: digest it once, check the digest is really finished, then let every agent start from that same finished digest and only digest what is new for it.

While checking today's code against that idea, the scout found a real bug: when AIEN launches a swarm of agents, it sets aside the memory for the digest, marks the digest as done, and hands it to every agent, but the model never actually digests the prompt. The agents start writing from an empty memory. In short: the space was reserved, the work was never done. A fix is being written on a separate branch. This campaign is the test plan that must prove the fix and then measure how much the shared digest saves.

---

## 1. Thesis

Context ingestion should produce a first-class reusable computational artifact. Read once. Verify once. Branch many. Recompute only the delta.

"Prefill once. Prove it ready. Fork the understanding. Compute only what changed."

## 2. Current behavior at sovereign-core `cfd9982`

Each claim below is from the PREFILL-SCOUT report, which read source with `git show cfd9982:<path>`. Nothing was built or run. Scout confidence in the overall verdict: 92% (residual: behavior not executed; Blackwell GPU path internals beyond `forward_decode_batch` not read).

### 2.1 What exists

| # | Claim | Status | Evidence (`cfd9982`) |
|---|---|---|---|
| C1 | Immutable context revisions; only the missing prefill span is computed | CONFIRMED in code, but not used in production | `ContextRevision` holds `Arc<Vec<ContextSegment>>`: `crates/aien-runtime/src/context.rs:55-61`; `append_memory` clones into a new revision: `context.rs:177-191`; `compute_missing_prefill` returns only `[cursor, total)`: `context.rs:200-218`. Only caller is a test: `crates/aien-runtime/tests/runtime_spine_integration.rs:43,53`. The spine owns a `ContextComposer` (`crates/aien-runtime/src/spine.rs:26,44`) but never calls it. |
| C2 | Scheduler separates prefill from decode, chunks prefill; Blackwell batch plan mixes rows | CONFIRMED | `SchedulerConfig` `prefill_chunk_size` / `chunk_prefill`: `crates/aien-scheduler/src/lib.rs:22-23,33-34`; running loop decode vs continuing chunk: `lib.rs:370-404`; admission chunking: `lib.rs:468-473, 511-524`; progress update: `lib.rs:600-613`; `SequencePhase`: `crates/aien-scheduler/src/sequence.rs:187-196`; `BlackwellBatchPlan` with D decode rows and P prefill rows: `crates/aien-inference-abi/src/blackwell_batch.rs:15-29, 43-80`. |
| C3 | KV manager: reference-counted zero-copy forks, copy-on-write tails | CONFIRMED | `fork_sequence` bumps `ref_count`, sets `is_shared`, copies the table: `crates/aien-kv-cache/src/lib.rs:963-985`; copy-on-write of a shared partial tail in `append_token_with_slot`: `lib.rs:1011-1031`; free decrements: `lib.rs:1179-1192`. |
| C4 | `prefix_cache` is dead code; docs describing radix-tree prefix dedup are ahead of code | CONFIRMED | `#[allow(dead_code)] prefix_cache: HashMap<Vec<u32>, BlockId>`: `crates/aien-kv-cache/src/lib.rs:688-689`; only initialized (`lib.rs:718,774,823`) and snapshot-copied (`lib.rs:653,1133`); no lookup or insert in `lib.rs`. Docs ahead of code: `docs/PROVENANCE.md:34`, `docs/AIEN_RUNTIME_ARCHITECTURE.md:23`, `docs/API_STABILITY.md:54`, `docs/STATE_OF_AIEN.md:26`, `crates/aien-kv-cache/Cargo.toml:6`, `crates/aien-kv-cache/src/lib.rs:2`. |

### 2.2 The defect: allocated != computed

| # | Claim | Status | Evidence (`cfd9982`) |
|---|---|---|---|
| D1 | `allocate_sequence()` allocates and zeros blocks and records the prompt token count; it does not compute K/V | CONFIRMED | `crates/aien-kv-cache/src/lib.rs:920-961`; `allocate_block` zeros via `pool.zero_block`: `lib.rs:904-917`; sets `num_tokens` per block and `table.total_tokens` = prompt length: `lib.rs:946,956`. No model call. |
| D2 | A sequence with a block table is treated as prefilled and enters decode without prefill | CONFIRMED | `crates/aien-scheduler/src/lib.rs:475-492`: if `get_block_table(id)` exists at admission, sets `is_prefilled = true`, phase `Decode`, `prompt_tokens_prefilled = prompt_len`, pushes to `decode_requests`. The comment at `lib.rs:475-476` says this is intentional ("Pre-forked branches ... enter decode directly without redundant prefill"). No check that K/V was computed. |
| D3 | The swarm forks before any model prefill | CONFIRMED | `SwarmManager::launch_swarm`, `crates/aien-runtime/src/swarm.rs:86-114`: arena allocates root (`:86`), `kv.allocate_sequence(root)` (`:95`), `prefill_cursor` = prompt length and state `Prefill` (`:97-100`), then forks N children: `arena.fork` (`:107`) and `kv.fork_sequence` (`:111`). No model call. Runtime `arena.fork` hard-codes child `state: Decode` and copies `prefill_cursor`: `crates/aien-runtime/src/sequence.rs:159-171`. |
| D4 | The root is never prefilled and children decode from an empty state | CONFIRMED by reading | `AienRuntimeSpine::launch_swarm` (`crates/aien-runtime/src/spine.rs:183-218`) submits only the children (`spine.rs:199-214`), never the root. The admission rule (D2) sends children straight to decode. `NativeTransformerBackend::forward_decode_batch` (`crates/aien-inference-abi/src/transformer_backend.rs:919`) creates an empty per-sequence state for an unknown request, `pos = 0`, `last_token = 1` (`transformer_backend.rs:939-948`), and reserves an append slot in the shared KV (`:978-986`), which triggers copy-on-write of a never-written zeroed tail. |

**Reachability.** Public path: CLI swarm command tokenizes `--prompt` (`crates/aien-cli/src/commands.rs:1410`) and calls `client.launch_swarm` (`commands.rs:1429`, `crates/aien-runtime/src/client.rs:100`) over the runtime socket; the daemon (`commands.rs:1143-1188`) builds the spine with `NativeTransformerBackend` (`commands.rs:1102-1140`); the server dispatches to `spine.handle_control_command` (`crates/aien-runtime/src/server.rs:356`), then `ControlCommand::LaunchSwarm` (`spine.rs:233-242`).

**No guard found.** The scout checked `is_prefilled` / `prompt_tokens_prefilled` (`crates/aien-scheduler/src/sequence.rs:211-212`, set unconditionally at `lib.rs:485-487`), runtime `prefill_cursor` / `SequenceState::Prefill` (set, never read by the scheduler), `compute_missing_prefill` (test-only), and the KV `BlockTable` / `KvBlock` (`crates/aien-kv-cache/src/lib.rs:600-613`: no "computed" flag).

**Why tests did not catch it.** Every swarm test uses `MockInferenceBackend`, which ignores prompt content (`crates/aien-inference-abi/src/lib.rs:264-300`). No runtime test asserts that a swarm branch processed any prefill tokens.

**Fix in flight.** A fix is being written on aien-sovereign-core PR #145 (branch hive/PREFILL-GATE-prefill, commit d6455da; host tests queued, NOT_RUN until forge receipt). This spec does not describe the fix; it states the gates the fix must pass (G1, G2). Open follow-up: the transformer backend still starts each branch from an empty internal state (transformer_backend.rs:939-948 at cfd9982), so branches do not yet consume the shared root prefill; #145 closes the scheduling gate only (source: ~/handoffs/2026-10-01-PREFILL-GATE-builder.md, line 40).

### 2.3 Related open questions (not part of the defect claim)

- Does the Blackwell (`new_blackwell`) path use the same `forward_decode_batch`? UNVERIFIED, confidence 80% yes.
- Scheduler `insert_with_id` (`crates/aien-scheduler/src/sequence.rs:425-470`) overwrites an occupied slot without checking; runtime and scheduler share the u64 id space. Separate defect candidate, UNVERIFIED in practice, confidence 70%.
- Forking a parent that is mid-prefill: scheduler forks inherit parent `is_prefilled` (`crates/aien-scheduler/src/sequence.rs:555-556`, via `lib.rs:226-284`). Behavior UNVERIFIED, confidence 60%.
- The CLI tokenizes swarm prompts as raw bytes (`crates/aien-cli/src/commands.rs:1410`), not with the model tokenizer. Recorded fact; affects the meaning of `tokenizer_digest` in section 4.

## 3. Proposed abstraction (proposal, not implemented)

```
ContextRevision -> model prefill -> PrefillArtifact -> verified READY
  -> freeze shared prefix -> fork 1/8/64/500 -> branch-local delta + decode
```

The runtime stays model-agnostic. Shared prefill is a runtime capability; existing ABI-visible types are preserved (section 9.3).

## 4. PrefillArtifact binding fields (proposal)

A PrefillArtifact is bound to every field below. Two artifacts may be shared or reused for one another only if all binding fields match.

| Field | Meaning |
|---|---|
| `context_revision_digest` | digest of the immutable `ContextRevision` whose tokens were prefilled |
| `model_digest` | digest of the model weights that computed the K/V |
| `tokenizer_digest` | digest of the tokenizer that produced the token ids (see section 2.3, raw-byte CLI tokenization) |
| attention / KV layout | the KV layout the cache was written in |
| position / RoPE config | position encoding configuration used during prefill |
| prefix length | number of tokens whose K/V is computed |
| physical KV / latent handles | the physical blocks (or latent handles) holding the computed K/V |
| generation | generation counter of the artifact, so a stale handle is refused |
| completion fence | the fence that proves the prefill compute finished |
| verification state | the state machine position in section 5 |

Field encodings, byte layout and where the record lives are not fixed here. Candidate homes named by the scout: `aien_kv_cache::BlockTable` (`crates/aien-kv-cache/src/lib.rs:608-613`) or `aien_scheduler::sequence::SequenceRecord` (`crates/aien-scheduler/src/sequence.rs:200-215`).

## 5. State machine (proposal)

```
Allocated -> PrefillPending -> PrefillReady -> SharedFrozen -> Reclaimed
```

| State | Meaning |
|---|---|
| Allocated | blocks exist; no K/V is claimed computed |
| PrefillPending | model prefill submitted, completion fence not yet signalled |
| PrefillReady | completion fence signalled and verification state set; K/V for `prefix length` tokens is computed |
| SharedFrozen | prefix is read-only and may be forked; branch writes go to copy-on-write tails |
| Reclaimed | all references released; physical KV returned |

Rule: branches are forbidden from using a cache before PrefillReady.

## 6. Cases

Copied from the operator material without change:

1. Cold prefill.
2. Exact-prefix reuse.
3. Append-only context revisions.
4. Cortex-memory append.
5. Tool-result append.
6. Fanouts 1 / 8 / 32 / 128 / 500 over 32K, 128K, and the backend's true max context.

The backend's true max context is not stated in this file. It must be read from the backend at run time and recorded in the receipt.

## 7. Measurements

Copied from the operator material without change:

- TTFT (time to first token)
- prefill tok/s
- bytes moved
- physical KV bytes
- GPU package energy
- cache-hit fraction
- fanout amortization
- exact/logit parity

## 8. Gates (verbatim)

| Gate | Text (verbatim) |
|---|---|
| G1 | no decode from Allocated |
| G2 | only PrefillReady may be shared |
| G3 | warm identical prefix = zero redundant model prefill |
| G4 | appended revision computes only its suffix |
| G5 | 500 forks do not multiply common-prefix storage by 500 |
| G6 | shared vs independently-prefilled agree within the measured numerical noise floor |
| G7 | full swarm reclamation returns physical KV to baseline |

G1 and G2 are the immediate correctness gates for the section 2.2 defect. G6 requires the noise floor to be measured, not assumed, and the measured value to be recorded in the receipt.

## 9. Results

### 9.1 Results table

Every leg is NOT_RUN. Hardware legs (GB10 chip runs, energy, TTFT, throughput) stay NOT_RUN until a GB10 receipt exists. Host legs stay NOT_RUN until a forge receipt exists. QEMU: N/A (runtime campaign, no guest boot).

| Gate / measurement | Host (CPU reference backend) | GB10 hardware |
|---|---|---|
| G1 no decode from Allocated | NOT_RUN | NOT_RUN |
| G2 only PrefillReady may be shared | NOT_RUN | NOT_RUN |
| G3 warm identical prefix = zero redundant prefill | NOT_RUN | NOT_RUN |
| G4 appended revision computes only its suffix | NOT_RUN | NOT_RUN |
| G5 500 forks do not multiply prefix storage by 500 | NOT_RUN | NOT_RUN |
| G6 shared vs independent parity within noise floor | NOT_RUN | NOT_RUN |
| G7 full reclamation returns physical KV to baseline | NOT_RUN | NOT_RUN |
| TTFT | NOT_RUN | NOT_RUN |
| prefill tok/s | NOT_RUN | NOT_RUN |
| bytes moved | NOT_RUN | NOT_RUN |
| physical KV bytes | NOT_RUN | NOT_RUN |
| GPU package energy | N/A (no GPU) | NOT_RUN |
| cache-hit fraction | NOT_RUN | NOT_RUN |
| fanout amortization (1/8/32/128/500) | NOT_RUN | NOT_RUN |
| exact/logit parity | NOT_RUN | NOT_RUN |

### 9.2 Receipt shape

A result cell may change from NOT_RUN only with a receipt that names: sovereign-core commit, backend (CPU reference or Blackwell), model digest, tokenizer digest, context length, fanout, the backend's reported max context, the measured noise floor (G6), and the raw measurement files. Failing receipts are kept.

### 9.3 ABI note

ABI-visible types named by the scout: `#[repr(C, align(64))] SequenceRecord` (`crates/aien-runtime/src/sequence.rs:47`), `#[repr(C)] KvLayoutDesc` (`crates/aien-kv-cache/src/lib.rs:126`), `#[repr(C)] BlackwellBatchPlanC` (`crates/aien-inference-abi/src/blackwell_batch_executor.rs:79-96`); serde wire types `LaunchSwarmReq`, `ControlCommand`, `RuntimeStatusReport` (`crates/aien-runtime/src/control.rs:8,49,74`), `ScheduledBatch` / `SequenceRequest` (`crates/aien-inference-abi/src/lib.rs:187,196`). The scout's reading is that a readiness field need not touch `BlackwellBatchPlanC`. Any change to the others is called out in the fix PR.

## 10. Prerequisites

1. The section 2.2 fix (aien-sovereign-core PR #145 (branch hive/PREFILL-GATE-prefill, commit d6455da; host tests queued, NOT_RUN until forge receipt)) merged with a test that fails on `cfd9982` and passes after (G1, G2 on host).
2. A swarm test that runs a real backend (CPU reference `NativeTransformerBackend`), since mock-backend tests cannot detect the defect (section 2.2).
3. A forge receipt for every host leg before any host cell leaves NOT_RUN.
4. A GB10 chip-run slot under the shared test queue for hardware legs; GPU package energy measurement path available. Chip runs are never killed or timed out.
5. The backend's true max context read and recorded (section 6).
6. For G3 and G4: a live prefix lookup (today `prefix_cache` is dead code, C4) and a production caller of `compute_missing_prefill` (today test-only, C1).

## 11. Outside references

Only VERIFIED items are quoted. Fetched by the PREFILL-REFS lane on 2026-10-01.

- **YOCO (VERIFIED).** Sun et al., "You Only Cache Once: Decoder-Decoder Architectures for Language Models", arXiv 2405.05254, NeurIPS 2024. "It consists of two components, i.e., a cross-decoder stacked upon a self-decoder." ... "YOCO only caches once." https://arxiv.org/abs/2405.05254
- **DeepSeek pricing (VERIFIED, page wording paraphrased by the fetch tool; recheck exact text before quoting further).** https://api-docs.deepseek.com/quick_start/pricing, per 1M tokens, deepseek-flash (DeepSeek-V4.1-Flash): cache hit $0.003 off-peak / $0.006 peak; cache miss $0.15 off-peak / $0.3 peak.
- **Xiaomi MiMo-V2.5 hybrid sliding-window attention (VERIFIED).** Model card: "interleaving Sliding Window Attention (SWA) and Global Attention (GA) with a 5:1 ratio and 128 sliding window." https://huggingface.co/XiaomiMiMo/MiMo-V2.5
- DeepSeek V4.1-Flash Causal Encoder-Decoder (CED), about 8B active parameters for prefill vs 16B for decode, as a DeepSeek paper: UNVERIFIED, confidence 60%. Only a third-party source was found (Baseten blog, https://www.baseten.co/blog/deepseek-v41-flash-more-efficient-prefill-for-coding-agents/); the primary paper was not fetched.
- MiMo-V2.5 prefill throughput falloff near 1M cached prefix: UNVERIFIED, confidence 25% (not found in model card or search).

### 11.1 Pass 2 reference check (fetched 2026-10-01)

Numbers are quoted only where found in the fetched source. The pass 2 handoff (`~/handoffs/2026-10-01-prefill-program-pass2.md`) named all of these as unverified; where the source differs from the handoff, the source wins and the difference is stated.

| Reference | Status | What the source says | URL |
|---|---|---|---|
| Lost in the Middle (Liu et al.) | VERIFIED | "performance is often highest when relevant information occurs at the beginning or end of the input context, and significantly degrades when models must access relevant information in the middle of long contexts." | https://arxiv.org/abs/2307.03172 |
| RULER | VERIFIED | "almost all models exhibit large performance drops as the context length increases"; 17 models tested, 13 tasks; only about half kept acceptable performance at 32K (fetch-tool paraphrase). | https://arxiv.org/abs/2404.06654 |
| NoLiMa | VERIFIED, differs from handoff | "At 32K, for instance, 11 models drop below 50% of their strong short-length baselines." 13 models evaluated. The handoff's "10/12" is not what the abstract says. | https://arxiv.org/abs/2502.05167 |
| CacheBlend | VERIFIED | "2.2-3.3x" TTFT reduction and "2.8-5x" throughput versus full KV recompute. | https://arxiv.org/abs/2405.16444 |
| EPIC | VERIFIED | "up to 8x improvements in Time-To-First-Token (TTFT)"; also "7x throughput gains" with negligible or no accuracy loss. | https://arxiv.org/abs/2410.15332 |
| Prompt Cache | VERIFIED, differs from handoff | Latency reductions "8x for GPU-based inference to 60x for CPU-based inference". The handoff's "~8x" is the GPU figure only. | https://arxiv.org/abs/2311.04934 |
| Tessera | UNVERIFIED (confidence 15%) | A search for the name and the 3.6x TTFT claim found no paper called Tessera. Not found, so no number is quoted. | none found |
| LMCache | VERIFIED | "up to 15x improvement in throughput" with vLLM on multi-round QA and document analysis (search result text); supports offloading and prefill/decode disaggregation. | https://arxiv.org/abs/2510.09665 |
| DistServe | VERIFIED | Separates prefill and decoding onto different GPUs; "serve 7.4x more requests or 12.6x tighter SLO" (fetch-tool wording); OSDI 2024. | https://arxiv.org/abs/2401.09670 |
| NVIDIA Dynamo | VERIFIED (description only) | README describes "The open-source, datacenter-scale inference stack"; orchestration layer for disaggregated prefill/decode. No performance number quoted. | https://github.com/ai-dynamo/dynamo |
| Hydragen ("up to 32x" claim), MiMo cache-aware routing numbers | UNVERIFIED (confidence 50%) | Not fetched in this pass. | none |
| GB10 / DGX Spark memory | VERIFIED | "128 GB LPDDR5x unified system memory, 256-bit interface, 4266 MHz" and "273 GB/s bandwidth". | https://docs.nvidia.com/dgx/dgx-spark/hardware.html |

## 12. PARKED

- Model-level YOCO / Causal Encoder-Decoder architecture lane: parked until an AIEN-native model is trained; runtime stays model-agnostic, ABI preserved.
- Mamba, Titans, Native Sparse Attention, and KV pruning/quantization (KIVI, SnapKV, H2O, Quest): parked to the AIEN-native model lane / later. KV pruning and quantization attack decode memory, not read-once prefill (pass 2 source). Not runtime patches.
- Turing connection: shared prefill lowers the physical cost of acquiring context; it does not raise Turing gain; same gain at lower energy = better Turing yield (higher T/J); keep quantities separate.


## 13. Program roadmap (pass 2, operator material of 2026-10-01)

Source: `~/handoffs/2026-10-01-prefill-program-pass2.md`. Seven steps, each a separate cut, in this order unless independent. This list does not change the gates in section 8. It is a roadmap, not a milestone; `CURRENT_EXECUTION_PLAN.md` owns sequencing.

1. **PREFILL-CORRECTNESS.** First-class PrefillArtifact. Allocated is not Ready. The scheduler must require state PREFILL_READY, a completed fence, a model digest equal to the active model, and a context digest equal to the requested one. This is aien-sovereign-core PR #145, in flight (section 2.2).
2. **EXACT PREFIX REUSE.** A context revision digest maps to a reusable artifact. An appended revision computes only the new suffix (gates G3, G4).
3. **BRANCH-AWARE ATTENTION (leads to PREFILL-3-SPEC).** Hydragen-style exact decomposition: attention over the shared prefix is batched across branches, per-branch suffix attention is computed separately, and the two are combined exactly. It generalizes to tree-shaped sharing and needs a native Blackwell attention kernel path. The source judges it likely more valuable than YOCO for 32, 128 and 500 branch workloads.
4. **CACHE-AWARE SCHEDULING (leads to PREFILL-4-SPEC).** Cost is uncached prefill tokens times prefill cost, plus shared-prefix attention cost, plus artifact movement cost, plus branch-local suffix cost, not raw input tokens. It enters the scheduler and the Omega physical cost model. Precedent named in the source: Xiaomi MiMo-V2.5 length bucketing and cache-aware routing (numbers UNVERIFIED).
5. **CORTEX-AWARE PREFETCH.** Cortex recall returns context-computation locality hints (which artifacts, and where: GPU resident, unified RAM, NVMe, or missing) so that move, recompute or compose can run while planning continues. Precedent: Tessera, which the source calls very new; treat its numbers as promising only (section 11.1: not found).
6. **TIERED PREFILL ARTIFACTS.** Unified-memory hot tier, cooler pages, then NVMe, with explicit identity and provenance. The LMCache control-plane idea is borrowed, not its implementation.
7. **COMPOSABLE NON-PREFIX REUSE.** Only after the exact path is proven. EPIC and CacheBlend style selective recompute, under separate correctness and quality contracts.

## 14. exactness_class rule and target field set

Every artifact carries an `exactness_class`: **EXACT** (lineage-preserving shared prefix) or **COMPOSABLE/APPROXIMATE** (content reused at a different position). The classes are never silently mixed. Reuse requires matching class.

Target PrefillArtifact field set from the source (supersedes nothing in section 4; section 4 stays as the binding list of the first cut): `context_revision_digest`, `token_digest`, `model_digest`, `tokenizer_digest`, `model_architecture_id`, `weight_generation`, `rope_config`, `absolute_position_range`, `kv_dtype`, `kv_layout`, `block_size`, `attention_layout`, `prefix_length`, `storage_handles`, `generation`, `completion_fence`, `exactness_class`, `provenance`, `state`.

Target `state` names are Allocated | Computing | Ready | FrozenShared | Retired. Mapping to the names in section 5: Allocated = Allocated; Computing = PrefillPending; Ready = PrefillReady; FrozenShared = SharedFrozen; Retired = Reclaimed. Section 5 names stay authoritative in this spec until a cut renames them.

Reuse precondition precedent (LMCache cross-engine, per the source): model revision, TP arrangement, KV dtype, page size and chunk size must all agree.

## 15. QUALITY dimension (speed alone is not enough)

Cases at increasing context, in addition to section 6:

1. exact token retrieval
2. multi-hop
3. middle-position retrieval
4. distractor resistance
5. repository cross-file reasoning
6. memory + tool-result interaction
7. branch-specific fact isolation
8. shared-prefix parity

Three failures are measured separately: (a) not cached correctly; (b) cached but attention did not retrieve; (c) retrieved but reasoning failed.

Results (every cell NOT_RUN; no quality case has run on any tier):

| Case | (a) not cached correctly | (b) cached, not retrieved | (c) retrieved, reasoning failed |
|---|---|---|---|
| exact token retrieval | NOT_RUN | NOT_RUN | NOT_RUN |
| multi-hop | NOT_RUN | NOT_RUN | NOT_RUN |
| middle-position retrieval | NOT_RUN | NOT_RUN | NOT_RUN |
| distractor resistance | NOT_RUN | NOT_RUN | NOT_RUN |
| repository cross-file reasoning | NOT_RUN | NOT_RUN | NOT_RUN |
| memory + tool-result interaction | NOT_RUN | NOT_RUN | NOT_RUN |
| branch-specific fact isolation | NOT_RUN | NOT_RUN | NOT_RUN |
| shared-prefix parity | NOT_RUN | NOT_RUN | NOT_RUN |

## 16. Topology rule

Single DGX Spark box first. Avoid redundant work inside the unified-memory box before any prefill/decode disaggregation across boxes. No hyperscaler-style prefill/decode split now. GB10 memory figures, 128 GB LPDDR5x unified and 273 GB/s, are VERIFIED against https://docs.nvidia.com/dgx/dgx-spark/hardware.html (fetched 2026-10-01).
