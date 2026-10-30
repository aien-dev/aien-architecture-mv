# Physics-0 learning machinery and sealed controls: Milestone 0 inventory

Scout, read-only. Pins: omega 16e729b (only src/physics0, tests/physics0, docs/physics0, mk/physics0*.mk, evidence/physics0 read), physics 8b23e5a, aien-sealed 3a6659dc. Nothing was built or run; `make -n` only. Paths are relative to the repo named; `O:` omega, `P:` physics, `S:` aien-sealed/brownian.

## Classification table

| Capability | Class | Anchor |
|---|---|---|
| Black-box world, bounded interventions, budgets, hash-chained records | Implemented and integrated | O:src/physics0/pd0_world.c:42-102 |
| Generator isolation from learner (symbol check) | Implemented and integrated | O:tests/physics0/isolation.sh:12-15 |
| One-step sparse polynomial learner (numerical + symbolic, MDL) | Implemented and integrated | O:src/physics0/learner/pd0_learner.c:21-30,126-180 |
| Independent ladder checker (T1..T7), scorer, negative controls | Implemented and integrated | O:src/physics0/ladder, score, controls; mk/physics0-verify.mk:7 |
| Experiment planner (active vs passive) | Implemented, partly integrated (learner has a stand-in; real planner is bridged in tests only) | O:src/physics0/planner/pd0_planner.h:1-8; learner.h:57-61; mk/physics0-planner.mk:5 |
| Held-out score with 1.5x extrapolation box | Implemented and integrated | P:docs/PD0_HIDDEN_EQUATION_BENCHMARK.md:206-210; O:src/physics0/score/pd0_score.c:44-67 |
| PD-0b sealed run (external world, final/audit protocol v2) | Implemented and integrated; seal-1 result FAIL | O:docs/physics0/PD0_PROTOCOL_V2.md; P:evidence/PD0B/PD0B_VERDICT-seal1.json:6 |
| Latent (hidden) state recovery | Missing in learner (flag only, unreliable) | O:docs/physics0/LEARNER.md:133-137 |
| Multi-step consistency in candidate ranking | Missing | O:docs/physics0/LEARNER.md:135-136 |
| Hidden-state suspicion flag | Experimental | O:src/physics0/learner/pd0_learner.c:180 |
| PD-1 machine-record view (unchanged learner on real machine logs) | Experimental, development evidence only | O:mk/physics0-pd1.mk:1-3 |
| Brownian sealed lifecycle (freeze, one-attempt ledger, sealed parent, leak oracle) | Implemented and integrated (private repo, separate domain) | S:src/brw_protocol.h:94-170 |
| EXP-003-CERT w2.v1 | Frozen on paper (receipt R3-66); no qfreeze or sealed world exists; waits for Drake | S:wave2/W2V1_FREEZE_RECEIPT.md:3,5,57 |
| Changed dynamics between episodes (drift, regime switch, version bump) | Missing | see section 6 |
| Fixed-vs-updating learner comparison | Missing | see section 7 |

## 1. Components of omega/src/physics0

- `pd0_gen.[ch]`: the only place the hidden equations live; levels L0..L6 plus NULL (`pd0_gen.h:1-5`, enum `:15`). Constants drawn once per seed from declared ranges (`pd0_gen.c:20-35`); L6 has one hidden variable h (`pd0_gen.h:28`), equations at P:docs/PD0_HIDDEN_EQUATION_BENCHMARK.md:142-144 (`s0'=s0+s1*dt; s1'=s1+(-k*s0+m*h+u)*dt; h'=h+(-w*h+q*s0)*dt`), h = 0 at every reset (`:141`, `pd0_world.c:60`).
- `pd0_world.[ch]`: describe/reset/step, budgets (3000 steps, 300 episodes; 8000 steps for L5/L6 per spec `:111-112`), out-of-bounds ends the episode with nothing revealed (`pd0_world.c:91-96`), episode ends at `episode_max_steps` (`:100`). Runs as its own process over framed pipes (`pd0_world.h:6-9,57-58`; `pd0_world_main.c`).
- `pd0_wire.[ch]`: describe record (PD0DESC2, per-variable reset box), PD0REC1 records with SHA-256 chain. `pd0_rng.[ch]`: SplitMix64 named streams. `pd0_relation.[ch]`: PDLAW1 relations in delta form, degree <= 3, up to 2 latent variables (`pd0_relation.h:16-20`), rollout, NRMSE, law encode/decode (`:41-62,64-107`). `pd0_chan.c`: learner-side handle; the learner never holds a world (`pd0_world.h:6-9`).
- `pd0_guard.[ch]`: STAND_IN range check. A step is ok only if channel is none or `chan_min <= value <= chan_max`; a reset only if every value is inside its per-variable reset box (`pd0_guard.c:3-13`). A refusal is a recorded outcome that still costs the step or episode (`pd0_guard.h:1-6`; `pd0_world.c:53-58,80-84`). Post-step values beyond +-PD0_BOUND (10.0 units, PD0_PROTOCOL_V2.md:50) are caught by `pd0_guard_in_box` (`pd0_guard.h:21`).
- `learner/`: see below. `ladder/`: independent checker that replays the evidence ledger and derives the state itself (`pd0_ladder.h:1-2`), thresholds `min_t1_records 100, min_prereg 5, min_batches 3, min_batch_episodes 10, rollout_steps 20` (`pd0_ladder.c:29`); void rule for out-of-bounds trial episodes (`:265-269`); T6 trial failure -> refutation (`:331`), T7 batch failure (`:355`). `ladder/pd0_fmt.[ch]` holds byte layouts shared with learner (no generator). `score/`: scorer holds truth, never linked to a learner (`pd0_score.h:1`); checks degree, size, bits, support, constants, in-box/extrap/one-step NRMSE, and for L6 a latent requirement plus "latent-free reference must fail by factor" (`pd0_score.c:44-67`). `controls/`: negative controls NC-1.. (`pd0_controls.h:1`), receipts (`pd0_receipt.c`). `planner/`: proposes PD0EXP1 preregistrations only, no execution path (`pd0_planner.h:1-8`).

