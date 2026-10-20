#!/usr/bin/env bash
# name-check: refuse new uses of the retired names (ADR 0038).
#
#   name-check.sh [--base REF] [--repo DIR] [--allow GLOB]...
#
# Looks only at lines ADDED between the merge base of REF and HEAD (default REF:
# origin/main, else HEAD~1). Fails (exit 1) when an added line outside the allowed
# paths names the project with a retired word:
#   Aienix / AIENIX   retired everywhere (the whole system is AienOS)
#   AIENOS / Aienos   retired in prose (the kernel is Aienux, the whole system AienOS)
# Not flagged: lowercase names (paths, crates, URLs, the aienos.com address), and
# identifiers that only contain the word (AIENOS_DISK, AienosCapRef, AIENOS-PKV-...):
# those are code and change with their own tests, not with prose.
# Allowed paths (history is never rewritten): evidence/, receipts/, docs/history/,
# CHANGELOG*, the naming ADR itself and this tool; glossary lines starting "_Avoid_:". Exit 2 on usage or git errors.
set -euo pipefail

base="" repo="." allow=()
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    --repo) repo="$2"; shift 2 ;;
    --allow) allow+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "name-check: unknown argument: $1" >&2; exit 2 ;;
  esac
done
cd "$repo" || exit 2
if [ -z "$base" ]; then
  if git rev-parse -q --verify origin/main >/dev/null; then base=origin/main; else base=HEAD~1; fi
fi
mb=$(git merge-base "$base" HEAD) || { echo "name-check: no merge base with $base" >&2; exit 2; }

allowed() {
  case "$1" in
    evidence/*|*/evidence/*|receipts/*|*/receipts/*|docs/history/*|CHANGELOG*|*/CHANGELOG*) return 0 ;;
    docs/adr/0038-*|tools/name-check/*) return 0 ;;
  esac
  local g
  for g in "${allow[@]+"${allow[@]}"}"; do
    # shellcheck disable=SC2053
    [[ "$1" == $g ]] && return 0
  done
  return 1
}

# A retired word that stands as a word: no letter, digit or _ beside it, not joined
# by - or . or / to another token (labels, paths, file names).
L='(?<![A-Za-z0-9_\-/.@$])'
R='(?![A-Za-z0-9_]|[-./][A-Za-z0-9])'
pat="${L}(Aienix|AIENIX|AIENOS|Aienos)${R}|Aienix"

bad=0 file=""
while IFS= read -r line; do
  case "$line" in
    "+++ b/"*) file="${line#+++ b/}" ;;
    "+++ "*) file="" ;;
    "@@ "*) n="${line#*+}"; n="${n%%[, ]*}" ;;
    "+_Avoid_:"*) n=$((n + 1)) ;;   # glossary lines that name the retired words on purpose
    "+"*)
      if [ -n "$file" ] && ! allowed "$file" && printf '%s\n' "${line:1}" | grep -qP "$pat"; then
        word=$(printf '%s\n' "${line:1}" | grep -oP "$pat" | head -1)
        echo "name-check: $file:$n: retired name '$word' (use Aienux for the kernel, AienOS for the whole system)"
        bad=1
      fi
      n=$((n + 1)) ;;
    " "*) n=$((n + 1)) ;;
  esac
done < <(git diff --no-color --no-ext-diff -U0 "$mb" HEAD)

if [ "$bad" -ne 0 ]; then echo "name-check: FAIL"; exit 1; fi
echo "name-check: PASS (added lines since $(git rev-parse --short "$mb"))"
