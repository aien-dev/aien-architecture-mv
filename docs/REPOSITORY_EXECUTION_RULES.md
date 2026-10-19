# AIEN Repository Execution Rules

## Adoption

Adopted 2026-10-10 from Drake's revised rules for the six-issue campaign (interplane#97 and #98, aien-sovereign-core#397 and #398, aegis-runtime#38 and #39). Tooling: `scripts/pr-gate.sh`. Amended 2026-10-19 by RFC-0003 Amendment 2: crumbs are advisory notes and are no longer part of these rules (sections 2 and 3 below).

## Recorded facts (2026-10-10)

- (a) Branch protection read from GitHub: interplane requires the checks schemas-and-fixtures, rust, python, cross-language, adapter-aien and adapter-odysseus, in strict mode, with no review count. aien-sovereign-core requires the check "Workspace Verification & Invariant Audit", 0 reviews, enforce_admins on. aegis-runtime requires the check "Test & Invariant Verification", 0 reviews, enforce_admins on. Therefore `--admin` is never needed for a green PR.
- (b) interplane has no .crumb files; aegis-runtime and aien-sovereign-core use crumbs. Since 2026-10-19 this makes no difference to a merge (section 2).
- (c) INTERPLANE carries a Python SDK by Drake's 2026-10-04 direction (approved exception). The Motus adapter for interplane#97 lives only under interplane adapters/motus. No Python enters any AIEN-owned repository.


These rules apply to Claude Code, all delegated workers, and all repositories involved in this implementation campaign.

The objective is to ship verified code without corrupting shared branches, bypassing security requirements, or creating unnecessary integration conflicts.

## 1. Source of Truth

GitHub main is authoritative. Inspect current code, tests, active PRs, and repository instructions before editing.

Never implement an issue solely from its description. Check whether the functionality already exists or has been superseded.

Use separate branches and worktrees for concurrent development.

One worker owns each writable worktree. Never allow two workers to modify the same worktree concurrently.

## 2. Crumbs (advisory since 2026-10-19)

Crumbs are notes a person writes for the next reader (RFC-0003 Amendment 2, `docs/CRUMB_PROTOCOL.md`). Read the crumb chain of a path with `crumb context <path>` before changing it, and respect its invariants.

There is no crumb compilation, no crumb verification and no separate crumb commit. A PR may edit a `.crumb` together with source when the note is wrong. No gate, readiness check or merge rule looks at crumbs.

## 2a. Local verification

`scripts/pr-gate.sh` reads GitHub's CLEAN state. It does not prove the commit was verified. The local admission check that complements CLEAN is `aien-test verify COMMIT` (sovereign-core `tools/aien-test`, ADR 0033 amendment 2026-10-11): it prints READY when every gate required at the base ref has a PASS receipt for that exact commit and BLOCKED otherwise, with the reason (a missing or NOT_RUN gate, an UNMAPPED changed path, or a BLOCKED_OPERATOR head). Run it on the head of the branch. Crumbs are not part of readiness since RFC-0003 Amendment 2 (the readiness change itself lives in sovereign-core `tools/aien-test`).

Trust anchors come from the base ref, never from the head under test (ADR 0033 amendment, A1): the required gate set, `.aien/verify.pub`, `.aien/always` and `.aien/unmapped-ok` are read from `origin/main`. A head that changes the pipeline's own configuration (`.aien/`, `tests/gates/`, `.github/workflows/`, `.forgejo/`, `tools/aien-test/`) is BLOCKED_OPERATOR: the operator runs its verification by hand and says so in the PR.

## 3. Rebase

After each merge to main, evaluate remaining PRs for drift and rebase them onto `origin/main` when needed. Since crumbs hold no generated data, a crumb can only conflict when two PRs edit the same note; resolve that like any text conflict. `scripts/rebase-crumb.sh` was retired with RFC-0003 Amendment 2.

Before rebasing:

- Confirm the worktree has no uncommitted changes.
- Confirm the intended branch and remote.
- Preserve the expected remote head for force-with-lease protection.
- Ensure no other worker is writing to that branch.

Never discard source changes to manufacture a clean rebase.

Do not rewrite another worker's branch without coordination.

## 4. Definition of CLEAN

A PR may merge only when all of the following hold:

