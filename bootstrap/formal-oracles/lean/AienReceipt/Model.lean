/-!
# Abstract model of the Rust admission receipt (DEVELOPMENT_ORACLE)

Source modelled: aien-dev/aienux `crates/aienos-artifact/src/receipt.rs` at 2ee61b4
(`validate`, `decode`, `encode`, `valid_reason`; consumer `build_receipt` in
`crates/aienos-kernel/src/artifact_loader.rs` is read for context only).

Invariant: AIEN.INV.RECEIPT.REJECTION_CONSISTENCY.V1 (formal/invariants/artifact-receipt-v1.toml).

Abstractions (each is an ASSUMPTION, not a proof):
* Cryptography. SHA-256 nonce derivation is an arbitrary function `nf`; every theorem holds for
  EVERY `nf`. Ed25519 signature checking is not modelled (it lives in `verify`, not `validate`).
  The signature block is reduced to one Boolean (`sigOk`: all zero, or well formed algorithm id).
* Digests (32 bytes) are naturals; "all zero" is `= 0`. Fixed-width integer overflow is not modelled.
* Little-endian byte packing is not modelled. `Raw` is the record after splitting into fixed-width
  fields at the offsets of `AienReceipt.Layout`. That the byte packing is a bijection per field is assumed.
* `exit_status` is an `Int` (Rust `i32`).
* Presence flags and result flags are structures of Booleans, so unknown bits cannot be written.
  `decode` rejects unknown bits on the Raw word first (see `Layout.lean`).
-/
namespace AienReceipt

inductive Decision | admitted | rejected | canaryFailed | destroyed
  deriving DecidableEq, Repr

inductive Tier | seed0bQemu | seed0bMachine1
  deriving DecidableEq, Repr

/-- Rust `ExecutionStatusCode` (offset 64). -/
inductive Status | notRun | exited | timeout | fault | badSyscall | resourceOverrun | canaryFailed
  deriving DecidableEq, Repr

/-- Presence flags (offset 16): bits 0 machine id, 1 context id, 2 timestamp. -/
structure Presence where
  machine : Bool
  context : Bool
  time    : Bool
  deriving DecidableEq, Repr

/-- Result flags (offset 72): bits 0..7 in the order of the Rust `RESULT_*` constants. -/
structure ResultFlags where
  readOk       : Bool
  writeDenied  : Bool
  reclaimed    : Bool
  canaryPassed : Bool
  forgedDenied : Bool
  mappedMatch  : Bool
  executedMatch : Bool
  wxSealed     : Bool
  deriving DecidableEq, Repr

/-- In-memory receipt. Digest fields that no rule inspects are kept as one opaque list. -/
structure Receipt where
  pres      : Presence
  decision  : Decision
  tier      : Tier
  sequence  : Nat
  nonce     : Nat
  observed  : Nat
  status    : Status
  exitCode  : Int
  rflags    : ResultFlags
  stage     : Nat
  reason    : Nat
  syscalls  : Nat
  reads     : Nat
  denials   : Nat
  frames    : Nat
  digests   : List Nat
  verifier  : Nat
  machineId : Nat
  generation : Nat
  contextId : Nat
  deriving DecidableEq, Repr

/-- Rust `MAX_REJECTION_STAGE`. -/
def maxStage : Nat := 9

/-- Rust `valid_reason`: 1..=19 or 0x101..=0x10a. -/
def validReason (c : Nat) : Bool :=
  (decide (1 ≤ c) && decide (c ≤ 19)) || (decide (0x101 ≤ c) && decide (c ≤ 0x10a))

/-- `result_flags & !RESULT_RECLAIMED == 0`. -/
def ResultFlags.onlyReclaimed (f : ResultFlags) : Bool :=
  !f.readOk && !f.writeDenied && !f.canaryPassed && !f.forgedDenied &&
  !f.mappedMatch && !f.executedMatch && !f.wxSealed

/-- Rust lines 322-330: an absent presence flag forces the value to its zero. -/
def presenceOk (r : Receipt) : Bool :=
  (r.pres.machine || r.machineId == 0) &&
  (r.pres.context || (r.generation == 0 && r.contextId == 0)) &&
  (r.pres.time || r.observed == 0)

/-- Rust lines 331-335. -/
def codesOk (r : Receipt) : Bool :=
  decide (r.stage ≤ maxStage) && (r.reason == 0 || validReason r.reason)

/-- Rust lines 336-355: the decision match. -/
def decisionOk (r : Receipt) : Bool :=
  match r.decision with
  | .rejected =>
      r.stage != 0 && r.reason != 0 && r.status == .notRun && r.exitCode == 0 &&
      r.syscalls == 0 && r.reads == 0 && r.denials == 0 && r.rflags.onlyReclaimed
  | _ => r.stage == 0 && r.reason == 0

/-- Rust lines 356-360. -/
def canaryOk (r : Receipt) : Bool :=
  !r.rflags.canaryPassed || (r.status == .exited && r.exitCode == 0)

/-- Rust line 361, with the SHA-256 nonce function `nf` abstracted. -/
def nonceOk (nf : Nat → Nat → Nat) (r : Receipt) : Bool :=
  r.nonce == nf r.verifier r.sequence

/-- Rust `validate`, `Ok` exactly when this is `true`. -/
def validate (nf : Nat → Nat → Nat) (r : Receipt) : Bool :=
  presenceOk r && codesOk r && decisionOk r && canaryOk r && nonceOk nf r

end AienReceipt
