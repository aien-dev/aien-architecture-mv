# Zero-legacy closure checker (seeded `.om`)

Owner: [aien-architecture-mv #316](https://github.com/aien-dev/aien-architecture-mv/issues/316)
under the inventory authority [#300](https://github.com/aien-dev/aien-architecture-mv/issues/300).
Status: **v0, transitional inventory mode qualified on the host; release mode implemented and
gate-tested on fixtures; not yet wired into any release decision.**

Two native Omega programs, built only by the pinned seed compiler in `omega.pin`
(`seed/out/omc` of `aien-dev/omega-mv`, born from `seed/rung0/seed0.hex` by
`sh seed/omega-from-seed.sh`). No C, Rust, Python or foreign runtime is on their
implementation path. The bootstrap loader independently authenticates the compiler;
scanner and fixture judgments are made by native `.om` programs.

| Program | Role |
| --- | --- |
| `closure.om` | walk one checked-out tree, classify every regular file, apply a manifest, print rows and a summary, refuse in release mode |
| `expect.om` | judge a report against an expected-row file (order free, row counts equal) |

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
| `SHELL` | `.sh` `.bash` | outstanding |
| `FOREIGN` | shell whose head mentions `python`, `perl`, `node` or `ruby` | outstanding |
| `HEXASM` | `.hex` `.hex1` `.s` `.S` `.s2` `.asm` | outstanding; `.hex`/`.hex1` may be declared `data` |
| `MAKE` | `Makefile`, `.mk` | outstanding (build logic) |
| `HIDDEN` | any name not in a source row above (including `.om`) whose head starts with `#!`, or contains `#include` or `fn main(` | outstanding |
| `DOC` | `.md .txt .json .toml .yml .yaml .lock .csv .svg .html .css .png .jpg .gif .pdf .gate .xml .pub .sig .tex .ini .cfg .pem .crumb .log`, dotfiles with one dot, all-capitals names | neither |
| `OTHER` | everything else | unknown |
| `SYMLINK` | not followed | neither |
| `UNREADABLE` | directory or file that could not be opened or read, or an entry whose path would exceed 4095 bytes (the parent directory is printed) | unknown |

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
shell executing Python, a `.om` launcher, forged `data` over a `.c` and a `.s`, an ELF, an
archive, a stale `.hex`, a Makefile, a skipped directory) must be refused with exit 1 and match
`fixtures/tree.expected` row for row; `fixtures/clean` must be accepted with its manifest and
refused (undeclared hex) without it.

The native `fixtures/io-build.om` generates an instrumented copy of the actual scanner
with exact-count anchor checks, appending `fixtures/io-errors.om`. The gate builds and
runs both error cases: a real negative directory read, and a bad directory descriptor
after one successful enumeration batch. No production fault switch is added. These
are host filesystem tests, not GB10 compute tests. Native execution of these added
tests is NOT_RUN until the pinned compiler is available; old receipts do not qualify
this changed scanner or gate.

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

## Candidate product-dependency ledgers (`ledgers/`)

`ledgers/aien-serve-http-bin-19173f9e.tsv` records the 87 members reported by
`ar t` of the `libomega_gpu.a` shipped beside bin-19173f9e (SHA256SUMS reported
verified by the author), resolved to 85 omega-mv a0eafa39 source paths (36,232 C lines)
and two physics-mv 048e5f5e paths (`nvrm/nvrm.c`, `m16/m16_native.c`).
It also records 30 workspace crates reached by `cargo metadata` from
`aien-serve-http` in sovereign-core 9699d928 (128,931 Rust lines).

Rows are `ARCHIVE_MEMBER object source` and `WORKSPACE_DEPENDENCY name`.
Archive membership does not prove an object was extracted into the final executable;
dependency reachability does not prove which code was linked or executed.
`src/compiler/*` is absent from this inventory, not thereby proven absent from every
build/runtime dependency. These are candidate migration rows for Core #753 and
CUDApp #79, not a qualified live-product closure denominator.

Exact final-ELF/link-map membership, dynamic libraries/process descendants, build
configuration/source-to-artifact binding and current deployment identity remain
UNKNOWN pending receipts under #316. The recorded binary hash identifies the
reported artifact; it is not a fresh observation of the running server.

## Gate runner and hasher in `.om` (replaces the shell step)

`gate.om` is the gate: it compiles `closure.om`, `expect.om` and `sha256.om` with the compiler it
is given, hashes that compiler with the native `sha256` and refuses (exit 3, NOT_RUN) unless the
digest equals `omc_sha256` in `omega.pin`, runs the hostile and clean fixtures, judges them with
`expect`, prints the `AIEN-OBS` lines and exits 0 only when every expectation holds. A compiler
with one semantic edit in `omc.om` (`fail 12`→`fail 13`, digest `ca2aa132…`) is refused by this
check. `gate.sh` is the thin bootstrap loader: it independently authenticates the compiler
pin before compiling `gate.om` and handing over. Fixture judgments remain native `.om`.

`sha256.om` is FIPS 180-4 SHA-256 (file or stdin, hex on stdout, 16 MiB cap, exit 65/66). Checked
byte for byte against coreutils on the empty string, `abc`, the million-`a` vector, random inputs of
55, 56, 64 and 3,000,000 bytes, and the omc binary; 38 MB/s on one Spark core. It is a
`.om` implementation corresponding to an archive member (`src/sha256.c`,
`ledgers/aien-serve-http-bin-19173f9e.tsv`); the in-process cutover of that C file waits on an
`.om` object/C-ABI boundary (OM_COMPLETION FR-7), which belongs to the compiler owners.

The compiler under test compiles the native hasher, so that self-check is defense in depth,
not an independent root of trust. Before executing the candidate compiler, `gate.sh`
authenticates it against the reviewed `omega.pin` using trusted system `sed` and
`sha256sum`. This temporary external bootstrap boundary is disclosed; fixture judgments
remain native `.om`. The former shell runner also performed an independent pre-execution
check; replacing that check with self-authentication was not equivalent. This assumes
trusted OS/tools/pin and a compiler file not concurrently replaced.

### Bootstrap rejection regression (NOT_RUN)

Run only in an isolated fixture checkout with an independently verified pinned
`AIEN_OMC`. The direct invocation proves the sentinel works before checking rejection.
This fixture has not been compiled or executed for this change.

```sh
cd tools/zero-legacy
mkdir -p build
"$AIEN_OMC" < fixtures/loader-sentinel.om > build/loader-sentinel
chmod +x build/loader-sentinel
rm -f build/untrusted-compiler-ran
if build/loader-sentinel; then rc=0; else rc=$?; fi
[ "$rc" -eq 98 ] && [ -f build/untrusted-compiler-ran ] || exit 1
rm -f build/untrusted-compiler-ran
if AIEN_OMC="$PWD/build/loader-sentinel" sh ./gate.sh; then rc=0; else rc=$?; fi
[ "$rc" -eq 3 ] && [ ! -e build/untrusted-compiler-ran ] || exit 1
```