**Learner model class (numerical AND symbolic).** One-step change of each observed variable is regressed on every monomial of total degree <= 3 over observed variables and channels (`pd0_learner.c:21-30`; `LEARNER.md:39-46`). Forward selection with backward pruning, up to 10 terms per equation (`pd0_learner.h:17`; `pd0_learner.c:126-155`), scored by MDL = n*log2(rmse_micro) + 8*(n_vars+n_channels)+24 bits per term (`pd0_learner.c:122-124`). Up to 8 candidates incl. an explicit null and runner-up rivals, re-ranked on SELECT (`pd0_learner.h:16`; `LEARNER.md:53-58`). Floats only inside fitting; all emitted numbers are micro-unit integers evaluated by the checker's integer stepper (`pd0_learner.h:7-9`; `LEARNER.md:44-46`). No latent variables are ever fitted (`LEARNER.md:133-136`).

**How generator truth is kept from the learner.** (a) The learner accepts only FIT and SELECT tagged records and refuses everything else (`pd0_learner.c:44`, I10); HOLDOUT/TRIAL/REP never reach it (`pd0_harness.c:193-197`; `pd0_learner.h:5-6`). (b) `isolation.sh` greps learner objects for any `pd0_gen_`, `pd0_world_`, `fopen/open*` symbol (`isolation.sh:12-15`), wired into `test-physics0-learner` via `p0l-isolation` (`mk/physics0-learner.mk:37-38,62`). (c) Learner and checker link only verifier byte formats; world and truth run as separate processes (`LEARNER.md:30-35`). (d) PD-0b protocol v2: shape terms and score are refused until `final` is accepted once; play ops refused after final; all refusals counted (`PD0_PROTOCOL_V2.md:35-40,59-64,94-96`).

**How interventions are bounded.** Describe record gives `chan_min/chan_max`, reset box, `episode_max_steps`, step and episode budgets (`pd0_learner.h:20-26`); guard enforces them (above); exploration and the stand-in planner only draw inside the bounds (`pd0_learner.c:55-61`; `pd0_learner.h:57-60`); a planner request outside bounds is a gate failure (spec `:307`).

**Separate experimental evaluation path.** Ladder: falsifier declared and hashed before TRIAL data (spec T4 `:177`), >=5 preregistered planner schedules not in FIT/SELECT/HOLDOUT (T5 `:178`), trials within eps (T6 `:179`), >=3 fresh REP batches of >=10 episodes, half planner, half random (T7 `:180`). Scorer runs 20 noise-free truth episodes (10 in-box, 10 at 1.5x) via protocol op 3 after final (`LEARNER.md:76-77`; `PD0_PROTOCOL_V2.md:42-57`). Exploration split per five episodes: FIT FIT FIT SELECT HOLDOUT (`pd0_harness.c:193-197`).

## 2. Documented limitations (quotes)

