#!/usr/bin/env bash
# corpus.sh: parity corpus for tools/doctrine/doctrine.om against the retired bash oracle.
# Builds mutated copies of the doctrine tree under a scratch directory, runs the oracle and
# the .om binary on each, and compares stdout and exit code byte for byte.
#
# usage: tools/doctrine/corpus.sh ORACLE.sh DOCTRINE-BINARY [REPO-ROOT]
#   ORACLE.sh        the bash script (git show <sha>:scripts/check_doctrine.sh > /tmp/oracle.sh)
#   DOCTRINE-BINARY  the compiled doctrine.om
# Exit 0 when every case is identical, 1 otherwise. Scratch dir: $CORPUS_DIR or mktemp.
set -u
export LC_ALL=C
ORACLE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
BIN="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
ROOT="${3:-$(cd "$(dirname "$0")/../.." && pwd)}"
WORK="${CORPUS_DIR:-$(mktemp -d)}"
mkdir -p "$WORK"
HB='<!-- HISTORICAL-PROVENANCE:BEGIN -->'
HE='<!-- HISTORICAL-PROVENANCE:END -->'

n=0; bad=0
# fresh <name>: a copy of the real tree (only the files in scope) at $D
fresh() { D="$WORK/$1"; rm -rf "$D"; mkdir -p "$D/doctrine" "$D/docs"
  cp "$ROOT"/doctrine/*.md "$D/doctrine/"; cp "$ROOT"/docs/milestone-*-spec.md "$D/docs/"; }
# app <file> <text...>: append one line
app() { f="$1"; shift; printf '%s\n' "$*" >> "$D/$f"; }
# run <name>: oracle vs .om on $D (or on a literal path when $2 is given)
run() { n=$((n + 1)); t="${2:-$D}"
  (cd / && env PATH=/usr/bin:/bin bash "$ORACLE" "$t") > "$WORK/$1.sh.out" 2> "$WORK/$1.sh.err"; a=$?
  (cd / && "$BIN" "$t") > "$WORK/$1.om.out" 2> "$WORK/$1.om.err"; b=$?
  if [ "$a" = "$b" ] && cmp -s "$WORK/$1.sh.out" "$WORK/$1.om.out"; then
    printf 'ok   %-28s exit %s, %s line(s)\n' "$1" "$a" "$(wc -l < "$WORK/$1.om.out")"
  else
    bad=$((bad + 1)); printf 'DIFF %-28s exit sh=%s om=%s\n' "$1" "$a" "$b"
    diff "$WORK/$1.sh.out" "$WORK/$1.om.out" | head -20
  fi; }

fresh real; run real "$ROOT"

fresh c01-status-tag; app doctrine/AIEN.md 'The ledger is [COMPLETE] and [IN PROGRESS] and [QEMU QUALIFIED] here.'
app doctrine/TRUST.md '  [COMPLETE / QEMU QUALIFIED]'; app doctrine/TRUST.md '[REOPENED anything at all]'; app doctrine/TRUST.md '[REOPENED without close'; run c01-status-tag

fresh c02-wrong-number; app doctrine/OMEGA.md 'See Milestone 3 (`DOCTRINE_V1`) and `OMEGA_VERIFY` (M8) later.'
app doctrine/OMEGA.md 'Milestones 12 - OMEGA_LIVING_MATVEC is fine but MILESTONE 11 — OMEGA_LIVING_MATVEC is not.'
app doctrine/OMEGA.md 'Correct: Milestone 7 (`OMEGA_VERIFY`); and `PHYSICS_BOOT` (Milestone 2).'
app docs/milestone-5-spec.md 'M27: AIEN_HUMAN_INTERFACE'; app docs/milestone-5-spec.md 'PHYSICS_EFFECTS (MILESTONE 4)'; run c02-wrong-number

fresh c03-unbalanced-begin; app doctrine/TRUST.md "$HB"; app doctrine/TRUST.md 'ALPHA inside the open block is blanked'; run c03-unbalanced-begin
fresh c04-unbalanced-end; app doctrine/FORGE.md 'ALPHA before'; app doctrine/FORGE.md "$HE"; app doctrine/FORGE.md 'ALPHA after'; run c04-unbalanced-end
fresh c05-nested-begin; app doctrine/FORGE.md "$HB"; app doctrine/FORGE.md "$HB"; app doctrine/FORGE.md "$HE"; app doctrine/FORGE.md "$HE"; run c05-nested-begin

fresh c06-row-deleted; sed -i '/^| \*\*M5\*\* |/d' "$D/doctrine/ROADMAP.md"; run c06-row-deleted
fresh c07-28-milestone; app doctrine/OMEGA.md 'The old 28-milestone plan, a 31-Milestone list, and the 128-milestone joke.'
app doctrine/OMEGA.md 'Twenty-eight precise milestones; twenty-eight milestones; Thirty-one milestones; thirty-one  milestones.'; run c07-28-milestone

fresh c08-alpha; app doctrine/ATLAS.md 'ALPHA release and the Alpha stage and alpha.bin and alpha.memory-map.'
app doctrine/ATLAS.md 'alphabet alpha.binary ALPHA_X xAlpha alpha.audit. alpha.sha256)'; app doctrine/ATLAS.md 'éALPHA ALPHAé _ALPHA'; run c08-alpha

fresh c09-el1; app doctrine/PHYSICS.md 'Monotonic Handoff (EL1) and EL1 handoff and at EL1 privilege level'
app doctrine/PHYSICS.md 'EL1 Jump; strictly at **EL1**; EL1 HANDOFF (no)'; run c09-el1

fresh c10-m27-closure; app doctrine/SOVEREIGNTY.md 'Milestone 27 — SOVEREIGN_MACHINE_CLOSURE'
app doctrine/SOVEREIGNTY.md '| M27 | SOVEREIGN_CLOSURE |'; app doctrine/SOVEREIGNTY.md 'SOVEREIGN_CLOSURE lands at M 27.'
app doctrine/SOVEREIGNTY.md 'XM27 AIEN_HUMAN_INTERFACE'; app doctrine/SOVEREIGNTY.md 'XM27 SOVEREIGN_CLOSURE'; app doctrine/SOVEREIGNTY.md 'M270 SOVEREIGN_CLOSURE'; run c10-m27-closure

fresh c11-retired; app doctrine/ATLAS.md 'SENTINEL_GATE_3 and SENTINEL_GATE_12 and ATLAS_BOOT and PHYSICS_CORE_MEMBRANE.'
app doctrine/ATLAS.md 'xBOOTSTRAP_SEED_ATLAS AIEN_SEED_TOPOLOGYx (AIEN_SEED_TRAINING)'; run c11-retired

fresh c12-physics-zero; app doctrine/DISCOVERY.md 'Physics Zero spans M26-M35.'
app doctrine/DISCOVERY.md 'M27-M35 (Physics Zero) is right; M27-M36 (physics zero) is not.'
app doctrine/DISCOVERY.md 'Physics Zero M27–M35 with an en dash never matches gawk in C.'
app doctrine/DISCOVERY.md 'Physics Zero runs M27 - M35 exactly.'
app doctrine/DISCOVERY.md 'Physics Zero (see M1-M2) M27-M35 takes the longest match.'
app doctrine/DISCOVERY.md 'Physics Zero. M26-M35 after a dot is out of reach.'
app doctrine/DISCOVERY.md 'physics zero M27-M35 and then physics zero M27-M34.'; run c12-physics-zero

fresh c13-roadmap-status; sed -i 's/^\(| \*\*M30\*\* | \)Physics Zero Discovery/\1Foundational/; s/^\(| \*\*M10\*\* | \)[^|]*|/\1General AIEN |/; s/^\(| \*\*M8\*\* | \)[^|]*|/\1Physics Zero Discovery |/' "$D/doctrine/ROADMAP.md"
sed -i '/^| \*\*M12\*\* |/ s/| [^|]*|$/| DONE |/' "$D/doctrine/ROADMAP.md"; run c13-roadmap-status

fresh c14-dup-table; app doctrine/INDEX.md '| **M3** | x |'; app doctrine/INDEX.md '  M12:  OMEGA_X'; app doctrine/INDEX.md 'M123: ABCD'; app docs/milestone-3-spec.md '	M4:	PHYSICS_EFFECTS'; run c14-dup-table

fresh c15-roadmap-missing; rm "$D/doctrine/ROADMAP.md"; app doctrine/OMEGA.md 'Milestone 3 (`DOCTRINE_V1`)'; run c15-roadmap-missing
fresh c16-roadmap-is-dir; rm "$D/doctrine/ROADMAP.md"; mkdir "$D/doctrine/ROADMAP.md"; run c16-roadmap-is-dir

fresh c17-historical-blanked; app doctrine/TRUST.md "$HB"; app doctrine/TRUST.md 'ALPHA [COMPLETE] 28-milestone Milestone 3 (`DOCTRINE_V1`)'; app doctrine/TRUST.md "$HE"; app doctrine/TRUST.md 'clean after'; run c17-historical-blanked

fresh c18-strip-and-cut; app doctrine/OMEGA.md "$(printf '\t  \r ALPHA %0300d' 0)"; app doctrine/OMEGA.md "$(printf '%0170dALPHA' 0)"; run c18-strip-and-cut
fresh c19-crlf; sed -i 's/$/\r/' "$D/docs/milestone-2-spec.md"; app docs/milestone-2-spec.md $'[COMPLETE]\r'; sed -i 's/$/\r/' "$D/doctrine/ROADMAP.md"; run c19-crlf

fresh c20-extra-files; app doctrine/zz.md 'ALPHA'; app doctrine/Aa.md 'ALPHA'; app doctrine/.hidden.md 'ALPHA'; mkdir "$D/doctrine/sub.md"; app doctrine/sub.md/x.md 'ALPHA'
app docs/milestone--spec.md 'ALPHA'; app docs/milestone-x-spec.md.txt 'ALPHA'; app docs/milestone-spec.md 'ALPHA'; app docs/Milestone-9-spec.md 'ALPHA'
ln -s AIEN.md "$D/doctrine/link.md"; ln -s nowhere "$D/doctrine/dangling.md"; app doctrine/_under.md 'ALPHA'; app doctrine/ZZ.md 'ALPHA'; app doctrine/a.md 'ALPHA'; run c20-extra-files

fresh c21-no-trailing-newline; printf 'x\nALPHA at the very end' >> "$D/doctrine/TRUST.md"; run c21-no-trailing-newline
fresh c22-empty-file; : > "$D/doctrine/EMPTY.md"; printf '\n' > "$D/doctrine/NL.md"; run c22-empty-file

fresh c23-milestone-emdash; app doctrine/OMEGA.md 'MILESTONE 12  — foo'; app doctrine/OMEGA.md ' MILESTONE 12 — x'; app doctrine/OMEGA.md 'MILESTONE 12 —x'; run c23-milestone-emdash
fresh c24-m-range-m27; app doctrine/OMEGA.md 'M1-M27 and M1 – M27 and M1–M27 and M1-M270 and xM1-M27 and M1-M27x'; run c24-m-range-m27
fresh c25-physics-boot; app doctrine/PHYSICS.md 'PHYSICS_BOOTSTRAP is COMPLETE'; app doctrine/PHYSICS.md 'PHYSICS_BOOT | COMPLETE'; app doctrine/PHYSICS.md 'PHYSICS_BOOT_COMPLETE and PHYSICS_BOOT COMPLETED'; run c25-physics-boot

fresh c26-roadmap-leading-zero; sed -i 's/^| \*\*M5\*\* |/| **M05** |/' "$D/doctrine/ROADMAP.md"; app doctrine/OMEGA.md 'Milestone 5 (`OMEGA_AARCH64`) and `OMEGA_AARCH64` (M05)'; run c26-roadmap-leading-zero

fresh c27-two-per-line; app doctrine/OMEGA.md 'Milestone 7 (`OMEGA_VERIFY`) then Milestone 9 (`OMEGA_VERIFY`) then Milestone 10 (`OMEGA_VERIFY`)'
app doctrine/OMEGA.md '`OMEGA_VERIFY` (M7) then `OMEGA_VERIFY` (M9) and Milestone 9 (`DOCTRINE_V1`)'; run c27-two-per-line

fresh c28-roadmap-historical; sed -i "/^| \*\*M38\*\* |/i $HB" "$D/doctrine/ROADMAP.md"; sed -i "/^| \*\*M40\*\* |/a $HE" "$D/doctrine/ROADMAP.md"; run c28-roadmap-historical

fresh c29-identifier-edges; app doctrine/OMEGA.md 'M5_OMEGA_AARCH64 and M5 _OMEGA_AARCH64 and M6__OMEGA_AARCH64 and MILESTONE 6 ___ OMEGA_AARCH64'
app doctrine/OMEGA.md 'THE OMEGA_AARCH64 (M6) and ABC_ (M5) and OMEGA_AARCH64` (Milestones 6) and OMEGA_AARCH64 ((M6)'
app doctrine/OMEGA.md 'OMEGA_AARCH64`----(M6) and OMEGA_AARCH64-----(M6) and OMEGA_AARCH64 (M 6) and OMEGA_AARCH64 (Milestone6)'; run c29-identifier-edges

fresh c30-roadmap-short-row; sed -i 's/^| \*\*M20\*\* |.*/| **M20** | Physics Zero Discovery |/' "$D/doctrine/ROADMAP.md"; run c30-roadmap-short-row
fresh c31-roadmap-dup-code; sed -i 's/^\(| \*\*M39\*\* | [^|]*| \)`[^`]*`/\1`OMEGA_VERIFY`/' "$D/doctrine/ROADMAP.md"; app doctrine/OMEGA.md 'Milestone 7 (`OMEGA_VERIFY`)'; run c31-roadmap-dup-code
fresh c32-row-with-space-status; sed -i '/^| \*\*M3\*\* |/ s/| [^|]*|$/|   COMPLETE   |/' "$D/doctrine/ROADMAP.md"; sed -i '/^| \*\*M4\*\* |/ s/| [^|]*|$/| COMPLETE	|/' "$D/doctrine/ROADMAP.md"; run c32-row-with-space-status

fresh c33-many-rows; for i in $(seq 41 45); do app doctrine/ROADMAP.md "| **M$i** | General AIEN | \`EXTRA_$i\` | x | PLANNED |"; done; run c33-many-rows
fresh c34-both-markers-one-line; app doctrine/TRUST.md "$HB $HE"; app doctrine/TRUST.md 'ALPHA blanked (BEGIN wins)'; run c34-both-markers-one-line
fresh c35-second-begin-then-end; app doctrine/INDEX.md "$HB"; app doctrine/INDEX.md "$HE"; app doctrine/INDEX.md "$HB"; app doctrine/INDEX.md 'x'; app doctrine/INDEX.md "$HB"; run c35-second-begin-then-end
fresh c36-relative-root; run c36-relative-root "$(realpath --relative-to=/ "$D")"
fresh c37-row-digits-only; sed -i 's/^| \*\*M0\*\* |/| **M** |/' "$D/doctrine/ROADMAP.md"; app doctrine/ROADMAP.md '| **M41** |'; run c37-row-digits-only
fresh c39-roadmap-no-rows; sed -i '/^| \*\*M[0-9]*\*\* |/d' "$D/doctrine/ROADMAP.md"; app doctrine/OMEGA.md 'Milestone 3 (`DOCTRINE_V1`)'; run c39-roadmap-no-rows

# missing ROOT: exit 2, empty stdout, and the script's own stderr line (bash prints its own
# "cd: ... No such file or directory" diagnostic first; that shell line is not reproduced)
n=$((n + 1)); (cd / && env PATH=/usr/bin:/bin bash "$ORACLE" "$WORK/does-not-exist") > "$WORK/c38.sh.out" 2> "$WORK/c38.sh.err"; a=$?
(cd / && "$BIN" "$WORK/does-not-exist") > "$WORK/c38.om.out" 2> "$WORK/c38.om.err"; b=$?
if [ "$a" = "$b" ] && cmp -s "$WORK/c38.sh.out" "$WORK/c38.om.out" && [ "$(tail -n 1 "$WORK/c38.sh.err")" = "$(cat "$WORK/c38.om.err")" ]; then
  printf 'ok   %-28s exit %s (script stderr line identical)\n' c38-missing-root "$a"
else bad=$((bad + 1)); printf 'DIFF %-28s exit sh=%s om=%s\n' c38-missing-root "$a" "$b"; fi

echo "corpus: $n cases, $bad differ (work dir $WORK)"
[ "$bad" = 0 ]
