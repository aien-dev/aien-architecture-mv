# Instructions for agents working on AIEN architecture

Before making cross-project architectural or roadmap changes, read these files in order:

1. `PLAN_AUTHORITY.md`
2. `CURRENT_EXECUTION_PLAN.md`
3. `doctrine/ARCHITECTURE.md`
4. `doctrine/ROADMAP.md`
5. the relevant accepted ADRs

Rules:

- There is one active cross-project master implementation plan: `CURRENT_EXECUTION_PLAN.md`.
- Do not create another “master”, “final”, “complete”, or “canonical” whole-system plan.
- Superseded plan files under `docs/archive/plans/` are historical only.
- Component roadmaps are local implementation aids and do not override cross-project architecture or sequencing.
- Current subsystem name: FORGE. Historical `PHYSICS_*` milestone IDs/receipts remain unchanged.
- Implementation/evidence truth beats planning claims. If code and plan differ, record the discrepancy; do not pretend the target is implemented.
- A milestone status changes only in `doctrine/ROADMAP.md`.

## Issue-first work tracking

For new substantive work, follow [`docs/process/ISSUE_FIRST_DELIVERY.md`](docs/process/ISSUE_FIRST_DELIVERY.md). Open or reuse a tracking issue before implementation, freeze acceptance gates and non-overlapping workstream ownership, link reviewable PRs and evidence, and record qualified results before closure. This protocol organizes work; it does not override `PLAN_AUTHORITY.md`, the active execution plan or the roadmap.

## Agent guidance in the tree (agents.toml)

This repository describes its agent guidance in [`agents.toml`](agents.toml) at the root ([ADR 0038](docs/adr/0038-agent-guidance-travels-with-the-tree.md), PROPOSED): the component skill [`skills/architecture-basics/SKILL.md`](skills/architecture-basics/SKILL.md) and the hooks in [`tools/agent-hooks/`](tools/agent-hooks/), which refuse `gh pr merge --admin`, force pushes, killing running jobs and edits to pipeline files, and point you at the right skill before an edit. The hooks here are the canonical copy for the whole tree; change them here first and run `bash tools/agent-hooks/test.sh`. `aien agents sync` (aien-sovereign-core) installs this manifest into each agent's own files once it lands.
