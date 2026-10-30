# AienOS

AienOS is becoming a native AI runtime architecture centered on managed model contexts, shared physical KV memory, an effect boundary, typed subsystem protocols, native inference execution, and persistent state. It is not yet an operating system.

## Language

### Names (ADR 0038)

**AienOS**:
The whole operating system: Aienux plus Omega plus the runtime (sovereign core) plus Aien. The site www.aienos.com shows this name.
_Avoid_: Aienix (retired: another company uses it), AIENOS, Aienos

**Aienux**:
The kernel: it boots the machine and drives the hardware (repository aien-dev/aienux; the old name aienos-mv is retired, ADR 0038).
_Avoid_: AIENOS, Aienos, "the OS" when only the kernel is meant

**AIEN**:
The project and the agent. Unchanged.

### Runtime

**Inference context**:
The named state of one model computation: its identity, lineage, generation, model fingerprint, tokenizer fingerprint, KV format, logical state digest, runtime binding, and recovery recipe.
_Avoid_: agent, session, prompt, conversation, KV pool

**Inference client**:
A component that submits tokens to the inference runtime. Native chat, the AEGIS agent loop, and subagents are inference clients.
_Avoid_: Cortex, RSI, composition host

**KV pool**:
The physical memory of model computation, owned by the inference runtime.
_Avoid_: inference context, conversation

**Composition host**:
Infrastructure that exposes or hosts inference clients. `aien-local-stack` is a composition host.
_Avoid_: inference client, inference context, composition root

**Cortex**:
The durable memory system.
_Avoid_: cortex_recall, vector database

**AEGIS**:
The cross-cutting invariant and contract verifier. It checks admissibility and compliance; it does not mint capabilities or execute actions.
_Avoid_: Aienux, OpenClaw, inference runtime, Effect Broker

**Effect Broker**:
The executor for an effect that leaves the machine.
_Avoid_: AEGIS, shell dispatch, enforcement membrane

**RSI**:
The out-of-band promotion loop for candidate changes.
_Avoid_: inference runtime, canary observation

### Capabilities

**Capability**:
A model-facing contract. It performs that contract, or it reports itself unavailable.
_Avoid_: feature, plugin

**Tool**:
An atomic capability. Canonical identifiers include `cortex.search`, `telemetry.read`, `process.execute`, `filesystem.read`, and `filesystem.write`. `cortex_recall` is a legacy alias for `cortex.search`, not a second tool.
_Avoid_: skill, procedure, cortex_recall

**Skill**:
A reusable procedure composed from tools, success criteria, constraints, and optional J-Space strategy.
_Avoid_: atomic handler, tool

### Effects

**Workspace-bound execution**:
Execution whose working directory and path capability are checked against a workspace root. The command text may still name other paths, the network, and other processes.
_Avoid_: OS sandbox, enforcement membrane, confinement

**Shell dispatch**:
The single AEGIS entry for a shell request. It applies the enforcement membrane and the workspace-bound checks, then admits local execution only when the effect is positively shown to stay on the machine.
_Avoid_: OS sandbox, Effect Broker, denylist

**Local execution**:
Execution inside AEGIS that has already been shown to stay on the machine. Unclassified shell text is not local execution.
_Avoid_: workspace-bound execution, default shell, denylist fallback

**Enforcement membrane**:
The deterministic pre-dispatch policy that stands in front of shell execution, including the destructive-command denylist.
_Avoid_: OS sandbox, workspace-bound execution

**OS sandbox**:
Process isolation by namespace, mount, network, user identity, and syscall filtering. The shell path does not have this.
_Avoid_: workspace-bound execution, enforcement membrane

### Evidence

**Canary observation**:
A uniquely identified measured result of executing one candidate, bound to that candidate's artifact digest. A new observation id counts once. The same id with the same canonical record is an idempotent success and does not count again. The same id with a different record is a conflict and does not count.
_Avoid_: synthetic rehearsal, safety envelope, canary quota

**Canary quota**:
The number of qualifying canary observations required before promotion.
_Avoid_: canary observation, synthetic rehearsal

**Safety envelope**:
A signed wrapper around an authorization or a body of evidence.
_Avoid_: canary observation, empirical proof

**Synthetic rehearsal**:
A generated event used to exercise a mechanism. It may share an observation's shape. Its provenance makes it ineligible for the production canary quota.
_Avoid_: canary observation, production evidence

### Secrets

**Secret provider**:
The component that holds credentials. `atlas-vault` is the secret provider.
_Avoid_: vault client, TPM

**Vault client**:
The in-process component that asks the secret provider for a credential. `VaultResolver` is a vault client.
_Avoid_: secret provider, TPM

**Production secret resolution**:
An in-memory cache, then the secret provider. If the provider does not answer, resolution fails closed.
_Avoid_: process environment, hardware silicon

**Development secret fallback**:
An explicit, default-off permission for a development process to read a credential from its environment after the secret provider does not answer.
_Avoid_: production secret resolution, implicit fallback

### Dependencies

**Verified Crumb**:
A content-addressed, immutable library object keyed by Omega semantic id and bound to a passing evidence receipt. It is the only thing Omega may resolve an import to (ARCH-0029). Always written in full; it is neither a `.crumb` coordination file (RFC-0001, `docs/CRUMB_PROTOCOL.md`) nor a Crumbline curriculum item.
_Avoid_: crumb (alone), package, library file, dependency by name or version

### Status

**Implemented**:
Running behavior that performs the contract its name states.
_Avoid_: partial integration, scaffold

**Partial integration**:
A real subsystem that is not yet on the same path as the runtime it serves.
_Avoid_: scaffold, implemented

**Scaffold**:
A registered name whose implementation does not perform its contract.
_Avoid_: success-shaped result, healthy fixture
