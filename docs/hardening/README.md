# Hardening: plain-English summary

**NOT A MASTER PLAN.** Sequencing stays in `CURRENT_EXECUTION_PLAN.md`; milestone status stays in `doctrine/ROADMAP.md`. This folder explains the hardening decisions in everyday words.

The decision record is [ADR 0025](../adr/0025-execution-transcript-causal-id-resource-contract.md) (status: PROPOSED, 2026-10-01).

## The problem in one paragraph

AIEN already keeps several tamper-evident diaries: Omega's World logs every reaction, ARGUS logs security events, Cortex keeps a memory journal, the trainer keeps a dispatch log, and the kernel writes admission receipts. Each one can prove nobody edited it. None of them can yet be *replayed*: run the same work again from the diary and point at the first step where the second run differs. The ids in those diaries are also not joined up, so a receipt cannot say which outside request caused it. And the three code bases use words like "budget" and "deadline" in different ways; in Omega a missed deadline is only counted, and nothing is actually stopped.

## What ADR 0025 decides

1. **One shared diary format (the "execution transcript", TRN1).** Every subsystem keeps its own diary, but each can be converted into one common format. One checker can then replay any of them and report "matches through step N" or "first differs at step N, in subsystem X". The exact byte layout lives in `aien-protocols`, `specs/execution-transcript/`.
2. **One thread of ids from request to receipt.** Each kind of id (run, request, branch, permission-slip generation, outside action, receipt) is created in exactly one place. Everything else copies it. A component never invents a substitute id.
3. **What is left out on purpose.** Clock time and "which worker thread ran it" are kept out of anything that is compared, so the same work gives the same fingerprint on any schedule. Secrets are never written. Large contents (memory reads, model weights, network data, tool output) appear only as fingerprints; the actual bytes needed for replay sit beside the diary, keyed by fingerprint. Secret inputs are never stored, and a replay says "not run" for those steps instead of pretending they matched.
4. **One set of resource words.** Budget, need, charge, refund, quota, deadline, cancel, overrun and busy each have one meaning. Work is either accepted (and charged) or refused up front with a typed reason (busy, over budget, unknown, quota). After it starts it can only stop with a written record (cancelled or overrun). Cancelling a parent must cancel its children and give their resources back.
5. **Four honesty labels.** Every result says where it ran: **host** (a normal program on a computer), **QEMU** (an emulator), **hardware** (the real machine), or **NOT_RUN** (with the reason). A pass at one level never counts as a pass at a higher level. A pass is never typed into a script by hand; it comes from a check that actually ran. A failing result stays on record.

## Order of work

1. Fix the scripts that write a pass without checking (aienos).
2. Write the shared diary format and a set of good and deliberately broken example diaries (aien-protocols), alongside this decision.
3. Build two independent checkers against those examples: one in C inside Omega, one in Rust in sovereign-core.
4. Carry the request id end to end, and make the kernel write real events (not the synthetic boot-time ones it writes today).
5. Write the resource-contract format and make deadlines and cancels actually stop work.
6. Later: moving live work between machines, faster guessed-ahead inference, hot replacement, self-improvement evidence.

## What was true when the decision was written (2026-10-01)

Nothing in this decision had run yet. Omega and aienos had chained diaries that could be checked for tampering, not replayed. The aienos C kernel had only run in the emulator. These limits are listed in the ADR under "Limits at the time of this decision".

## Later changes (checked 2026-10-19)

- ADR 0025 is still PROPOSED (its status line on `main`).
- The TRN1 folder now exists: [aien-protocols-mv `specs/execution-transcript/`](https://github.com/aien-dev/aien-protocols-mv/tree/main/specs/execution-transcript). This summary has not been rechecked against the omega and sovereign-core checkers.
- The aienos C kernel has since run on real hardware: a Raspberry Pi 5 on 2026-10-13 (see the [aienos README](https://github.com/aien-dev/aienux#readme)) and a 2017 Intel iMac from 2026-10-17 ([aienos-mv#405](https://github.com/aien-dev/aienux/pull/405)). It is still not qualified on hardware.
