# Declared compatibility boundaries and audit obligations

The 27 fixed upstream references in SOURCES.md are specification starting points.
They do not imply27 compatible libraries or complete API inventories. The native
target is handwritten seeded .om with explicit semantics. No component here
executes arbitrary Python, imports PyTorch or hides a foreign runtime.

| Boundary | Intended contract | Owning issue and release gate |
|---|---|---|
| Native numerical API | Tensor/operator/module/differentiation/optimizer behavior, with declared dtype, rounding, layout, mutation, alias and gradient rules | Omega663/664 and train6; independent numerical tests and actual consumers for every declared operator |
| External file compatibility | Tokenizer/model/config, dataset and checkpoint files including Safetensors, GGUF and ONNX where declared | Train5, Omega651/665; exact format/version, malformed inputs, independent decode and reload-equivalence tests |
| External protocol compatibility | Serving, model retrieval, collective and observability protocols where explicitly selected | Omega666/667, train7; exact protocol/schema, authenticated custody, errors/cancellation and real peer consumers |
| Source translation | Any accepted non-.om source language or graph representation must have a separately enumerated supported subset | Omega665 and existing CUDApp35/36 owner; accepted/refused corpus and independent lowering relation |
| Runtime emulation | No general Python/PyTorch/JAX/TensorFlow runtime emulation is claimed or implemented by this programme slice | A new explicit implementation issue and dedicated gates are required before any such claim; no hidden compatibility engine |

PyTorch API families, NumPy/SciPy services, JAX transformations and TensorFlow
equivalents map to capabilities rather than requiring duplicate execution
engines. Native operator semantics do not automatically provide source-level
import compatibility. Loading weights does not establish model, tokenizer,
template, optimizer-state or training-resume compatibility.

The pinned inference engines are comparison and interoperability references for
Omega666, not permission to call their execution engines in the Omega product.
TensorRT/Triton/NCCL are accelerator/compiler/collective reference surfaces for
Omega665/661 and train7; replacing their first-party uses requires exact device,
numerical, transport and cost gates. Driver, OS and firmware boundaries remain
explicit external platform dependencies subject to the existing hardware rules.
No driver change, runtime installation or deployment is part of this batch.

MLflow maps to registry/tracking Omega667; Ray and KServe to scheduling/lifecycle
Omega649 and serving Omega666; lm-evaluation-harness to evaluator Omega667.
Specific API/protocol selections and actual consumer paths remain to be frozen
in those issues. An upstream tag pin alone does not settle those contracts.

For each feature admitted to a release denominator, the issue must record:
upstream specification/version, exact local source/branch/owner, current consumer,
native semantics, external format/protocol obligations, transitive dependencies,
numerical or behavioral oracle, hardware tier, priority, acceptance commands,
consumer switch and deletion requirements. Missing values remain open gates;
invented source paths or presumed owner activity are unacceptable.

## Current dependency evidence

The actual numerical component compiles L720 add32/mul32, M20 metadata, the affine
consumer and a handwritten caller into one static AArch64 ELF. The independent
review inspected its program/dynamic headers and traced file/process/network
operations: no child runtime, dynamic library or external model file was observed
in that scoped caller. The independent symbolic oracle is external qualification
software and is absent from the delivered numerical path. This trace is bounded
evidence, not a proof of every possible path or the entire ecosystem.

The original Core tokenizer still wraps the Rust tokenizers library. Its model
loader still handles BF16 Safetensors through existing foreign implementation.
L491's reusable general trainer/tape/tensor substrate still includes C. These are
active migration obligations, not native replacements. L292's Rust/Python corpus
branch is DROPPED and was not resumed. L689 owns weight-flow scheduling and is
not a dataset-loader/checkpoint owner. Existing native supplied-token validation
and curriculum admission do not replace tokenization or file ingestion.

Outer build/test operations still use Linux shell/git/checksum/ELF tools and the
existing C-built Crumb gate. They are explicitly unretired. No package manifest
was removed because no production flow in this batch passed complete replacement
acceptance. Architecture300/Omega599 retain first-party deletion responsibility.

Full build/train/evaluate/serve transitive dependency audits and subprocess traces
must be repeated on the final integrated native paths before any retirement or
full-ecosystem claim. This remains an open architecture301/302 gate.
