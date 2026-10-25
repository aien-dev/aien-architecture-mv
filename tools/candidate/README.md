# tools/candidate: the candidate-manifest checkers in seeded Omega

Two first-party tools of `docs/qualification/CANDIDATE.md`, rewritten from bash into seeded
native Omega (`.om`) for the zero-legacy migration (#300, #316). They replace
`scripts/check_candidate.sh` and `scripts/check_candidate_pins.sh` (last at 1dd84d1) with the
same arguments, the same stdout and stderr lines in the same order, and the same exit codes.

| program | usage | exit |
|---|---|---|
| `check_candidate.om` | `check_candidate <manifest.toml>` | 0 valid, 1 invalid (usage error: 1) |
| `check_pins.om` | `check_pins <manifest.toml>` | 0 every pin agrees, 1 any mismatch or read failure |

Build with the pinned seed compiler (`tools/zero-legacy/omega.pin`, `omc_sha256`
`734f0a39…6b61`): `$AIEN_OMC < check_candidate.om > check_candidate && chmod +x check_candidate`.
Each file is one unit; Omega has no `import`, so the shared part (parser, key table, process
spawning) is carried by both files, as `tools/zero-legacy/*.om` carry their own helpers.

What they check is unchanged and documented in `docs/qualification/CANDIDATE.md`: commit pins are
40 lowercase hex and exist (`gh api repos/aien-dev/<repo>/commits/<sha> -q .sha`, or the command in
`CAND_SHA_CHECK` run as `$CAND_SHA_CHECK <repo> <sha>`); executable digests are 64 hex and not all
zero, `UNBUILT` only while the status starts with `draft`; every `<stem>.amendment-<n>.toml` next to
the manifest is checked (schema, candidate, number, date and reason, `manifest-sha256` of the frozen
manifest computed natively, added keys only, never in `[commits]`, `[contracts]`, `[executables]`
or `[consumed_pins]`, `*-sha256` values real). `check_pins` fetches lock files
(`gh api -H "Accept: application/vnd.github.raw" repos/aien-dev/<repo>/contents/<path>?ref=<sha>`,
or `$CAND_FILE_AT <repo> <sha> <path>`) and compares them with the manifest's pins and
`[consumed_pins]`.

## The parsed TOML subset

Both programs parse exactly what the bash parsed, and every manifest and amendment under
`qualification/candidates/` and `scripts/testdata/` uses only this:

- `key = "value"` with an optional trailing `# comment` after the closing quote. Whitespace
  (space, tab, CR, VT, FF) may surround the key, the `=` and the value. The key is
  `[A-Za-z0-9_.-]+`; the value is any bytes but `"` (so a `#` inside the quotes is kept, and a
  quoted value cannot contain `"`).
- `[section]` with the same name alphabet, optionally followed by a `# comment`. Keys after it
  are stored as `section.key` until the next section line.
- Blank lines and `# comment` lines.
- A duplicate key keeps its last value. A final line without a newline is not read (bash
  `while read` stops there). NUL bytes are dropped from a line (bash `read` drops them).

Any other line (`key = 5`, `key = [..]`, `[[array]]`, `key = "a" "b"`, unterminated quotes) is
ignored, exactly as the bash ignored it; a required key written that way reads as missing and is
reported by the existing checks (`missing field`, `is not 40 lowercase hex`, `does not match its
file name`, ...). No new refusals were added because the frozen contract is byte parity with the
bash; the adversarial corpus below pins that behaviour (`wrong-type`, `dup-key`, `extra-section`,
`junk-lines`, `crlf`, `trailing-space`, `no-final-newline`, `nul-byte`, ...).

Keys read by `check_candidate`: `schema`, `id`, `status`, `created`, `commits.omega`,
`commits.aienos`, `commits.aien-sovereign-core`, `commits.aien-protocols`,
`commits.aien-architecture`, `contracts.crumb-spec`, `contracts.spark-crumbs`, optional
`commits.physics`, `commits.interplane`, every `executables.*`; in an amendment `schema`,
`candidate`, `amendment`, `date`, `reason`, `manifest-sha256` and the added `section.key` entries.
Keys read by `check_pins`: `commits.aien-sovereign-core`, `commits.omega`, `commits.aienos`,
`commits.physics`, `commits.aien-protocols`, `contracts.crumb-spec`, `contracts.spark-crumbs` and
every `consumed_pins.*` (`sovereign-core-omega-lock`, `sovereign-core-cargo-lock-aien-protocols`,
`omega-physics-lock`, `omega-aienos-lock`, `omega-argus-lock` are compared; any other name is
reported `SKIP`).

## Order of lines: bash associative arrays, reproduced

The bash walked `${!kv[@]}` for the `[executables]` checks, the amendment keys and the
`[consumed_pins]` loop. That order is bash 5.2's hash order, so the .om keeps its keys in a table
that walks the same way: FNV-1 (multiply first, offset 2166136261, prime 16777619, 32-bit) over
the key bytes, 1024 buckets, growth x4 when the entries reach twice the buckets, a new key at the
head of its bucket, walk buckets ascending. Verified against `bash 5.2.21` on 30 random key sets up
to 5000 keys (including growth) and by the corpus (`many-exe-bad`: 50 FAIL lines in bash order;
`amend-many-bad`, `many-consumed`).

## Children and the environment

A child (`gh`, or the `CAND_SHA_CHECK` / `CAND_FILE_AT` command, split on space, tab and newline
as bash splits an unquoted variable) runs as `/bin/sh -c 'set -a; . "$1"; set +a; shift; exec
"$@"' sh /proc/self/fd/N cmd args...` where fd N is a memfd holding this process's environment
as single-quoted shell assignments. Omega's `execprog` starts a child with an empty environment
and no PATH search; the replay gives the child the full environment (so a test's `PATH`,
`GH_STUB_LOG`, `PARITY_FILES` reach it) and `sh` does the PATH search. Only entries whose name is a
shell identifier are replayed. In `gh` mode `check_candidate` sends the child's stdout and stderr
to `/dev/null` as the bash did; `check_pins` captures stdout through a pipe (trailing newlines and
NUL bytes dropped, as `$(...)` does) and leaves stderr alone.

## Oracle and parity corpus (`parity/`)

`parity/run.sh <check_candidate> <check_pins> [record]` runs every case under `parity/cases/`
and compares stdout+stderr (one pipe, in order) plus `rc=N` with `parity/expected/`. The expected
files were recorded from the bash scripts at 1dd84d1 (`record`), before they were deleted; the
.om binaries must reproduce them byte for byte. 74 candidate cases and 43 pins cases: every
case of the two test suites, the live `CAND-0` and `CAND-4` manifests, the gh code path with its
argv log, and adversarial inputs (missing, duplicate and wrongly typed keys, extra sections,
CRLF, trailing spaces, no final newline, NUL and non-ASCII bytes, empty and junk files, 50 bad
executables, 24 bad amendment keys, three amendments, a directory where a file is expected,
command words in `CAND_SHA_CHECK`/`CAND_FILE_AT`, empty and comment-only lock files, several and
forked Cargo.lock revisions, an 800-package Cargo.lock). Result: **113 identical, 4 named
limits, 0 different**. A case with a `limit` file is a documented difference: it is printed, not
counted as a failure, and reported if it ever becomes identical.

The suites `scripts/test_check_candidate.sh` (47 checks, 7 mutants) and
`scripts/test_check_candidate_pins.sh` (17 checks) compile the .om with `AIEN_OMC` and run it;
their counts are the same as against the bash. The mutants are now sed edits of the .om source
(`z = zero64 e`, `notq`, `NREQ`, `optpins`, `optpin`'s `shaex`, `mfeq`, `inmf`), recompiled.
`tests/gates/run.sh script-tests` refuses to run (exit 3, NOT_RUN) unless `AIEN_OMC` hashes as
`tools/zero-legacy/omega.pin` pins, then runs the parity corpus and the four suites.

## Limits (named differences from the bash)

1. **Locale.** The bash ran under the caller's `LANG`; in a UTF-8 locale its regexes refused a
   line holding invalid UTF-8 and counted any `iswspace` character (U+2003, U+3000, not U+00A0)
   as `[[:space:]]`. The .om matches bytes and knows the six ASCII spaces only, which is the
   bash's own behaviour under `LC_ALL=C`. Every real manifest is ASCII. Cases
   `non-ascii-invalid`, `non-ascii-space`.
2. **Amendment order.** The bash glob `<stem>.amendment-*.toml` sorted in the locale's
   collation (`en_US`: 10, 1, 2); the .om walks the names in byte order (1, 10, 2; the `LC_ALL=C`
   order). Only the order of FAIL lines when several amendments fail differs; the count, the
   checks and the exit code do not. Case `amend-order`.
3. **NUL warning.** When a fetched lock file holds a NUL byte, bash printed
   `warning: command substitution: ignored null byte in input` on stderr and went on; the .om
   drops the byte silently. Case `lock-nul`.
4. **Diagnostics of the shell itself** are not reproduced: an unreadable manifest (bash printed
   `Permission denied` and went on with no keys; the .om goes on with no keys silently), a
   `CAND_SHA_CHECK` command that does not exist (`sh: not found`, exit 127, versus bash's
   `command not found`, exit 127; both report `commit ... not found`), and glob characters in
   `CAND_SHA_CHECK` words (bash expanded them; the .om does not).
5. **Capacities** (exit 70 with a message, where bash had none): a manifest, amendment or fetched
   file over 999,000 bytes; more than 4096 keys in one file; a key or section name over 8191
   bytes; more than 1024 amendment files; more than 256 revisions of one package in a Cargo.lock;
   a child argument list over 4096 bytes; an environment entry over 65,536 bytes is not replayed.
6. **Binary lock files.** `grep` in a UTF-8 locale treats invalid UTF-8 as binary and prints
   `binary file matches` instead of the line; the .om reads the bytes. Not exercised by the corpus.
