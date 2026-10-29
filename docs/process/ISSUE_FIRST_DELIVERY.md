# Issue-first delivery protocol

**Status:** OPERATING PROCESS (on main; in force for current work). **Scope:** substantive new AIEN capabilities, experiments, significant fixes, cross-repository changes and agent implementation work. **NOT A MASTER PLAN.**

**Tracking issue:** [aien-architecture-mv #175](https://github.com/aien-dev/aien-architecture-mv/issues/175). **Reference implementation issue:** [omega-mv #358 (AT-0)](https://github.com/aien-dev/omega-mv/issues/358).

## Authority and evidence

This document governs **how work is recorded and qualified**, not what AIEN should build or the order in which it should build it. It does not supersede [PLAN_AUTHORITY.md](../../PLAN_AUTHORITY.md), [CURRENT_EXECUTION_PLAN.md](../../CURRENT_EXECUTION_PLAN.md), [doctrine/ARCHITECTURE.md](../../doctrine/ARCHITECTURE.md), accepted ADRs or [doctrine/ROADMAP.md](../../doctrine/ROADMAP.md).

Before opening an issue, check the live owning repository's source, tests, build contracts and existing issues. Plans and issues establish intent, **not** current implementation. Never mark a roadmap milestone complete solely because an issue or PR closed. Only the canonical milestone registry owns that status.

## Human-Directed Agentic Engineering

This process records the two loops of Human-Directed Agentic Engineering (HDAE). Humans set the objective, architecture, constraints, acceptance gates and stopping points, then review the observed behavior. Within those boundaries, agents implement, execute checks, diagnose failures and revise. Human acceptance remains separate from agent execution and model review; naming the method does not change plan authority or qualification policy.

Method reference: Gregory M. Kurtzer, *Ginux: Building an Independent Kernel That Runs Linux Userspace through Human-Directed Agentic Engineering* (2026), [doi:10.5281/zenodo.23682548](https://doi.org/10.5281/zenodo.23682548). The report documents a method and case study and does not claim to originate the general idea or phrase.

## Normal workflow

1. **Discover and deduplicate.** Identify the owning repository and current executable behavior. Search existing open/closed issues and merged PRs. If a capability already exists, link the evidence instead of recreating it.
2. **Open one tracking issue before work.** Use the initiative issue template for new capabilities, research, major fixes or cross-repo work. Give an executive summary that a non-specialist can understand, precise observed code evidence, goal, excluded scope, owner, dependencies and risks. Set status `PROPOSED`. Smaller defects can use the repository's existing bug form.
3. **Define acceptance before coding.** Name measurable, falsifiable gates (tests, baseline/negative controls, security/performance checks when relevant), artifacts and independent verification needs. Distinguish `PASS`, `FAIL`, `INCONCLUSIVE`, `NOT_RUN` and applicable blocked statuses. Declare agent and path ownership. Freeze interfaces before parallel implementations.
4. **Plan bounded workstreams.** Small task: one owner, one branch and one PR. Medium task: one parent issue with a few independently reviewable PRs. Large cross-repo task: parent issue in `aien-architecture-mv` plus child issues in owning repositories, linked in both directions. The parent coordinates, not replaces, the execution plan or owning-repo backlog. Spawn as many agents as useful, **not a fixed number**. Do not assign two concurrent agents the same paths.
5. **Implement via branches and PRs.** Work in isolated worktrees/branches; respect each repository's `AGENTS.md`, access, security and CI. Every implementation PR references a tracking issue and identifies the gate(s) it advances. Use `Refs owner/repo#N` on intermediate PRs; use `Closes #N` only when the PR really completes that issue. Keep one PR independently testable.
6. **Verify with primary evidence.** Show exact commands, outputs/results, negative tests, commit IDs, relevant machine profile and immutable receipts where required. An assertion in an issue, README, report or agent summary is not evidence of implementation. Independent qualification must be independent in fact; otherwise record `UNISOLATED` or `INCONCLUSIVE`.
7. **Reconcile and close.** The issue is the change ledger: maintain links to child issues, PRs, merged SHAs, evidence and known failures. Close only when the issue's acceptance contract is satisfied **or** close explicitly as cancelled/superseded with that reason. Link downstream defects/new work rather than burying partial results. Before changing a canonical roadmap status, follow `PLAN_AUTHORITY.md` and cite qualified evidence.

## Minimal initiative issue contract

Every substantive initiative must have:

- **Executive summary:** objective, current status, next decision, plain English.
- **Current state:** checked source paths, tests and related existing issues/PRs; observed versus proposed.
- **Scope:** deliverables, non-goals, risks, affected repositories and authoritative plan/milestone reference (if any).
- **Ownership and order:** paths, agent/worktree boundaries, serial dependencies and parallel-safe work.
- **Acceptance gates:** observable results, expected evidence, failure and `NOT_RUN` handling.
- **Tracking ledger:** linked child issues, reviewable PRs, merge commits, receipts, qualification outcomes and follow-ups.

For experimental research, append the hypothesis, alternative explanations, positive and negative controls, independence/blinding conditions, precommitted scoring and precisely bounded claims. For a routine bug, keep these sections proportionate.

## Status is not a scientific verdict

Progress states: `PROPOSED` -> `SCOPED` -> `ACTIVE` -> `IN_REVIEW` -> `COMPLETE`; `BLOCKED` or `CANCELLED` where appropriate.

Qualification verdicts are **separate**: `PASS`, `FAIL`, `INCONCLUSIVE`, `NOT_RUN` or documented blocked status. A green CI check is not evidence of a scientific discovery, silicon qualification, security guarantee or benchmark superiority. An issue can be `COMPLETE` with a recorded `FAIL` when its objective was to run an experiment and report the outcome honestly.

## Exceptions, older work and enforcement

- Active existing work may keep its existing issues; attach initiative fields and evidence only when its scope expands substantially. Do not retroactively rewrite historical evidence.
- Incident response or urgent security containment may proceed immediately through an authorized process; create/link an issue with evidence as soon as safe, without exposing secrets or exploitation details publicly.
- Trivial documentation or typo-only changes may use a focused PR directly; **new capabilities and material implementation changes are always issue-first**.
- The organization `.github` repository supplies **fallback** issue/PR templates when a repository does not have local templates. Repositories with local templates must opt into the initiative format explicitly. Templates are defaults, not proof that every repository enforces a gate.
- Hard CI/branch-protection enforcement is a separate decision requiring compatible rollout and verified checks. Until enabled, reviewers enforce issue linking and evidence requirements. Never claim this protocol is technically enforced merely because the template exists.

## Operator checklist

- [ ] Current code/test state inspected and existing work deduplicated
- [ ] Tracking issue opened with scope, status, owner and acceptance gates
- [ ] Plan authority and cross-repo dependencies checked
- [ ] Agent worktrees and file ownership assigned without overlap
- [ ] PRs linked to issue and tests/evidence attached
- [ ] Qualification verdicts and negative/blocked outcomes recorded
- [ ] Merged PRs/commits reconciled; issue closed with an auditable summary
