# Source and external reference pins

Observed 2026-10-23. These are development inputs, not a successor release freeze.

| Repo / role | Exact commit | Branch / status |
|---|---|---|
| aien-architecture-mv baseline | 1a3594340c70969c245554b07062efd8ead8a026 | GitHub main |
| omega-mv baseline | cd5897e3f92f72a015892c67b17f096e433b54f7 | GitHub main; no complete active seeded tree |
| aien-train baseline | ed8b6ea2562efdda7913234ca8f34b443714a987 | GitHub main |
| CUDApp baseline | 80f3a2492eef315106feebfdffcb32de39be7d95 | GitHub main |
| A: omega-bridge source-only seed import | 0fc7d8662cb799e7c206b17c18ea4c3ec2b8fea9 | Separate repository; imported seed29b12760; qualified scalar compiler |
| B: omega-mv definition export | 43f86be20f7257e02622f10a19abd2da2c98a290 | seed/definition-export-L408; complete SHA in seed lane profiles.json |
| C: omega-mv native-host | f0499f415571bdd7496b6de391096915e78f7556 | feat/seed-native-host; file/process/network branch |
| L491 trainer/locality | 0e7dbb14f7877f9d861f173fbbde8c3e1db1d9e8 | issues/locality-602-606-20261022; functional source0daf1a44, first-party C still present |
| CUDApp native AMD/AGX lab | 268a2e9dddab02b63140c37ea937ac442c55917e | feat/native-amd-agx-lab; simulated device only |
| Omega transport | c9846a44ef350bdece0a2822decec793b59cbbbc | PR538; HTK1 tasks are not collective transport |
| L720 software IEEE binary32 | 7e1d0d61755ec1a0bbf20941a18379861b5b9d0d | omega-bridge feat/renda8b-ref32-L720; native/ref32/add32.om and mul32.om |
| Tensor metadata candidate | 8975287573f284dd2140b2f2b169619d3e145cf1 | omega-mv feat/ecosystem663-admission; functional source3a995ba8dace538c1532c747d829ca6e4a73582d |
| Seed qualification candidate | 3b3a67393d4d5d2ea9b70e43353e1946e5e2430a | omega-mv qualify/ecosystem660-seed; stacked on profile B ancestry |
| Distributed admission candidate | 2ff2144819fb46993d2b373fc83d4de1a8d72990 | aien-train feat/distributed7-admission; independently reviewed component, no collective transport |
| Numerical consumer candidate | c7642d96c0b84b6d176dbb2dc8558b536cabe729 | aien-train feat/ecosystem6-native-step; functional d79b34352f769687b62cc77ba2e3739445723010; independent review complete |
| Data packing candidate | 4f93aabb11e584e3f556a3cc9ea2a8d0ce062272 | aien-train feat/ecosystem5-packing; functional088258d0c76c4e3b6c73ad92c12e20948014cc6f; independent review complete |
| Existing learning benchmark core | 84d03c5523f39ca1045d1c313c5f62597779462b | Omega L775; src/learning/benchmark/core.om, consumed by packing |
| Existing curriculum admission | d8d14c47647e49774f64b58e3c138335656f175d | Omega L776; published1a14972c3b2d7494ba445df79967e7963359230e, consumed by packing |

Compiler A SHA256:
`191b776ef98821597c3e30655da6d680a9b66edbc9ceaca3c39c61ea6df098e9`.
Compiler B SHA256:
`bcf3abc7d322b1f4e53f65559fb7e10b089a8febb5f82242f919f3aeaf9d54be`.
Compiler C SHA256:
`e5d60db892c8f21cc8c9128af26d8bded0e96d7f92946f5a549397c43a872649`.

