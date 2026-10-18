# Crumb Protocol RFC-0003: The Crumb Compiler

**Status:** Proposed, 2026-10-04. Decided by the operator, Drake Stapleton, through his approved compiler spec of 2026-10-04 (pasted; the paste is the decision). Source of record: `~/handoffs/rfc-0002/crumb-compiler-spec-drake-2026-10-04.md` on the Spark.
**Extends:** RFC-0002 (`docs/CRUMB_PROTOCOL_RFC_0002.md`). RFC-0001 and RFC-0002 are not changed; this adds a generated block inside `.crumb` and five commands.
**Implementation:** `tools/crumb/crumb.c` (C11, no dependencies, own SHA-256). Reference implementation and the binding design decisions D1-D9: `tools/crumb/crumb-compile.sh` (POSIX sh + git + jq). Code is the truth; where this text and the code differ, the difference is a bug in one of them.

## In plain words

Until now people and agents wrote the descriptions in crumbs by hand, and they went stale. The repository now compiles its own crumbs: a program reads Git and the files and writes the structural facts (which files, which child folders, which receipts, a fingerprint of everything below). Humans keep only what a program cannot know: why a folder exists and what must never be broken. If a fingerprint no longer matches the files, the crumb says STALE, and CI refuses the change until someone runs `crumb compile`.

## 1. Hand-authored versus generated

| Part of `.crumb` | Who writes it | Notes |
|---|---|---|
| `purpose`, `layer`, `invariants`, `exports`, `related`, `boundaries` (the semantic kernel) | Humans | The compiler never writes these keys (D5). |
| `extensions.proposed.purpose` | `crumb propose` | Stays PROPOSED until a human moves it into `purpose`. Programs infer structure; they cannot prove intent. |
| `extensions.generated` | `crumb compile` | Everything below. Never edited by hand. |
| `.crumb.local` / shared store | `crumb claim` etc. | Ephemeral coordination. Never enters the compiled state (D1). |

## 2. Generated block

`extensions.generated` holds: `compiler` (`crumb-compile/1`), `source_tree` (sha256 of the sorted `blob path` lines of tracked files below the directory), `files` (count), `children` (one entry per NEAREST crumbed descendant directory, found by walking down through directories that hold no `.crumb`: `name` (path relative to this directory, e.g. `archive/plans`), `digest`, first 96 characters of its `purpose`, `last_commit`), `children_root`, `evidence_files`, `evidence_root`, `digest`, plus two stamps that are not inputs: `generated_at_commit` and `compiled_at`. Master crumbs (any crumb with children) are therefore generated summaries of their children: an agent reads one file and descends only where relevant.

**Amended 2026-10-18 (D11).** The committed `extensions.generated` now holds only `compiler` (`crumb-compile/2`) and `children` (each `{name, purpose}`). The fingerprints described in this section and in section 3 are still computed on every run, in the same order, and `crumb digest` prints the root one, but they are never written into a `.crumb`. Neither are `generated_at_commit`, `compiled_at` or `children[].last_commit`.

## 3. Merkle rule

`digest = sha256(semantic || source_tree || children_root || evidence_root)`, where `semantic` is the compact, key-sorted JSON of the semantic kernel with null keys removed, and the three roots are the lowercase hex digests. `children_root` is the sha256 of each child's digest followed by a newline, in name order. Directories are compiled deepest first (D4), so a parent always embeds its children's final digests. Changing one file therefore changes that directory's digest and those of its ancestors only; siblings stay CURRENT.

## 4. Design decisions D1-D11 (binding; D1-D9 from the reference implementation), D3a and D11

