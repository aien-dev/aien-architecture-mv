# External Prior Art to Study

AIEN should reuse protocols and primitives where possible while owning its integration semantics.

| Area | Prior art | What to borrow |
|---|---|---|
| Heterogeneous local compute | Exo | discovery/topology ideas |
| Remote model compute | llama.cpp RPC | remote device exposure |
| Multi-machine Apple compute | MLX distributed | low-latency distributed patterns |
| Resource scheduling | Ray / Dask | placement concepts |
| MCP | official Rust `rmcp` | protocol correctness |
| Authorization | Cedar | fast declarative policy model |
| Workload identity | SPIFFE/SPIRE | short-lived node identity principles |
| Sandboxed plugins | Wasmtime/WASI | portable least-privilege extension runtime |
| Provenance | in-toto / DSSE | signed envelope concepts |
| Observability | OpenTelemetry | semantic conventions |
| Durable workflows | Temporal | deterministic replay/activity isolation |
| Path reasoning | PEARL / KELP / PoG / MOSAIC | contextual path ranking and adaptive exploration |
| Agent harness mechanics | Hermes Agent (NousResearch, MIT) | bounded micro-compaction, evidence-anchored token accounting, agent-written skills under an editorial policy, skill ledger with rollback; see [hermes-agent-prior-art.md](hermes-agent-prior-art.md) |

External technologies are implementation inputs, not reasons to give up AIEN's own typed state/effect semantics.
