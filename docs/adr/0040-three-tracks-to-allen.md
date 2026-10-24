# ADR 0040: Three tracks to Allen: body first, learning layer, own model by teaching

Status: ACCEPTED (Drake, 2026-10-24: "I completely agree with you. Please plan out and proceed as you have laid out", amended the same hour: "I want them to finish what they're doing because it's important ... you're all in your own lanes ... work together as a team").
Date: 2026-10-24
Related: ADR 0038 (names: Aienux kernel, AienOS), ADR 0039 (Aienux written in Omega, C kernel sunset), ADR 0024, ADR 0035 (ALLEN), mind map notes 2026-10-24-one-chip-cpu-and-gpu-as-one-fluid-motion-no-heartb, 2026-10-24-cut-the-movements-bytes-per-token-on-the-35b-and-w, 2026-10-24-the-spark-shaped-model-one-bus-shaped-serving-mode.

## Context (facts with receipts)

- The goal is Drake's own AI (Allen): his own learner, on Omega, on his hardware (north star, 2026-10-03). Borrowed open-weight models are yardsticks and scaffolding, not the product.
- One DGX Spark cannot grow a knowledgeable language model from nothing. Using the whitepaper peak (1 PFLOP NVFP4 sparse, taken as 250 TFLOP/s dense FP8) and an ASSUMED 40% utilization: a 35B-class pretraining run takes about 205 years (calc:aefe6201); a 1B model on 10^12 words about 694 days (calc:9f169f7e); a 0.5B model on 2x10^10 words about 7 days (calc:c591deb5). The peer design calc agrees in kind: a 163B Spark-shaped model from scratch is 42.6 years (calc:5a6211e8). Utilization is not measured; the conclusion does not depend on the exact factor.
- The body already exists and is ours: the Omega engine serves the 35B at 50.5 tok/s, 20.7 ms per step = 168 GB/s = 62% of the 273 GB/s bus (calc:5d25c99d). Host handoff per token is 0.2%. The memory bus is the ceiling under any kernel; the kernel is not on the token path.
- Big models are frozen the day they ship. Learning after training, personal memory and decision-making are where an own system can win on hardware this size; Allen's REFLEX core already beat the best borrowed small model on its held-out exam (aienos#379: 21/26 vs 20/26).

## Decision

Work runs on three tracks plus the house. Every open lane maps to one of them (map: ~/handoffs/2026-10-24-team-map.md). Nobody is cut: each lane finishes its own done-when, lanes help each other, and no new agent starts on work an open lane already covers.

A. BODY first. Finish the Omega engine to the memory ceiling (One Chip L803 frame; motor lanes L310, L312, L313, L314, L354, L355, L356, L371, L375, L376; Omega-as-CUDA-replacement L386/L408/L801; driver L332/L401). Yardstick: tokens per second against the 273 GB/s ceiling, identical tokens on goldens.

B. LEARNING LAYER. The borrowed brain is a rented part on the body; the own effort goes to what it cannot do: Allen's memory (Cortex/World), learning after training measured by Turing yield (held-out bits predicted), the REFLEX decision core, Omegese (lanes L048, L108, L111, L112, L170, Allen lanes). Yardstick: Turing yield per day.

C. OWN MODEL by teaching. Grow own models by distillation and repair-training from the rented brain plus Allen's own data; Spark-shaped (aien-train #21), compact student (#18), experience world model (#19), draft/wormhole L190. It replaces the rental task by task when it beats it on the same goldens. One-off large training may use rented compute if Drake approves it when the pipeline is proven; inference stays sovereign on his hardware. Yardstick: own-model score against the rental.

D. HOUSE. ADR 0039 stands (C kernel frozen, Omega is the kernel language). In-flight kernel lanes (L801, L802 prerequisites, L040) finish their current deliverables. No new kernel subsystem lanes start until tracks B and C have a running mind to house.

Rules for every lane: (1) no number from a model's head: every figure goes through a calculator with a receipt (aien-calc calc:id on the Spark; Wolfram wherever an agent has it); (2) facts others need go on the team board, lasting facts in team memory; message the overlapping lane before touching a shared file; (3) READY lines to the desk; the merge train judges.

## Consequences

- The stand-in brain stays the 35B-A3B FP8 (3B active per token keeps it fast on this bus). No effort goes into making it "ours".
- "Park the kernel" means no new kernel lanes, not stopping anyone: this is the amendment Drake made on the same day.
- The One Chip plan (L803) is a frame, not a second engine: its steps belong to the lanes named in the team map.
- Reversal: if a track's yardstick does not move for a stated period, Drake decides; this ADR does not set dates.
