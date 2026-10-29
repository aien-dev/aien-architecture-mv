# Zero-legacy closure checker (seeded `.om`)

Owner: [aien-architecture-mv #316](https://github.com/aien-dev/aien-architecture-mv/issues/316)
under the inventory authority [#300](https://github.com/aien-dev/aien-architecture-mv/issues/300).
Status: **v0, transitional inventory mode qualified on the host; release mode implemented and
gate-tested on fixtures; not yet wired into any release decision.**

Native Omega programs, built only by the pinned seed compiler in `omega.pin`
(`seed/out/omc` of `aien-dev/omega-mv`, born from `seed/rung0/seed0.hex` by
`sh seed/omega-from-seed.sh`). No C, Rust, Python or foreign runtime is on their
implementation path. The shell in `tests/gates/run.sh` only sequences the build and the
runs; every judgment is made by these programs.

| Program | Role |
| --- | --- |
| `closure.om` | walk one checked-out tree, classify every regular file, apply a manifest, print rows and a summary, refuse in release mode |
| `expect.om` | judge a report against an expected-row file (order free, row counts equal) |
| `bind.om` | bind one closure report to owning issues and print the M0 ledger rows of #300 |

## Build and run

```
sh seed/omega-from-seed.sh                      # in omega-mv at the pinned commit
seed/out/omc < tools/zero-legacy/closure.om > closure && chmod +x closure
./closure ROOT [release] [MANIFEST]
```

Exit: 0 inventory done (transitional) or release accepted; 1 release refused, outstanding
first-party rows remain; 2 release refused, unknown rows remain; 64 usage; 65 manifest
unreadable. Program-mode traps exit 100 + code (103: the 1 MiB directory stack overflowed).

Output: one `CATEGORY<TAB>path` row per file, then `# CATEGORY count` lines, `# MODE 0|1`,
`# OUTSTANDING n`, `# UNKNOWN n`.

## Classification (content first, then name)

| Category | Rule | Counts as |
| --- | --- | --- |
| `ELF` | head bytes `7f 45 4c 46` | unknown unless declared `generated`/`external` |
| `ARCHIVE` | gzip, zip, xz, or `ustar` at byte 257 | unknown unless declared `external` |
| `OM` | `.om` | native |
| `WRAPPER` | `.om` containing the word `execprog` (a launcher of something else) | outstanding until reviewed |
| `C_H` `RUST` `PYTHON` `OSC` | `.c` `.h` `.cc` `.cpp` `.hpp` `.cu` `.cuh`, `.rs`, `.py`, `.osc` | outstanding |
| `XLANG` | `.ts .tsx .js .jsx .mjs .cjs .go .swift .zig .rb .vue .ps1 .java .kt .php .lua .mojo .pl .pm .dart .cs .sql .nix` | outstanding (first-party code in another language; before this row these files were `OTHER`) |
| `SHELL` | `.sh` `.bash` | outstanding |
| `FOREIGN` | shell whose head mentions `python`, `perl`, `node` or `ruby` | outstanding |
| `HEXASM` | `.hex` `.hex1` `.s` `.S` `.s2` `.asm` | outstanding; `.hex`/`.hex1` may be declared `data` |
| `MAKE` | `Makefile`, `.mk` | outstanding (build logic) |
| `HIDDEN` | any name not in a source row above (including `.om`) whose head starts with `#!`, or contains `#include` or `fn main(` | outstanding |
| `DOC` | `.md .txt .json .toml .yml .yaml .lock .csv .svg .html .css .png .jpg .gif .pdf .gate .xml .pub .sig .tex .ini .cfg .pem .crumb .log`, dotfiles with one dot, all-capitals names | neither |
| `OTHER` | everything else | unknown |
| `SYMLINK` | not followed | neither |
| `UNREADABLE` | directory or file that could not be opened, or an entry whose path would exceed 4095 bytes (the parent directory is printed) | unknown |

Rules are tried in the table's order after the two magic checks; the first match wins. Only the first 4096 bytes of a file are inspected. `.git` entries are skipped at every depth.

## Manifest

Lines `data P`, `generated P`, `external P`, `skip P`; `P` is a path prefix relative to ROOT.
Other lines, and lines with an empty prefix, are ignored. The first matching line wins; `skip` on a directory stops the walk below it and is counted once under `SKIP`. A manifest of 65,535 bytes or more is refused (exit 65). Unreadable files under `data`/`generated` stay `UNREADABLE`.

| Kind | Effect | Refused as `FORGED` when the file is |
| --- | --- | --- |
| `data` | golden vectors, non-executable hex: row `DATA` | any source category, `.s/.S/.s2/.asm` assembly text, an ELF or an archive |
| `generated` | emitted machine code or artifacts: row `GENERATED` | any source category or an archive |
| `external` | third-party or vendor files: row `EXTERNAL`, always listed | never (a reviewer reads these rows) |
| `skip` | not scanned (build directories): counted under `SKIP` | n/a |

`FORGED` rows are outstanding: a manifest cannot turn a `.c` file into data. A handwritten
`.hex` seed declared as `data` is accepted by this tool; distinguishing executable from
golden hex is the manifest owner's claim, reviewed by the issue owner (#725 for the seed
rungs), not something this tool can decide from bytes.

## Gate

`tests/gates/arch-zero-legacy-closure.gate` runs `tests/gates/run.sh zero-legacy` with
`AIEN_OMC` pointing at an omc whose sha256 equals `omega.pin`; otherwise NOT_RUN (exit 3).
The hostile fixture `fixtures/tree` (hidden C in a `.txt`, a shebang file without a suffix,
shell executing Python, a `.om` launcher, forged `data` over a `.c`, a `.ts` and a `.s`, a
TypeScript file, an ELF, an archive, a stale `.hex`, a Makefile, a skipped directory) must be
refused with exit 1 and match `fixtures/tree.expected` row for row; `fixtures/clean` must be
accepted with its manifest and refused (undeclared hex) without it. The gate then binds the
hostile report with `bind` (see below) and requires: bound ledger exit 0 and equal to
`fixtures/ledger.expected`; owner gap (`owners-gap.tsv`) exit 1 and not equal to the expected
ledger; unresolved gap (`owners-unres.tsv`) exit 2; an owners line with an empty field
(`owners-bad.tsv`) exit 65; a report without its final `# UNKNOWN` line (`cut.report`) and a
report with a category closure never prints (`badcat.report`) exit 66.

## M0 ledger (`bind.om`)

```
./bind REPORT OWNERS REPO SHA [full]
```

`REPORT` is one `closure` report of a tree checked out at `SHA` (40 lowercase hex). `OWNERS`
lines are `REPO<TAB>PREFIX<TAB>OWNER<TAB>BLOCKER`; `PREFIX` `.` is the whole repository; the
first line whose repository equals `REPO` and whose prefix matches the path wins. Output rows:
`REPO SHA CLASS STATUS CATEGORY PATH OWNER BLOCKER`, then `# LEDGER`, `# CLASS` and `# UNBOUND`
summary lines. Classes: `native` (OM), `first-party` (every outstanding category), `generated`,
`external`, `doc-data` (DOC and DATA, printed only with `full`), `unresolved` (closure's unknown
categories plus SYMLINK and SKIP). Status: NATIVE, OPEN (first-party with owner), INVENTORIED
(generated/external/doc-data), UNKNOWN (unresolved with owner), UNBOUND (no owner line).
Exit: 0 every first-party and unresolved row has an owner; 1 a first-party row is unbound;
2 only unresolved rows are unbound; 64 usage or a SHA that is not 40 lowercase hex; 65 an
unreadable or oversized input or an owners line with an empty field; 66 a report that is not
whole (unknown category, empty path, or no final `# UNKNOWN` line).

`m0/` holds the repository-wide run for #300: `owners.tsv` (one file for every repository),
`repos.tsv` (every enumerated repository with visibility, archived/fork status, scanned sha and
closure/bind exit codes; archived and fork repositories are listed, not scanned; namespaces the
bot cannot enumerate are `UNKNOWN` rows) and `ledger/<owner>_<repo>.tsv` (the bind output per
repository, without `full`). It is regenerated by shallow-cloning each repository at its default
branch head and running, from the clone's root, `closure . > R` then
`bind R owners.tsv OWNER/REPO SHA`. The clone loop is a few lines of shell that only sequence
these two programs; it is not part of the tool.

## Limits of v0 (honest scope)

- Source tree only. It does not yet follow the build: linked libraries, process trees, and
  the ELF closure of a product are the next slice (#316 item 2) and need the device/process
  words already in the language (`execprog`, `waitpid`, `pipefds`, `readlnk`).
- Head-only inspection (4096 bytes); a `#include`, shebang or `execprog` past that is missed, as is
  C or Python text that carries none of the three markers. The content rules are a floor, not a parser.
- `expect.om` consumes each matched output line, so repeated rows must each occur (multiset match).
- A file name containing a newline splits its row; entry types come from `getdents64` `d_type`.
- Capacities: manifest 64 KiB, path 4095 bytes, 999,999 directories per run, 1 MiB directory
  stack.
- This repository's own `tools/crumb/crumb.c`, its Makefile and `scripts/*.sh` are reported as
  outstanding by this checker; they are migration rows of this repository, not exemptions.

## Product-closure ledgers (`ledgers/`)

`ledgers/aien-serve-http-bin-19173f9e.tsv`: the native closure of the live 35B server, read from
the `libomega_gpu.a` shipped beside the binary (`ar t`, SHA256SUMS verified), each member resolved
to its source path in omega-mv a0eafa39 (85 files, 36,232 lines of C) and physics-mv 048e5f5e
(`nvrm/nvrm.c`, `m16/m16_native.c`), plus the 30 workspace crates `cargo metadata` reaches from
`aien-serve-http` in sovereign-core 9699d928 (128,931 lines of Rust). `src/compiler/*` is absent
from this closure. Ledger rows are `LINKED object source` and `CRATE name`; they are read from a
built artifact, not from Makefile text, so they are the closure denominator for Core #753 and
CUDApp #79, not the source-row counts above.

## Gate runner and hasher in `.om` (replaces the shell step)

`gate.om` is the gate: it compiles `closure.om`, `expect.om`, `sha256.om` and `bind.om` with the compiler it
is given, hashes that compiler with the native `sha256` and refuses (exit 3, NOT_RUN) unless the
digest equals `omc_sha256` in `omega.pin`, runs the hostile and clean fixtures, judges them with
`expect`, prints the `AIEN-OBS` lines and exits 0 only when every expectation holds. A compiler
with one semantic edit in `omc.om` (`fail 12`→`fail 13`, digest `ca2aa132…`) is refused by this
check. `gate.sh` is the loader that compiles `gate.om` (exit 1 with a message when that compile
fails, instead of exec'ing an empty binary) and execs it, the same role
`seed/rung0/load0.sh` has for the seed; no judgment lives in shell any more.

`sha256.om` is FIPS 180-4 SHA-256 (file or stdin, hex on stdout, 16 MiB cap, exit 65/66). Checked
byte for byte against coreutils on the empty string, `abc`, the million-`a` vector, random inputs of
55, 56, 64 and 3,000,000 bytes, and the omc binary; 38 MB/s on one Spark core. It is the first
`.om` implementation of a file that is in the live product closure (`src/sha256.c`,
`ledgers/aien-serve-http-bin-19173f9e.tsv`); the in-process cutover of that C file waits on an
`.om` object/C-ABI boundary (OM_COMPLETION FR-7), which belongs to the compiler owners.

Circularity, stated: the compiler under test compiles the hasher that checks the compiler. A
forged compiler could forge both. The receipt consumer (aien-test, or a human) must check
`omega.pin` with a hasher it trusts before trusting this gate's NOT_RUN/PASS; the shell step it
replaced had the same shape with coreutils `sha256sum`.
