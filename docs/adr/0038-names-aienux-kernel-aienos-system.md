# ADR 0038: Names: Aienux is the kernel, AienOS is the operating system, Aienix is retired

**Status:** ACCEPTED (2026-10-20). Decided by Drake Stapleton on 2026-10-20. Recorded by the naming worker (ledger L180, Claude).
**Supersedes:** the name "Aienix" for the core tree (aien-dev/aienix front page and the organisation profile) and "AIENOS" as the name of the kernel and of the whole system in prose.
**Related:** ledger L180; brief `~/handoffs/briefs/L180-naming.md`; `CONTEXT.md` section "Names"; `tools/name-check` (branch `naming/name-check-gate`).
**Evidence base:** GitHub default branches of the 29 own aien-dev repositories on 2026-10-20 (forks t3code, rpi5-uefi, edk2-non-osi and translate not counted).

---

## Decision

Drake's words, 2026-10-20:

> "Aienux for the kernel"
>
> "we get rid of Aienix altogether since it's already being used"
>
> "or better AienOS"

| Word | Means | Spelling | Today |
| :--- | :--- | :--- | :--- |
| **Aienux** | The kernel: boots the machine, drives the hardware. | Exactly `Aienux`. | Repository aien-dev/aienos-mv (C kernel, Rust crates, QEMU gates, Allen's window). |
| **AienOS** | The whole operating system: Aienux + Omega + runtime (sovereign core) + Allen. | Exactly `AienOS`. | The core tree repository aien-dev/aienix. |
| **AIEN** | The project and the agent. | Unchanged. | |
| **Omega** | The language, semantic substrate and GPU engine. | Unchanged. | aien-dev/omega-mv. |
| Aienix | Retired everywhere. Another company ("Aienix Technologies") uses it. | | |
| AIENOS, Aienos | Retired in prose. Write Aienux when the kernel is meant and AienOS when the whole system is meant. | | |

The web address www.aienos.com stays (domain names ignore case); the site text says AienOS.

## Rules

1. **Prose** uses the new names from now on. Old prose was changed on branches `naming/aienux-aienos` in every affected repository.
2. **History is never rewritten.** Evidence, receipts, `docs/history`, changelogs, ledger text, commit messages, signed bundles, dated reports and results, and accepted ADRs keep the words they were written with. Read "AIENOS" there as "Aienux" when it names the kernel or its repository, and "Aienix" as "AienOS".
3. **Code names stay until their own change.** Lowercase names (paths, crate and binary names such as `aienos-kernel`, URLs, environment variables), identifiers that contain the old word (`AIENOS_DISK_NATIVE`, `AienosCapRef`) and string labels that feed cryptography (`AIENOS-PKV-ENVID-KEY-V1`) are not prose. Renaming them changes builds, gate names, receipts or derived keys, so each needs its own change with its own tests. Labels that feed key derivation are never renamed.
4. **Strings a test or a person matches** (boot banners, GRUB menu entries, serial log lines) keep their current text until the kernel changes them with their tests; docs quote them as they are.
5. **Check.** `tools/name-check/name-check.sh` fails a change that adds a retired word in prose outside the history paths. It ignores lowercase names and identifiers (rule 3).

## Repository renames (requested, not done here)

Renames are GitHub writes and go through the PR desk:

- aien-dev/aienos-mv to aien-dev/aienux.
- aien-dev/aienix to aien-dev/aienos.

Found on 2026-10-20: `aien-dev/aienos` and `aien-spark/aienos` are not separate repositories. Both are GitHub redirects to aien-dev/aienos-mv (one history, same first commit; the Rust crates and the C kernel live in that one repository). Renaming aienix to aienos takes the name `aienos` and ends that redirect: any clone or script that still uses `github.com/aien-dev/aienos` would then reach the AienOS tree instead of the kernel. Every such remote and reference must move to the kernel's new name first. The list is in the desk log entry for L180.

## Consequences

- The kernel docs say Aienux; the front page, profile and website say AienOS.
- Old ADRs and evidence still say AIENOS and Aienix; rule 2 tells a reader how to map them.
- Code identifiers and paths still carry `aienos` and `AIENOS_`; renaming them is follow-on work per repository, gated by that repository's own tests.
