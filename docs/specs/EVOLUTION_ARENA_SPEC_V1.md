# Specification: Evolution Arena V1 (`EVOLUTION_ARENA_V1_PASS`)

| Field | Value |
|---|---|
| Document ID | SPEC-ARENA-V1 |
| Program | Evolution Arena (research program: `docs/research/evolution-arena-program.md`) |
| Classification | Frozen contract. Docs only. No runtime change is authorized by this document. |
| Status | PROPOSED (draft for orchestrator review) |
| Opened | 2026-09-29 |
| Authority | ARCH-0016 (resident reaction architecture), ARCH-0015 (Resident Semantic Store), ARCH-0014 (FORGE realizes, AEGIS verifies), ARCH-0007 (J-Space effect boundary), OS-0012 (self-construction, capability growth, generations), ARCH-0017 (ARGUS defensive plane, merged on main) |
| Lineage | Omega `OMEGA_COGNITIVE_ROUTING_PASS` (#57), `OMEGA_PLAN_REUSE_PASS` (#58), `OMEGA_EMPIRICAL_OPTIMIZER_PASS` (#60, merged), R9 generation barrier (`rx_generation`), physics #13 FORGE-0 / FORGE-HWID (merged) |

---

## 0. What this document freezes, and what it does not

> **In plain words (read this first).** The Evolution Arena is a controlled way for the machine to try many small variations of a method it already has (for example, a different way to arrange a multiplication so it runs faster) and keep only a variation that is proven better. Every variation is written down before it is tested, and nothing about it is ever erased afterwards, so its full family history can always be traced. The tests are fixed in advance, and a final exam set is locked away and opened only once, by an independent grader, so the machine cannot "study for the test". A variation that gives a different answer, even a faster one, is thrown out rather than ranked. The machine can suggest a winner but can never install it itself: swapping it in needs a separate key held on the owner's side, and the old version always stays available to fall back on. This document only writes the rules down; it switches nothing on, and no Arena code may run until every item in §0.1 is closed.

This specification freezes exactly five things:

1. the **Candidate** object,
2. the **Lineage** model,
3. the **Evaluation** contract,
4. the **Promotion** contract,
5. the **first flagship experiment** and its pass criteria.

Everything else in the research document (Cortex epistemics, the machine self-model, analog substrates, search-policy evolution, Physics Zero) is explicitly **out of scope for V1** and is not constrained here.

Changing any frozen item after a candidate has been generated against it requires a new spec commit and a full rerun of the affected experiment (same rule as every pre-registered gate in this project).

Language and platform rules for any eventual implementation (project rules 2026-09-27/29): C (+asm where measured), shell tooling; no Rust, no Python, no systemd; no GPU/NVIDIA work until the owner decides the NVIDIA/GB10 direction. **[Superseded 2026-10-01 by [ADR 0024](../adr/0024-rust-scaffolding-omega-destination.md): Rust is scaffolding, Omega is the destination, C and asm only where hardware, boot, ABI or measurement justifies them. The no-Python, no-systemd and no-NVIDIA-work rules in this sentence are unchanged by that ADR.]**

### 0.1 Activation hold

Nothing in this document may become runtime behaviour until all of the following are true. This is the same hold the research document states, restated with today's status (2026-09-29). A "receipt" below means a signed test record, committed to the repository, proving that a gate passed.

| Prerequisite | In plain words | Status today | Closes when |
|---|---|---|---|
| R16 orchestrator retirement | the old central "conductor" program is fully replaced by self-starting pieces | W2/W4 done, W5 not done; omega #68 is a draft | `R16_ORCHESTRATOR_RETIRED` receipt (pending, omega #68) on omega main |
| FORGE v1 boundary | the part that turns a method into machine code has a proven, sealed edge and can read the real hardware's identity | physics #13 merged (5969159; Gates 3 and 4 pass) | closed (physics #13 merged with Gate 3 / Gate 4 receipts) |
| Authority instance identity across restart | after a reboot the permission system can prove it is the same one as before | replay determinism proven; instance identity is an open question for the next version of the binary interface (ABI v2, decision D7; which machine identifier to use is pending) | D7 decided and a receipt recorded for it |
| ARGUS-0 | the watchdog's first stage is finished within stated limits | ARGUS-0 complete under documented limits 2026-09-29 (R8 +3.87 % with a spare core; runtime findings cleared at aienos d39dd5b), per aienos `feat/argus-0` c30f168 `ARGUS0_GATES.md` | closed as recorded; ARGUS-1 continues in parallel |
| ARGUS-1 containment live | the watchdog can actually fence off a misbehaving piece | code started (aienos feat/argus-1-l0, spec #162); gates not yet run | `ARGUS1_G1`..`G13` PASS. Until then the Arena is **observe-and-record only**: Candidates may be proposed, verified and measured in draft Worlds, but no Candidate may act with real permissions and no promotion request may be created |
| Omega empirical optimizer | the existing "try several versions and measure" tool is accepted | omega #60 merged | #60 merged (its arm / judge / learner vocabulary becomes canonical) |
| OSC-0B machine semantics freeze | the rules for how numbers and IDs are laid out as bytes are settled | omega #76 draft, 4 owner decisions pending | accepted and identity-break timing decided; Arena schemas re-checked |

OSC-0B is on this list for identity stability, not because the Arena needs the Omega compiler (V1 generates no code): its pending decisions (u64 generations everywhere, and the identity break for canonical payloads, R9 generation-store rows and crumb digests) change the exact bytes the frozen `candidate_id`, `objective_id` and Evidence digests, and the EA-G1 byte-for-byte reconstruction, are computed over.

Until then: schemas, receipt formats and this contract may be written and reviewed, as documents only. No Arena code runs on the Spark. Independently of the rows above, ARGUS-1 containment must be live before any Arena Candidate acts with real permissions (ARGUS-1 row); before that, evaluation is observe-and-record only.

### 0.2 Reading rules

- Words in `code` are existing identifiers on main (omega `rx_generation.{h,c}`, ARCH-0016 §52–53, ADR 0015) or in the open PRs and branches named in the Lineage and Authority rows; each identifier that is not yet on main is marked "(pending: …)" where it first appears. Words in **bold** are terms this spec defines. Nothing here renames an existing identifier.
- "FORGE" in this document always means the ARCH-0014 machine realization engine. The OS-0012 "AIEN FORGE" (self-construction machinery) is referred to here as **self-construction**; the Arena is a bounded instance of it.
- "World" without qualifier means the single generation-addressed object world of ARCH-0016 §13. A J-Space **draft World** (docs/08, ARCH-0007) is a speculative branch inside it whose results are Ephemeral state until promoted.
- "Generation" without qualifier means the ARCH-0016 / `rx_generation` World generation that the R9 barrier commits through the ADR 0015 ordered commit protocol. The OS-0012 whole-machine Generation and the Store v1 durability generation are named as such when they appear.
- Plain glosses for recurring terms:
  - **ordered commit protocol** (ADR 0015): the fixed order in which a change is written to disk, so that after a crash the system sees either the whole old state or the whole new one, never a half-written mix.
  - **R9 barrier** (`rx_generation`): the single checkpoint every change of the active method must pass; it checks permission, freshness and verification, then switches old to new all at once.
  - **dependency-ready reaction**: a small piece of work that starts by itself as soon as what it needs exists, instead of being called in turn by a central scheduler.
  - **principal**: an identity that the permission system recognises and grants rights to (a user, a service, or a running reaction).
  - **externalize effects**: do something visible outside the sandbox (write to the real system, the network or hardware), as opposed to changing only draft working state.

---

## 1. Doctrine the Arena inherits

The Arena adds no new authority and no new loop. It composes existing faculties, in the doctrine order which is a statement of responsibilities, not a turn order (ARCH-0016 Part I, "Doctrine reconciliation"):

```text
ATLAS AWAKENS. AIEN PROPOSES. OMEGA DEFINES. FORGE REALIZES.
AEGIS VERIFIES. HARDWARE ACTS. EVIDENCE TEACHES.
```

Restated for the Arena:

| Faculty | Arena role | May not |
|---|---|---|
| AIEN | publishes typed proposals (`Hypothesis`, `PlanCandidate`) that become Candidates | promote, grade, or alter the evaluation contract |
| J-Space | forks draft Worlds, keeps score dimensions separate, prunes dominated Candidates, retains counterfactuals | externalize effects (ARCH-0007), commit anything |
| OMEGA | applies typed mutations to semantic programs; verification stays separate from selection ("REALIZE VERIFY MEASURE RECORD SELECT") | realize outside the Candidate's declared surface |
| FORGE | realizes verified Omega programs on declared substrates, reports constraints and alternatives | act as gatekeeper, self-authorize |
| AEGIS | verifies realization faithfulness and invariants; authors `PolicyDecision` / `CapabilityRequest`; states promotion requirements | mint capabilities (only the Aienux root mints), execute the promotion itself |
| Evidence | immutable, content-addressed receipts bound to hardware identity | be edited, be replaced by prose or model confidence |
| Cortex | admits claims through candidate → evidence → Signed Admission Receipt | own the speculative lifecycle, feed hard-invariant decisions (ARCH-0017 §2.3, aien-architecture branch) |
| Promotion right holder | the only principal that can call `rx_gen_promote`. In Flagship 1 this is the operator-held promotion principal on the native Aienux authority, as in the R9 and omega #60 receipts; never an Arena reaction | be the proposer; delegate the right |
| ARGUS | observes; emits `ArgusFinding`s (pending: ARCH-0017 branch) | write World objects, take part in the promotion decision |

**No self-widening.** No Arena principal (proposer, J-Space allocator, judge, learner, cost model) may request, receive or be delegated any capability beyond those granted at run start. No Arena principal may ever receive new capabilities; the Arena never widens its own authority.

**Every automatic decision is accountable.** Every automatic Arena action (J-Space budget allocation, pruning to ARCHIVED, evaluation freeze, pre-commit fallback, and every RNG seed used by the search) is, in the ADR 0017 invariant style: *attributable* (names the principal that took it), *generation-bound* (names the active generation it was taken against), *receipt-producing* (emits an Evidence package or causal crumb recording the decision and its inputs), and *recoverable* (can be re-derived or undone from durable state). An action that does not meet all four makes replay impossible and is a gate failure (EA-G1).

Hard rules carried over verbatim in force (see ARCH-0016 §3, §54; OS-0012 rules 3–6, 10; OS-0012 is aienos `docs/adr/0012`):

- INTELLIGENCE ≠ AUTHORITY. The World may reference capabilities; it may not invent them.
- I9: intelligence cannot promote itself past authority policy.
- I10: failed optimization cannot destroy the last-known-good realization.
- I16: semantic meaning remains stable across realization changes.
- THE SYSTEM HAS NO SEMANTIC MASTER LOOP. Each Arena stage is a dependency-ready reaction (it starts when its inputs exist), not a step in a scheduler.
- Repeated failed repairs stop and are reported; there is no endless self-modification loop.

---

## 2. The Candidate object (frozen)

A **Candidate** is an immutable, content-addressed experimental descendant of an active method. It is the Arena's unit of proposal and the same object the RSI evaluation flow (docs/09) calls a Candidate; the Arena is that flow moved in-band.

Arena Candidates (identified by a sha256 `candidate_id`, and there may be many per run) live as a CandidateHeader plus their Evidence (§3, §4.4). They are **not** `rx_generation` store candidates: the store has a small fixed number of candidate slots (`MAX_CAND 4` in `rx_generation.c`) and assigns each one a u64 id at `rx_gen_propose(..., uint64_t *out_id)`. Only the single ELIGIBLE winner becomes a store candidate, at §6.3 step 10, and the promotion record (§5.4) binds that store u64 id to the Candidate's sha256 `candidate_id`.

When the winner is handed to the store, it becomes an `RxGenDraft` (omega `rx_generation.h`) whose blobs are populated as follows. No new blob kinds are introduced in V1.

| `RxGenDraft` blob | Arena content |
|---|---|
| `provenance` | the **CandidateHeader** below, in the omega canonical encoding (big-endian, per omega `spec/canonical-encoding.md`; exact bytes re-checked after OSC-0B, §0.1), digest = `candidate_id` |
| `realization` | the Omega program plus the FORGE realization plan (a `ForgeVerifiedRealization` (physics #13 merged) once sealed) (a hardware realization record, not part of accepting a result; ADR 0016 Amendment 1) |
| `config` | mutation parameters (tile size, unroll factor, arm selection, …) |
| `model` | unused in V1 (reserved for learned components; forbidden mutation surface) |
| `evidence` | root digest of the Evidence packages about this Candidate (§4.4), written by the measurement/judge reaction; the proposer and Candidate code have no write path to it |
| `objects` | World object refs the Candidate reads; never capability refs it did not hold |

### 2.1 CandidateHeader

```text
CandidateHeader v1 {
    schema             = "AIEN_ARENA_CANDIDATE_V1"
    candidate_id       : sha256 of this header with candidate_id zeroed
    parent_ids[]       : 0..2 candidate_ids (0 = human-supplied baseline; 2 = recombination)
    lineage_root       : candidate_id of the baseline this lineage descends from
    mutation_class     : one of the typed operators in §2.3
    mutation_params    : digest of the `config` blob
    objective_id       : digest of the frozen Evaluation contract (§4) the Candidate is answering
    semantic_digest    : Omega semantic digest of the program (must equal the parent's; I16)
    realization_digest : digest of the `realization` blob
    proposed_by        : principal id (subject) of the proposing reaction
    proposed_at_gen    : active generation id at proposal time
    required_caps[]    : capability ids the Candidate needs to run in its draft World
    resource_limits    : {cpu_ms, gpu_ms, bytes, joules} ceilings; hard, enforced by R5/R6;
                         V1 requires gpu_ms = 0
    substrate_scope    : declared substrate list for FORGE; in V1 the only admissible
                         value is Grace CPU (Blackwell is not admissible in any V1 contract)
}
```

Rules:

- `candidate_id` is content-addressed. Two proposals with identical headers are one Candidate.
- The header is written once, before any evaluation. A Candidate that has seen an evaluation result cannot change any header field; a "fixed" version is a new Candidate with `parent_ids = [old]`.
- `semantic_digest` must equal the parent's semantic digest. A Candidate that changes meaning is not a Candidate; it is REJECTED at VERIFIED (I16).
- `required_caps[]` may only list capabilities the proposer already holds. A Candidate cannot request wider authority for itself (see also "No self-widening", §1).
- `rx_gen_promote` checks the promoter's subject against the `proposer` argument recorded at `rx_gen_propose`, not against the header field (`RX_GEN_ERR_AUTHORITY` if equal). Therefore, when the winner is handed to the store, header `proposed_by` must equal the `proposer` passed to `rx_gen_propose`, and header `proposed_at_gen` must equal the store's `parent_id` for that store candidate (the active generation it was proposed against); both are checked when the store candidate is created, and a mismatch refuses creation.

### 2.2 Lifecycle

Candidate status is derived from Evidence, never set by the Candidate. It maps onto existing reaction and generation outcomes:

```text
PROPOSED    header written and recorded as Evidence (no store candidate yet)
   ↓
REALIZED    FORGE produced a realization for every declared substrate, or reported why not
   ↓
VERIFIED    OMEGA semantic check + AEGIS invariant check both PASS; realization sealed
   ↓         (FAIL → REJECTED; sealed realization mutated → REJECTED,
   ↓          NEG_POST_VERIFICATION_MUTATION_REFUSED (physics #13 merged))
EVALUATING  running in its draft World against training + validation workloads
   ↓
EVALUATED   all pre-registered measurements recorded as Evidence
   ↓
ELIGIBLE    meets the promotion threshold on validation; may be graded on the sealed holdout once
  ↙       ↘
ARCHIVED    PROMOTED   (winner handed to the store via rx_gen_propose, then rx_gen_promote
                        committed through the R9 barrier)
```

Terminal statuses: `REJECTED`, `ARCHIVED`, `PROMOTED`, plus `STALE` (parent generation is no longer active; `RX_GEN_ERR_STALE`) and `BUDGET_EXHAUSTED` (resource_limits hit; R6). Every terminal status is Evidence and is retained (§3).

### 2.3 Typed mutation operators (V1 allowed surface)

V1 permits exactly these mutation classes. Each is a semantic transformation Omega can name; none is a textual source edit.

```text
CHANGE_REALIZATION        pick a different existing verified realization (arm) for an operation
CHANGE_TILE_SIZE
CHANGE_UNROLL_FACTOR
CHANGE_MEMORY_LAYOUT      *
SPECIALIZE_FOR_SHAPE      *
FUSE_OPERATIONS           *
SPLIT_OPERATION           *
RECOMBINE                 two parents, one child; both parents must be VERIFIED or better
```

`*` In V1 these four are allowed only as a choice among existing verified arms that already implement the fused, split, shape-specialized or re-laid-out form. Producing a new such realization is reserved for V2.

Forbidden in V1 (not a mutation surface, a header naming one is REJECTED at PROPOSED): AEGIS policy, the capability root, the promotion right, the evaluation contract, the holdout, ARGUS, the boot chain, any `model` blob, the empirical cost model (the draft `ALTER_COST_MODEL` operator is deferred beyond V1), J-Space search policy, Skills. V1 realizations are human-written C (+asm where measured) built by the project toolchain; no generated native code, verified or not (OS-0012 rule 5: no native admission of generated code on physical hardware before M3 enforcement).

---

## 3. The Lineage model (frozen)

The **Lineage graph** is the set of all Candidates with edges `parent_id → candidate_id` labelled by `mutation_class`. It is the ground truth; Cortex claims are derived from it and never replace it.

Rules:

1. **Append-only, forward-only.** No Candidate, edge or Evidence package is ever deleted or rewritten. This is the ADR 0015 §9 forward-only history rule applied to experiments. Archiving is a status, not a removal.
2. **Content-addressed storage.** Candidates and Evidence are stored as content-addressed objects in the ADR 0015 Store v1 and referenced from the World as `DURABLE` state (ARCH-0016 §19 / ADR 0015 §2) only once the Store generation that contains them has committed (§4.4). A copy of each is exported as `evidence/ARENA/<sha256>.json` (omega receipt convention, committed to git for review) with the same digest; the export is a copy, not the durable store. Draft-World working state is `EPHEMERAL`.
3. **Causal crumbs.** Every transition in §2.2, and every automatic Arena decision (allocation, pruning, freeze, pre-commit fallback, RNG seed; §1 "Every automatic decision is accountable"), emits an R4 causal crumb naming `candidate_id` (where one applies), the principal and reaction that caused it, the active generation, and the Evidence digest. Ancestry, and why the search went where it did, must be reconstructible from crumbs alone (R4 exit criterion reused).
4. **Failed lineages persist.** `REJECTED`, `STALE` and `BUDGET_EXHAUSTED` Candidates keep their full Evidence. Counterfactual draft Worlds (candidates that lost) keep their measured Evidence even though their World is discarded.
5. **The archive is a view, not a store.** The **Evolution archive** (the **current best** arm, meaning the omega #60 winning arm, plus the known-good reference and per-dimension best lineages) is a set of tagged references into the Lineage graph, recomputed from Evidence. Tags carry no authority.
6. **The known-good reference is always present.** Every lineage root is a human-supplied baseline that is itself VERIFIED and always eligible for selection (the omega #60 "known-good reference" arm). I10: no experiment may remove it.

Exit gate (EA-G1, §6.4): given the World's durable root, every Candidate's ancestry, every Evidence package and every automatic Arena decision can be reconstructed byte-for-byte on a clean machine.

---

## 4. The Evaluation contract (frozen)

An **Evaluation contract** is a pre-registered, content-addressed document that exists before the first Candidate is proposed against it. Its digest is the Candidate's `objective_id`.

### 4.1 Contents

```text
EvaluationContract v1 {
    schema                 = "AIEN_ARENA_EVAL_V1"
    objective              : plain statement (what "better" means)
    mutation_surface[]     : subset of §2.3
    training_workloads[]   : shape/seed digests, visible to the proposer
    validation_workloads[] : shape/seed digests, visible; used for ELIGIBLE
    holdout_commitment     : sha256 of the sealed holdout set (contents not visible until grading)
    correctness_bound      : oracle + tolerance per operation (the Omega semantic oracle)
    dimensions[]           : measured separately, never collapsed (see 4.2)
    resource_limits        : per-Candidate ceilings (mirrors CandidateHeader; gpu_ms = 0 in V1)
    budget                 : max Candidates, max total cpu time, max joules for the run
                             (total gpu time = 0 in V1)
    promotion_threshold    : per-dimension rule (e.g. "latency p50 ≤ 0.9 × baseline AND energy ≤ 1.0 × baseline AND correctness PASS on every validation workload")
    failure_conditions[]   : conditions that end the run as FAIL
    judge                  : the independent judge realization digest (never the learner)
    substrate_scope[]      : hardware the run may claim (V1: Grace CPU only)
}
```

### 4.2 Dimensions

Recorded separately per Candidate per workload, in the J-Space `ScoreVector` sense (docs/06): semantic correctness (PASS/FAIL against the oracle), latency (p50, p99, monotonic clock), throughput, energy (joules, measured, not modelled), peak memory, verification cost, synthesis cost, failure rate. Pareto filtering happens before any ranking. A scalar fitness may be used for search allocation only, never for ELIGIBLE or promotion.

### 4.3 Separation rules

- **Verification is separate from selection.** OMEGA/AEGIS verification runs before any performance number is looked at; a fast wrong answer is REJECTED, not ranked (ARCH-0016 §2).
- **Judge apart from learner.** The judge (grader) is a different realization from anything that proposes or learns, and is link-isolated from the learner the same way `rx_route.o` / `rx_costmodel.o` (pending: omega #60) are `nm`-checked against `rx_gen_*`.
- **Holdout is sealed.** Only its digest is in the contract. The holdout contents are capability-guarded: only the judge holds the read capability, no proposer, learner or Candidate does, and the read is single-use (the capability is consumed by the one permitted read). It is opened exactly once per run, for the single ELIGIBLE Candidate that wins validation. After grading, the opened holdout set is itself retained as Evidence, so the grade can be replayed and its contents checked against `holdout_commitment`. Any further read attempt is refused and ends the run as FAIL.
- **Hardware claims need hardware.** A dimension measured on a stand-in, emulator or mock is reported under `not_claimed[]`, never as a result (OS-0012 evidence discipline).

### 4.4 Evidence package

Every measurement emits one immutable **Evidence package**, written by the measurement or judge reaction (never by the proposer or the Candidate):

```text
Evidence v1 {
    schema              = "AIEN_ARENA_EVIDENCE_V1"
    candidate_id, parent_ids[], objective_id
    machine_descriptor  : FORGE-HWID observed descriptor digest (physics #13)
    substrate           : which declared substrate ran
    world_id, generation: draft World and active generation at run time
    workload_id         : which training/validation/holdout item
    realization_digest, verification_result
    measurements        : the §4.2 dimensions actually taken
    conditions          : thermal, load, quiet-flag state, concurrent heavy tests
    errors[], faults[]
    result_digest       : digest of the produced output (compared to oracle)
    run_commit, tree_dirty, test_binary_sha256, host   (omega receipt fields)
}
```

The Evidence digest is its object id in the Store and the filename of its `evidence/ARENA/` export. Evidence follows the ADR 0015 §14 states PROPOSED → WRITTEN → DURABLE → RECOVERED: it is `WRITTEN` when appended to the Store v1 append arena, and `DURABLE` only after the Store generation containing it has committed (superblock flush). Nothing may cite an Evidence package as grounds for ELIGIBLE or promotion before it is `DURABLE`.

---

## 5. The Promotion contract (frozen)

### 5.1 Who promotes

Promotion is the existing R9 operation and nothing else:

```text
rx_gen_promote(RxPromotionRequest{
    candidate_id,          /* the store's u64 id from rx_gen_propose, not the sha256 candidate_id */
    subject, cap_id, cap_generation,
    resource = RX_GEN_RES_PROMOTION, rights = RX_GEN_RIGHT_PROMOTE })
```

validated against the native Aienux authority. The Arena introduces no promotion path, no promotion capability and no promotion policy of its own. In Flagship 1 the `subject` is the operator-held promotion principal on the native Aienux authority, as in the R9 and omega #60 receipts; never an Arena reaction.

What `rx_generation.c` on main enforces today, and what this spec adds on top:

- Enforced today: `subject` ≠ the `proposer` recorded at `rx_gen_propose` (`RX_GEN_ERR_AUTHORITY`); wrong resource or rights, or a capability the native authority does not validate, is refused (`RX_GEN_ERR_AUTHORITY`); the store candidate's `parent_id` must equal the active generation, else `RX_GEN_ERR_STALE`; a candidate whose `proofs_ok` flag is not set is refused (`RX_GEN_ERR_VERIFY`); the commit goes through the ADR 0015 ordered commit protocol and recovery yields OLD or NEW, never a torn generation (`RX_GEN_ERR_TORN` is a refusal, not a state).
- **Not enforced today, required by this spec:** on main, `proofs_ok` is copied from the `RxGenDraft` the proposer supplies to `rx_gen_propose`, and `rx_gen_set_evidence` (like `rx_gen_add_work` / `rx_gen_finish_work`) takes no subject and makes no authority check. So the code alone does not stop a proposer from self-certifying VERIFIED or writing its own evidence blob. For the Arena: only AEGIS/Omega verification may set `proofs_ok`, and only the judge / measurement reaction may set the `evidence` blob; the proposer has no path to either. Before calling `rx_gen_promote`, the promotion-right holder re-checks the VERIFIED Evidence digest and the holdout Evidence digest against the durable Store; a mismatch or absence is a refusal. Any eventual implementation must make these hold (§6.5 hostile test).
- The promotion right is not delegable; a Candidate presenting itself as the authority is refused.
- AEGIS states the promotion requirements and verifies them; it does not hold or exercise the promotion right. ARGUS does not participate.
- Learners, routers, cost models and the judge are link-isolated from `rx_gen_promote`, `rx_gen_*` and `aienos_cap_*`. The eventual implementation must pass the existing `nm -u` build check applied to every Arena object file.

### 5.2 What promotion may change

Only the method the Evaluation contract named as the mutation surface. In V1 that is a realization-selection policy and the parameters of existing verified realizations. Promotion never changes the evaluation contract, the holdout, the threshold, the capability root, AEGIS policy, ARGUS, or the previous generation's durable state.

### 5.3 Rollback

Two distinct mechanisms, named apart because ADR 0015 §9 names them apart:

- **Pre-commit fallback (automatic).** If verification, the holdout grade or the R9 barrier fails, the active generation is untouched and the Candidate is `REJECTED`/`ARCHIVED`. This is ARCH-0016 "known-good realization fallback" and needs no authority. Like every automatic Arena action it is attributable, generation-bound and receipted (§1).
- **Post-commit rollback (operator only).** Reverting a PROMOTED generation is an ADR 0015 "operator-authorized historical rollback": it produces a new forward generation whose method is the previous one, under offline operator authentication (ADR 0006 as cited by ADR 0015 §9, i.e. aienos `docs/adr/0006` deterministic recovery core and offline operator authority). The Arena may *recommend* it by Evidence; it may never execute it. Whole-machine rollback is never autonomous (I3 of the ARGUS-1 spec, aienos branch `feat/argus-1-spec`, applies system-wide). OS-0012 rule 10's automatic restore is not an Arena power (§7).

### 5.4 Promotion record

The R9 barrier's own existing receipt is the authoritative record of the promotion. The Arena adds no receipt-writing to the barrier. After the barrier returns, a non-proposer reaction writes a companion Evidence object with schema `AIEN_ARENA_PROMOTION_V1` binding: the barrier receipt digest, the Candidate's sha256 `candidate_id` and the store's u64 candidate id it was promoted as, objective_id, the VERIFIED and holdout Evidence digests, promoter subject, `cap_id`/`cap_generation`, old and new generation ids, the ADR 0015 commit digest, and `not_claimed[]`. Neither the Candidate nor the proposer writes it.

---

## 6. First flagship experiment: `ARENA_FLAGSHIP_1` (frozen)

### 6.1 Scope decision

The research document's flagship targets Grace CPU and Blackwell GPU realizations of matrix/vector families. V1 narrows this deliberately:

- **Substrate: Grace CPU only.** The Blackwell population is deferred to `ARENA_FLAGSHIP_2`. Reasons: OS-0012 rule 5 forbids native admission of generated code on physical hardware before M3 enforcement; the NVIDIA/GB10 direction is an open owner decision; and R9 evidence to date is host-CPU only. A CPU-only pass is a full pass of this spec, not a partial one.
- **Mutation surface: selection and parameters, not new code.** Candidates choose among, and re-parameterize, realizations that are already VERIFIED on main once omega #60 is merged (the omega #60 matvec arms and their tile/unroll/layout parameters). No Candidate emits new machine code in V1.
- **Workload family:** matvec and small matmul, the operations for which Omega already has a semantic oracle and measured CPU arms.
- **No canary step in V1.** docs/09 and OS-0012 rule 6 describe canary promotion; V1 omits it because V1 promotes only a selection among already-verified human-written arms inside one World generation, and the pre-commit fallback plus operator rollback (§5.3) cover the same risk. A canary step is a V2 question.

This keeps the experiment inside every existing rule while still testing the whole mechanism end to end.

### 6.2 Pre-registration

Before the first Candidate: the `EvaluationContract` (§4.1) is committed with training shapes, validation shapes, the sealed holdout digest, correctness bounds (bitwise or tolerance per the Omega oracle), budget, threshold, judge, and the seeds of any RNG the search uses. The baseline set (human-supplied, ≥ 3 verified arms plus the known-good reference) is registered as lineage roots.

### 6.3 Run protocol

Each numbered item is a dependency-ready reaction, not a scheduler step (R13/R16):

```text
 1. Baseline draft World forked from the active generation.
 2. Proposer emits Candidates via the §2.3 operators (budget-bounded, R6).
 3. OMEGA constructs each Candidate's program; semantic_digest checked (I16).
 4. AEGIS verifies invariants; the FORGE realization plan is sealed for hardware realization (not an accept step, ADR 0016 Amendment 1); failures → REJECTED.
 5. Verified Candidates run in their draft Worlds on training + validation shapes.
 6. Evidence packages written (§4.4), bound to the FORGE-HWID descriptor.
 7. J-Space keeps dimensions separate, Pareto-filters, allocates remaining budget
    toward non-dominated lineages; dominated Candidates → ARCHIVED with Evidence.
    Every allocation and prune is receipted (§1).
 8. Budget exhausted or threshold met → evaluation frozen (no more proposals).
 9. Single ELIGIBLE winner graded once on the sealed holdout by the judge.
10. Winner handed to the store (rx_gen_propose; proposed_by / proposed_at_gen checked,
    §2.1); promotion-right holder re-checks VERIFIED + holdout Evidence, then either
    promotes (R9) or refuses.
11. Machine power-cycled (full power-off; see X925 boot-state note).
12. Promoted method reconstructed from durable state; holdout re-measured.
13. Transfer probe: a related, previously unseen shape family is registered as a new
    EvaluationContract; the number of Candidates needed to reach threshold is compared
    against the same search started from the original baseline.
14. Hostile tests (§6.5) run against the same build.
```

### 6.4 Pass criteria (all required; each is a pre-registered sub-gate)

| Gate | Criterion | Reuses |
|---|---|---|
| EA-G1 | Lineage, Evidence and every automatic Arena decision (allocation, prune, freeze, fallback, RNG seeds) reconstructed byte-for-byte on a clean machine from the durable root | R4, ADR 0015 §14 |
| EA-G2 | Every executed Candidate has a VERIFIED Evidence package; no REJECTED Candidate ran outside its draft World | ARCH-0007, I5 |
| EA-G3 | No `EvaluationContract` field changed after the first Candidate (digest equality) | pre-registration rule |
| EA-G4 | ≥ 1 Candidate beats the baseline on the frozen threshold on validation | – |
| EA-G5 | The same Candidate meets the threshold on the sealed holdout, opened exactly once by the judge; opened holdout retained as Evidence | judge apart |
| EA-G6 | Promotion committed by a subject ≠ proposer through `rx_gen_promote`; barrier receipt present and referenced by the `AIEN_ARENA_PROMOTION_V1` record | R9 |
| EA-G7 | After full power-off, the promoted method is active and re-measures within tolerance | R9 recovery, R14 |
| EA-G8 | Pre-commit fallback exercised at least once (an ELIGIBLE Candidate refused at the barrier leaves the active generation byte-identical) | I10 |
| EA-G9 | Transfer probe reaches threshold with fewer Candidates than the cold search (report the ratio; V1 claims only "fewer") | – |
| EA-G10 | All claimed measurements carry a real FORGE-HWID descriptor; stand-in results appear only under `not_claimed[]` | OS-0012 evidence discipline |

Verdicts use the project's existing forms: PASS, FAIL, PASS-WITH-DOCUMENTED-LIMITS. The gate id is `EVOLUTION_ARENA_V1_PASS`; sub-gates print `GATE ARENA1_Gn PASS|FAIL`.

### 6.5 Hostile tests (must all be refused)

- Candidate header lists a capability the proposer does not hold → REJECTED at PROPOSED.
- Candidate with a different `semantic_digest` → REJECTED at VERIFIED.
- Proposer calls `rx_gen_promote` on its own Candidate → `RX_GEN_ERR_AUTHORITY`.
- Proposer self-certifies: sets `proofs_ok` in its own `RxGenDraft`, or writes the `evidence` blob → refused (no write path), and a store candidate whose VERIFIED / holdout Evidence digests do not match the durable Store is not promoted.
- Header `proposed_by` differs from the `proposer` passed to `rx_gen_propose`, or `proposed_at_gen` differs from the store `parent_id` → store candidate creation refused.
- Arena principal (proposer, allocator, judge, learner, cost model) requests a capability it was not granted at run start → refused.
- Proposer, learner or Candidate attempts to read the holdout → refused (no capability); judge attempts a second holdout read → refused, run FAIL.
- Learner object file references `rx_gen_*` → build fails (`nm -u`).
- Sealed realization mutated after verification → `NEG_POST_VERIFICATION_MUTATION_REFUSED` (physics #13 merged).
- Crash injected mid-promotion → recovery reports OLD or NEW, never torn.
- Evaluation contract edited after first Candidate → EA-G3 FAIL, run void.

### 6.6 Not claimed by V1

Blackwell or any GPU realization; generated native code; analog substrates; Cortex claim extraction beyond storing Evidence; machine self-model; search-policy evolution; cost-model evolution; Skill evolution; canary promotion; whole-machine (OS-0012) Generation promotion; any energy figure measured while other heavy tests run (quiet-flag rule).

---

## 7. Reconciliations recorded

These naming and rule collisions were found while aligning this spec with main. This section restates existing ADRs and code and freezes nothing new; it is recorded so the same collisions do not have to be rediscovered.

1. **FORGE:** ARCH-0014 engine here; OS-0012 "AIEN FORGE" is called self-construction.
2. **World:** single object world; J-Space draft Worlds are speculative branches within it (Ephemeral until promoted).
3. **Generation:** ARCH-0016 / `rx_generation` generation, committed through ADR 0015. OS-0012 machine Generations are out of scope for V1.
4. **Pipeline shape:** the research document's arrow diagram is responsibilities, not a loop. Implementation is reactions (R13/R16).
5. **Independent promotion authority:** the holder of `RX_GEN_RIGHT_PROMOTE` on the native authority (in Flagship 1, the operator-held promotion principal). Not AEGIS (verifies, does not mint), not ARGUS (observes), not the proposer, never an Arena principal.
6. **RSI:** docs/09's Hypothesis → Candidate → Evaluation Plan → Judge → Canary → Promote/Rollback is the same flow; this spec is its in-band form and keeps its must-not list. V1 omits the Canary step (§6.1).
7. **"Admission":** three senses kept distinct. OS-0012 deterministic admission gates (verification), Cortex Signed Admission Receipt (knowledge), capability admission (authority). This spec uses "verified", "admitted to Cortex", and "granted" respectively.
8. **Rollback:** automatic pre-commit fallback vs operator-only post-commit rollback (§5.3).
9. **Learning only via promotion:** the empirical optimizer's online updates live in a working copy and take effect only when a Candidate carrying them is promoted (omega #57/#60). V1 does not mutate the cost model at all (§2.3).
10. **Oracle stability:** Omega must not optimize a primitive whose behaviour is not stable enough to be an oracle (ARCH-0016 §56). V1's workload family is limited to operations with an existing oracle.
11. **OS-0012 rule 10 and rule 6:** rule 10's automatic restore of the most recent known-good Generation applies to OS-0012 whole-machine Generations and live-capability health; it is not an Arena power, and the Arena may neither trigger nor suppress it. Rule 6's inactive-slot plus canary promotion is not used in V1 (§6.1).
12. **candidate:** the Arena **Candidate** (sha256 `candidate_id`, many per run) vs the `rx_generation` store candidate (u64 id assigned by `rx_gen_propose`, at most `MAX_CAND` slots, and the `CANDIDATE` journal phase) vs omega #60's "candidate &lt;commit&gt;" wording. Only the ELIGIBLE winner becomes a store candidate; the promotion record binds the two ids (§2, §5.4).
13. **lineage:** the spec's Lineage graph / `lineage_root` vs the `rx_generation` `lineage` counter (`rx_gen_active(..., lineage)`). Unrelated.
14. **parent:** header `parent_ids[]` (ancestry in the Lineage graph) vs store `parent_id` (the active generation a store candidate was proposed against; the `RX_GEN_ERR_STALE` check).
15. **PROPOSED / REJECTED:** Candidate statuses (§2.2) vs the ADR 0015 §14 Evidence lifecycle states of the same names. Context names which is meant; Evidence states are only used in §4.4.
16. **I-numbers:** ADR 0016 invariants I1–I16 (used unqualified in this spec) vs ARGUS-1 spec I1–I5 (always written "ARGUS-1 I…"); ADR 0017 uses finding codes 1–16, not I-numbers.
17. **oracle:** the Omega semantic oracle (correctness reference for a workload) vs ADR 0016 Part I "legacy orchestrated paths become the reference oracle" (a migration reference). This spec means the former.
18. **ADR 0006 / ADR 0017:** aien-architecture's ADR 0006 is "Production Secrets Are Vault-Only"; the offline operator authority cited via ADR 0015 §9 is aienos `docs/adr/0006`. Likewise aienos `docs/adr/0017` is the M5 key hierarchy ADR, while ARCH-0017 (ARGUS) is merged on main.

---

## 8. What follows this spec (informative; not frozen)

This section is informative only and authorises nothing. Any build needs its own approved plan after every §0.1 row has closed. The research document's EA numbering maps onto this spec as follows:

```text
EA0  candidate identity / lineage          (§2, §3)
EA1  isolated evaluation draft Worlds      (§1, §4.3)
EA2  typed Omega mutations                 (§2.3)
EA3  empirical measurement + Evidence      (§4.4)
EA4  sealed holdout + judge                (§4)
EA5  promotion integration + hostile tests (§5, §6.5)
EA6  restart + transfer proof              (§6.3 11–13)
```

Whatever plan is later approved, one owner should control the three shared schemas (`AIEN_ARENA_CANDIDATE_V1`, `AIEN_ARENA_EVIDENCE_V1`, `AIEN_ARENA_EVAL_V1`), and no piece of work may define a parallel Candidate, Evidence or World identity. Language rules are in §0.
