# ADR 0040: Five identities; "same meaning, same identity" holds only under a named normalization

**Status:** PROPOSED (draft, 2026-10-26). Decision taken by Main, the orchestrating agent, adopting
an outside architecture review that Drake Stapleton forwarded. Operator acceptance is pending.
Recorded by OmegaIntent.
**Amends (reading only, text unchanged):** at main `fabf7b7`, ADR 0015 line 97 (the invariance
principle), ADR 0018 line 46 ("the same program, with the same identity") and ADR 0019 line 23
("the same meaning gets two ids"). This ADR narrows how those lines are read.
**Related:** ADR 0039 (typed-construction interface); omega-mv #830 (semhash), #826 (bounded
equivalence, PROPOSED).

---

## Context

Three accepted ADRs say, in different words, that one meaning has one identity:

- ADR 0015 §3: "A semantic object must have the exact same identity regardless of what CPU, GPU,
  memory address, or operating system instance executes it."
- ADR 0018: "A program that is correct on a CPU is the same program, with the same identity, when
  FORGE realizes it on an analog array."
- ADR 0019 line 23 calls it a failure when "the same meaning gets two ids".

Read as stated, "semantically equivalent implies the same identity" asks for a function from
programs to ids that is equal exactly when two programs mean the same thing. Program equivalence is
undecidable in general (Rice's theorem), so no hash can deliver that. A tool that claims to deliver
it can only be wrong in one of two ways:

- false SAME: it merges different behaviour under one id;
- false CHANGED: it splits one meaning into two ids.

A false SAME is the dangerous one.

The intent of those ADRs is narrower and achievable: substrate, address, process and device must not
leak into an identity.

## Decision

1. **Five identities.** They are distinct. None is inferred from another without the evidence named
   here.

   | Identity | What is hashed | Established by |
   |---|---|---|
   | Source | the exact source bytes | SHA-256 of the bytes |
   | Normalized structure | the output of a named normalization system N | the N tool, versioned and pinned |
   | Declared behaviour | the spec or contract text (requires/ensures, experiment spec) | hash of its canonical encoding |
   | Proven equivalence | a pair or class of programs | a certificate naming property, domain, checker and assumptions |
   | Machine realization | the binary or realization artifact | SHA-256 of the artifact, plus compiler pin and target |

2. **The narrowing.** "Same meaning, same identity" in ADR 0015, 0018 and 0019 means equality under
   a defined normalization system N. N is stated by:
   - the transforms it identifies (the equalities it preserves);
   - its tool and pin;
   - the direction in which it fails.

   N must fail toward CHANGED: when it cannot show that a difference is meaning-free, the ids differ.
   Equivalence beyond N is a proof claim, not an identity. It holds only under its certificate's
   stated assumptions and domain.

3. **The first N** is omega-mv #830 semhash (seeded `.om`, per-function Merkle hash, PR not merged):
   - Identified: renames of locals and parameters, notes, blank lines and spacing, function order,
     and function-name-only renames. A call is hashed as the callee's hash.
   - Not identified: everything else is kept verbatim (fails toward CHANGED).
   - Algebraic rewrites, loop transforms and different algorithms for the same function are not
     identified. Treating them as equal needs a proof certificate, for example from #826 bounded
     equivalence, which is PROPOSED.

4. **Substrate independence is unchanged.** The source, normalized-structure and declared-behaviour
   identities never contain substrate, address, process or device values (ADR 0015 §3 item 2). A
   machine realization carries them by design. A realization on a new substrate is the same program
   only in this sense: it has the same normalized-structure identity, and a realization record links
   it to that identity. It is not the same realization identity.

5. **No promotion without evidence.** An agent or tool may report VALID-UNPROVEN (ADR 0039).
   A claim that two programs are equivalent, or that a realization implements a declared behaviour,
   is reported with its certificate or as UNKNOWN. A matching normalized hash is reported as
   "equal under N@pin", never as "equivalent".

## Consequences

- Content-addressed stores key semantic objects by normalized-structure identity under a named N, and
  record N's pin with the key. Changing N is an identity break and needs its own ADR, as ADR 0019
  already requires for OMG1.
- Merge, deduplication and caching decisions that rely on "same meaning" use N equality only, and a
  wider equivalence only through a certificate.

## Evidence at the time of writing

- **semhash invariances and controls:** as stated in the body of omega-mv #830. At head `b8b969c6`
  it reports `SEMHASH PASS cases=211 controls=13`. This is that PR's claim, not re-run for this ADR
  (NOT_RUN here).
- **#826 bounded equivalence:** PROPOSED, NOT_RUN.
