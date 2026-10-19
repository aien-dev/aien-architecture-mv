# Contributing to AIEN Architecture

Architecture changes must answer four questions:

1. **Owner:** which subsystem owns the responsibility?
2. **Boundary:** what typed protocol crosses into or out of it?
3. **Failure:** what happens if the subsystem, Machine, network, provider, or model fails?
4. **Evidence:** how can the behavior be tested and proven?

## Rules

- Do not describe planned work as implemented.
- Use **Machine 1**, **Machine 2**, etc. in architecture diagrams.
- Hardware/vendor names belong only in capability examples.
- Distinguish Tool, Skill, World, Cortex, J-Space, policy, effect, and provenance.
- External irreversible effects must pass AEGIS and the Effect Broker.
- Models never own raw credentials.
- MCP is a compatibility transport under the Capability Graph, not the internal semantic model.
- New architectural decisions require an ADR.
- Changes to security boundaries require explicit negative tests.
- Claims about current code should name the repository/path or PR/commit that establishes them.

## ADR workflow

Create `docs/adr/NNNN-short-title.md` containing:

- Context
- Decision
- Alternatives considered
- Consequences
- Security implications
- Performance implications
- Migration plan
- Acceptance tests

## Architecture-gap workflow

Open an issue when:

- current code contradicts an ADR,
- two repositories claim ownership of the same canonical behavior,
- a required typed boundary does not exist,
- a bypass exists around policy/provenance,
- documentation refers to a component that no longer exists.

## Crumbs

Some directories carry a `.crumb` file: a short note a person wrote about what the directory is for and the rules it keeps. Crumbs are advisory (RFC-0003 Amendment 2): no check runs on them and a pull request needs no crumb commit.
Before editing a directory, read its notes with `crumb context <path>`. If a note is wrong, fix it by hand in the same pull request. Format and rules: [docs/CRUMB_PROTOCOL.md](docs/CRUMB_PROTOCOL.md). Who works where is the lane system on the Spark, not crumbs.
