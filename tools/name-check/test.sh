#!/usr/bin/env bash
# Offline test of name-check.sh: builds throwaway git repos under mktemp.
# Red cases must fail (exit 1), green cases must pass (exit 0). No network.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
nc="$here/name-check.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0

# case NAME WANT_EXIT PATH TEXT: commit TEXT to PATH on top of a clean base, run the check
case_() {
  local name="$1" want="$2" path="$3" text="$4" d="$tmp/$1" got=0
  git init -q "$d"
  git -C "$d" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  mkdir -p "$d/$(dirname "$path")"
  printf '%s\n' "$text" > "$d/$path"
  git -C "$d" add -A
  git -C "$d" -c user.name=t -c user.email=t@t commit -q -m change
  "$nc" --repo "$d" --base HEAD~1 >"$d.out" 2>&1 || got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass + 1)); echo "ok   $name"
  else fail=$((fail + 1)); echo "FAIL $name: want exit $want, got $got"; sed 's/^/     /' "$d.out"; fi
}

# red: retired names in prose
case_ aienix-prose        1 README.md      "Aienix is the core tree of AIEN."
case_ aienix-caps         1 docs/x.md      "Welcome to AIENIX."
case_ aienix-in-word      1 docs/y.md      "the Aienix-wide plan"
case_ aienos-caps-prose   1 notes.md       "AIENOS boots on the iMac."
case_ aienos-mixed-prose  1 src/a.c        "/* Aienos kernel entry */"
case_ aienos-sentence-end 1 a.md           "It runs AIENOS."
# green: clean text and the new names
case_ clean-text          0 README.md      "Aienux is the kernel; AienOS is the whole system; AIEN is the agent."
case_ new-names-only      0 docs/z.md      "AienOS = Aienux + Omega + runtime + Allen"
# green: identifiers, labels, paths and addresses stay legal
case_ macro-identifier    0 src/b.h        "#define AIENOS_DISK_NATIVE 1"
case_ type-identifier     0 src/c.c        "AienosCapRef r = { 0 };"
case_ kdf-label           0 src/d.rs       'let l = "AIENOS-PKV-ENVID-KEY-V1";'
case_ lowercase-paths     0 docs/w.md      "see github.com/aien-dev/aienix and www.aienos.com and crates/aienos-kernel"
case_ file-name-token     0 docs/v.md      "docs/AIENOS.md"
# green: history paths are never judged
case_ evidence-path       0 evidence/r.md  "AIENOS receipt text, Aienix era"
case_ receipts-path       0 receipts/a.md  "Aienix"
case_ history-path        0 docs/history/h.md "AIENOS history"
case_ changelog           0 CHANGELOG.md   "- Aienix renamed"
case_ glossary-avoid     0 CONTEXT.md     "_Avoid_: Aienix (retired), AIENOS, Aienos"

echo "name-check tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