- Working tree is clean.
- Changes are based on the intended current main.
- No unresolved merge conflicts.
- Required compilation passes.
- Required tests and CI checks pass.
- Required approvals are present and valid.
- GitHub reports a mergeable state.
- No outstanding blocking security findings.
- The final diff contains no unintended changes.
- The implementation satisfies the linked issue's acceptance criteria.

Do not equate GitHub's CLEAN merge-state label with complete verification.

## 5. Merge Procedure

Serialize merges into each repository's main branch.

Default command: `gh pr merge N -R aien-dev/<repo> --squash --delete-branch`

Only use `--admin` when explicitly authorized for that specific PR and when the required project governance permits it.

Never use administrative privileges to hide failing tests, missing approvals, security findings, or unresolved conflicts.

After every merge, refresh main and revalidate dependent or competing PRs.

## 6. GitHub PR Editing

The normal `gh pr edit` workflow is currently unreliable in this environment.

Use the API fallback: `gh api -X PATCH repos/aien-dev/<repo>/pulls/N -F body=@file`

Verify the returned response and fetch the PR afterward to confirm the update.

Do not assume an API operation succeeded merely because the command exited.

## 7. Language and Runtime Constraints

No Python or systemd may be introduced as part of this campaign.

Use Rust for AIEN-owned runtime, orchestration, adapters, and execution control.

Motus may run externally using its own dependencies, but the AIEN integration must communicate over an explicitly verified protocol boundary.

If a task requires Python inside an AIEN-owned repository, treat it as an architectural conflict. Redesign it or report the blocker before proceeding.

Existing Python files do not authorize adding more Python. Flag any conflict with the strict repository policy rather than silently ignoring it.

## 8. Command Hooks

A local Bash hook rejects certain command text containing accelerator or kernel-module related terms.

Do not embed source-file contents containing these terms into Bash commands or heredocs. Use the approved Write tool for file creation and editing.

Do not attempt to bypass restrictions on executing prohibited operations.

If an approved development command is incorrectly blocked, report the exact failure and use an authorized alternative.

## 9. Commits and Attribution

Use small, logically isolated commits.

Required commit trailers, when attribution accurately reflects the contributors:

`Co-authored-by: Drake Stapleton <drake@aienos.com>`
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`

Do not invent contributors or misrepresent authorship.

Required PR footer: 🤖 Generated with [Claude Code](https://claude.com/claude-code)

Every PR must reference its issue, describe its implementation, identify verification performed, and disclose limitations.

## 10. Worker Models and Verification

Use Sonnet for delegated implementation workers unless instructed otherwise.

Workers may inspect, implement, test, and propose solutions within their assigned ownership boundaries.

A worker's claim of completion is not verification.

The coordinating agent must independently inspect every worker's changes and verify relevant tests, security invariants, and actual GitHub state.

Do not accept unsupported claims about test passes, hardware performance, successful merges, or completed integrations.

Use an independent reviewer for security-sensitive changes.

## 11. Failure Handling

Do not repeatedly retry the same failing operation without identifying the cause.

On failure:

1. Capture the exact failure and affected commit.
2. Determine whether it is source-related, environmental, or caused by concurrent changes.
3. Apply the smallest justified correction.
4. Rerun the affected verification.
5. Escalate or isolate persistent blockers without destroying valid work.

Never force-push another worker's changes away.

Never turn off tests, security checks, or authorization rules merely to make a PR merge.

## 12. Communication

Use plain English when reporting to Drake. Do not use em dashes or en dashes.

Provide concise updates that identify completed work, active work, blockers, and next actions.

Do not confuse attempted operations with completed operations.

## 13. Final Delivery

Before declaring the campaign complete:

- Verify every merged PR against its issue.
- Check relevant cross-repository interfaces.
- Run integration tests.
- Confirm no unintended dependency or architecture changes.
- Report remaining failed, skipped, or unavailable verification.
- Confirm final GitHub issue and PR status.

A task is complete only when the implementation, verification, and required integration are finished.

## 14. Worker Instructions

Worker briefs live with each campaign; this document wins when they conflict.

Stable rules and validated scripts live in aien-architecture (`docs/REPOSITORY_EXECUTION_RULES.md`, `scripts/pr-gate.sh`).

**Operating principle: Ship correct, verified code. Preserve other workers' changes. Protect main. Never trade correctness for apparent progress.**
