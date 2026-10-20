# name-check

Refuses new uses of the retired project names (ADR 0038). The kernel is **Aienux**, the whole operating system is **AienOS**, and the old names are retired in prose.

- `name-check.sh [--base REF] [--repo DIR] [--allow GLOB]...` looks only at lines added since the merge base with REF (default `origin/main`, else the previous commit). Exit 0 PASS, 1 FAIL with file and line, 2 usage or git error.
- Lowercase names (paths, crate names, URLs, the `aienos.com` address) and identifiers that only contain the old word (macros, type names, key-derivation labels) are not flagged: renaming those is code work with its own tests.
- History is never judged: `evidence/`, `receipts/`, `docs/history/`, `CHANGELOG*`.
- `test.sh` is the offline test: seven cases that must fail, sixteen that must pass. The gate `ARCH-NAME-CHECK` runs both.

No Python, no network. Bash and GNU grep with `-P`.
