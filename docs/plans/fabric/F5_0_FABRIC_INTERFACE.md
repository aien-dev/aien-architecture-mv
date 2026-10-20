# Fabric interface F5-0: local loopback, typed records

**NOT A MASTER PLAN.** This is a finite workstream document for the first
Fabric slice (CURRENT_EXECUTION_PLAN.md §F5, "interface design allowed now").
`CURRENT_EXECUTION_PLAN.md` owns sequencing and `doctrine/ROADMAP.md` owns
milestone status. Nothing in this document closes F5 or any milestone.

Status: implemented and tested host-only in omega `src/fabric/` (see §8).
aienos ADR 0010 (Fabric machine identity and capability advertisement) is
still **Proposed**; its preconditions (M6 networking, signature scheme,
operator approval) are not met. F5-0 is a host-side model of the data
structures and rules, which ADR 0010 §12 permits, and ships in no trusted base.

## 1. What F5-0 is

Membership, capability advertisement, leases and loss detection between
machines, as typed records keyed by the canonical `AienMachineId`
(omega#113), carried over an **in-process loopback transport**. It feeds the
canonical Capability Graph (`rx_capq`, omega#115) through its public header
only, and answers J-Space placement (`JsHome`, omega#116) for live members.

Out of scope: real networking, placement, topology/latency measurement,
failure recovery beyond withdrawal, remote J-Space, load telemetry, any
change to `src/runtime/`.

## 2. Ownership

| Thing | Owner | F5-0 touches it how |
|---|---|---|
| Roster (who may be a member) | AEGIS / owner-key boundary (caller) | reads only; no call adds to it |
| Membership view (per peer) | the receiving node's `FabNode` | sole writer: `fab_receive`, `fab_tick` |
| Capability entries | `rx_capq` (canonical Capability Graph) | `cq_wire_apply`, `cq_machine_advertise_id`, `cq_withdraw` |
| Authority | World authority view (`CqHeld`) | never; `fabric.o` may not reference authority or World symbols (build check) |
| Machine identity | `aien_machine_id.h` | records carry the 44-byte `AienMachineId`, never a local index |

## 3. Message format (version 1)

Fixed header 120 bytes + body + 32-byte tag; integers little-endian.

| off | len | field |
|---|---|---|
| 0 | 4 | magic `AFAB` |
| 4 | 1 | version 0x01 |
| 5 | 1 | kind: JOIN 1, RENEW 2, ADVERTISE 3, LEAVE 4 |
| 6 | 2 | body_len (must equal the kind's size) |
| 8 | 44 | sender `AienMachineId` record |
| 52 | 44 | dest `AienMachineId` record |
| 96 | 8 | generation (sender's membership generation, >= 1) |
| 104 | 8 | seq (within the generation, >= 1, rising) |
| 112 | 8 | sent_us (informational) |
| 120 | n | body |
| 120+n | 32 | tag over bytes 0..120+n-1 |

Bodies: JOIN = ontology digest (`cq_ontology_digest`, 32) + requested lease
(u64 us); RENEW = requested lease; ADVERTISE = one 188-byte `rx_capq` wire
record whose machine must be the sender; LEAVE = empty. The wire record may
be any `rx_capq` kind (ADVERTISE 1, AVAILABILITY 2, WITHDRAW 3): a machine
changes or withdraws only its own entries.

## 4. Receive rules (first failure is the verdict; nothing changes, except
that an authenticated message of the held generation that passed rule 6
consumes its seq, so a refused message never succeeds on replay)

1. form -> `FAB_E_FORMAT`
2. dest is not me, or sender is me -> `FAB_E_MISMATCH`
3. sender not on the roster -> `FAB_E_NOT_ENROLLED`
4. tag fails -> `FAB_E_AUTH` (forged identity, altered bytes)
5. generation below held -> `FAB_E_STALE_GEN`
6. same generation, seq not above last -> `FAB_E_REPLAY`
7. JOIN whose generation is not above held -> `FAB_E_STALE_GEN`
8. non-JOIN from a non-member or another generation -> `FAB_E_NOT_MEMBER`
9. non-JOIN after the lease ended -> `FAB_E_LEASE_EXPIRED` (rejoin with a higher generation)
10. JOIN with a different operation catalog -> `FAB_E_ONTOLOGY`
11. ADVERTISE naming another machine -> `FAB_E_MISMATCH` (nobody speaks for a peer)
12. ADVERTISE the Capability Graph refuses -> `FAB_E_CAPQ`

The node applies the clock (`fab_tick`) before every receive, so loss is a
function of time only and a recorded run replays bit for bit.

## 5. Leases and loss

The receiver grants `min(requested, max_lease)` from its own clock and gives
the end to `cq_machine_advertise_id`. At `now >= lease end` the member is
LOST and every entry it advertised is withdrawn from the receiver's graph.
Loss is the receiver's view only: the lost machine's identity and its own
local records are untouched (ADR 0010 invariant 5, partition sovereignty).
Capability entry generations are `membership_generation << 32 | revision`,
so a rejoin always outranks older records.

## 6. Interfaces other lanes consume

**COMPOSITION-2 (Lane 3, runtime integration).** `fabric.h`:
`fab_node_init(FabNode*, const FabConfig*)` with a canonical `CqCatalog`;
`fab_poll` / `fab_receive` (inbound), `fab_tick` (clock), `fab_join`,
`fab_renew`, `fab_advertise(node, CqKey own, CQ_WIRE_*)`, `fab_leave`;
views `fab_member`, `fab_member_live`, `fab_home(node, AienMachineId, now,
JsHome*)` (LOCAL for self, REMOTE_OWNED for a live member, refused
otherwise); `fab_state_digest`. Rebuild of the capq index after an
ingested record is done by the Fabric.

**Aienux M6 transport (Lane 5).** Two vtables, nothing else:
`FabTransport { send(from, to, bytes), recv(self, buf) }` (untrusted; the
Fabric authenticates every message itself) and `FabAuth { sign(bytes) ->
tag[32], verify(claimed AienMachineId, bytes, tag) }`. The real transport
must also put each send through AEGIS as an outbound effect (ADR 0010 §8);
F5-0 has no such gate.

## 7. Known gaps (recorded, not hidden)

- The loopback authenticator is HMAC-SHA256 with one symmetric key per
  machine. A verifier holding that key could sign with it. It stands in for
  the TRUST-1 owner-key signature, which must replace it before any real use.
- Advertisement is sent to every roster peer (provisioned-trust set), not
  pull-or-respond as ADR 0010 §7 states. Revisit when the transport exists.
- No AEGIS effect evaluation on send (ADR 0010 §8); belongs to the real
  transport path.
- No load telemetry class, no Machine Capsule derivation (ADR 0010 §5, §9).
- The held generation and seq live in memory only: a receiver restart
  forgets them, and a refused new-generation JOIN is not remembered.
- Not in omega `all`/`test` or the R13 living-system build until
  COMPOSITION-2 integrates it.

## 8. Evidence

Gate `F5_0_FABRIC_LOOPBACK`: three enrolled machines join, advertise (one
with two capabilities), renew; one goes silent, its lease ends, both peers
mark it LOST and its capability entries are withdrawn; it rejoins under a
higher generation. Negatives refused: expired lease, stale generation,
forged identity (wrong key, altered bytes, unenrolled sender), replayed
advertisement, machine mismatch (relayed record, misdelivery), after-leave.
Routing never mints authority: every Fabric candidate returns not held and
`require_held` filters all of them. The scenario runs twice; transcripts and
state digests must match.

Command: `make test-fabric` in omega (receipt: `make fabric-receipt`).
Result: PASS. omega PR #123, merge a18ec6b (tested commit 0fc309c, re-run
after merging main 5c403f0). `checks 318 (scenario 160 per run), failures 0`,
ASan/UBSan PASS, purity PASS. Receipt:
`evidence/F5-0/e419a00b54d52b7307cada39d29e501d8a776a100471e0c2a2c41dfd84753858.json`.
Codex review: 6 passes, all findings fixed or answered in the PR body.
Scope: host-only loopback with an HMAC stand-in; no network, no TRUST-1
signature, no hardware qualification.