The independent seed worker reconstructed all three from committed source.
Do not combine B's structs/definition export with C's host facilities into an
imaginary single compiler. L408 owns integration. None of these tested profiles
provides IEEE floating-point types. L720 nevertheless implements actual IEEE
binary32 addition and multiplication in handwritten .om using integer bit
operations; this is a usable numerical dependency, not a fixed-point substitute.
Its bounded independent review exercised19041 checks. That does not supply a
complete tensor engine, division, square root, nonlinearities or general autograd.
The ecosystem6 lane consumes the exact existing source for an affine
forward/VJP/SGD qualification:374708 author checks,1041 separate reviewer checks
including14 central differences, and3 compiled mutants caught by both suites.
Self-stage equality establishes consistency,
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
| [Tokenizers](https://github.com/huggingface/tokenizers/tree/afaae088837b277c19f90604a1111a272838857b) | 0.22.1 | afaae088837b277c19f90604a1111a272838857b |
| [Datasets](https://github.com/huggingface/datasets/tree/7e1350b41d19eabc961e7de9e26f1aa09f18e110) | 4.2.0 | 7e1350b41d19eabc961e7de9e26f1aa09f18e110 |
| [PEFT](https://github.com/huggingface/peft/tree/53c25fe4fdd7c6aa4b40db0560815ea570d32303) | 0.17.1 | 53c25fe4fdd7c6aa4b40db0560815ea570d32303 |
| [Accelerate](https://github.com/huggingface/accelerate/tree/623cc0ba588d192c77758939a6e340adf07edd4f) | 1.10.1 | 623cc0ba588d192c77758939a6e340adf07edd4f |
| [TRL](https://github.com/huggingface/trl/tree/4529a1c8b1813480a85b02c9c8e7f75a29085d65) | 0.23.1 | 4529a1c8b1813480a85b02c9c8e7f75a29085d65 |
| [JAX](https://github.com/jax-ml/jax/tree/94233144f5469af28c065aa4263a6849338eeaa1) | 0.7.2 | 94233144f5469af28c065aa4263a6849338eeaa1 |
| [TensorFlow](https://github.com/tensorflow/tensorflow/tree/72fbba3d20f4616d7312b5e2b7f79daf6e82f2fa) | 2.20.0 | 72fbba3d20f4616d7312b5e2b7f79daf6e82f2fa |
| [ONNX](https://github.com/onnx/onnx/tree/57b9c6a4f6eebb09ae1b34cfb632078518f72832) | 1.19.0 | 57b9c6a4f6eebb09ae1b34cfb632078518f72832 |
| [Safetensors](https://github.com/huggingface/safetensors/tree/aa6c43d729868fc43918e862d42bfeaf60485d1d) | 0.6.2 | aa6c43d729868fc43918e862d42bfeaf60485d1d |
| [vLLM](https://github.com/vllm-project/vllm/tree/b8b302cde434df8c9289a2b465406b47ebab1c2d) | 0.11.0 | b8b302cde434df8c9289a2b465406b47ebab1c2d |
| [llama.cpp / GGUF](https://github.com/ggml-org/llama.cpp/tree/3f750f8d760ab5a61491e6a9409072dfeee4b4d7) | b6748 | 3f750f8d760ab5a61491e6a9409072dfeee4b4d7 |
| [TensorRT](https://github.com/NVIDIA/TensorRT/tree/94e2b9ef6d2cce74c76cdad499cca36cc4949197) | 10.13.3 | 94e2b9ef6d2cce74c76cdad499cca36cc4949197 |
| [MLflow](https://github.com/mlflow/mlflow/tree/78d075062b120597050bf2b3839a426feea5ea4c) | 3.4.0 | 78d075062b120597050bf2b3839a426feea5ea4c |
| [Ray](https://github.com/ray-project/ray/tree/479fa716904109d9df4b56b98ca3c3350e1ec13c) | 2.49.2 | 479fa716904109d9df4b56b98ca3c3350e1ec13c |
| [KServe](https://github.com/kserve/kserve/tree/d623ea29e4a7312e509829f9104209cd6f820268) | 0.15.2 | d623ea29e4a7312e509829f9104209cd6f820268 |
| [lm-evaluation-harness](https://github.com/EleutherAI/lm-evaluation-harness/tree/d021bf846218f1bb3bdc0603864789329476d464) | 0.4.9.1 | d021bf846218f1bb3bdc0603864789329476d464 |
| [Triton](https://github.com/triton-lang/triton/tree/c3c476f357f1e9768ea4e45aa5c17528449ab9ef) | 3.5.0 | c3c476f357f1e9768ea4e45aa5c17528449ab9ef |
| [NCCL](https://github.com/NVIDIA/nccl/tree/ae7aed194dc63c65d1bf5c0385ba3d68d3b64c8c) | 2.28.7-1 | ae7aed194dc63c65d1bf5c0385ba3d68d3b64c8c |

All rows above still need their per-API and actual-consumer inventory.
Additional external surfaces awaiting exact reference pins include hub protocols,
workflow/IDE/debugger interfaces and non-NVIDIA accelerator libraries (Omega667,
Omega665, CUDApp36/62). The boundary map is in COMPATIBILITY.md.
The pinned engine/library sources are reference specifications
and test-oracle candidates, not installed product dependencies.
This remaining work keeps architecture301 open. These are reference/interoperation
targets, never permission to use them as hidden first-party execution engines.
