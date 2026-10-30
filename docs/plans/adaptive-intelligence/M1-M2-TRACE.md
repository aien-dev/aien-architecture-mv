# Milestone 1 + 2: causal trace and acceptance report (host, 2026-10-11)
Written only from receipts and test output already on disk. No test was run for this report. Paths are relative to this directory. B = `baseline/`. Run ids: omega 16e729b6d844 (Milestone 0 baseline) and 24d185057ab2 (after omega#398, G1 Cortex journaling). Everything here is host evidence: `silicon_observed` is false in the R13 receipt, and no silicon gate was run. Nothing here is scientific verification.

## 1. The causal sequence and where each transition is proven
Reaction names: `aien.*` from `src/runtime/rx_aien.h` header comment, `living.*` and `generation.*` from `src/runtime/rx_living.h:5-20` (omega main). R11 = `B/r11.log`. R13 = `B/r13-run2.log` (idle, PASS). EP = `B/cortex-episode-n1-pr398.log` (the omega#398 test, record ids from that run). Chain B and chain A are two separate provenance chains in the Cortex.

| # | Transition | Producer (reaction / object) | Proof (test, phase) | Quoted line |
|---|---|---|---|---|
| 1 | Observation | outside input (demand interval, placement change); `aien.observe` -> belief | R11 steady step; EP CHAIN B (observation is the root, an outside input) | R11: `[*] a steady record is predicted and confirmed; one outlier is not a failure`. EP: `ok   observation  -> cortex record 553 kind 0x10001` |
| 2 | Prediction | `aien.predict`: belief -> prediction | same R11 step; EP CHAIN B | EP: `CHAIN B: hypothesis 651 <- prediction 649 <- belief 648 <- observation 646` |
| 3 | Unexpected result | prediction state PRED_FAILED after a miss streak (`rx_aien.h` enums) | R11 core-class step; R13 POSITIVE costs line (cost on the new cores differs from the confirmed incumbent) | R11: `[*] a failed prediction after a core-class change becomes a hypothesis and a plan`. R13: `R13 costs: incumbent 6775 ns, target 3726 ns, selected 2687243 ps, reference on new cores 4776609 ps` |
| 4 | Hypothesis | `aien.explain`: prediction state -> hypothesis (CORE_CLASS, or DRIFT when nothing else changed) | R11 core-class and drift steps; EP CHAIN B | R11: `[*] a failure with nothing else changed is drift; a second failure refutes it`. EP: `CHAIN B: hypothesis 651 <- ...` |
| 5 | Experiment | `aien.plan` (ACT_RESEARCH, one per untried condition) -> `living.experiment.prepare` -> `living.blackwell.add` (R5 admission, R7 authority) | Hypothesis-driven plan: R11 core-class step. Goal-driven plan: R13 POSITIVE, EP CHAIN A | R11: `... becomes a hypothesis and a plan`. R13: `R13 positive: generation 1 -> 2, recovered 2; served 1312 (131 after promotion), crumbs 2949, GPU claims 16, durable links 11`. EP: `CHAIN A: evidence 1048 <- experiment 1047 <- plan 557 <- assessment 556 <- goal 554` |
| 6 | Evidence | `living.experiment.evidence`: GPU output -> checked sum -> evidence object | R13 POSITIVE (16 GPU claims, 11 durable links); EP | EP: `ok   evidence     -> cortex record 1048 kind 0x10004` and `candidate 1221 has evidence 1048 in its provenance: 1; experiment belief 1049: 1` |
| 7 | Updated belief | AIEN experiment belief (`rx_aien_register_experiment`; EXP_SUPPORTED / EXP_REFUTED) | R13 POSITIVE; refutation path in R11 drift step; EP | EP: `ok   exp-belief   -> cortex record 1049 kind 0x10004`. R13: `aien_final_goal_status: "MET"` in `B/20261011T142755Z-16e729b6d844/R13/rx_living_receipt.json` |
| 8 | Changed later decision | `generation.prepare` -> `generation.promote` (separate subject) -> in-force record read by production | R11 living run; R13 POSITIVE; EP | R11: `A725 record 0 at 6938 ns; X925 under it 4701 ns; X925 new record 3f6db775476a4f99 at 2880 ns (1.63x)`. R13: `generation 1 -> 2 ... (131 after promotion)`. EP: `ok   promotion 2242 descends from candidate 1221` |

How the chains are shaped (stated plainly, no overclaim):
- In R13 the experiment plan is goal-driven: CHAIN A is evidence <- experiment <- plan <- assessment <- goal (the goal is a human input, kind CX_K_WORK_ACCEPTED, per `tests/runtime/rx_r13_cortex_episode.c`). The test does not check that the plan descends from the hypothesis in the Cortex.
- The hypothesis chain is separate: CHAIN B is hypothesis <- prediction <- belief <- observation. The test follows it only up to the hypothesis, not on to the experiment record.
- The hypothesis-driven plan (hypothesis state -> plan) is proven in R11 (core-class step) inside the World, not in the Cortex journal. So the full eight-step chain is shown by joining three proofs (R11 + R13 + EP), not by one unbroken Cortex path.
- The R13 GPU operation is a fixed add used as a physical witness of the authority path; it does not measure matvec cost (`rx_living.h` header). The cost numbers come from the CPU realization.

## 2. Control arms and what each refutes
R13 (`B/r13-run2.log`):
- Control A, `no AIEN -> no plan, no GPU experiment, no candidate, generation stays 1`. Refutes: the improvement happens without the AIEN faculty.
- Control B, `verified candidate 2 refused (RX_GEN_ERR_AUTHORITY); never in force, production stayed on the reference`. Refutes: a verified candidate becomes in force without the promotion authority.
- Control C, `revoked grant -> seat blocked on authority, no claim, no evidence; 770 requests served meanwhile`. Refutes: the experiment runs without its grant, or that revocation harms production.
- Control D, `output generation changed mid-claim -> result refused, no evidence, no candidate`. Refutes: stale GPU output becomes evidence.
- Control E, `crashing candidate refused by the verifier; the promoted generation holds a verified one`. Refutes: an unverified or crashing candidate gets promoted. Its episode line: `generation 1 -> 2, recovered 2; served 19520 (132 after promotion)`.
R11 (`B/r11.log`):
- `[*] control: the same move without AIEN leaves the body on the old record` with `A725 6885 ns, X925 after 192 more requests 4853 ns`. Refutes: the core move alone, with no AIEN, re-realizes the code.
Limit: controls A-E are single runs per run id; they show each link is necessary in this rig, not a statistical rate.

## 3. Item 7 behaviours
- No-op convergence: R11 `[*] no record yet: AIEN watches and publishes nothing`; also `[*] a human goal: unknown, met, unmet -> one plan, then unmet and explored` (a condition already explored is not re-planned) and `[*] a settled failure is relearned, so a later core move is still noticed`.
- Invalidation and quarantine: R14 C, `cycles contained in 7 ms (max 256 activations), 3 containment crumbs, organism untouched; production 4970 during, 102 after` (`B/r14.log`). This is containment of a reaction cycle. R14 A also refuses bad candidates: `A tamper: verdict REFUSED reason 2`, `A semantic: ... reason 4`, `A crash: ... reason 5`, each `generation 1 -> 2 holds verified quad4`. There is no separate quarantine store for beliefs or lessons; none is claimed.
- Admission and budget: R14 D, `3200 lane requests, at most 4 claims at once (cap 4), up to 12 waiting; 3200 published once, 0 lost, 0 duplicated`. R14 E: `seat killed holding lane claim 232; lost once, seat generation 1 -> 2, retry published once, stale claim refused`.
- Cancellation and emergency stop: NOT demonstrated by these receipts. Every operator line reads `stops 0 resumes 0 restored 0 open 0; under stop: commits 0 externals 0 cancelled 0; order ok` (`B/r13-run2.log`), and the receipt says `"stops": 0 ... "activations_cancelled_under_stop": 0`. That shows the stop audit ran and found no stop, not that a stop cancelled work. The stop mechanism and its audit exist in `tests/runtime/rx_r13_living.c` (counts `RX_CRUMB_CANCELLED` with `RX_ERR_HALTED`); no run here exercised it.
- Authority revocation: R11 `[*] AIEN cannot write what it observes; revoked, AIEN stops and the world does not`; R13 control C (above); R14 B `forged/borrowed/revoked/stale/GPU refused ... renewed grant, lanes 117 published`.

## 4. Restart: what survives and what does not
Survives (durable):
- R9 generation store: in-force record, candidate bytes, config, evidence, durable provenance links. R13: `recovered 2`. R14 F, eight crash points, all exit 86 and recover (`B/r14.log`): the first five recover OLD generation 1 (`BEFORE_CANDIDATE_WRITE`, `DURING_CANDIDATE_WRITE`, `AFTER_CANDIDATE_WRITE`, `BEFORE_ROOT_FLIP`, `DURING_ROOT_FLIP`, each `restore REFERENCE`, adapted again) and the last three recover NEW generation 2 (`AFTER_ROOT_FLIP`, `BEFORE_RECEIPT`, `AFTER_RECEIPT`, each `restore RESTORED`). The directive spoke of six crash points; the log shows eight in scenario F (A-F are the six scenarios).
- Cortex journal after omega#398 (EP, test `test-r13-cortex-episode`, 41 checks, `R13_CORTEX_EPISODE PASS: pass 41 fail 0`): `recorder wrote 2549 records, 0 errors`; `journal reopened: 2554 records (was 2554)`; `cx_verify_chain passes after restart`; `cx_recall by the evidence subject returns 22 records, ordered and repeatable`; `journal with one flipped byte is refused at open (rc -4)`; `tampered evidence record: cx_verify_chain fails and the gate refuses`; `2406 protected records (authority, receipts, verification evidence, promotion) byte-identical after restart`.
- Protected-record count depends on run length. A second run on omega main 24d1850 (`B/cortex-episode-n6-main-24d1850.log`) shows 4216 recorded, `4024 protected records ... byte-identical after restart`, and the same 22 recalled. The figure 2667 given in the work order appears in no log on disk and is not used.
Ephemeral (lost on restart, by design today): every AIEN world object (belief, prediction, hypothesis, plan, assessment, memory of explored conditions), reaction state, capabilities, the crumb log. The test prints this: `not in Cortex: live World objects and their field versions, reaction state, capabilities and the crumb log itself (only each crumb's result is kept)`. So after a restart the Cortex can answer why (recall by evidence subject), but the live AIEN will re-explore an already explored condition until memory is rebuilt from Cortex. That rebuild is not built (`inventory/omega-runtime.md`, last section).
Lessons: two lesson records are appended by the TEST: `lesson records appended: evidence-ref 2550 (wrong 2551), candidates 2552 and 2553`. `promotion with a missing evidence record refused (rc -6)`, `... wrong-digest ... refused (rc -1)`, matching evidence accepted, `lesson 2553 is still only a candidate`. Work item N6 owes lesson records written by the body itself.

## 5. Failures and limits
Failure, kept on record:
- R13 run1, load average 5.7, scouts and a compile running (`B/r13-run1-under-load.log`): `R13 mode 5: AIEN never confirmed the incumbent cost`, `R13 E failed verification FAILED: plan 1 search 2 GPU 0 evidence 0 belief 0 ...`, `R13 gate: R13_LIVING_SYSTEM=FAIL`, receipt `B/20261011T142633Z-16e729b6d844/R13`. Control arms A-D and the POSITIVE arm passed in the same run. Documented reason (header of `tests/runtime/rx_r13_living.c`): "`target` is 55 percent of the incumbent cost AIEN confirmed on the old core class ... Both are wall-clock (CLOCK_MONOTONIC) measurements taken at different times, so CPU contention that slows the second more than the first can miss the goal." The check is deliberately unchanged.
- R13 run2, alone (load before 5.71, after 4.75 per the log): `R13 gate: R13_LIVING_SYSTEM=HOST_PASS_NON_SILICON`. I did not re-run to learn how often run1 fails; that frequency is unknown. One pass and one fail are the whole sample.
Limits:
- Silicon gates (`test-r13-silicon`, `test-r14-silicon`) were NOT run. All gate words are HOST_PASS_NON_SILICON; `"silicon_observed": false`. The GPU claims are the stand-in path on this host.
- The Cortex record of an object is keyed by slot index, not identity: `observation record is an outside input about object slot 0`. Slot reuse is not tested.
- Lesson and evidence-ref records are written by the test, not by the body.
- The production R13 program does not attach the recorder. Only `test-r13-cortex-episode` does. `test-r13-host` is unchanged (omega#398 description: "Production R13 program unchanged").
- EP runs a POSITIVE episode only; the Cortex was not exercised across the control arms.
- Emergency stop and cancellation: see section 3; not shown.
- The scenario is one operation (64x256 integer matvec) and one move (A725 to X925). Nothing here shows the loop generalises, learns a changed regime, or beats a fixed policy over time (those are Milestone 3+ and are Missing in `INVENTORY.md`).
- Receipts are `candidate_bound: false` and `candidate_commit: "unknown"` (baseline runs, not a release candidate).

## 6. Reproduce
Setup used for the baseline (`inventory/omega-runtime.md`): omega clone with siblings `../physics` and `../aienos-argus` (symlink to the aienos-argus checkout holding argus.lock b375dcaa2887d), and an aienos clone holding aienos.lock b84c0a67590a9.
```
cd <omega clone>
git checkout 16e729b6d844        # Milestone 0 baseline (R11, R13, R14)
AIENOS_LOCK_REPO=~/workspace/aienos-c793fc-clone make test-r11
AIENOS_LOCK_REPO=~/workspace/aienos-c793fc-clone make test-r13-host   # run it alone; load above ~5 failed once
AIENOS_LOCK_REPO=~/workspace/aienos-c793fc-clone make test-r14-host
git checkout 24d185057ab2        # after omega#398
AIENOS_LOCK_REPO=~/workspace/aienos-c793fc-clone make test-r13-cortex-episode
```
Each run writes a receipt under `build/qual-runs/<run id>/`. Do not run silicon targets without a chip window.
Receipt and log sha256 (computed from the files in this directory):
```
fa601cbc8c49  B/20261011T142516Z-16e729b6d844/R11/rx_aien_faculty_receipt.json  (R11 PASS)
78d0d9e56b78  B/20261011T142633Z-16e729b6d844/R13/rx_living_receipt.json         (R13 run1 FAIL)
46ba69bad971  B/20261011T142755Z-16e729b6d844/R13/rx_living_receipt.json         (R13 run2 HOST_PASS_NON_SILICON)
4952d259c721  B/20261011T142649Z-16e729b6d844/R14/rx_recovery_receipt.json        (R14 HOST_PASS_NON_SILICON)
0ef0b52fede9  B/cortex-episode-n1-pr398.log        (omega#398 branch run, 41 checks)
be42e3acefde  B/cortex-episode-n6-main-24d1850.log (omega main 24d1850 run, 41 checks)
```
The two cortex-episode logs were copied from /tmp (N1 and N6 working logs, compile lines removed) because the work order named no receipt file for them; they are console output, not signed receipts. The N1 log was produced in a pre-merge worktree; the N6 log is from a worktree at 24d1850 whose files were already being edited, so treat it as corroboration only.

## Verdict
GATE 1 (host): PASS with limits listed; GATE 2: PARTIAL (journaling + tamper + restart proven; body-written lessons and production attach open)
