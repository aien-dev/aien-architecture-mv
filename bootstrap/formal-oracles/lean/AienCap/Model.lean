/-!
# Abstract model of the Rust AEGIS capability graph (DEVELOPMENT_ORACLE)

Source modelled: aien-dev/aienux `crates/aienos-aegis/src/capability.rs` at 2ee61b4
(functions `derive_child_token`, `revoke`, `validate_token`).

Abstraction: authority is a finite set of atoms; expiry and depth are naturals;
revocation is a list of ids. Cryptography (the HMAC signature) is an ASSUMPTION:
every token in a graph is taken to carry a valid signature, so signature
checking is not modelled. The graph is assumed acyclic (parents precede children).
`CapabilityScope::contains` is abstracted to set inclusion (`Auth.Sub`).

Invariants: AIEN.INV.CAP.ATTENUATION.V1, AIEN.INV.CAP.REVOCATION_CLOSURE.V1.
Lean names here do not identify invariants; the manifest IDs do.
-/
namespace AienCap

abbrev Atom := Nat
/-- Authority as a finite set of atomic permissions. -/
abbrev Auth := List Atom

/-- Authority containment (the neutral "authority subset" relation). -/
def Auth.Sub (c p : Auth) : Prop := ∀ a, a ∈ c → a ∈ p

structure Token where
  id     : Nat
  parent : Option Nat
  auth   : Auth
  depth  : Nat
  expiry : Nat

structure Graph where
  tokens  : List Token
  revoked : List Nat

/-- Lookup by id. Newest insertion shadows older ones, as the Rust HashMap insert overwrites. -/
def Graph.find (g : Graph) (i : Nat) : Option Token :=
  g.tokens.find? (fun t => t.id == i)

def Graph.put (g : Graph) (t : Token) : Graph := { g with tokens := t :: g.tokens }

/-- Abstract revoke: marks the target id. The Rust code also marks every descendant in
`child_map`; that is redundant for validity because `validate_token` also walks ancestors.
This model is therefore a lower bound on what Rust rejects, which is the safe direction. -/
def Graph.revoke (g : Graph) (a : Nat) : Graph := { g with revoked := a :: g.revoked }

/-- Some ancestor, found by walking `parent` links through the graph, is revoked
(Rust: the "Cascading ancestor revocation check" loop in `validate_token`). -/
inductive AncRev (g : Graph) : Token → Prop
  | direct {t : Token} {p : Nat} : t.parent = some p → p ∈ g.revoked → AncRev g t
  | up {t pt : Token} {p : Nat} : t.parent = some p → g.find p = some pt → AncRev g pt → AncRev g t

/-- `validate_token` succeeds (signature assumed). Expiry boundary is inclusive:
expired only when `now > expiry`, so `now = expiry` is still valid (Rust `>`). -/
def Valid (g : Graph) (now : Nat) (t : Token) : Prop :=
  t.id ∉ g.revoked ∧ ¬ AncRev g t ∧ now ≤ t.expiry

/-- Success of `derive_child_token`: the parent exists and is valid, has positive depth,
contains the child scope, and the child gets parent expiry exactly and depth minus one. -/
def Derive (g : Graph) (now pid cid : Nat) (auth : Auth) (c : Token) : Prop :=
  ∃ p, g.find pid = some p ∧ Valid g now p ∧ 0 < p.depth ∧ Auth.Sub auth p.auth ∧
    c = { id := cid, parent := some pid, auth := auth, depth := p.depth - 1, expiry := p.expiry }

/-- `t` descends from `a` by parent links. -/
inductive Desc (g : Graph) (a : Nat) : Token → Prop
  | direct {t : Token} : t.parent = some a → Desc g a t
  | up {t pt : Token} {p : Nat} : t.parent = some p → g.find p = some pt → Desc g a pt → Desc g a t

end AienCap
