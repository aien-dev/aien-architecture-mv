# ADR 0039: One thing per repo (the Unix rule for kernel, machines and drivers)

Status: DECIDED by Drake, 2026-10-20. Written by the training-chat coordinator the same day. Supersedes nothing; narrows ADR 0038 (names) and the L300 kernel split.

## Drake's words (2026-10-20)

"One thing I want to embrace is the Unix philosophy. We have the MacBook, the iMac, the Spark, and now we're doing this Windows one. I think those need to be their own separate repos and modules and they don't need to be buried in the Aienux kernel." And: "All the different drivers and stuff, they all need to be in their separate repos."

## Decision

Every separable thing lives in its own repository, does one job, and is composed by pinned versions, not by living in one tree.

| Kind | Repo name | Holds | Does not hold |
|---|---|---|---|
| Kernel | `aien-dev/aienux` | The machine-independent kernel: scheduler, memory, capabilities, the driver port (the documented slot a driver plugs into), the boot handoff contract, the test harness for those | Any one machine's quirks, any one device's driver |
| Machine | `aien-dev/aienux-spark`, `aienux-imac`, `aienux-macbook`, `aienux-pc` | What one machine needs to boot and run: firmware facts, ACPI/device-tree handling, memory map, the boot package and the stick/netboot staging for that machine, its evidence of real boots, the list of driver repos it pins | Drivers (pinned from driver repos), kernel code |
| Driver | `aien-dev/aienux-driver-<device>` (for example `aienux-driver-rtl8127`, `aienux-driver-nvme`, `aienux-driver-mt7925`, `aienux-driver-tpm-crb`, `aienux-driver-xhci`, `aienux-driver-hda`, `aienux-driver-bt-hci`) | One device: the driver, its chip model, its tests, its firmware inventory and licences, its receipts | Kernel code, other drivers |
| System | `aien-dev/aienos` | The assembly: which kernel, which machine repos, which drivers, which runtime (Omega, the model server, Allen) at which pinned versions; the images; the first-run experience | Source of the parts it assembles |
| Runner | `aien-dev/aienos-run` (already separate) | Runs an AienOS image on a host OS (Windows, macOS, Linux) | Kernel or drivers |

Composition is by lock files with pinned commits and digests, the way `omega.lock` pins Omega inside aien-sovereign-core today. A machine repo pins the kernel and its drivers; `aienos` pins machine repos. A build is reproducible from the locks alone.

The driver port is the contract. A driver repo depends only on the port the kernel publishes (ADR for the port: the L215 driver-contract model, where a driver is a checked device contract the kernel compiles). The rule from L203 stands: the kernel makes the port, not the driver; whoever wants a device builds its repo against the port.

## Why

- Unix: one tool, one job, composed. A reader of `aienux-driver-nvme` sees one device and all of its evidence, not a 3,582-file tree.
- Four machines and a Windows runner already exist; each has its own firmware, its own boot path and its own physical limits. Burying them in the kernel tree means every machine change is a kernel change and every kernel judge run pays for every machine.
- Drivers are the part most likely to be built by other people (Drake: "whoever wants one builds it"). A separate repo with its own receipts is the unit someone can own.
- Judging and receipts get cheaper: a driver change runs that driver's tests and chip model; the kernel judge runs only on kernel changes.

## Consequences

1. L300 (pull the kernel out of aienos-mv) becomes the first move of this layout, not a single split: `aienux` plus `aienux-spark` plus one driver repo per existing native driver, with history preserved per path (`git filter-repo` on each path set). It stays parked until the naming branches (L180) and the in-flight Spark driver work (L206, L207, L225) land, so it does not fight 272 renamed files and live branches.
2. In-flight driver streams (RTL8127 L198, NVMe L199, TPM/RTC L200, Wi-Fi L206, Bluetooth/HDA L207) finish where they are. Their final home is a driver repo each; the split moves them with their history. New driver work after this ADR starts in its own repo from day one.
3. Every repo gets: AGPL-3.0, a README that says what the one thing is and links its evidence, a judge lane (or the desk's read-the-diff rule for docs-only repos), and a lock file for what it pins.
4. The receipt chain (L122) and the Program map (L115) list repos, not directories.
5. Names follow ADR 0038: Aienux is the kernel, AienOS the system; Aienix does not appear.

## Open items (ledger)

- L300: the split, with this layout, trigger as above.
- The driver port spec is the gate for every driver repo: it must be published in `aienux` before the first driver repo is created, or the drivers have nothing stable to pin. Owner: the L215 driver-contract stream; the split waits for it.
- Which native/ parts are kernel and which are machine (boot, crypto, sig, store, capability, net, disk): decided by dependency when L300 runs; the rule is "used by more than one machine and no device: kernel; one machine: machine repo; one device: driver repo".
