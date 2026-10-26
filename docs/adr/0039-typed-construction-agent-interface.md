# ADR 0039: The typed-construction interface is Omega's primary agent programming interface

**Status:** Accepted (Main, delegated by Drake, 2026-10-26). Main, the orchestrating agent, adopted
an outside architecture review that Drake Stapleton forwarded, and accepted this ADR under Drake's
delegation of technical calls. Recorded by OmegaIntent.
**Related:** omega-mv #599 (Omega workstream), #652 (OM-LEARN), #653 (benchmark, owned by OmegaEval),
#655 (incremental feedback with no false-prefix rejection), #656 (contract-to-.om synthesis),
#830 (semhash), #838 (omq, stage 1 of this interface); ADR 0040 (identity layers); omega-mv
`docs/one_layer/OMEGESE.md` and `spec/visor.md` (design input only).

---

## Context

Omega was meant for AI agents to write. In practice an agent writes `.om` text, runs `omc`, and reads
`omc: line N: error E`. Errors 3 (define before use), 7 (type reuse), 12 (too many live names) and
13 (name too long) are rules the agent can only learn by failing. Each failure costs a full
generate-compile cycle. Nothing tells the agent what may be written at a given point.

## Decision

1. Agents program Omega through a versioned, compiler-native typed-construction interface with seven
   operations:

   | Operation | Answers |
   |---|---|
   | inspect | names in scope with types and writability, functions, the position being built |
   | legal_actions | the statement or value forms the compiler accepts at that position |
   | apply | a typed edit at that position, refused unless legal |
   | obligations | open blocks, remaining name/register room, contracts, effects, unresolved choices |
   | realize | the machine realization (compiled binary) of a complete program |
   | verify | checks of declared behaviour against the realization, with evidence |
   | explain_refusal | the diagnostic: code, byte span, expected/found, obligation, and a repair the compiler re-checked |

2. `.om` text stays a first-class projection: every construction state prints as `.om`, and `.om`
   parses back into one. An agent may still write text. It is no longer required to.

3. **Outcome values.** Every answer about a program or partial program carries exactly one of:
   - INVALID: a type, scope, effect or resource rule is broken, and no continuation can repair it;
   - INCOMPLETE: not yet a program, but a valid continuation exists;
   - VALID-UNPROVEN: well formed, with an obligation (declared behaviour) not discharged;
   - UNKNOWN: the checker cannot decide yet.

   No operation turns UNKNOWN or VALID-UNPROVEN into a proven property. Only a proof certificate does
   that (ADR 0040), and it names the property, domain, checker and assumptions.

4. **One authority.** The interface is implemented by the seeded `.om` compiler (`omc`). `omegese
   next` and `spec/visor.md` are design input and migration evidence, not a second authority.
   Compiler changes go through the Omega compiler integrator, with the existing gates (byte-identical
   off path, TLS constant-time and per-function checks, a paired timing A/B).

5. **Staging.**
   - Stage 1, a black-box witness oracle. `seed/query/omq.om` (omega-mv #838) runs the pinned
     `omc` on witness programs and reports only what `omc` accepted. Its answers become the
     differential oracle for stage 2.
   - Stage 2, white box. An `om2 query` lead line makes `omc` print its held state (names,
     functions, open blocks, contracts, register pool) as JSON instead of an ELF. It must agree with
     stage 1 on every gate case.
   - Stage 3. apply, realize and verify, plus #656 contract-to-.om synthesis, behind the same
     interface.

6. **Independence.** The builder of the interface does not judge it. Benchmark tasks, splits,
   baselines and verdicts belong to #653 (OmegaEval). The interface is adopted for agent use when
   #653 measures fewer authoring errors per total time against plain text authoring with the same
   model, budget and tasks. A negative or inconclusive result is reported as such.

7. **First domain.** Reproducible experiments with integer and fixed-point arithmetic:
   - objective to experiment;
   - a sealed train/evaluation split;
   - a score in bits;
   - replayable evidence.

   Unresolved choices (population, statistical assumptions, success criteria) are surfaced as
   obligations and never invented. Bridge support for floats, text and heap is milestone 0 for wider
   domains.

## Consequences

- Agents get the compiler's rules as answers instead of as failures. Each stage 1 answer costs tens
  to hundreds of compiles. Stage 2 removes that cost.
- The interface's JSON schema is versioned with the compiler pin. A schema change is a compiler
  change.
- Language-friction fixes, for example requiring `=` in bindings behind a dialect switch with a
  byte-identical rewriter, are measured through #653 before they land.

## Evidence at the time of writing

- **Stage 1, omq (omega-mv #838, branch `feat/omc-query`, omc pin `2c824805…`).**
  - MEASURED: `sh seed/query/check.sh` printed `SEED QUERY PASS 36 checks` on the host (AArch64 DGX
    Spark).
  - MEASURED: on 112 seeded holes in 28 repository programs, the removed statement's form was
    offered at all 112 (`/home/drakestapleton/handoffs/OmegaIntent/realprog/fresh2.jsonl`).
  - Host evidence only: EXERCISED, not QUALIFIED, not merged.
- **Stage 2 and stage 3:** NOT_RUN.
- **Agent-loop comparison (#653):** NOT_RUN.
