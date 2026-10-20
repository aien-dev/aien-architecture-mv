# L113 first complete measurement window (2026-10-20)

Window `20261020T095626Z-bd2f56`, opened with `spark-window open l113-window-8 --ledger L113 --lease 90 --gb10 none --wait`,
held 09:56:27Z, closed 09:59:31Z. Copies of the four JSON files are here. The full set, including the stream
with a time stamp per piece, the request, the GPU-lock samples and the receipts, is in `~/yardsticks/windows/20261020T095626Z-bd2f56/` on the Spark.

| What | Value |
|---|---|
| Memory copy, 1 thread (median of 10) | 45.65 GB/s |
| Memory copy, 8 threads (median of 10) | 86.15 GB/s |
| Wall power with the GPU held idle, 30 s | 245.3 W (box load 28.7: other agents' CPU work kept running) |
| 27B decode, client clock (63 tokens, first to last) | 8.358 s, 7.538 tok/s |
| 27B decode, server's own log for the same reply | 8360 ms for 64 tokens, 7.66 tok/s |
| Wall J/token over the decode (5 sensor samples, coarse) | 40.3 J; 7.8 J above the window's idle |
| Reply fingerprint (fixed prompt, seed 1, greedy) | sha256 9132f20e... |
| Checks | ok: 64 tokens, HTTP 200 on the first send, no other GPU-lock holder during the decode, window held throughout, reply streamed (not one burst) |

The client and server decode times agree to 2 ms. The 27B server was busy with other clients for 96 s
before our send (480 polls of /health at 0.2 s); the decode itself is unaffected by that wait.
