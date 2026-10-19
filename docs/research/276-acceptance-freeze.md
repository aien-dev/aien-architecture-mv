# #276 acceptance freeze and contract reconciliation

Status: PROPOSED (the #276 coordinator promotes it). Qualification: NOT_RUN for this document; it runs nothing.
Date: 2026-10-19. Ledger L060. Branch `research/276-acceptance-freeze` off aien-architecture main 134920d2.
Tracking issue: [aien-architecture-mv#276](https://github.com/aien-dev/aien-architecture-mv/issues/276).
This is a finite workstream record, NOT A MASTER PLAN. It follows `PLAN_AUTHORITY.md`, `CURRENT_EXECUTION_PLAN.md`
and `doctrine/ROADMAP.md`; it changes no milestone status.

Every child freeze below is pinned by full commit sha in aien-dev/omega-mv. Numbers are copied from those files at
those shas and are not re-derived here, except where an `aien-calc` receipt (calc:id) is shown. Where a child has no
number yet, the cell says "pin pending".

## 1. Purpose and what is not claimed

#276 asks for one persistent entity that does the minimum necessary computation for each accepted objective: prove work
unnecessary, reuse a verified result, update only changed dependencies, simplify what remains, and optimize only when
the full lifecycle cost pays back. The children (omega-mv#583, omega-mv#584, aien-architecture-mv#246, #249 and the
entity pilot) each froze their own protocol. This document pins them together, states the contracts between them, copies
their numerical gates in one place and shows the status of every #276 completion line.

Not claimed, by any child or by this document:

- No zero-processing claim. Required timers, IO, display scanout and background activity are reported, never hidden.
- No general-intelligence or general-transfer claim. Every experiment is one bounded suite on one host.
- No global-optimum claim. A search that stops on its budget reports "best found under budget".
- Simulation alone proves nothing physical. #583 outputs are predictions until a held-out measurement checks them.
- No energy claim without a named instrument (section 5).

## 2. Overlap record (Symposium and existing code)

| Item | Source | Pin | Verdict |
|---|---|---|---|
| Symposium crossover matrix | omega-mv `docs/research/276-crossover-matrix.md` | `1cd04c8ecc14c42b5fbcb4fc707311ba344f1da8` (branch `research/cost-sim-583`), posted as [#276 comment](https://github.com/aien-dev/aien-architecture-mv/issues/276#issuecomment-6274721769) | PASS (source observation): no mechanism, file or contract overlap with #583, #584 or #246 |
| Symposium source read | symposium-dev/symposium | `b420d5dc4c71abde973cea8cb4f30ea4c8e76ae0`, open PRs #320 to #361 | as above |
| Agent-guidance work that already took from Symposium | ADR 0038, aien-architecture branch `agents/in-tree-guidance` | `600a7584c277fa02ff3fbea48088e1d0ac07f149` | no overlap with cost, search or reuse paths |

Source observations from the #276 audit, confirmed present on omega-mv main `a8ffd2b912c84197d08f963b05f9c7d8b30a3f8a`
(the base every omega child branched from) on 2026-10-19. These are file-existence and PR-state checks, not reruns.

| Observation | Pin | Role for #276 |
|---|---|---|
| `src/runtime/rx_costmodel.c` fits empirical operation costs with uncertainty | omega a8ffd2b9 | reused by #583 for `kind=matvec` estimates; not replaced |
| `src/runtime/rx_plan.c`, `rx_plan.h`, `tests/runtime/rx_plan_reuse.c` | omega a8ffd2b9 | the E03 cache (#246) and the reuse arm of #584 |
| `src/omega_realize_synth.c` bounded schedule heuristic | omega a8ffd2b9 | #584 realizes every action through it; not an unrestricted synthesizer |
| `src/omega_synthesis.c` probe signatures (6 probe inputs) | omega a8ffd2b9 (#249 cites the same sha) | heuristic grouping only; never authorizes substitution (#249) |
| `src/runtime/rx_cortex.h` record classes and kinds | omega a8ffd2b9 | persisted arm state (section 3.4) |
| GPU simulator work omega-mv PRs #514, #509 | both OPEN on 2026-10-19 | correctness models, not timing or energy |
| FORM0 physics-mv PR #46, ADR 0034 architecture PR #127 | both MERGED | physical-form identity respected where applicable |

Consequence: the "overlapping runtime changes wait for this check" gate in #276 is cleared. No child edits `src/runtime/`,
`src/omega_realize_synth.c` or `src/omega_synthesis.c`; a needed runtime change is a separate reviewed PR through #276.

## 3. Child interfaces (contracts between streams)

### 3.1 Pinned child freezes

| Stream | Ledger | Branch (omega-mv) | Frozen file | Pinned sha |
|---|---|---|---|---|
| #583 offline evidence schema (OEV1) | L050 | `research/cost-sim-583` | `spec/offline-evidence-v1.md` | `5d864920f8355bfa230fbd66975a79e30c66ac6c` |
| #583 DAGSIM held-out precommit | L050 | `research/cost-sim-583` | `evidence/DAGSIM-583-48ca401/PRECOMMIT.md` | `d009a2b0a1ab091c72fb2fd42c2004e99797af12` |
| #584 LS584 freeze | L048 | `research/learning-search-584` | `research/learning-search-584/FREEZE.md` | `9e1824d798cf045fe3a5ca83f03466537a2eed05` (branch head; history fe29edb5, 31c4c028, 9e1824d7) |
| #246 E03 payback protocol | L049 | `research/e03-payback-246` | `evidence/PLAN_REUSE/e03-payback/00-frozen-protocol.md` | `293b49a748a0ea63fd8d71288be016c5c531f8f5` (unchanged at head 503f990f) |
| Entity pilot | L058 | `research/entity-pilot-276` | `evidence/ENTITY-276/FREEZE.md` | pin pending: `research/entity-pilot-276`, `evidence/ENTITY-276/FREEZE.md` |
| #249 checked elimination | L059 | `research/rewrite-elim-249` | `evidence/REWRITE-249/FREEZE.md` | pin pending: `research/rewrite-elim-249`, `evidence/REWRITE-249/FREEZE.md` |

### 3.2 OEV1 records (producer #583; consumers #584, #246, #249, entity pilot)

Pin: OEV1 at omega `5d864920`. Format: plain UTF-8 text, one record per line, `key=value` fields after a record keyword,
`#` comments, unknown keywords are errors with line numbers. Static limits: 256 operations, 32 resources, 256 buffers,
1024 dependencies; a larger DAG is refused (`REFUSED_UNSUPPORTED`), never truncated.

- Units fixed by the schema: time `ns`, bytes `B`, bandwidth `B/s`, power `W`, energy `J`, capacity `B`.
- Every number carries `prov=` one of `specified`, `measured`, `fitted`, `synthetic`, `unknown`, and `src=` for
  measured or fitted values. `unknown` never becomes a number; a result built on `synthetic` is marked `synthetic=1`.
- Records: `oev`, `machine`, `build`, `calibration`, `resource` (compute, bandwidth, capacity, launch), `op`, `dep`,
  `buffer`, `sync`, `energy`, `removed`.
- Refusals a consumer must handle: `REFUSED_STALE`, `REFUSED_NO_CALIBRATION`, `REFUSED_CAPACITY`, `REFUSED_UNSUPPORTED`,
  `REFUSED_REMOVED_REQUIRED`.
- CPU and GPU unified memory are one capacity resource (`unified_mem`) on the Spark.

Consumers: #584 emits one `.oev` per arm (its `oev-emit.sh` at 9e1824d7); #246 maps its per-phase ledger onto OEV1 ops;
#249 and the entity pilot emit OEV1 for their baseline and transformed DAGs (pin pending for both).

### 3.3 `removed` ledger records (producer #249 and every reuse or incremental arm; consumer #583 `diff` and ablation)

Pin: OEV1 at omega `5d864920`. Exact form:

```
removed op=<id> reason=<eliminated|reused|unchanged_dep|deferred|moved|shared|lookup> [ref=<op or result identity>] [proof=<src>]
```

- `eliminated`: #249 supplies `proof=` naming a checkable derivation (rewrite contract, assumptions, checker receipt).
  Probe-signature agreement is not a proof.
- `reused` and `lookup` require `ref=` (the reused result identity, for example a semantic id).
- `unchanged_dep`: the incremental arm names the dependency whose version did not change.
- `deferred`, `moved`, `shared` are not eliminations; #583 reports them separately from work removed.
- A remaining op that depends on a removed op whose reason is not `reused` or `lookup` is refused
  (`REFUSED_REMOVED_REQUIRED`): required work cannot be removed by assertion.

### 3.4 net(H) payback diagnostic (producer #246 and #584 calibration; consumer #584 policy and #263 dossier)

Base formula, from #246 issue text: C one-time acquisition cost, p applicability probability per opportunity, Delta net
saving per applicable use, r per-opportunity retention, H opportunities.

| Case | Formula as frozen in E03 (293b49a7), maintenance m per opportunity |
|---|---|
| 0 < r < 1 | net(H) = p * Delta * (1 - r^H) / (1 - r) - C - m * H |
| r = 1 | net(H) = H * p * Delta - C - m * H |
| r = 0 | net(H) = p * Delta - C - m * H for H >= 1 (one opportunity, then gone); net(0) = -C |

No finite positive payoff (m = 0, 0 < r < 1) when C >= p * Delta / (1 - r). Break-even (m = 0, 0 < r < 1):
H* = ceil( ln(1 - C(1 - r)/(p Delta)) / ln r ) when the argument is in (0, 1]. Every closed-form value is checked against
the direct finite sum with an `aien-calc` receipt.

How each producer defines the inputs (copied, not merged):

| Input | #246 E03 (293b49a7) | #584 LS584 (9e1824d7) |
|---|---|---|
| unit | seconds per task, wall e2e primary, thread CPU beside it | CPU ns (thread CPU) |
| C | identify + store + decision + index beyond arm A on the acquiring task | first-solve cost under learning arm minus under A, plus persistence |
| p | accepted reuses / opportunities, dev estimate with Wilson 95% interval | accepted reuses / reuse opportunities (blocks 2 and 5) |
| Delta | e2e_A minus e2e_B on the same instance, dev median and IQR | median A cost on repeats minus median learning-arm cost on accepted reuse |
| r | 1 minus forget events / opportunities | r = h^(1/d), block 5 hit rate h over interference distance d |
| m | lookup + refusals + index publish, charged per opportunity | not in the formula (lookup cost sits inside Delta on hits; misses are not modelled) |

Reconciliation rule: each stream reports net(H) in its own unit with its own input definitions, and states whether m is
included. The #263 dossier does not add, average or rank net(H) values across the two streams. When h = 0, #584's
r = h^(1/d) gives r = 0 and the r = 0 row applies; #584's FREEZE does not state that case explicitly (discrepancy D3).

### 3.5 Persisted arm state through Cortex (producers #584 and entity pilot; owner Cortex)

Pin: `src/runtime/rx_cortex.h` at omega a8ffd2b9; use as frozen in LS584 section 9 (9e1824d7).

- Each retained item is a `CX_CLAIM` class record of kind `CX_K_CANDIDATE` (LS584 payload: version word, key, semantic
  id, program body words).
- Promotion only through `cx_promote` after verified reuse, which appends `CX_K_PROMOTION` with links {candidate,
  evidence}; the evidence is a `CX_EVIDENCE` / `CX_K_EVIDENCE_REF` record carrying the realization id.
- Reload only through `cx_open` (replay and digest verification). A candidate without a promotion loads as CANDIDATE;
  with one, as VERIFIED. A corrupt or torn journal is refused and the arm starts from empty state (counted).
- No independent store, no second journal format, no bypass of Cortex promotion.
- Entity pilot record kinds: pin pending (`research/entity-pilot-276`, `evidence/ENTITY-276/FREEZE.md`).

### 3.6 Goal object for the bounded command adapter (producers #584 and entity pilot; owner rx_plan / ALLEN)

Pin: `src/runtime/rx_plan.h` at omega a8ffd2b9, object type `PL_OT_GOAL` with five fields in this order:
0 seq, 1 kind, 2 max steps, 3 energy budget, 4 facts ref (facts in a separate `PL_OT_GOALFACTS` object, eight packed
facts). The LS584 adapter (FREEZE section 11 at 9e1824d7) maps bounded text commands onto exactly these five fields and
nothing else; malformed or ambiguous commands get clarification or abstention and never commit (8 preface commands per
stream). The entity pilot's use of this layout: pin pending. ALLEN interface ownership is unchanged.

### 3.7 Ablation ladder (owner per row)

| Row | Owner | Status on 2026-10-19 |
|---|---|---|
| incumbent (no elimination, no reuse, no incremental) | #584 arm A; #246 arm A | frozen (9e1824d7, 293b49a7), NOT_RUN |
| elimination only | #249 | pin pending: `research/rewrite-elim-249` |
| reuse only | #246 arm B; #584 arm B | frozen, NOT_RUN |
| incremental update only | #584 (combination and policy owner) | not frozen in LS584 at 9e1824d7; pin pending |
| combined | #584 | not frozen in LS584 at 9e1824d7; pin pending |
| optimization overhead (search, check, storage, maintenance charged) | #584 policy, costed by #583 | partial: LS584 section 6 charges search and persistence |
| stop-search control versus bounded always-search | #584 policy | pin pending |
| fixtures and evaluation of every row | #583 (`tools/dagsim` eval, pareto, diff) | evaluator at omega d8c74201 |
| entity pilot | entity pilot | NOT_RUN for ablations by design |

## 4. Budgets and held-out gates (numeric, copied with source sha)

### 4.1 LS584 bounded learning search (omega `9e1824d798cf045fe3a5ca83f03466537a2eed05`)

| Item | Frozen value |
|---|---|
| Arms | A incumbent, B existing verified reuse, C0 (no composition), C1 (full C); one C variant carried to sealed |
| Search budget | at most 524,288 candidate evaluations per objective (2^19, calc:70a8150aa8194d4e24745f90421284ff38b84d32aa5ac008e888d1eb4361d53e); covers the 518,480-program space (calc:4d6c80822fbac0928f9f4a32b358321db56ad7f1d62012b8906bb71562bdfbe1) |
| Realization budget | at most 4 `omega_synthesize_for_dgx_spark` calls per objective |
| Action length | at most 6 steps |
| Table capacity | 32 entries (PL_MAX_TEMPLATES), no eviction |
| Stream | 8 preface commands plus 240 objectives (64+48+32+32+24+24+16, calc:455e734eae4946cc8574abdd5390bdb57e96376f8aba0a92e19794548ec5e3cc) from a 64-key pool |
| Seeds (xorshift64*) | development 0x5841, 0x5842, 0x5843; calibration 0x5851, 0x5852, 0x5853; sealed 0x5861 to 0x5865 |
| Selection | C variant chosen on calibration only, recorded in `SELECTION.md` before sealed run |
| F1 semantic | 0 commits whose realization disagrees with examples; 0 commits without passing verification |
| F2 per sealed stream, per arm | success / objectives >= 0.90 and wrong commits <= 2 |
| F3 stale or wrong memory control | 0 wrong commits |
| Controls | shuffled feedback, disabled learning (bit-identical to A), stale or wrong memory, unseen composition |
| Mutants | M1 flipped immediate, M2 swapped retained program, M3 corrupt journal word; each must give bad rows > 0 |
| Restart | cut after block 4, reopen journal, blocks 5 to 7 continue; counts equal an uncut run |
| Retention interval | "112 to 136 objectives" as written (see discrepancy D2) |
| Energy | UNMEASURED |

### 4.2 E03 lifecycle payback (omega `293b49a748a0ea63fd8d71288be016c5c531f8f5`)

| Item | Frozen value |
|---|---|
| Arms | A no reuse (A* every task), B existing reuse; C (#584 arm) only if runnable when the held-out run starts |
| Development partition | seeds 200 to 211 (12 per shape); H_dev = 12 tasks per shape |
| Held-out partition | seeds 300 to 339 (40 per shape); H = 40 tasks per stream |
| Shapes | REVERSE (tower of 6), MERGE (two towers of 3), OTHER (tower of 5, never seen in development) |
| Streams | S1 repeated, S2 held-out bindings and compositions, S3 interference, S4 changed preconditions, S5 stale generations (bump every 4 tasks), S6 restart |
| Controls | P+ (S1 MERGE, H = 40, expected positive), P0 (generation bump every task, expected negative), stale, corrupt |
| Mutants | M1 ledger drops identify+store, M2 reload skips semantic-id check, M3 sign detector reads A as B |
| Floors (per task; any violation fails the arm on that stream) | F1 goal holds; F2 plan length B equals A; F3 evidence present equals required and crumbs verify; F4 false applicability = 0; F5 no STALE template accepted, no corrupt record stored |
| Break-even | smallest H with cumulative (A minus B) >= 0 |
| Prediction (#262) | p, r, Delta, C, m from development only, in `01-prediction.json`, committed before the held-out run |
| Stopping rule | one held-out run per stream at frozen H; no re-runs to improve a number |
| Energy | UNMEASURED (no package counter on this kernel; UPS step 10 W x 2 s = 20 J against an expected per-task delta below 1 mJ, as stated in the protocol) |

### 4.3 DAGSIM held-out precommit (omega `d009a2b0a1ab091c72fb2fd42c2004e99797af12`)

| Item | Frozen value |
|---|---|
| Fitting set | M1 block4 rows gb=1 threads=1 (T1 median 0.1117 s) and threads=8 (CAP median 65.4 GB/s) |
| Held-out set | k = 2, 3, 5, 6 at 1 GB, 10 reps each; k = 4 and k = 16 excluded from gates |
| G-err | relative error of predicted versus measured median <= 25% on 4 of 4 held-out k |
| G-cov | evaluator [lo, hi] contains the measured median on at least 3 of 4 held-out k |
| Controls (not gated) | nearest-k lookup from block4; spec roofline max(T1/k, 2 GB / 273 GB/s) |
| Selection regret | NOT_RUN for this family (one candidate per k) |
| Energy | UNMEASURED |

### 4.4 Entity pilot gates (omega-mv#584 "Additional gates"; numbers pin pending: `research/entity-pilot-276`, `evidence/ENTITY-276/FREEZE.md`)

1. Same identity and history with the view open, detached, reattached and after restart; no shadow memory authority.
2. No redundant inference, search or application redraw on the unchanged-state control; required IO, timers and
   scanout disclosed separately.
3. Changed assumptions and human corrections invalidate the relevant shortcuts; output correctness and response floors kept.
4. Ablations isolate elimination, reuse, incremental update and their combination, with construction and optimization
   costs, failures and storage (owned per section 3.7; the pilot itself reports NOT_RUN for ablations).
5. Retained verified knowledge reduces cumulative cost on held-out repeated tasks, or an explicit negative verdict is recorded.

### 4.5 #249 checked elimination (acceptance from #249 issue text; numbers pin pending: `research/rewrite-elim-249`, `evidence/REWRITE-249/FREEZE.md`)

1. Budgets and held-out cases frozen before measuring.
2. Invalid assumptions and mutants rejected.
3. An independent derivation checker accepts every deletion or rewrite.
4. Same accepted outputs and contracts as the incumbent.
5. Total search plus checking plus execution cost and memory measured, not expression size alone.
6. Derivations cached under their assumptions and invalidated on changed semantics.
7. A timeout reports best found under budget, never "globally optimal". The E04 dependency and existing gates stay.
8. Required negative cases: sqrt(x*x) without a sign assumption, overflow-domain mismatch, floating-point reassociation.

## 5. Shared evidence rules (all children)

- Fields per run, in each campaign's append-only `evidence/<CAMPAIGN>/README.md`: date, host, head sha, command, load
  average and MemAvailable at start and end, instrument, result, claim_strength (proven_in_scope, measured, inferred,
  unresolved), verdict (PASS, FAIL, INCONCLUSIVE, NOT_RUN).
- Receipts: every timing of record runs under `quiet-measure flock /tmp/aien-gb10.lock` inside `spark-receipt NAME --`,
  so a receipt JSON lands in `~/yardsticks/receipts/`; the README names the receipt path. Every sum, ratio or
  break-even in a verdict cites an `aien-calc` receipt id, exported next to the evidence.
- Energy: UNMEASURED unless a named instrument covers a steady run of 30 s or more. The UPS wall meter reads the whole
  box at 10 W resolution. Device-only numbers stay device-only. TDP is not a measurement. Synthetic power is labelled
  and never ranked.
- Reinvestment ledger: savings spent on further learning are reported as reinvested and are not also counted as saved
  (E03 definition at 293b49a7: saved_gross, spent_learning, net, reinvested, unfunded).
- A faster incorrect candidate is a failed experiment. Correctness floors are checked before cost is compared.
- Out-of-sample prediction (#262): the prediction, its band and its inputs are committed before the held-out run; the
  result reports predicted versus measured and whether the measurement fell in the band.
- A check counts only after its mutant went red (bad rows > 0). A mutant with 0 bad rows means the check is broken.
- Loaded-box numbers carry their load and are never quoted as quiet-box numbers.

## 6. Completion checklist of #276

| #276 completion line | Status | Where |
|---|---|---|
| Existing-code/PR/Symposium overlap matrix and pinned source links recorded | DONE | section 2; omega 1cd04c8e; #276 comment 6274721769 |
| Child interfaces, budgets and held-out gates frozen before experiments | IN PROGRESS | this document (L060); four pins frozen; entity pilot (L058) and #249 (L059) pin pending |
| Simulator prediction error and selection regret measured on unseen cases under #262 | IN PROGRESS | #583 `research/cost-sim-583` (L050): round 1 G-err FAIL 0 of 4, G-cov FAIL 0 of 4 at omega d8c74201 (source observation, not re-checked here); selection regret NOT_RUN |
| Lifecycle learning payoff reported, including failures and no-payoff regimes | IN PROGRESS | #246 `research/e03-payback-246` (L049) instrumented at 503f990f, held-out NOT_RUN; #584 `research/learning-search-584` (L048) sealed NOT_RUN |
| Native pilot uses existing execution and persistence with qualified fallback and no authority bypass | IN PROGRESS | entity pilot `research/entity-pilot-276` (L058), not frozen |
| #263 receives a reproducible dossier and explicitly bounded verdict | NOT_RUN | format below |

Final verdict format for #263: one table, one line per gate, columns gate, owning stream, frozen source sha, evidence
path, receipt ids, verdict (PASS, FAIL, INCONCLUSIVE, NOT_RUN), claim_strength. No aggregate score, no weighted sum, no
overall percentage. A PASS states the bounded hypothesis it covers. Task completion is reported separately from gates.

## 7. Discrepancies recorded (not fixed here; implementation truth beats this document)

- D1 (#583): `spec/offline-evidence-v1.md` changed after its freeze at 5d864920. Commit
  `7d683ddb903d5b8ff55d521144aa144253e016bf` rewrote the `sync` meaning from "every listed op waits for every other"
  to "declares a barrier op X that completes when every listed op completes". OEV1 says a change to a frozen field is
  a v2. The #583 owner records this as an amendment or a v2; consumers pin 5d864920 and treat `sync` as unsettled.
- D2 (#584): FREEZE section 4 states recall is tested "112 to 136 objectives after first exposure". Block 5 is
  objectives 177 to 200 and block 1 is 1 to 64, so the possible span is 113 (calc:e704c09539b7b23d4f47da2e11249700d5d1ae1afe234d3149d3f286dddda347)
  to 199 (calc:45861d22406838dcf5dfdbab876e15ba9c8b29038ff4902eea755b91a9ec932c). The stated pair equals 177 minus 65
  (calc:d410dd4b3b1048ceef0e767ea67408125f4218c83ea125748f6426464a6804e4) and 200 minus 64
  (calc:6b442279fe82c1f14327dc559f71af0b12671aaae6ec340d713c9328598e688c). The harness (ls584.c at 9e1824d7) picks
  untouched block-1 keys, so realized distances come from the data. The #584 owner confirms before the sealed run.
- D3 (#584): the LS584 net(H) omits the r = 0 case and the maintenance term m; see section 3.4 for the reporting rule.
- D4 (#584): F2 counts all 240 objectives, so at most 24 non-successes are allowed (240 x 0.90 = 216,
  calc:7cacb8e1a0c0a17b4ae23fef11c1c3794c0e74e1ac4c383199e3a7722c9229fe), while FREEZE block 7 (16 objectives) states
  success there "is expected to be low for every arm". This is a recorded expectation, not a change to the floor.
- D5 (#584): FREEZE.md was edited at 31c4c028 and 9e1824d7 after the fe29edb5 freeze. The #584 handoff states no run had
  started then, so these are pre-run refinements. Its header still says "refined 31c4c028"; the pin here is 9e1824d7.
- D6 (#584 and #246): net(H) units differ (CPU ns versus wall seconds). No cross-stream comparison (section 3.4).

## 8. Amendment rule

#583 measured its held-out set before this document was written (omega d8c74201). The rule is therefore in force from
the first commit of this file: after that commit, this document changes only by an appended "Amendments" section, each
entry with date, author, reason and the commit it amends. Filling a "pin pending" cell with the sha of a child freeze
committed before that child's first sealed run is the one edit allowed without an amendment, and the commit message
names the cell. A child's own freeze changes only through that child's AMENDMENTS file.
