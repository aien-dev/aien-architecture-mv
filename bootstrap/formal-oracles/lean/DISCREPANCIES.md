# Rust versus C capability semantics (FORMAL-3 prep)

Observed on aien-dev/aienux main 2ee61b4. Read only. This note records what each implementation does. The Lean model in `AienCap/Model.lean` models the Rust code only.

| Topic | Rust `crates/aienos-aegis/src/capability.rs` | C `native/capability/aienos_capability.c` |
|---|---|---|
| Authority | `CapabilityScope::contains` (typed scope, per kind rules), checked at line 280 | Rights bitmask. `r->rights & ~auth->rights` refuses with `AIENOS_CAP_ERR_AMPLIFY` (line 253). Privileged right is never delegable (line 254). Resource must be equal (line 252) |
| Child expiry | Not an argument. Child gets parent expiry exactly (line 288) | Child lease is `clock + lease_ticks`, chosen by caller. If parent expiry is nonzero, child must be nonzero and `<= parent` or `ERR_AMPLIFY` (lines 257 to 261). If parent expiry is 0 (no expiry) any child expiry is allowed |
| Expiry boundary | Expired only when `now > valid_until` (line 354). Equal is still valid | Expired when `lease_expiry != 0 && clock >= lease_expiry` (line 97). Equal is expired |
| Depth | Per-token counter. Child depth = parent depth - 1 (line 287). Parent depth 0 refuses `DelegationDepthExceeded` (line 276) | No counter. Absolute chain cap `AIENOS_CAP_MAX_DEPTH = 8` (header line 23), enforced by `ancestor_hops(...) >= AIENOS_CAP_MAX_DEPTH` returning `ERR_CHAIN` (line 255). Delegation also needs the DELEGATE right (line 250) |
| Validity check order | revoked, ancestor revoked (lines 345 to 352), expired, signature | State based slot validity with generation and cascade revoke (`cascade_revoke`), no signature |
| Revocation | `revoke` marks the token and all `child_map` descendants (line 319); `validate_token` also walks ancestors | Revokes live descendants by cascade over slots |
| Duplicate child id | `derive_child_token` does not check `child_id`. `self.tokens.insert(child_id, ...)` at line 312 silently overwrites an existing token and `child_map` gets a second entry at line 313. The caller supplies `child_id` | Slots are allocated by the authority (first free slot, generation counter), the caller does not choose the id |
| Holder | `new_holder` is not checked against the parent holder | Authority must equal parent reference (lines 244 to 246) |

Consequence for the Lean model: the Rust "child expiry <= parent" and "child depth < parent depth" hold by construction (equality, and minus one). The C rules differ in kind. They are separate takeover items, not assumed equal. The overwrite behaviour affects identity uniqueness, not attenuation, and is not modelled (the model lets a newer token shadow an older one with the same id).

# Receipt consistency (FORMAL-4)

Observed on aien-dev/aienux main 2ee61b4, `crates/aienos-artifact/src/receipt.rs`. Read only. The Lean model is `AienReceipt/`; it models `validate`, `decode` and `encode` (field level, offsets in `AienReceipt/Layout.lean`).

## Finding: CanaryFailed decision is not tied to the CanaryFailed execution status

- `validate` (lines 320 to 365) matches on the decision at lines 336 to 355. The `Rejected` arm (337 to 349) is strict. The `_` arm (350 to 354) checks only `rejection_stage == 0` and `rejection_reason == 0`.
- No line of `validate` mentions `ExecutionStatusCode::CanaryFailed` (the only places the name appears in this file are the enum variants at lines 45 and 66 and the code tables at 195 and 228). `decode` (244 to 317) adds only layout and enum range checks, then calls `validate`.
- So the code ALLOWS a mismatch in both directions: decision `CanaryFailed` with execution status `Exited` (or anything else), and decision `Admitted` or `Destroyed` with execution status `CanaryFailed`. `decode` accepts such bytes. Lean statements: `validate_decision_irrelevant_when_not_rejected`, `canary_decision_status_unconstrained` (Theorems.lean) and `finding_*` in Corpus.lean.
- The tests do not cover it: `receipt_tests.rs` never names `CanaryFailed`.
- Producer side: `build_receipt` (`crates/aienos-kernel/src/artifact_loader.rs` lines 1460 to 1530) emits only decisions `Admitted` and `Rejected`, and its status mapping (1472 to 1477) never yields `ExecutionStatusCode::CanaryFailed`. So the mismatch is unreachable from this producer today. It is reachable for any other producer, or for hand-built or externally supplied bytes, because validation does not refuse it.
- Not asserted either way whether the missing linkage is intended. Recorded, not fixed (aienos is read only here).