- Latent state: "Not implemented: Latent-variable fitting, local refinement in the planner (Direction 5), multi-step consistency in candidate ranking, PD0DESC2 parsing beyond the assumed per-variable layout." (O:docs/physics0/LEARNER.md:133-137)
- "L6 (hidden variable). Candidates are latent-free fits; ... the trials or batches exceed eps, which is the honest outcome for a wrong model class. `hidden_state_suspected` did not fire on L6 because the latent-free fit's one-step residuals are small (0.001 to 0.005); the flag needs a rollout-based test, left for the next cut." (LEARNER.md:103-109)
- Dev table: "L6 | CANDIDATE 5/5 (3 refutations each) | FAIL 5/5 (307 latent missing, 308 reference too good) ... reported, not claimed: no latent mechanism" (LEARNER.md:93)
- Flag definition: fires if any |lag-1 residual autocorrelation| > 0.3 AND fit one-step NRMSE > 5000 micro (`pd0_learner.c:180`). The recorded dev run `evidence/physics0/learner/pd0-learner-dev-b1ae4f609128.txt` shows `hidden_state=1` on L6 seeds 2-5, contradicting LEARNER.md:106-108. UNVERIFIED which commit each describes (confidence 60 percent the doc is older than that receipt).
- L6 pass rule open: "the factor-3 reference margin is still open with Drake; the learner reports L6 and claims nothing." (LEARNER.md:120-121). Spec: factor-3 margin met on 3 of 5 calibration seeds only; "until then L6 cannot pass" (P:docs/PD0_HIDDEN_EQUATION_BENCHMARK.md:240,370).
- Noisy-level reset binding gap (LEARNER.md:122-126; `pd0_ladder.c:138`). Batch top-up not implemented (LEARNER.md:110-112).
- Multi-step is used only by the checker (20-step rollouts for T6/T7, `pd0_ladder.c:29,309,350`); the learner ranks by one-step residual bits plus description bits (`pd0_learner.c:172-179`), so a one-step-good, rollout-bad model is not penalised at ranking time (inference from those lines; confidence 85 percent).
- Spec header is stale: line 3 still says "No code exists yet" (P:docs/PD0_HIDDEN_EQUATION_BENCHMARK.md:3) though the code and receipts exist.
- No hits in src/tests for TODO/KNOWN; "FAIL" hits are test harness strings.

## 3. Tests (omega)

Build/run lives in `mk/physics0*.mk`, included by `Makefile:5`, output in `build/` (`Makefile:4`). No run times are stated anywhere I found (UNVERIFIED; none measured).

| Target | Programs | Proves | Deterministic |
|---|---|---|---|
| `make test-physics0-learner` (`mk/physics0-learner.mk:62-67`) | isolation check; `tests/physics0/learner/test_pd0_learner.c` (plain + ASan/UBSan); `test_pd0_protocol_v2.c`; `test_pd0b_run.sh` | learner determinism (byte-identical reports and PDLAW1 round trip, `test_pd0_learner.c:43-50`), cubic world not fit by null and size <= 6 (`:52`), held-out theory error < 0.02 (`:59`), protocol v2 ops and refusal states | seeded streams; yes |
| `make physics0-test` (`mk/physics0.mk:76-92`) | `test_pd0_world.c` (G0, plain + ASan), isolation, `pd0_oracle.c` (V1 oracle all levels, V3 breach rates, mutants), `test_pd0_osc.c` | substrate rules, spec 2.3, oracle recovers every level incl. L6 latent, mutant sign flip is caught, Omega-language differential | seeded; yes. V3 may print FAIL without failing the target (`physics0.mk` comment, README:29) |
| `make test-physics0-verify` (`mk/physics0-verify.mk:7,31`) | `verify/test_pd0_fmt.c`, `test_pd0_ladder.c`, `test_pd0_score.c`, purity | verifier formats, ladder rules, scorer plus negative controls; per PD-0b verdict: 25 + 148 + 103 checks (P:evidence/PD0B/PD0B_VERDICT-seal1.json:14) | yes |
| `make test-physics0-planner` (`mk/physics0-planner.mk:65`) | `planner/test_pd0_planner.c`, `pd0_plan_eff.c`, `pd0_plan_eff2.c` | planner contract behaviours 1-6, purity, active vs passive information efficiency (dev evidence) | seeds 1..5 |
| `make physics0-learner-dev` (`physics0-learner.mk:70-74`) | `pd0_harness.c` + `pd0_truth_main.c` + world | full ladder run per level L0..L6 + null, seeds 1..5; writes `results.txt` | yes |
| `make physics0-pd0b-run PD0_WORLD_BIN=.. PD0B_SEEDS=..` (`:83-90`) | `pd0b_run.sh`, harness | frozen learner vs external world, new receipt each run, refuses dirty tree | yes |
| `make physics0-pd1-run RECORDS=..` (`mk/physics0-pd1.mk:5`) | `pd1/pd1_run.c` | unchanged learner on machine records, development only | seeded |

