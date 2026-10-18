# Necessary-work programme (make the necessary work the limiting factor)

**Status:** PROPOSED. Filed 2026-10-18. Docs only. Nothing in this folder has run on any tier. Every experiment is NOT_RUN.
**Authority:** operator material of 2026-10-18 (Drake Stapleton): the plan `AIEN_Physical_Limits_Project_Plan.md` in this folder, handed over verbatim. Pasted operator material is pre-approved.
**Not a master plan and not a milestone.** `CURRENT_EXECUTION_PLAN.md` owns sequencing and `doctrine/ROADMAP.md` owns milestone status (`PLAN_AUTHORITY.md`). This is one finite workstream feeding Phase E (E1, E2) and Phase H3.
**Feasibility research:** [docs/research/necessary-work-program-feasibility.md](../../research/necessary-work-program-feasibility.md) (anchors verified on GitHub main 2026-10-18; collisions with standing rules and their fixes; what exists per experiment; execution order).

## In plain words

Before making the chip faster, find the work that is not necessary and delete it, prove that what remains is necessary, run the
remainder as close to the hardware's limit as it allows, and never call a slow result "physics" without a proof. Twenty experiments
(E01 to E20), six promotion gates (G0 to G6), one append-only evidence ledger.

## Files

| File | What it is |
|---|---|
| `AIEN_Physical_Limits_Project_Plan.md` | The plan as handed over, unchanged (16 sections, source register G1 to G10, R1 to R7, D1, D2, H1). |
| `README.md` | This front page: status, rules applied, issue map. |

## Rules applied on top of the plan (details in the research note, section 2)

1. Results in SI units: seconds and joules per accepted objective, watts, each beside its physical bound and derivation. Tokens and bytes are supporting facts only.
2. Track C's primary figure is Turing yield T and T/J against our own previous run; "correctly completed objective" is the acceptance gate underneath.
3. No durations: the plan's weeks and day numbers are dropped; phases exit by gates in the plan's order.
4. Papers and outside tools (Nsight, egg, Undermind) are research input only; no published speedup appears in a result; native chip timestamps are the instrument.
5. Role codes map to models: MATH and REVIEW to Fable or Grok; OMEGA, GPU, AGENT, EXP to Opus, Astra on hard bugs; a different model reviews than built.
6. Spark judges every test; `quietlock check` before any GPU run; chip runs are never killed; no Python; no CUDA; the PR desk lands results.

## Order of work

Phase 0 (contracts, pins, three CPU objective families, apparatus check), then E01, E02, E04 on the CPU beside the PREFILL-E2E
critical path, then E09 and E10 in the first quiet chip slot, then E05 to E08 and E11 to E13 by their gates, then E14, E16, E17
(E15 folds into PREFILL-E2E), then E18 to E20.

## Issue map (aien-dev/aien-architecture-mv)

Filled in once the issues are created; see the epic for the live list.

| Item | Issue |
|---|---|
| Epic | (pending) |
| Phase 0 | (pending) |
| E01 to E20 | (pending) |
