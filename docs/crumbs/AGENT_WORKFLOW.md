# How an agent works with crumbs (RFC-0003 Amendment 2)

Crumbs are advisory notes. Read them; do not maintain them as a chore.

## Before changing a path

```
crumb context <path>
```

Read the purpose and the invariants of every crumb in the chain, root first. An invariant is a rule your change must keep. If your change must break one, stop and record why in the PR instead of quietly editing the crumb. Follow `related` entries and the listed commits (`git show <sha>`) when you need more.

A Claude Code hook usually shows you this output already. If there is no crumb for the path, read the code, the README and recent history as usual.

## When a crumb is wrong or missing

Edit it by hand in the same PR as your change, with only the allowed keys (see `docs/CRUMB_PROTOCOL.md`). Write a real purpose or nothing; never add a placeholder. There is no compile step and no separate crumb commit.

## Who works where

The lane system decides it: Spark `~/.local/state/aien-local-ci/LANES` and `DESK`. Crumb claims, locks, whispers and checkpoints are retired; those commands print one line and do nothing.

## What not to do

- Do not run `crumb compile` or `crumb verify` as a ritual before committing. Nothing requires them.
- Do not put generated data (file lists, digests, commit logs) into a crumb.
- Never put secrets in a crumb.