Exact baseline command (verified present with `make -n`, not executed): from `~/workspace/adaptive/omega`: `make test-physics0-learner && make physics0-test && make test-physics0-verify`. For learning-quality numbers: `make physics0-learner-dev` (prints one PD0L line per level and seed).

Baseline results on record (evidence/physics0/learner/pd0-learner-dev-b1ae4f609128.txt; LEARNER.md:85-94): L0-L5 REPLICATED 5/5 with scorer PASS; L6 stops at CANDIDATE (code 251, 3 refutations) 5/5; null stays OBSERVATION.

## 4. physics repo (8b23e5a)

- Contracts: `docs/PD0_HIDDEN_EQUATION_BENCHMARK.md` (372 lines). Level table `:104-112`. Acceptance (6.1): in-box NRMSE 0.02, extrapolation 0.06, one-step 0.01 for L0-L5; L6 0.03 / 0.08 / not scored (`:206-210`). L5 trial eps capped 0.05 (`:214`). Size bound |R| <= S*+2 (`:218`). Constants within 5 percent (L0-L4), 10 percent (L5), L6 coefficients unscored but latent required and latent-free reference must fail by factor 3 (`:236-238`). Ladder T1..T7 `:158-183`. Planner contract `:294-307`. Negative controls NC and M1-M5, positive control V1 `:313-332`. All thresholds labelled provisional/UNVERIFIED (`:3,372`).
- `docs/PD0B_SEALED_BENCHMARK.md` (63 lines): sealed families, commit then freeze then run then reveal (`:37-49`), author separation (`:26-35`), only allowed claim on PASS (`:55`). Inherits every threshold, adds none (`:14`).
- `docs/PHYSICS0_DISCOVERY_ENGINE.md` (107 lines, overview; not read in detail). Also `docs/PD1_MACHINE_LAW_BENCHMARK.md` exists (not read).
- Executable components in physics repo for PD-0: none found (`find -ipath '*pd0*'` shows only docs and evidence/PD0B); code lives in omega.
- PD-0b seal-1 evidence: `physics/evidence/PD0B/PD0B_VERDICT-seal1.json`. Verdict FAIL (`:6`); first failing: level index 6 failed 0 of 5 (`:7`); levels 0-5 each 5/5 REPLICATED, PROVISIONAL_LAW, scorer PASS (`:9,23-28`); level 6 `law_record_states: REFUTED x2, HYPOTHESIS x3`, scorer code 307 (`:29`); learner commit f9a1797, harness 965edfb (`:18`); open items: factor-3 margin, "the learner has no latent-variable mechanism", second seal needed (`:34-37`). Supporting: `PD0B_COMMIT-seal1{,b,c}.json`, `PD0B_FREEZE-seal1.json` (freeze 01:26:04Z before run 01:57:28Z, verdict `:12`), `PD0B_VALIDITY`, `PD0B_REVEAL` (43 of 43 hashes match, verdict `:11`), omega run receipts `evidence/physics0/pd0b/PD0B_RUN-965edfbf35e9-58c1fac11f47.txt` and `...d3a4063dc1a3...` (with laws). Memory claim confirmed. Note: ladder stop reasons were INTERVENED x3 (T7 batch too small, code 261) and CANDIDATE x2 (T6 failed, 251) (verdict `:7`).

## 5. aien-sealed/brownian (3a6659dc): sealed evaluation protocol

Domain note: Brownian is a different task (choosing observations/policies and predicting held-out points of diffusion, drift and mean-reverting processes, 3 families D0/D1/D2, `S:src/brw_world.h:11`), not Physics-0 dynamics. Reusable as a protocol, not as a learner.

