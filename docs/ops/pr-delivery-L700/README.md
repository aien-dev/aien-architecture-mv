# Architecture PR #294 planner correction (L700)

Source correction: `89a870f612976bcaf358ff3f7414313d879544df`, based on exact PR head `b159d1d513ef63f322a6a36bf3ade50f1a202fce`; current base `1a3594340c70969c245554b07062efd8ead8a026` is an ancestor.

## Change

Reuse L319's byte-preserving relocation of 54 evidence files into `docs/ops/spark-broker-evidence/`. Add `ARCH-SPARK-BROKER`, mapping executable broker inputs to the existing complete broker concurrency suite through the standard gate entry point. No broad allowlist or planner semantics change. No broker implementation or installation change. L118's INCONCLUSIVE performance verdict still stands; gate coverage is not a decision to deploy the experimental broker.

## Executed evidence

- Exact original planner: 68 unmapped paths (54 evidence, 14 broker source); exit4/operator hold, not PASS.
- Existing broker baseline suite: actual concurrency tests passed with private sockets/locks.
- Before correction, `tests/gates/run.sh spark-broker` exited2 (unknown step).
- Corrected entry point ran the complete real suite and emitted `AIEN-OBS spark_broker_suite 1`, exit0.
- Corrected committed-head planner with `--operator`: RUNNABLE, no unmapped paths, selects the new gate plus all existing required gates. This is planning only, not a signed full-workspace judge PASS.
- Without `--operator`: pipeline-configuration authorization hold remains.
- Committed negative-control variant deleting the new gate is refused with unmapped broker source.
- Injected failing make command exits17; entry point cannot emit the successful observation.

The first missing-gate control deleted only a working-tree file. It was INVALID because the planner intentionally reads committed Git objects; its unchanged graph was not a failure of mapping enforcement. Both that log and the corrected committed-mutant log are retained. `L700-controls.py` replays the controls at the source pin above.

## Remaining acceptance

Independent review and final-head signed full gate qualification remain required. No PR was updated/merged, no live judge rerun, and no production broker was installed by this correction. Renda remains the only PR writer.
