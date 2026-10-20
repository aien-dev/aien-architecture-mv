# ACCEPTANCE_E2E: the whole-system acceptance test (WHOLE-SYSTEM-E2E v1)

**Status: FROZEN 2026-10-10 (Drake directive: freeze the acceptance contract; lane L1 rows reference this file, aien-sovereign-core#387).** From this commit on this file is never edited; changes go to a v2 file. Tracking: aien-spark/aien-architecture#190, deliverable R3 (lane L0 of `INTEGRATION_PLAN.md`). **NOT A MASTER PLAN.** This file becomes FROZEN when its commit and sha256 are posted on #190 as milestone R3; after that it is never edited, and changes go to a v2 file. Every status word in it is NOT_RUN until a declared run reports it.

Written 2026-10-10 by the coordinating session (Claude Code 85679b2b). Shapes below reuse what exists in code on 2026-10-10 (`GAP_ASSESSMENT.md` section 2); nothing new is invented where an identity rule already exists.

## 0. Claim classes

Every statement in a run report carries one class, as the AT-1 reports did:

- **OBSERVED**: read from a receipt or an output file of the run.
- **INFERRED**: follows from observed lines by a stated rule.
- **NOT CLAIMED**: explicitly outside what the run shows.

A PASS here means the installation did what this file says, on the machine named, with the model named. It is not a claim about general reliability, security against an adversary, or fitness for anyone else's purpose.

## 1. Definitions

- **Installation**: one host user account, one home directory, the AIEN runtime daemon and the `aien` CLI from one build, one local model, no network during the run.
- **Objective**: an operator's free-form request in plain text, at most 2000 bytes UTF-8, that the installation must carry out. The run objective of v1 is fixed in section 3.
- **Objective identity** `objective_id`: the lowercase hex SHA-256 of the UTF-8 bytes of the objective text, prefixed by the domain tag `AIEN_E2E_OBJECTIVE_V1` and a newline. Identical text gives an identical identity on every machine.
- **Run identity** `run_id`: the lowercase hex SHA-256 over `objective_id`, newline, the installation's daemon binary sha256, newline, the model weights sha256, newline, the host name. It differs across machines and builds by design; it never enters a verdict.
- **Receipt**: a JSON object written by the installation or the harness during the run. Every receipt carries `objective_id`, `run_id`, `step` (one of E1 to E6 or `CTRL-<step>`), `utc`, and `prev_receipt_sha256` (the sha256 of the previous receipt file in the chain, or 64 zeros for the first). Receipts written by `aien compose` keep their existing fields (`tool`, `success`, `arguments_digest`, `result_digest`, as `crates/aien-cli/src/compose.rs` `receipt()` writes them); the harness wraps them with the chain fields rather than changing them.
- **Chain**: the ordered receipts of one run. The chain is unbroken if every `prev_receipt_sha256` equals the sha256 of the preceding file and no file is missing from the manifest.
- **Verdict identity** `verdict_id`: the lowercase hex SHA-256, domain tag `AIEN_E2E_VERDICT_V1`, over the LF-joined lines `objective_id <hex>`, `contract_sha256 <hex of this frozen file>`, then one line per step `E1 PASS|FAIL|NOT_RUN`, then one line per control `CTRL-E1 PASS|FAIL|NOT_RUN`. Nothing with a timestamp, host name or path enters it, so two machines that agree on every row produce the same `verdict_id` (the AT-1 rule, `evaluator/src/result.rs compute_verdict_id`). Byte layout (pinned at freeze): the hashed bytes are the ASCII tag `AIEN_E2E_VERDICT_V1`, one LF, then the lines in the order given joined by LF with no trailing LF; rows E1 to E6 then CTRL-E1 to CTRL-E6; `CTRL-E3` is PASS only when both its parts (desk key absent, revoke) PASS.
- **Verifier**: a separate program (lane L4) that reads only the chain and the output files, never the daemon, and writes the verdict. Verifier and executor share no code beyond the standard library and the hash routine.

## 2. The six steps, their receipts and their negative controls

| step | the installation must | receipt fields (beyond the common ones) | PASS when | negative control (must FAIL as predicted) |
|---|---|---|---|---|
| E1 install | install offline from the release artifact into a clean home and start | `artifact_sha256`, `signature_check` (`verified`, `dry-run-key`, or `none`), `signer`, `files_verified` (count), `daemon_sha256`, `cli_sha256` | signature check `verified` or, when no offline key exists, `dry-run-key` stated as a gap; every file in `release.toml` verified; daemon up | CTRL-E1: an artifact with one byte changed installs nothing and names `checksum` or `signature` as the reason |
| E2 objective | accept the objective text from the operator through the CLI and record it before any work | `objective_text_sha256`, `recorded_before_work` (true), `operator_surface` (`aien-cli`) | the objective record exists with `objective_id` and no effect receipt predates it | CTRL-E2: an objective that names a forbidden effect class (`EXTERNAL_IRREVERSIBLE`) is refused before execution with a named refusal |
| E3 execute | plan, route capabilities, run the local model, perform the file-writing effect through the approval desk | per effect: the `aien compose` receipt (`tool`, `success`, `arguments_digest`, `result_digest`), `grant_id`, `desk` (`required`), `model_weights_digest`, `backend_line` | the output file exists, matches `result_digest`, and every effect has a grant spent exactly once | CTRL-E3: with the desk key absent the daemon refuses to start (sc#342 behaviour); with a grant revoked before spend the effect is refused `Revoked` |
| E4 memory | write at least one memory item during E3; after a full daemon stop and start, carry out a second objective that needs that item | `memory_store` (the store named by lane L3), `item_sha256`, `recall_after_restart` (true), `restart_kind` (`graceful` or `sigkill`) | the second objective's output contains the recalled item and the recall receipt postdates the restart | CTRL-E4: with the store's files removed between stop and start, the second objective fails with a named refusal, never a silently wrong output |
| E5 verify | nothing; the verifier judges the chain and the outputs | verifier receipt: `verifier_sha256`, `verifier_build_host`, `chain_unbroken`, per-row verdicts, `verdict_id` | verifier reports every row and the chain unbroken; on a second machine, same `verdict_id` | CTRL-E5: one output file with one byte changed is rejected by the verifier (`result_digest` mismatch) |
| E6 recover | survive SIGKILL of the daemon between the approval and the effect, restart, finish the same objective | `kill_point` (the hold name), `restart_count`, `effects_before_kill`, `effects_after_restart`, `duplicates` (0) | the objective finishes, the output appears once, `duplicates` 0, chain unbroken through the restart | CTRL-E6: restart with the durable objective state removed gives a named refusal (`ReconciliationRequired` or the objective's own refusal), not a second effect |

Refusal names used above exist in code today: `Stopped`, `NotAuthorized`, `AlreadySpent`, `ReconciliationRequired`, `Revoked`, `Stale` (aien-sovereign-core#227 effect boundary) and the desk-key startup refusal (sc#342). A step that needs a refusal not yet in code says so in its lane's pre-registered acceptance rows; this contract does not invent refusal text.

## 3. The v1 run objective (fixed)

Objective text, exactly: `Read the three text files in the inbox folder and write a Markdown report named report.md in the outbox folder. Start with a Markdown heading line that begins with "# ". Use at most 200 words. Mention each file by name.`

Wording note (2026-10-10, harness v1 dry run RUN-1-dry-20261010T133749Z): the earlier text said "under 200 words; begin it with a heading line", which the runtime refused as an uncertain requirement before the model ran (aien-sovereign-core issue on goal interpretation). The objective now uses the two requirement phrasings the runtime recognizes; its meaning is unchanged. The objective still asks the installation to read files, which the compose proposer cannot do today (aien-sovereign-core#382); until that lands, step E3 on this objective is expected to FAIL, and that expectation is part of the record.

Fixture: an `inbox/` with three UTF-8 text files whose names and sha256 are listed in the chain's first receipt; an empty `outbox/`. The second objective for E4, exactly: `Append one line to report.md naming the file you reported on first.` The memory item E4 depends on is the first file's name as recorded by the installation during E3.

Output checks (used by the verifier, OBSERVED): `report.md` exists, UTF-8, first line starts with `# `, at most 200 words, contains all three file names; after E4, one appended line names the first file. These are the document checker rules of the ALLEN demo (`scripts/allen_e2e_demo.sh` `check_doc`, C1 to C5) extended by the file-name rule; the verifier reimplements them, it does not call the script.

## 4. Platforms and the order of runs

| run | machine | model path | counts as |
|---|---|---|---|
| RUN-1 | Spark, CPU-reference backend | the internal model (Llama 3.2, CAND-4; Drake ruling 2 of 2026-10-10 keeps it internal-test only) | first measurement of E2 to E6 |
| RUN-2 | Spark, GB10 through the native Omega engine, no CUDA, under a quiet hold | same | E3 with the accelerator backend line |
| second-machine verdict | MacBook, verifier built from a clean checkout with `rustc` directly | n/a (verifier only) | E5 cross-machine agreement |
| RUN-3 | Spark, installed from the release artifact into a clean user | the qualified public model (Qwen3-4B-Instruct-2507 after a frozen qualification PASS, lane L10); a dry-run artifact with the internal model is RUN-3-internal and never a public-release claim | E1 plus the whole chain |

Native Aienux is NOT_RUN in v1 and is not a row here; v2 of this file adds it when NEXT-PHASE-3 step 5 closes.

## 5. Rules of the run

1. No network: the harness records `ip route` and the daemon's bound sockets before the run; any non-loopback connection fails the run.
2. No Python, no systemd, no CUDA, no GPU except in RUN-2.
3. Real model weights; the weights sha256 is in every receipt.
4. The harness is shell plus `jq`; the verifier is Rust standard library only.
5. Evidence folder immutable once written; the chain manifest lists every file with its sha256.
6. NOT_RUN is never PASS. A step whose control was not run is NOT_RUN even if its positive row passed.
7. One attempt per declared run. A failed run stays recorded; a new attempt is a new run with its own folder.

## 6. What a PASS does not show

Not claimed by any PASS of this test: security against a hostile operator or model, behaviour under concurrent operators, long-running stability, correctness of the model's prose beyond the output checks, anything on the native Aienux target, anything about the research programs.

## 7. Freeze procedure

When lanes L1, L2, L6 have pre-registered rows that reference this file, the coordinating session posts on #190: this file's path, commit and sha256, and changes the status line to FROZEN in a one-line commit. The `aien-protocols` evaluation spec is amended in the same milestone to name `AIEN_E2E_VERDICT_V1` as a verdict identity domain.