## Code is stronger than the plan

As the manifest notes: `Rejected` also forces exit status 0, zero syscalls, zero object reads, zero denials, and result flags limited to RECLAIMED (lines 338 to 345). The Lean theorems prove the code's rules. `rejected_arm` is the full Rejected arm.

## Abstractions (assumptions, not proofs)

SHA-256 nonce derivation is an arbitrary function `nf` (every theorem holds for all `nf`). Ed25519 is not modelled (`verify` is out of scope; `validate` does not check signatures). Digests are naturals, zero meaning all zero. Little-endian byte packing is assumed to be a per-field bijection. Integer width overflow is not modelled. Unknown flag bits are unrepresentable in the model; `decode` checks them on the raw word (`flags < 8`, `rflags < 256`). `exit_status` is an `Int`. Opaque digests that no rule reads are kept as one list.

# Sequence identity and KV layout (FORMAL-6)

Observed on aien-dev/sovereign-core main dd1fe32 (PREFILL-E2E C8 merged, #154). Read only. Models: `AienSeq/` (runtime `SequenceArena`) and `AienKv/` (`KvLayout`).

## Finding: two sequence arenas, different wrap policy

- `crates/aien-runtime/src/sequence.rs` `free` (lines 197 to 209) sets the generation to `wrapping_add(1).max(1)`. After exactly 2^32 - 1 frees of one slot the generation repeats and a stale id resolves again. Lean: `aba_after_exactly_one_cycle`; below the cycle `no_aba_before_wrap`.
- `crates/aien-scheduler/src/sequence.rs` `free_sequence` (512 to 531) retires the slot at `u32::MAX` and never reuses it. Lean: `retire_strictly_increases`, `retire_at_max`. No ABA window, but capacity shrinks by one slot per exhausted slot.
- Not asserted which policy is intended. The invariant states the wrapping limitation explicitly and does not claim eternal ABA freedom.

## Finding: KV layout arithmetic is unchecked

- `KvLayout::from_config` (aien-kv-cache/src/lib.rs 169 to 184) multiplies `usize` values with plain operators and does not refuse overflow or zero dimensions.
- Reproduced with a throwaway example run in a release build of the real crate (scratch worktree, deleted afterwards, nothing committed): `KvPoolConfig { num_blocks: 1<<45, block_size: 16, num_layers: 22, num_kv_heads: 4, head_dim: 64, dtype: Fp32 }.layout()` returns `Ok` with `total_bytes = 6917529027641081856`; the true value is `25364273101350633472`. Lean: `wrap_witness_real`, `wrap_witness_machine`, `wrap_total_smaller`.
- The Lean bounds theorems hold for unbounded arithmetic. `machine_exact_when_total_fits` and `offset_fits_u64` say they transfer to the Rust code exactly when `total < 2^64` with nonzero dimensions.
- No current caller can reach this (block counts are small). Latent. Recorded, not fixed.

## Not covered (stated so nobody reads more into the proofs)

- Injectivity of the offset map (distinct valid tuples never share a byte) is not proven. Only the bounds and the disjointness listed in the manifest.
- Scheduler `insert_with_id` (explicit caller generation) is not modelled.
- Block table, copy-on-write and PrefillState are not modelled here. PREFILL gating is the PREFILL-GATE campaign's evidence.
