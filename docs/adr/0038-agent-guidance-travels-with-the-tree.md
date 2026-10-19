# ADR 0038: Agent guidance travels with the tree

**Status:** PROPOSED (2026-10-19). Written by the PR desk from the brief of 2026-10-19 ("agent guidance travels with the tree", Drake's direction to learn from Symposium and implement what applies).
**Related:** ADR 0003 (tools and skills are distinct), ADR 0004 (MCP is a compatibility layer), ADR 0033 (AIEN Verification, rule A4 of its 2026-10-11 amendment), the aienix README section "How a change gets in".

---

## Context

Coding agents (Claude Code, Codex, Hermes and others) do most of the day-to-day work in the AIEN repositories. What they are told, and what stops them from breaking a standing rule, is uneven across the tree. Audit of every repository's `origin/main` on 2026-10-19:

| Repository | Agent guidance in the tree today |
|---|---|
| aien-sovereign-core | `AGENTS.md`, `skills/<name>/SKILL.md` (8 skills), and `crates/aien-cli` has `skills.rs`, `hooks.rs`, `rules.rs` |
| aien-architecture, aegis-runtime, spark-rsi, benchmarks | `AGENTS.md` only |
| omega, aienos, physics, aien-protocols, aienix, synapse, interplane | nothing |
| Hooks that actually enforce rules | only on the Spark, in `~/.claude/hooks/*.sh` and the `gh` guard in `~/.local/bin/gh`: machine-local, Claude Code only, in no repository |

Three problems follow. Guidance is uneven, so an agent in omega or aienos starts with nothing. Enforcement lives on one machine, so a clone anywhere else, or a different agent on the Spark, runs with no guard rails. And nothing translates one description of a repository's rules into the files each agent actually reads (`.claude/settings.json` and `.claude/skills/` for Claude Code, `AGENTS.md` for Codex, `~/.hermes/skills` for Hermes).

**Prior art.** Symposium (<https://github.com/symposium-dev/symposium>, licence MIT OR Apache-2.0) is a `cargo agents` subcommand that "scans a Rust workspace, matches plugins against its dependency graph" and installs skills, hooks and MCP servers into whichever coding agent is in use, from one agent-agnostic configuration translated into each agent's own files. Plugins come from plugin sources; a central recommendations repository is enabled by default.

**What we take from it:**

- One agent-agnostic manifest per component, translated by one tool into each agent's native files.
- Skills and hooks shipped in the source tree next to the code they govern, so they move with it and are reviewed with it.
- Curation at one point: Symposium curates plugins in a central recommendations source; we curate at the pin boundary, where a core repository names the attachments whose guidance it accepts.

**What we do not take:**

- No matching against Cargo dependencies: our guidance is per component and per directory, not per crate.
- No fetch from crates.io or any other registry, and no outside plugin source: every skill and hook comes from the repository being worked on.
- No MCP server registration: MCP stays a compatibility layer (ADR 0004) and is configured by the operator, not by a repository.
- No dependency on Symposium itself: we follow its design idea and build our own small version (Drake's rule of 2026-10-16, build our own close to the metal).

## Decision

1. **Manifest.** Every repository root carries `agents.toml`, schema v1:

   ```toml
   schema = 1
   [component]
   name = "omega"                 # repository short name
   tree = "core"                  # core | attachment
   [[skills]]
   path = "skills/omega-basics"   # directory holding SKILL.md
   [[hooks]]
   event = "pre-command"          # pre-command | pre-edit | post-edit | session-start
   command = "tools/agent-hooks/no-admin-merge.sh"
   [attachments]
   allow = []                     # core repositories only
   ```

   An attachment's `agents.toml` is loaded only if its name is listed in the core's `[attachments] allow`. Hook commands are repository-relative, use bash and the python3 standard library only, and exit 0 (allow) or 2 (block, one-line reason on stderr).

2. **Skills.** `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, optional `paths:` globs) and a short body of facts taken from the repository's own README, docs and gates: how to build, how to run the full host test target and gates, the invariants that must not move, where receipts and evidence live, and what agents must not touch (`.crumb`, `crumb.lock`, `.aien/`, `tests/gates/`, `.github/workflows/`). This is the layout aien-sovereign-core already uses and it is the organisation standard.

3. **Hooks.** `tools/agent-hooks/`, identical files in every repository. The canonical copy is in aien-architecture; the duplication ends when the aienix tree import happens. Each reads the tool call JSON on stdin (Claude Code format: `.tool_input.command` for commands, `.tool_input.file_path` for edits), exits 0 quickly when nothing matches, and ships with `tools/agent-hooks/test.sh` (red and green cases):
   - `no-admin-merge.sh` (pre-command): blocks `gh pr merge ... --admin`.
   - `no-force-push.sh` (pre-command): blocks `git push` with `--force`, `-f` or a `+refspec` unless `--force-with-lease` is present.
   - `no-kill-jobs.sh` (pre-command): blocks `kill`, `pkill`, `killall` aimed at `aien-test`, `aien-serve-http`, `aien-local-ci` or `claude -p` workers.
   - `protected-paths.sh` (pre-edit): blocks edits under `.crumb`, `crumb.lock`, `.aien/`, `tests/gates/`, `.github/workflows/`, `.forgejo/` and `tools/aien-test/` unless `AIEN_PIPELINE_EDIT=1` is set (ADR 0033 rule A4: pipeline configuration changes are BLOCKED_OPERATOR).
   - `skill-context.sh` (pre-edit, never blocks): names the nearest matching `SKILL.md` once per directory per session.

4. **Sync tool** (aien-sovereign-core only): `aien agents sync [--agent claude-code|codex|hermes|all] [--scope project|global] [--dry-run]` and `aien agents check`. It reads and validates `agents.toml` (missing skill directories, missing hook files, unknown events and bad TOML are errors with line numbers), then writes:
   - Claude Code: hooks in `.claude/settings.json` (PreToolUse with matcher `Bash` for pre-command and `Edit|Write|MultiEdit|NotebookEdit` for pre-edit, PostToolUse for post-edit, SessionStart for session-start) and skills copied to `.claude/skills/<name>/`. It merges and never clobbers: entries it did not write stay, and its own entries carry a marker so a re-sync replaces only them.
   - Codex: a block in `AGENTS.md` between `<!-- aien-agents:begin -->` and `<!-- aien-agents:end -->` listing the skills and one line per hook rule.
   - Hermes: skills copied to `$HERMES_HOME/skills/aien/<component>-<skill>/` (default `~/.hermes/skills`), global scope only.

   `aien agents check` exits non-zero when the generated files are stale against the manifest, so a gate can run it later. No gate is added by this ADR.

## Consequences

- Every clone of every repository carries its own rules, whichever machine and whichever agent opens it. The Spark stops being the only place the rules are enforced.
- One command (`aien agents sync`) installs the rules into each agent's own format, so adding a new agent means teaching the sync tool one more output, not editing every repository.
- Until the aienix import, the hook scripts exist as identical copies in each repository. Drift between copies is the cost; the canonical copy and its `test.sh` live here, and a change lands here first.
- Hooks guard against mistakes, not a determined adversary: a command can always be phrased so a pattern does not see it. The trusted judge (ADR 0033) remains the authority on what merges.
- The hooks use python3 standard library for JSON, as the brief fixes. Some repositories have a no-Python rule for their own scripts (for example `scripts/check_doctrine.sh` here); the hooks are the declared exception, and a later version can move them onto the `aien` binary once it is installed everywhere.

## Migration

- The live Spark hooks in `~/.claude/hooks/` and the `gh` guard in `~/.local/bin/gh` stay exactly as they are until each rule has an in-tree hook merged in every repository.
- After that, each live copy becomes a thin wrapper that runs the in-tree hook of the repository being worked on, so there is one implementation of each rule.
- Repositories without a component skill get one written from their own README and gates; nothing is claimed that is not true on `origin/main`.

## Done means

- Every repository in the audit table has `agents.toml`, at least one component skill and an identical `tools/agent-hooks/` whose `test.sh` passes.
- `aien agents sync --dry-run` and `aien agents check` run clean in each repository, with unit tests for parse, validation errors, idempotent sync, merge that keeps foreign hook entries, and an `AGENTS.md` block that is replaced, not duplicated.
- The live Spark hooks for the five rules above are thin wrappers over the in-tree hooks.
- The aienix README describes agent guidance under "How a change gets in" and links this ADR.
