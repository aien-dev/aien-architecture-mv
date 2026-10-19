# Crumb Protocol: crumbs are advisory notes

Status: current since 2026-10-19 (RFC-0003 Amendment 2, accepted by Drake). This page replaces the older working rules.

## What a crumb is

A crumb is a small JSON file named `.crumb` that a person writes next to code. It says why a directory exists and what must not be broken there. Agents read it before they change that directory. It never blocks a merge, nothing checks it in CI, and no program writes into it.

Crumb Protocol is not Crumbline. Crumbline is the training curriculum in `aien-sovereign-core/crates/crumbs`. They share a word and nothing else.

## Allowed keys

| Key | Required | Meaning |
|---|---|---|
| `schema_version` | yes | The string `"1.0.0"`. |
| `name` | yes | Short name of the directory. |
| `purpose` | yes | One or two sentences: why this directory exists. |
| `layer` | no | Where it sits in the system. |
| `invariants` | no | Rules a change must keep. If a change must break one, stop and say why. |
| `exports` | no | What other code may rely on. |
| `related` | no | Other paths or repositories to read with this one. |
| `boundaries` | no | What this directory must not do or touch. |
| `above`, `below` | no | Parent and child directories, when that helps a reader. |

Nothing generated goes in a crumb: no file lists, digests, commit logs, `extensions.generated`, `extensions.provenance`, `extensions.seed` or `extensions.generated_policy`. Those can be computed from git whenever someone needs them. Do not add a crumb with a placeholder purpose. A crumb is worth having only when a person wrote something in it.

## How to read one

```
crumb context <path>
```

It prints the crumb chain for the path, root first (purpose, invariants, exports, related, boundaries), then the last 5 commits that touched the path, read live from git. `crumb explain <path>` is the same command, and `crumb sniff <dir>` is the same for a directory. Agents get this output automatically through a Claude Code hook. Reading the `.crumb` files by hand is fine too.

Other commands: `crumb verify [root]` is a readability lint (every crumb is JSON with `schema_version`, `name` and `purpose`), `crumb compile [root]` strips old generated data, and `crumb digest [dir]` prints a directory's structural digest computed now. None of them is a merge check.

## Claims are retired

`crumb claim`, `update`, `whisper`, `close`, `checkpoint` and `resume` are retired. They print one line and exit 0. Who works where is decided by the lane system on the Spark (`~/.local/state/aien-local-ci/LANES` and `DESK`), not by crumbs.

## Where the history lives

- RFC-0001 (format): `aien-spark/crumb-spec` `SPEC.md`, pinned at `10b8251`, archived.
- RFC-0002 (coordination plane, now retired): `docs/CRUMB_PROTOCOL_RFC_0002.md`.
- RFC-0003 (compiler) and its amendments, including Amendment 2: `docs/CRUMB_PROTOCOL_RFC_0003.md`.
- Tool: `tools/crumb/` (C11, single file). Build and test with `make -C tools/crumb test`.
- `<root>/.crumbignore` lists directories whose crumbs the tool skips (one relative directory per line).
