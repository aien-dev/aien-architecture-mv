# osh (Omega-native shell): first-release acceptance and status record

**NOT A MASTER PLAN.** Finite workstream record for [aien-spark/aien-architecture#158](https://github.com/aien-spark/aien-architecture/issues/158). It is subordinate to `PLAN_AUTHORITY.md`, `CURRENT_EXECUTION_PLAN.md`, `doctrine/ARCHITECTURE.md` and `doctrine/ROADMAP.md`. It does not reorder any campaign, change subsystem ownership, replace NEXT-PHASE-3, or raise any milestone status. It freezes the acceptance of one workstream and records, honestly, what exists. Where this file and those authorities disagree, they win. Implementation and evidence win over every claim below.

**Written:** 2026-10-08. **Pins read:** omega `b980783a4674275e720592e4c3887679dd24ec8b`, aienos `c63d6db8e9ac82592899ab0c2cbd9e2a76e6c7b2`, aien-protocols `3a4cdbe` (GitHub default branches). Re-read before acting on this file. Follows ADR 0024: Omega is the destination, Rust and C host code is replaceable scaffolding.

## 1. Frozen first-release language (R1)

R1 is what the Linux adapter must run. This section freezes the language so the ABI vectors and the differential suite have one target. Details of codes and offsets live in the platform ABI draft ([aien-protocols#16](https://github.com/aien-spark/aien-protocols/pull/16), `specs/osh-platform/OSH_PLATFORM_ABI.md`).

**In R1** (issue list): words, single and double quotes, backslash escapes, empty arguments; variable assignment and expansion with the documented field-splitting rule; `;`, `&&`, `||`, pipelines; `<`, `>`, `>>`, and the stderr forms `2>` and `2>>` (generally `N<`, `N>`, `N>>` with N in 0..2); exit statuses; builtins `cd`, `pwd`, `printf`, `export`, `unset`, `exit`; interactive input, `osh -c`, and script files.

**R1 additions** (queen engineering decision, 2026-10-08, from the script syntax inventory): `2>&1` and `N>&M` with N and M in 0..2 (applied left to right, so `>o 2>&1` and `2>&1 >o` differ), `$?`, `#` comments, backslash-newline continuation, `$0` to `$9`, `$#`, `"$@"` (and unquoted `$@`, `$*`; `"$*"` joins with one space).

**Refused by name** (each has its own refusal code, never a silent fallback): command substitution and backticks, `$((`, parameter operators such as `${A:-y}`, `$$ $! $- $_`, `${10}` and other positionals past 9, brace expansion (`{a,b}`, `{1..3}`), `NAME+=` assignments, `{NAME}` descriptor variables before a redirection, input that ends inside a quote, tilde, unquoted globbing characters in the source, and any unquoted expansion result containing `*`, `?` or `[` (`VALUE_GLOB`), background `&`, subshells, here-documents, `;;`, other redirections (`>|`, `<>`, descriptors above 2), `if for while until case function { } !`, bash builtins outside the six, decided on the command name after expansion (`set eval exec . source trap shift read return break continue local readonly alias wait : declare typeset let command type umask hash ulimit getopts jobs pushd popd dirs history unalias fg bg builtin enable shopt mapfile times caller disown suspend logout bind help compgen complete fc compopt`; names longer than 8 bytes such as `readarray` are not yet caught, omega#344), assigning `IFS`, empty commands, redirections without target, ambiguous redirections, NUL bytes in source or variable values.

**Rules:**
1. A syntax error or any refusal ends that list with exit status 2 and resets the session. Durable state (variables, location, `$?`) survives.
2. Validation is incremental, one complete list at a time. There is no whole-script atomicity: earlier lists of a script have already run when a later one is refused.
3. The guarantee is worded exactly: "refused before the effect of that pipeline". Refusals that depend only on text happen before anything in that list runs. Refusals that depend on variable values (`CAP_FIELDS`, `CAP_OUT`, `VALUE_NUL`, `VALUE_GLOB`) happen before that pipeline only.
4. IFS is fixed to space, tab and newline. Unset variables expand to empty. No `set -u`.
5. Paths and arguments are bytes; NUL is refused. Native storage locations are not POSIX paths (ABI section 8.2).
6. The language engine is never `bash -c`, `sh -c`, `system()` or equivalent.
7. (added 2026-10-08 from the bash differential review, omega#340) When `export` is the literal unquoted command word, its `NAME=value` arguments expand like assignments: no field splitting, `$@` joined. A quoted `"export"` or one reached through a variable splits, as in bash.
8. (same source) `osh -c` text ends at the true end of input, so a final backslash is literal (`osh -c 'echo a\'` prints `a\`); script files and standard input end their last line as bash does. `exit` with two or more arguments does not exit: status 1 and the rest of that list is dropped (under `-c` bash drops the rest of the whole string; known difference, omega#344).

## 2. Release ladder

| Release | Contents | Gate |
|---|---|---|
| R1 | Shared Omega core plus Linux adapter: interactive, `-c`, script modes. Interpreter and native ARM64 runs of the same core. | Section 3 |
| R1.1 | Aienux native: real console input path, storage locations over the Store, artifact packaging and loading, task and IPC use, QEMU acceptance. Depends on the 13 native services in section 6. | QEMU acceptance from the issue, hosted simulation does not count |
| R1.2 | Additions in inventory order (unlock count over 326 scripts, recount 2026-10-08): `$( )`, `set -e/-u/-o pipefail`, `if`, `for` and `while`, `case`, `{ }`. | Each addition gets its own vectors and differential rows before it is accepted |
| Later | Functions, globbing, here-documents, background jobs, hardware validation (separately authorized, attended). | Not scheduled here |

R1 is not "AIENOS shell done". R1.1 is still required by the issue and is not dropped.

## 3. R1 acceptance criteria

All of these must have recorded evidence before R1 is called done. Skipped checks are not passes.

1. **Pinned reference.** One Bash version, locale (`LC_ALL=C`), environment and fixture set, recorded with the receipt. Version set 2026-10-08: GNU bash 5.2.21 (omega `tests/osh/vectors/bash_verify.sh` refuses any bash other than 5.2.x). The locale, environment and fixture set are NOT yet pinned by the harness (it does not set `LC_ALL`); open.
2. **Differential categories** (issue): argument boundaries; relevant stdout and stderr; exit status; cwd and environment; filesystem effects; pipeline completion and cancellation. Supported-feature comparisons only; refusals are compared to the refusal table, not to bash.
3. **Hostile cases:** empty and quoted arguments, hostile filenames (spaces, leading dash, newline, non-UTF-8 bytes), malformed syntax, oversized input (line cap, token cap, workspace cap), large streams, early pipe-reader exit, failed redirections, partial launch failure, descriptor and child cleanup, Ctrl-C, EOF. Denied, revoked and stale capabilities are R1.1 for the native path and an adapter test on Linux through the binding check.
4. **Interpreter versus native ARM64:** the same core, same vectors, same results in both modes. Adapter tested independently of the core.
5. **Real script target:** `omega/evidence/CAND2-AUDIT-20261005/runners/run_builds.sh` (4 lines) run unchanged in a disposable fixture. The script uses `cd` to an absolute path, `>`, `>>`, `2>&1`, `;` and `$?`; its `echo` is the external `/usr/bin/echo`, resolved as a Linux executable. The fixture must supply that absolute directory and a stub `cand2_build.sh` (the script itself is not edited and its checks are not weakened). This is the only R1 real-script target; no other of the 326 scanned scripts is claimed.
6. **Conformance vectors** from aien-protocols pass in the core, with exact refusal codes and offsets.
7. **Exact revisions** of core, compiler, contract and harness are recorded; failed attempts are kept; no full-Bash, hardware or performance claim.

## 4. Placement (proposed, pending owners)

These are proposals, not ownership decisions. Reconcile with each repo's owners and `.crumb` before creating directories. No new repository.

| Piece | Proposed owner | Note |
|---|---|---|
| Compiler additions (OSC-EXT-BYTES, byte load and store, runtime bounds) | omega `src/compiler/` | extends the existing compiler; design merged as omega#169 |
| Shell core `.osc` (lexer, parser, expander, session) | omega | split across units (32 function limit per unit) |
| Linux host adapter | omega host scaffolding (ADR 0024), owner to confirm | ordinary C, no second parser |
| Aienux native adapter (console, Store locations, artifact loading, tasks) | aienos | R1.1 |
| Platform ABI and conformance vectors | aien-protocols, `specs/osh-platform/` | draft in aien-protocols#16; "if consistent with current ownership" per the issue |
| This record, compatibility matrix, status | aien-architecture | scoped, not a plan |
| Visor views | omega `src/visor/`, reused through explicit interfaces | section 5 |
| Authority (mint, revoke) | capability root, unchanged | the shell never grants |

## 5. Visor reuse boundary

The Visor (`omega/src/visor/`) is an operator REPL with 19 fixed command words, four argument slots, a 4095-byte line limit and a 255-byte token limit (`visor_parse_command.h:31-33`); it is not Bash syntax. It is not renamed and not called a shell.

Reuse: the console output contract (human and JSON shapes, class tags); the inspection hooks (inspect, type, id, graph, machine, evidence, world, why); the classify-before-run gate as the pattern for any osh "run" (`visor_console.c:304-321`); `visor_effect_request.*` as the only way to render an effect object as a request.

Do not: add any osh path that sets `authorized`, mints, grants, publishes or executes through Visor objects; link `rx_*`, `aienos_cap_*` or `rc_*` into Visor objects; reimplement the digest check in `visor_effect_request.c`; widen the closed Visor command table (use a separate word table).

The invariant, quoted: "Invariant: THE VISOR CAN ASK. THE VISOR CANNOT GRANT." (`src/visor/visor_effect_request.h:4`; also `spec/visor-authority.md:3`). It is enforced by a link check (`tests/visor/check_authority_link.sh`, `make visor-authority-check`).

## 6. R1.1 dependencies: native services that do not exist

From the Aienux readiness audit at `c63d6db` (read-only, no QEMU run; citations in the issue's audit are repo-relative). Each is an explicit dependency, to be implemented and reviewed, not assumed.

1. Serial console input (`console.c` has output only; the USB keyboard is the only key input).
2. A keyboard session beyond the 60 s total and 15 s idle limits, surviving the recovery choice (`usb_kbd.h:37-41`, `devices.c:75-83`, `xhci_fence.c:101-135`).
3. Shell commands beyond the six in the bounded console (`usb_hid.c:177-186`).
4. A task or process model to spawn into (scheduler is fixed 16 tasks, demo-only callers, `sched.h:9-10`).
5. An IPC endpoint for the shell (two principals, depth 8, 56-byte messages, `ipc.h:65-95`).
6. Runtime artifact read by name (read is boot-time only, `artifact_store.h:57-62`; no lookup-by-name).
7. Runtime artifact invoke (the loader runs once per boot, `artifact_loader.c:1326-1329`).
8. A trusted signer in the default build (zero anchors, `artifact_loader.c:90-91`, `admission.c:17`).
9. Production Store keys (default build uses TEST keys, `store_boot.c:363`; production blocked, `store_boot.c:342`).
10. The 64-bit capability authority started at normal boot with a shell view (only a test starts it, `stage_test.c:355`), and one capability model (the kernel IPC table is 32-bit, `ipc.h:39-54`).
11. A recovery console that accepts commands (the stub halts, `usb_kbd.c:571-592`).
12. A production operator key (`continuity_boot.c:36-38` is a TEST constant).
13. An Omega runtime or loader in native C (none found).

The existing recovery path stays model-independent and read-only; osh is not the only recovery mechanism and is not a repair bypass.

## 7. Status

Original record pinned above. **Status update 2026-10-08** (GitHub, omega `main` after #343, `ed7cbf3`). "DONE" requires a link to evidence; the shell is not done.

| Item | Status |
|---|---|
| Audit of compiler, Visor, Aienux, scripts, parser design | DONE as read-only notes (not committed evidence) |
| OSC-EXT-BYTES design | DONE, merged [omega#169](https://github.com/aien-spark/omega/pull/169) (design only) |
| OSC-EXT-BYTES implementation | DONE, merged [omega#335](https://github.com/aien-spark/omega/pull/335) `5227b88` (bytes and cells parameters) |
| First-release acceptance frozen | This file; frozen when merged |
| Platform ABI v1 and vectors | IN PROGRESS: DRAFT [aien-protocols#16](https://github.com/aien-spark/aien-protocols/pull/16), not frozen; implementation deltas folded in; 20 vectors, all run by the omega lexer, parser and expander tests |
| Shell core `.osc` | Lexer merged [omega#336](https://github.com/aien-spark/omega/pull/336) `da40e53`; parser merged [omega#339](https://github.com/aien-spark/omega/pull/339) `baedadc`; expander merged [omega#340](https://github.com/aien-spark/omega/pull/340) `fe73157`. Each unit is checked against an independent C reference |
| Linux adapter | Execution service merged [omega#337](https://github.com/aien-spark/omega/pull/337) `06b0f07`; driver loop and `osh` program (`-c`, script, interactive) merged in omega#340; capability enforcement, fail closed without a policy, merged [omega#341](https://github.com/aien-spark/omega/pull/341) `cb8b549` |
| Differential and hostile suite, pinned bash | IN PROGRESS: GNU bash 5.2.21 (locale not yet pinned); lexer expectations proved against real bash (`bash_verify.sh`); hostile bash differential review of omega#340 (about 1500 cases), fixed in #340 (merged; local evidence: expand 478,635 checks, parse 2,879,236, lex 2,928,338, host 1439, e2e 104 cases and 317 checks, all 0 failures), remaining differences listed in [omega#344](https://github.com/aien-spark/omega/issues/344) |
| Interpreter versus native ARM64 run | IN PROGRESS: lexer, parser and expander tests compare interpreter, native ARM64 and C reference on the same inputs (merged); e2e runs every case native and interpreted |
| Real script run (`run_builds.sh`) | NOT STARTED |
| Core-only step trace for Aienux | Linux side merged [omega#343](https://github.com/aien-spark/omega/pull/343) `ed7cbf3` (20 fixtures, native == interpreter == committed trace); Aienux side not merged |
| Aienux native services (section 6) | NOT STARTED as merged code |
| Native QEMU acceptance | NOT STARTED |
| Attended hardware validation | NOT STARTED; needs separate authorization |
| Compatibility and limits matrix | NOT STARTED as a matrix; known differences tracked in omega#344 |

No full-bash, hardware or performance claim. No milestone status changes.
