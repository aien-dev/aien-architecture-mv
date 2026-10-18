#!/bin/sh
# crumb-compile: Crumb Compiler stage 1+2 reference implementation (RFC-0003). POSIX sh + git + jq + sha256sum.
# The repository compiles its own crumbs: hand-authored semantic kernel stays, everything structural is generated
# bottom-up into `.crumb` -> extensions.generated, with Merkle digests so one change invalidates only its ancestor path.
#
# DESIGN DECISIONS (the C port must keep every one of them; each closes a real trap):
#  D1  source_tree excludes every .crumb and .crumb.local. Otherwise compiling changes the tree, which changes the
#      digest, which requires recompiling: the compiler would never reach a fixed point.
#  D2  Files are the TRACKED files of the working tree (git ls-files), hashed with git hash-object, not HEAD's tree:
#      a PR author compiles before committing, and CI's checkout gives the same answer. Untracked files never count.
#  D3  Digests cover content only: digest = sha256(semantic || source_tree || children_root || evidence_root).
#      generated_at_commit and compiled_at are stamps, NOT inputs, and `verify` ignores them. Otherwise every commit
#      would make every crumb "stale" and CI would fail forever.
#  D4  Bottom-up order (deepest first) so a parent's children[] digests are the children's FINAL digests.
#  D5  Semantic kernel = {purpose, layer, invariants, exports, related, boundaries} as hand-written (null-stripped,
#      sorted keys). The compiler never writes these keys; `propose` writes only extensions.proposed.purpose.
#  D6  last_commit per child uses pathspec ':!**/.crumb' so compile commits do not count as changes to the code.
#  D7  Only directories that already hold a .crumb take part (crumb seed decides membership; this tool never creates
#      directories' crumbs). Children = the NEAREST crumbed descendants: the walk descends through directories that
#      hold no .crumb, so every crumb is reachable from the root digest (amended 2026-10-11, orphan crumbs); a deep
#      child is named by its path relative to the parent crumb directory.
#  D8  Evidence = tracked files under the directory whose path has a component named evidence or receipts, or that
#      end in .receipt.json; evidence_root = sha256 of their blob ids in path order.
#  D9  Output is written with jq -S (sorted keys) via tmp+rename, byte-stable, so `verify` can be an exact comparison.
#  D10 (C tool only) <root>/.crumbignore subtrees never take part in compile/verify/status; this shell reference
#      does not implement D10, so the differential holds only for repositories without a .crumbignore.
#  D11 migration (C tool only): verify/status read a leftover crumb-compile/1 block by structure; this reference does not.
set -eu
die() { echo "crumb-compile: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "needs $1"; }
need git; need jq; need sha256sum
COMPILER="crumb-compile/2"
sha() { sha256sum | cut -c1-64; }

ROOT_ARG="${2:-.}"
TOP=$(git -C "$ROOT_ARG" rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository: $ROOT_ARG"
cd "$TOP"
HEAD=$(git rev-parse HEAD 2>/dev/null || echo "0000000000000000000000000000000000000000")
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# One pass: "blob path" for every tracked file that exists, excluding crumbs (D1, D2).
git ls-files -z | tr '\0' '\n' | grep -v -e '/\.crumb$' -e '^\.crumb$' -e '/\.crumb\.local$' -e '^\.crumb\.local$' > "$WORK/paths" || true
: > "$WORK/blobs"
if [ -s "$WORK/paths" ]; then
  while IFS= read -r p; do [ -f "$p" ] && printf '%s\n' "$p"; done < "$WORK/paths" > "$WORK/present"
  if [ -s "$WORK/present" ]; then
    git hash-object --stdin-paths < "$WORK/present" > "$WORK/hashes"
    paste -d' ' "$WORK/hashes" "$WORK/present" | LC_ALL=C sort -k2 > "$WORK/blobs"
  fi
fi

# Directories with a .crumb, deepest first (D4, D7).
git ls-files -z | tr '\0' '\n' | grep -e '/\.crumb$' -e '^\.crumb$' | sed 's|/\?\.crumb$||; s|^$|.|' \
  | awk '{ n=gsub("/","/"); print n, $0 }' | LC_ALL=C sort -k1,1nr -k2 | cut -d' ' -f2- > "$WORK/dirs"
# also include untracked .crumb files that exist on disk (freshly seeded, not yet committed)
find . -name .crumb -not -path './.git/*' | sed 's|^\./||; s|/\?\.crumb$||; s|^$|.|' >> "$WORK/dirs"
LC_ALL=C sort -u "$WORK/dirs" | awk '{ n=($0=="." ? -1 : gsub("/","/")); print n, $0 }' | LC_ALL=C sort -k1,1nr -k2 | cut -d' ' -f2- > "$WORK/dirs2"
mv "$WORK/dirs2" "$WORK/dirs"

mkdir -p "$WORK/digest"   # digest/<encoded dir> -> digest of that dir after this run
enc() { if [ "$1" = "." ]; then echo _root; else printf "%s" "$1" | tr "/" "%"; fi; }
subtree() { # $1 dir -> lines "blob path" under it
  if [ "$1" = "." ]; then cat "$WORK/blobs"; else awk -v d="$1/" 'index($2, d)==1' "$WORK/blobs"; fi
}
kids_of() { # $1 dir (repo-relative, "." = root) $2 name prefix -> lines "name<TAB>dir": the NEAREST crumbed descendants (D7)
  for k in $(ls -1A "$1" 2>/dev/null | LC_ALL=C sort); do
    kd=$([ "$1" = "." ] && echo "$k" || echo "$1/$k")
    [ -d "$kd" ] && [ ! -L "$kd" ] || continue
    [ "$k" = ".git" ] && continue
    if [ -f "$kd/.crumb" ]; then printf '%s\t%s\n' "$2$k" "$kd"; else kids_of "$kd" "$2$k/"; fi
  done
}
compute() { # $1 dir -> prints the generated object (without stamps) as JSON
  d="$1"
  st=$(subtree "$d" | sha)
  nfiles=$(subtree "$d" | wc -l | tr -d ' ')
  ev=$(subtree "$d" | awk '$2 ~ /(^|\/)(evidence|receipts)\// || $2 ~ /\.receipt\.json$/')
  evn=$(printf '%s' "$ev" | grep -c . || true)
  evr=$(printf '%s' "$ev" | awk '{print $1}' | sha)
  sem=$(jq -cS '{purpose, layer, invariants, exports, related, boundaries} | with_entries(select(.value != null))' "$d/.crumb" 2>/dev/null || echo '{}')
  kids='[]'
  kids_of "$d" "" | LC_ALL=C sort > "$WORK/kids.$$"
  while IFS="$(printf '\t')" read -r k kd; do
    kdig=$(cat "$WORK/digest/$(enc "$kd")" 2>/dev/null || jq -r '.extensions.generated.digest // "uncompiled"' "$kd/.crumb")
    kpur=$(jq -r '(.purpose // "") | .[0:96]' "$kd/.crumb")
    kids=$(printf '%s' "$kids" | jq -c --arg n "$k" --arg g "$kdig" --arg p "$kpur" '. + [{name:$n,digest:$g,purpose:$p}]')
  done < "$WORK/kids.$$"
  cr=$(printf '%s' "$kids" | jq -r '.[].digest' | sha)
  dig=$(printf '%s%s%s%s' "$sem" "$st" "$cr" "$evr" | sha)
  printf '%s' "$dig" > "$WORK/digest/$(enc "$d")"
  # D11: digests are computed (above) but never written; the committed block is structure only.
  : "$nfiles" "$evn"
  jq -cn --arg c "$COMPILER" --argjson kids "$kids" '{compiler:$c, children:($kids | map({name, purpose}))}'
}
strip_stamps() { jq -cS .; }   # D11: stamps are no longer written; a leftover stamp means STALE

cmd=${1:-help}
changed=0; stale=0; total=0
case "$cmd" in
  compile|verify|status)
    while IFS= read -r d; do
      [ -f "$d/.crumb" ] || continue
      total=$((total+1))
      new=$(compute "$d" | jq -cS .)
      old=$(jq -c '.extensions.generated // {}' "$d/.crumb" | strip_stamps)
      if [ "$new" = "$old" ]; then
        [ "$cmd" = status ] && echo "CURRENT    $d"
        continue
      fi
      stale=$((stale+1))
      case "$cmd" in
        status) if [ "$old" = "{}" ]; then echo "UNCOMPILED $d"; else echo "STALE      $d"; fi ;;
        verify) echo "STALE      $d" ;;
        compile)
          tmp="$d/.crumb.tmp.$$"
          jq -S --argjson g "$new" --arg h "$HEAD" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
             '.extensions = (.extensions // {}) | .extensions.generated = $g' \
             "$d/.crumb" > "$tmp" && mv "$tmp" "$d/.crumb"
          changed=$((changed+1)); echo "COMPILED   $d" ;;
      esac
    done < "$WORK/dirs"
    case "$cmd" in
      compile) echo "crumb-compile: $total crumbs, $changed rewritten, HEAD ${HEAD%${HEAD#???????}}" ;;
      verify)  if [ "$stale" -gt 0 ]; then echo "crumb-compile: VERIFY FAIL: $stale of $total crumbs stale; run: crumb-compile compile"; exit 1; fi
               echo "crumb-compile: VERIFY OK: $total crumbs current" ;;
      status)  echo "crumb-compile: $total crumbs, $stale not current" ;;
    esac ;;
  propose) # propose <dir> "<purpose>": D5, never touches .purpose itself
    d=${2:?dir}; p=${3:?purpose}; [ -f "$d/.crumb" ] || die "no .crumb in $d"
    tmp="$d/.crumb.tmp.$$"; jq -S --arg p "$p" --arg by "${CRUMB_SESSION:-$USER}" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.extensions = (.extensions // {}) | .extensions.proposed = {purpose:$p, status:"PROPOSED", by:$by, at:$t}' "$d/.crumb" > "$tmp" && mv "$tmp" "$d/.crumb"
    echo "PROPOSED purpose for $d (stays PROPOSED until a human moves it into .purpose)" ;;
  *) echo "usage: crumb-compile.sh compile|verify|status [repo-path] | propose <dir> \"<purpose>\""; echo "see header comments for the design decisions D1-D9"; exit 2 ;;
esac
