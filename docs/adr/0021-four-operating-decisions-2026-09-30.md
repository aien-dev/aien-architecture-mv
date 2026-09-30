# ADR 0021: Four Operating Decisions of 2026-09-30

**Status:** Recorded 2026-09-30 from the orchestrator brief of that date, which carries the operator's wording for all four decisions. This record states the decisions in full and adds the evidence checked when it was written.
**Supersedes:** nothing. **Amends:** nothing.
**Related:** ARCH-0015 (Resident Semantic Store), ARCH-0016 (resident reaction architecture, R16), OS-0015 (System Store v1 format, in `aien-dev/aienos`), M19 corrective qualification (`CURRENT_EXECUTION_PLAN.md` Phase B).

Citation note: in this repository "ADR 0021" and ARCH-0021 name the same decision. In other repositories cite it as ARCH-0021.

This record is not a plan. Sequencing stays in `CURRENT_EXECUTION_PLAN.md` and milestone status stays in `doctrine/ROADMAP.md`. Where the checked evidence differs from the brief's wording, the difference is written down under "Evidence" in the same section and the decision itself is left as the operator stated it.

---

## Decision 1: The Physics pin stays at `fecbedb` until the numeric chip gate is rerun

### Decision

The numeric gates are built and host-tested against Physics commit `fecbedb`. Physics commit `f63a6ef` only adds FORGE V2 and related FORGE material, which is unrelated to the numeric gates, so the pin does not move to `f63a6ef` until the numeric chip gate has been rerun against `f63a6ef`. Every pin move is its own commit, and that commit states the reason for the move.

### What this means in practice

- Omega's `physics.lock` keeps the value `fecbedb1b9cea9e4de0fa3c88fe795934fb361f9` until the numeric chip gate has been rerun on the GB10 against a Physics tree at `f63a6ef` and has passed.
- A pin move never rides along inside a feature commit, a receipt commit or a rebase. It is a separate commit whose message names the old commit, the new commit, and the gate run that justifies the move.
- A receipt produced while the pin is `fecbedb` stays bound to `fecbedb`. Moving the pin later does not rewrite that receipt.

### Evidence checked on 2026-09-30

- The pin lives in `aien-dev/omega` `physics.lock`, which contains `fecbedb1b9cea9e4de0fa3c88fe795934fb361f9`. The Omega `Makefile` target `check-physics-lock` refuses to build when the Physics checkout is at any other commit.
- `fecbedb` is the merge of `aien-dev/physics#15` (`feat/nvrm-alloc-uncached`).
- The range `fecbedb..f63a6ef` contains three merged changes, not one: `aien-dev/physics#13` (FORGE-0 seam, FORGE-HWID probe and a capability-check rename), `aien-dev/physics#16` (FORGE SUBSTRATE V2) and `aien-dev/physics#17` (Gate 3 and Gate 4 receipts renamed to digest-named files). The brief's phrase "only adds FORGE V2" is therefore narrower than the history. The conclusion still holds: the range changes 20 files, all of them additions (4401 lines inserted, none deleted), the only pre-existing file touched is `.gitignore` (two lines added), and no file used by the numeric gates is modified.

---

## Decision 2: The block layer follows the SSD's reported block size; the SSD is never reformatted

### Decision

The block layer reads the logical block size that the device reports and uses it. A Store record is fixed at 4096 bytes and is aligned to a whole multiple of the device's logical block size, which on a 512-byte device means one record spans exactly 8 logical blocks of 512 bytes. The SSD is never reformatted to 4096-byte sectors. Native boot remains blocked by the owner-key trust chain (TRUST-1) regardless of this decision.

### What this means in practice

- A 4096-byte record written to a 512-byte-sector device is not atomic: a power cut can leave some of its 8 sectors new and the rest old. The Store must therefore carry a torn-write recovery protocol that always recovers either the complete old record or the complete new record, and never a mixture.
- Reformatting the SSD to 4096-byte sectors is not an available fix, because it would destroy the data on the Spark's only internal disk.
- This decision does not unblock native boot. Native AIENOS boots on Machine 1 stay paused until TRUST-1 is complete.