| ID | Decision | Trap it closes |
|---|---|---|
| D1 | `source_tree` excludes every `.crumb` and `.crumb.local`. | Compiling would change the tree, which changes the digest: no fixed point. |
| D2 | Files are the tracked files of the working tree, hashed as git blob ids, not HEAD's tree. Untracked files never count. | A PR author compiles before committing; CI's checkout must give the same answer. |
| D3 | Digests cover content only. `generated_at_commit` and `compiled_at` are stamps and `verify` ignores them. | Otherwise every commit would make every crumb stale and CI would fail forever. |
| D3a | Added by the C port: `children[].last_commit` is written by compile but never decides STALE (it is a stamp in the sense of D3). | Committing a change moves a child's last commit, which would need another compile, which needs another commit: a PR could never pass `verify`. Demonstrated on the shell reference at `d41087c`, where a fresh clone reports 2 stale crumbs. |
| D4 | Bottom-up order, deepest first. | A parent's `children[]` must hold final child digests. |
| D5 | The compiler never writes the semantic kernel; `propose` writes only `extensions.proposed`. | An LLM description must not silently become architectural truth. |
| D6 | `last_commit` per child ignores `.crumb` files (`':!**/.crumb'`). | Compile commits would count as changes to the code. |
| D7 | Only directories that already hold a `.crumb` take part; `crumb seed` decides membership. Children are the nearest crumbed descendants: the walk descends through directories without a `.crumb` (amended 2026-10-11). | One mechanism for membership, not two. Before the amendment only immediate children were listed, so a `.crumb` under an uncrumbed directory was outside the root digest and its deletion was invisible to `verify` and `pr-gate.sh` (lane CRUMB proof 19 b2, aien-architecture#207). Now every compiled crumb is reachable from the root; the walk uses the same traversal policy as `find_crumbs` (D10 and build-directory exclusions, no symlinks), so a crumb inside a hidden directory is listed too. |
| D8 | Evidence is tracked files whose path has a component named `evidence` or `receipts`, or ending `.receipt.json`; `evidence_root` hashes their blob ids in path order. | Receipts become part of the fingerprint, so a changed receipt shows up as STALE. |
| D9 | Output is key-sorted JSON, written to a temporary file then renamed, byte-stable. | `verify` can be an exact comparison. |
| D10 | A directory listed in `<root>/.crumbignore` (one relative directory per line, the same file `crumb seed` reads) is excluded with its whole subtree from compile, verify and status: no `.crumb` under it is read as a child or rewritten. Its tracked files still count toward the enclosing crumb's `source_tree` and `evidence_root`. Added 2026-10-04 for the rollout to omega, aienos and physics. | Trees guarded by immutability checks (omega `evidence/`, which holds a seeded `.crumb`; physics `nvrm` and `m16`) would otherwise be rewritten by compile and fail their own CI. The shell reference does not implement D10; the differential holds for repositories without a `.crumbignore`. |
| D11 | Added 2026-10-18. The committed generated block is structure only: `compiler` and `children[{name, purpose}]`. `source_tree`, `files`, `children[].digest`, `children_root`, `evidence_files`, `evidence_root`, `digest`, `children[].last_commit`, `generated_at_commit` and `compiled_at` are no longer written; the Merkle digests are computed on demand (`crumb digest`). A crumb is STALE only when its children or their purposes change. Supersedes the storage parts of D3, D3a and the "touching one file stales its ancestors" rule. | `source_tree` covered every file below a directory, so any change anywhere rewrote the root `.crumb` and every pair of open pull requests conflicted on it (2026-10-18: most open PRs CONFLICTING, root `.crumb` the only conflicting file). Git already fingerprints every tree; a second copy stored inside the tree it fingerprints can only collide. |

## 5. Commands

- `crumb compile [root]`: regenerate stale crumbs (idempotent; a second run rewrites 0).
- `crumb verify [root]`: exit 1 and list every stale directory if any committed crumb differs from what compile would write now. This is the CI rule.
- `crumb status [root]`: CURRENT, STALE or UNCOMPILED per crumb.
- `crumb digest [root]`: print the root Merkle digest, computed now and never stored (D11).
- `crumb propose <dir> "<purpose>"`: write a PROPOSED purpose; `.purpose` is never changed.
- `crumb context [path]`: the agent entry point. Prints a freshness line (`Crumbs CURRENT at HEAD <sha>` or `Crumbs STALE: <n> (run crumb compile)`), the top-level tree with each child's purpose (or `PROPOSED: ...`), what the path touches, the crumbs to read (the path's ancestors, root first), current conflicts (shared-store locks on the path), and the newest relevant Continuation Crumb. Output is bounded (at most 40 tree entries, 8 continuation items).

## 6. CI rule

`.github/workflows/crumb.yml` builds the tool, runs `make -C tools/crumb test`, then `./tools/crumb/crumb verify .`. A pull request whose crumbs are not exactly what the compiler would produce fails. The author runs `crumb compile` and commits the result.

## 7. The PROPOSED semantic kernel

Structure is inferred; intent is not. A directory with no human `purpose` shows `(no purpose yet)` in `crumb context`. `crumb propose` records a candidate under `extensions.proposed` with author and time. It changes nothing a reader treats as truth until a human accepts it by moving it into `purpose`.

## 8. Stages

| Stage | Content | Status |
|---|---|---|
| 1 | `crumb compile`: deterministic structural data from Git, filesystem and receipts, in the C tool | This PR |
| 2 | Merkle hierarchy and generated master crumbs | This PR |
| 3 | `crumb verify` and CI: stale crumbs cannot merge | This PR |
| 4 | Compile and verify rules as Omega contracts | Later, when OSC can express them |
| 5 | Omega as authoritative verifier and compiler; C stays the bootstrap and differential implementation | Later |

Caveat for stages 4-5: Omega's program representation is still narrow (unary-u64 op set at the head checked), so these stages do not block on it. Dependency/import and exported-symbol extraction, tests-touching-the-area and active-milestone fields named in the compiler spec are NOT part of this cut; the generated block carries files, children, evidence and digests only.

## 9. Tests

`make -C tools/crumb test` runs `test.sh` and `test-continuation.sh`. The RFC-0003 cases are the lines starting `C3`.

| Test | Result |
|---|---|
| SHA-256 matches the known vector and `sha256sum` on 300 KB | PASS |
| Fresh crumbs are UNCOMPILED; `verify` exits 1 | PASS |
| Fixed point: second compile rewrites 0 | PASS |
| `verify` OK after compile; OK after an empty commit; OK after the compiled change is committed (D3a) | PASS |
| Touching one file stales no crumb (D11); a new or deleted crumbed child stales only its nearest crumbed parent; siblings stay CURRENT | PASS |
| D11: two branches that change files in different directories merge with no `.crumb` conflict and `verify` stays OK without a recompile (red on crumb-compile/1: conflict on the root `.crumb`) | PASS |
| D11: `crumb digest` prints the root Merkle digest; two clean compiles one second apart give the same digest (pipeline proof 13) | PASS |
| `propose` never changes `.purpose`; compile never touches the semantic kernel; a proposal does not make crumbs stale | PASS |
| `context` prints all sections, both freshness lines, ancestors, PROPOSED purpose, locks on the path only, bounded output | PASS |
| Differential against `crumb-compile.sh` on a scratch repo and on this repo (both tools compile from nothing, so `last_commit` is fresh in both): generated blocks identical, each tool verifies the other's output, whole file byte-identical apart from `compiled_at` | PASS (reported NOT_RUN if `jq` is missing) |
| Number literals other than plain integers inside the semantic kernel (jq canonicalises them, the C tool keeps them verbatim) | NOT_RUN (UNVERIFIED) |
| Paths containing spaces or newlines (the shell reference splits them; the C tool does not) | NOT_RUN (UNVERIFIED) |
