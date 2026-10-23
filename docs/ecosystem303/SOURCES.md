# Source and external reference pins

Observed 2026-10-23. These are development inputs, not a successor release freeze.

| Repo / role | Exact commit | Branch / status |
|---|---|---|
| aien-architecture-mv baseline | 1a3594340c70969c245554b07062efd8ead8a026 | GitHub main |
| omega-mv baseline | cd5897e3f92f72a015892c67b17f096e433b54f7 | GitHub main; no complete active seeded tree |
| aien-train baseline | ed8b6ea2562efdda7913234ca8f34b443714a987 | GitHub main |
| CUDApp baseline | 80f3a2492eef315106feebfdffcb32de39be7d95 | GitHub main |
| A: omega-bridge source-only seed import | 0fc7d8662cb799e7c206b17c18ea4c3ec2b8fea9 | Separate repository; imported seed29b12760; qualified scalar compiler |
| B: omega-mv definition export | 43f86be2 | seed/definition-export-L408; complete SHA in seed lane profiles.json |
| C: omega-mv native-host | f0499f415571bdd7496b6de391096915e78f7556 | feat/seed-native-host; file/process/network branch |
| L491 trainer/locality | 0e7dbb14f7877f9d861f173fbbde8c3e1db1d9e8 | issues/locality-602-606-20261022; functional source0daf1a44, first-party C still present |
| CUDApp native AMD/AGX lab | 268a2e9dddab02b63140c37ea937ac442c55917e | feat/native-amd-agx-lab; simulated device only |
| Omega transport | c9846a44ef350bdece0a2822decec793b59cbbbc | PR538; HTK1 tasks are not collective transport |

Compiler A SHA256:
`191b776ef98821597c3e30655da6d680a9b66edbc9ceaca3c39c61ea6df098e9`.
Compiler B SHA256:
`bcf3abc7d322b1f4e53f65559fb7e10b089a8febb5f82242f919f3aeaf9d54be`.
Compiler C SHA256:
`e5d60db892c8f21cc8c9128af26d8bded0e96d7f92946f5a549397c43a872649`.

The independent seed worker reconstructed all three from committed source.
Do not combine B's structs/definition export with C's host facilities into an
imaginary single compiler. L408 owns integration. None of these tested profiles
provides IEEE floating-point types. Fixed-point substitutes cannot satisfy the
native tensor/autograd/model gates. Self-stage equality establishes consistency,
not correctness or diverse-double-compilation trust (Omega650).

These fixed upstream versions define reference starting points, not current-latest
claims and not full compatibility promises. Git tag refs were resolved directly
from upstream. No source implementation was copied into this candidate.

| Reference | Version | Peeled commit |
|---|---|---|
| [PyTorch](https://docs.pytorch.org/docs/2.9/index.html) | 2.9.0 | 0fabc3ba44823f257e70ce397d989c8de5e362c1 |
| [Transformers](https://huggingface.co/docs/transformers/v4.57.1/en/index) | 4.57.1 | 8cb5963cc22174954e7dca2c0a3320b7dc2f4edc |
| [NumPy](https://github.com/numpy/numpy/tree/f2a77a76e08719556527e0819182073fe9b5f1c3) | 2.3.3 | f2a77a76e08719556527e0819182073fe9b5f1c3 |
| [SciPy](https://docs.scipy.org/doc/scipy-1.16.2/reference/) | 1.16.2 | b1296b9b4393e251511fe8fdd3e58c22a1124899 |
| [TorchVision](https://github.com/pytorch/vision/tree/7a9db90e9aadea3e3e1fec35969601167e9efd4f) | 0.24.0 | 7a9db90e9aadea3e3e1fec35969601167e9efd4f |
| [TorchAudio](https://github.com/pytorch/audio/tree/eaa9e4e4dd413dca1084116581dc84fad403db3b) | 2.9.0 | eaa9e4e4dd413dca1084116581dc84fad403db3b |
| [Diffusers](https://github.com/huggingface/diffusers/tree/0f252be0ed42006c125ef4429156cb13ae6c1d60) | 0.35.1 | 0f252be0ed42006c125ef4429156cb13ae6c1d60 |
| [scikit-learn](https://github.com/scikit-learn/scikit-learn/tree/25dee604bae18205b01548348388baf7a1cdfe0e) | 1.7.2 | 25dee604bae18205b01548348388baf7a1cdfe0e |
| [PyG](https://github.com/pyg-team/pytorch_geometric/tree/76ff9c2ce18c8cebf52122b57e2aeadce9793d10) | 2.7.0 | 76ff9c2ce18c8cebf52122b57e2aeadce9793d10 |

Additional external API surfaces awaiting exact version and per-API inventory:
tokenizers/datasets, PEFT/Accelerate/TRL (train5/6/3/4), JAX/TensorFlow transforms
(Omega664), ONNX/GGUF/safetensors (train5/Omega665), vLLM/TensorRT/llama.cpp
serving comparison (Omega666), hubs/tracking/workflow/IDE/debugger tools (Omega667).
This remaining work keeps architecture301 open. These are reference/interoperation
targets, never permission to use them as hidden first-party execution engines.