### Evidence checked on 2026-09-30

- The Spark's internal SSD (`nvme0n1`) reports a 512-byte logical block size, a 512-byte physical block size and a 512-byte maximum atomic write unit.
- `aien-dev/aienos` `crates/aienos-kernel/src/store/device.rs` already accepts both 512-byte and 4096-byte logical blocks and maps a 4096-byte Store unit to 8 or 1 blocks.
- The current non-test Store qualification path in `aien-dev/aienos` (`crates/aienos-boot/src/nvme_read.rs`) refuses any geometry that is not 4096-byte LBA and requires a power-fail atomic 4096-byte root write. Only the test-only 512-byte qualification mode (`aien-dev/aienos#136`) runs the Store at 512-byte LBA. The production path therefore does not yet match this decision; it must adopt a torn-write recovery protocol before it can accept the Spark's SSD.
- A C reference for that protocol, with fault-injection tests at 512-byte and 4096-byte logical block sizes, is proposed in `aien-dev/aienos` on branch `feat/store-torn-write-recovery`.

---

## Decision 3: Admission receipts are append-only and bound to clean source commits

### Decision

Receipts are append-only. Each receipt file is named by its own digest, records a verdict of PASS or FAIL, and is never overwritten. The M19 combined admission gate consumes PASS receipts only. Receipts are written to an evidence output directory and are bound to clean source commits. A receipt is never written inside the source checkout that is under qualification.

### What this means in practice

- A rerun of a gate produces a new receipt with a new digest name. The earlier receipt, whether it says PASS or FAIL, stays exactly as it was written.
- The M19 combined admission gate reads receipts and admits only those whose verdict is PASS. A FAIL receipt is kept as evidence but never counts toward admission.
- Every receipt names the source commit it qualifies, and that commit must have had no uncommitted changes when the gate ran. A receipt from a dirty tree is not admissible.
- The gate writes its receipt to a separate evidence output directory. Writing into the checkout under test would change the tree being qualified, so it is not allowed.

### Evidence checked on 2026-09-30

- `aien-dev/physics#17` already renamed the Gate 3 and Gate 4 receipts to digest-named files.
- Several existing receipts, for example those under `aien-dev/aienos` `evidence/`, live inside source repositories. They are historical records and are not rewritten. The decision applies to receipts produced from now on.
- No combined M19 admission-gate harness exists yet. The M19R numeric receipt in `aien-dev/omega#32` is not yet digest-named or bound to a clean commit; that work is open.

---

## Decision 4: R16 is not complete; G4 comes first

### Decision

The G4 caller-identity fix is in progress. It changes the runtime so that the runtime issues the credentials that identify a caller, instead of trusting the identity a caller states about itself. Gates G6, G7 and G8, and the immutable R16 receipt, are blocked behind G4. R16 is not complete.

### What this means in practice

- No document, receipt or status table may describe R16 as closed until G4, G6, G7 and G8 pass and the immutable R16 receipt exists.
- Work that waits for R16 closure (for example EST-4 and later, AR4, AR5, and edits to `omega/src/runtime/`) keeps waiting.

### Evidence checked on 2026-09-30

- `aien-dev/omega#106` (draft, branch `feat/r16-g3-g5-host`) reports G3 passing on the host only (not on silicon), G5 passing, and G4 printing FAIL. Two probes found real bypasses: a legacy context holding the promoter's grant that names the promoter subject gets a promotion accepted, and a reaction naming that subject writes the in-force record. The cause is that identities are whatever the caller states. That branch records the flaw as spec clarification C5 and says the fix is not made there. The fix (runtime-issued caller credentials) is in progress as clarification C6, which was not yet on that branch when checked (head `44d8c06`).
- `CURRENT_EXECUTION_PLAN.md` already records R16 as IN PROGRESS with G3 to G8 and the final receipt absent from `main`.