- Lifecycle (`S:src/brw_protocol.h:1-18`): dev worlds (step 2, `:94-100`), freeze (step 5, `:102-119`: artifact digest, qprofile, devman, calibration digest into qfreeze), seal (steps 6-7, `:121-133`: refusals for no qfreeze, artifact digest mismatch, qprofile mismatch, hostile cell, dirty tree; "one-sealed-attempt ledger (O_EXCL)", second attempt is STOPPED, `:17-18,131`), gain/score (steps 8-9, `:136-176`). Files are digest-named, write-once, mode 0444 (`:9-10`; `brw_write_excl` `:54`).
- Holdout separation: held-out points per world H (`brw_cellinfo`, `:62`); scoring is fit-once on the prefix (`brw_predict.h:2-3`); PRD1 bytes are the only scoring path (`brw_protocol.h:136`). Leak oracle regenerates true parameters from the sealed seed and fails the run if the oracle beats the candidate (`:152-160`). Hostile cells are development only, never sealed (`:64-65`).
- Candidates cannot touch holdout: certification candidates are reference opcodes; discovery candidates run in a bwrap sandbox with a frozen argv and line protocol (`:162-171`); packet scanner and seed scan refuse leaked seeds (`:173-178`); sealed parent derives from the qfreeze digest (`brw_sealed_parent`, `brw_protocol.c:994,1253`; W2V1_FREEZE_RECEIPT.md:57). EXP-003 contract: posterior mixture weights fixed at stop, "no learning from held-out points" (S:wave2/EXP-003-CONTRACT-DRAFT.md:136); DISC references rerun on fresh worlds (`:137`).
- Replication separation: `w2_cert verify` recomputes everything from stored files, `replay` regenerates from scratch and compares (`S:src/w2_cert.c:3-6`); `dryrun` mode has the development parent and no path to the sealed parent (`:8-11`); fault hooks active only in dryrun (`:13-15`); dev worlds never reused (receipt `:57`).
- EXP-003-CERT w2.v1 freeze state: FROZEN by decision R3-66, 2026-10-10 (`R2_INTEGRATOR_DECISIONS.md:517`; receipt `W2V1_FREEZE_RECEIPT.md:3`). Frozen set hashes at receipt `:13-21` (profile 54418df9..., thresholds 30e66c77..., evaluator tree content 7f4d6712..., omega scorer pin 2564f57, N7 receipt cdca1cec...). Receipt says "no qfreeze, no sealed parent, no seed and no world value; none exists yet" (`:5`); gates G1-G13 table `:53-67` (G1 omega digest PR was an OPEN ITEM at record time, `:55`; fault injection 341 boundaries, 0 reached PASS, `:61`). Contract file itself still carries a DRAFT header (`wave2/EXP-003-CONTRACT-DRAFT.md:3`; receipt `:23` says acceptance is R3-62/R3-63). Sealed run waits for Drake per memory (not verifiable from these files). Cap: profile 1 of 3 (`:49`).

## 6. Changed dynamics between episodes

**Missing.** Evidence: constants are drawn once at `pd0_gen_init` per seed (`pd0_gen.h:42-45`, `pd0_world.c:11-18`); the world holds one `gen` for its whole life (`pd0_world.h:34-35`); `grep -iE "drift|regime|non-stationar|version bump|between episodes"` over src/physics0, tests/physics0, docs/physics0 returns only an episode-numbering check (`pd0_harness.c:91`). Hits in physics repo are hardware sensor drift (forge) and in Brownian a DIFFUSION_DRIFT statistical model (mean drift of a random walk, `S:src/brw_predict.h:15`), neither is environment change between episodes. Adjacent hooks that make adding it small: single-process world with explicit `pd0_world_reset` (`pd0_world.c:46-70`), protocol v2 `final/audit` counters, `pd0_gen_init(level, seed)` (a regime switch could re-init constants mid-run, but nothing does). The Brownian "B2-emerging" label (`brw_stats.c:420`) concerns a within-trajectory property; UNVERIFIED whether it is a regime change (not read, confidence 40 percent it is not).

## 7. Fixed-vs-updating learner comparison

**Missing.** Closest pieces: (a) the learner refits after a refutation, moving TRIAL records into FIT, up to three attempts (`pd0_harness.c:199,230`; `LEARNER.md:74-75`), which is a within-run update but never compared with a frozen counterpart; (b) planner efficiency compares active vs passive schedules, not fixed vs updating models (`tests/physics0/planner/pd0_plan_eff.c:1-12`); (c) PD-0b freezes the learner by commit (`PD0B_SEALED_BENCHMARK.md:39`). No test has a fixed relation scored on later dynamics against a refit one.

## Smallest defensible improvement candidate (partially observed prediction)

Add a rollout-based residual check to candidate ranking and the hidden-state flag: score each candidate by 20-step rollout NRMSE on SELECT episodes (reuse `pd0_learner_rollout` `learner.h:65`, which already exists and carries latent from 0) and use it in `cand_cmp` / the `hidden_state_suspected` rule at `pd0_learner.c:180`. Motivating quote: "the flag needs a rollout-based test, left for the next cut" (LEARNER.md:108-109) and "Not implemented: ... multi-step consistency in candidate ranking" (LEARNER.md:135-136). Acceptance: public L6 seeds 1-5 flag fires on 5/5 and L0-L5 and null do not; frozen PD0B trees (learner, ladder, score, controls) would change, so it must be a new learner version, not a seal-1 amendment (`PD0B_FREEZE-seal1.json`).
