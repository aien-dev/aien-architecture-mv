# Crumbs in the sovereign local pipeline

Status: since 2026-10-19 (RFC-0003 Amendment 2), crumbs play no part in judging or merging a change.

- No gate checks crumbs. `CRUMB-VERIFY` is gone from `.aien/always` and `tests/gates/`, and the hosted AIEN Verification workflow has no crumb step. `ARCH-CRUMB-TOOL-TEST` only runs the crumb tool's own unit tests when `tools/crumb/` changes.
- Readiness does not read crumbs, and no repository pins a crumb tool for its gates.
- A branch needs no `crumb compile` commit, no final crumb-only commit and no `rebase-crumb.sh` (deleted). Rebase onto `origin/main` like any other change. The commit that is judged is simply the head of the branch.
- `scripts/pr-gate.sh` no longer has a crumb step.
- Editing a `.crumb` is a docs-like change: `.crumb` paths are in `.aien/unmapped-ok`, so they need only the always-run gates.

What an agent does with crumbs in the pipeline: read them with `crumb context <path>` before changing code (see `AGENT_WORKFLOW.md`). Who works where is the lane system (Spark `~/.local/state/aien-local-ci/LANES`).

The earlier pipeline rules and their measured proofs (proofs 13 to 23, results of 2026-10-11) are in git history before this change.
