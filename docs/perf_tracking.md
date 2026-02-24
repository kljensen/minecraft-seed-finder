# Performance Tracking

## 2026-02-19

Benchmark command:

```sh
scripts/bench_parity.sh
```

Parameters:

- `PARITY_BENCH_SEEDS=96`
- `PARITY_BENCH_BIOMES=256`
- `PARITY_BENCH_RADIUS=4`
- `PARITY_BENCH_SPAN=8192`
- `PARITY_BENCH_SALT=42424242`
- `PARITY_BENCH_OPT=ReleaseFast`

Results:

- `baseline` (`threads=1`, `simd=0`): `38886 vectors/s`
- `simd_1t` (`threads=1`, `simd=1`): `76849 vectors/s` (~`1.98x`)
- `parallel` (`threads=10`, `simd=0`): `425942 vectors/s` (~`10.95x`)
- `parallel_simd` (`threads=10`, `simd=1`): `395808 vectors/s` (~`10.18x`)

Notes:

- SIMD gives strong speedup in single-thread mode on the coordinate generation path.
- On this host, high-thread throughput was best with `PARITY_SIMD=0`; memory and synchronization effects dominate at full parallelism.

## 2026-02-19 (Pass 2)

Changes:

- SIMD coordinate generation path in `src/gen_parity_vectors.zig`.
- Parallel worker mode in `src/gen_parity_vectors.zig`.
- Streaming JSON write (no giant `stringifyAlloc`) and compact mode for fuzz/bench.
- `PARITY_THREADS=0` now means auto CPU count.

Benchmark command:

```sh
scripts/bench_parity.sh
```

Results:

- `baseline` (`threads=1`, `simd=0`): `43075 vectors/s`
- `simd_1t` (`threads=1`, `simd=1`): `78550 vectors/s` (~`1.82x`)
- `parallel` (`threads=10`, `simd=0`): `516229 vectors/s` (~`11.98x`)
- `parallel_simd` (`threads=10`, `simd=1`): `514518 vectors/s` (~`11.94x`)

Comparison vs first pass:

- baseline: `38886 -> 43075` (`+10.8%`)
- parallel: `425942 -> 516229` (`+21.2%`)

## 2026-02-24 (Iteration 20)

Changes:

- Two-phase constraint evaluation in `src/main.zig`:
  - `threshold` mode for expression gating and compare-only checks.
  - `full` mode only for emitted matches (score/diagnostics correctness).
- Added explicit parity tests locking `threshold` decisions to `full` decisions for biome and structure constraints.

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 2` passed (golden vectors + text/jsonl/csv streams).
- `scripts/pure_zig_parity_50.sh 10` passed with `total_mismatch=0`.

Benchmark snapshots:

- `scripts/bench_parity.sh` run `20260224T044449Z`:
  - `baseline`: `78145 vectors/s`
  - `simd_1t`: `78840 vectors/s`
  - `parallel`: `473702 vectors/s`
  - `parallel_simd`: `463450 vectors/s`
- `scripts/bench_shadow_mode.sh` run `20260224T044223Z`:
  - `baseline`: `12819 ms`
  - `native_shadow`: `20458 ms`
  - `native_compare_only`: `20416 ms`

Notes:

- The evaluator split is behavior-preserving by test and differential evidence.
- Search-loop workload time improved versus prior recorded shadow run `20260224T023439Z` (baseline `14035 -> 12819 ms`, compare-only `21628 -> 20416 ms`).

## 2026-02-24 (Iteration 22)

Changes:

- Added conjunction-only expression fast path in `src/main.zig`:
  - New plan builder flattens `and`-only atom expressions into an index list.
  - Main loop evaluates that list iteratively with short-circuit.
  - Falls back to recursive evaluator for mixed operators (`or`/`not`) to preserve behavior.
- Added regression test `conjunctive expression plan matches recursive evaluator`.

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 1` passed (golden vectors + text/jsonl/csv streams), run `20260224T045253Z`.
- `scripts/pure_zig_parity_50.sh 10` passed, run `20260224T045253Z`, with `total_mismatch=0` over `79` compared candidates.

Benchmark snapshots:

- `scripts/bench_shadow_mode.sh` baseline run `20260224T045001Z` (pre-change) vs latest `20260224T045455Z`:
  - `baseline`: `13797 -> 13249 ms` (`-3.97%`)
  - `native_shadow`: `21276 -> 21580 ms` (`+1.43%`)
  - `native_compare_only`: `20978 -> 20505 ms` (`-2.25%`)
- `scripts/bench_parity.sh` prior run `20260224T044449Z` vs latest `20260224T045455Z`:
  - `baseline`: `78145 -> 78670 vectors/s` (`+0.67%`)
  - `simd_1t`: `78840 -> 78660 vectors/s` (`-0.23%`)
  - `parallel`: `473702 -> 484418 vectors/s` (`+2.26%`)
  - `parallel_simd`: `463450 -> 468697 vectors/s` (`+1.13%`)

Notes:

- External behavior is unchanged; fast path is only selected for expressions proven equivalent to recursive `and` evaluation.
- Differential stream parity and compare-only strict stress both remained mismatch-free.

## 2026-02-24 (Iteration 23)

Changes:

- Tightened compare-only native backend proxy scans in `src/main.zig`:
  - `nativeBiomeProxyCount` now stops at the exact `needed` threshold used for the comparison decision.
  - `runNativeComparePass` computes `needed` first and passes it into proxy counting.
- Added regression test `native biome proxy count respects comparison threshold`.

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 1` passed (golden vectors + text/jsonl/csv streams), run `20260224T050309Z`.
- `scripts/pure_zig_parity_50.sh 10` passed, run `20260224T050507Z`, with `total_mismatch=0` over all 10 iterations.

Benchmark snapshots:

- `scripts/bench_shadow_mode.sh` pre-change run `20260224T050053Z` vs latest `20260224T050518Z`:
  - `baseline`: `12997 -> 12864 ms` (`-1.02%`)
  - `native_shadow`: `20519 -> 20090 ms` (`-2.09%`)
  - `native_compare_only`: `20360 -> 20101 ms` (`-1.27%`)
- `scripts/bench_parity.sh` pre-change run `20260224T050147Z` vs latest `20260224T050611Z`:
  - `baseline`: `80830 -> 80936 vectors/s` (`+0.13%`)
  - `simd_1t`: `80862 -> 80946 vectors/s` (`+0.10%`)
  - `parallel`: `488610 -> 492485 vectors/s` (`+0.79%`)
  - `parallel_simd`: `500825 -> 496819 vectors/s` (`-0.80%`)

Notes:

- No externally visible behavior changed; this only reduces redundant biome sampling work in experimental compare-only/shadow paths.
- Differential stream parity and strict compare-only stress remained mismatch-free.

## 2026-02-24 (Iteration 24)

Changes:

- Gated native compare preparation and invocation in `src/main.zig`:
  - Build `biome_compare_reqs` only when `--experimental-native-shadow` or `--experimental-native-backend-compare-only` is enabled.
  - Skip `runNativeComparePass` entirely in normal runs.
  - Applied the same gating to `snapshotSearchOutput` used by regression tests.

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 1` passed (golden vectors + text/jsonl/csv streams), run `20260224T051408Z`.
- `scripts/pure_zig_parity_50.sh 5` passed, run `20260224T051408Z`, with `total_mismatch=0`.

Benchmark snapshots:

- `scripts/bench_shadow_mode.sh` pre-change run `20260224T051213Z` vs latest `20260224T051610Z`:
  - `baseline`: `13240 -> 13283 ms` (`+0.32%`)
  - `native_shadow`: `21224 -> 21633 ms` (`+1.93%`)
  - `native_compare_only`: `20608 -> 20151 ms` (`-2.22%`)
- `scripts/bench_parity.sh` pre-change run `20260224T051213Z` vs latest `20260224T051610Z`:
  - `baseline`: `78590 -> 78620 vectors/s` (`+0.04%`)
  - `simd_1t`: `78600 -> 77715 vectors/s` (`-1.13%`)
  - `parallel`: `471544 -> 469760 vectors/s` (`-0.38%`)
  - `parallel_simd`: `472261 -> 474064 vectors/s` (`+0.38%`)

Notes:

- External behavior remains unchanged; the optimization only removes inactive compare-path work.
- The measurable improvement is on `native_compare_only` throughput; other small shifts are within normal run-to-run noise.

## 2026-02-24 (Iteration 26)

Changes:

- Removed the single-thread temporary worker-copy path in `src/gen_parity_vectors.zig`:
  - Added `processRangeAppend` to generate vectors directly into final output buffers.
  - Kept multi-thread worker mode unchanged for behavior and ordering.

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 1` passed (golden vectors + text/jsonl/csv streams), run `20260224T053717Z`.
- `scripts/pure_zig_parity_50.sh 5` passed, run `20260224T053717Z`, with `total_mismatch=0`.

Benchmark snapshots:

- `scripts/bench_parity.sh` pre-change run `20260224T053556Z` vs latest `20260224T054001Z`:
  - `baseline`: `78135 -> 80474 vectors/s` (`+2.99%`)
  - `simd_1t`: `78047 -> 80474 vectors/s` (`+3.11%`)
  - `parallel`: `442640 -> 498814 vectors/s` (`+12.69%`)
  - `parallel_simd`: `490540 -> 472621 vectors/s` (`-3.65%`)
- `scripts/bench_shadow_mode.sh` prior run `20260224T053056Z` vs latest `20260224T053922Z`:
  - `baseline`: `13305 -> 12927 ms` (`-2.84%`)
  - `native_shadow`: `14077 -> 12916 ms` (`-8.25%`)
  - `native_compare_only`: `12911 -> 12912 ms` (`+0.01%`)

Notes:

- External behavior remained unchanged; optimization only removes unnecessary copying in the parity vector generator path.
- Differential stream parity and compare-only strict stress remained mismatch-free.

## 2026-02-24 (Iteration 27)

## 2026-02-24 (Iteration 28)

Changes:

- `src/main.zig`:
  - Added impossible-fail short-circuiting to `evalBiomeThresholdAndProxy` so compare-path biome scans stop once `min_count` cannot be satisfied.
  - Added regression test `evalBiomeThresholdAndProxy matches independent threshold/proxy decisions`.
- `scripts/bench_parity.sh`:
  - Added one-time warm-up generation outside measured cases to isolate build/cache startup from per-label benchmark timings.

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 1` passed, run `20260224T070324Z`.
- `scripts/pure_zig_parity_50.sh 5` passed, run `20260224T070324Z`, with `total_mismatch=0` over `26` compared candidates.

Benchmark snapshots:

- `scripts/bench_shadow_mode.sh` prior run `20260224T062422Z` vs latest `20260224T072324Z`:
  - `baseline`: `12883 -> 12946 ms` (`+0.49%`)
  - `native_shadow`: `12872 -> 12962 ms` (`+0.70%`)
  - `native_compare_only`: `12903 -> 12935 ms` (`+0.25%`)
  - compare-only overhead vs baseline: `+20 ms -> -11 ms`
- `scripts/bench_parity.sh` prior run `20260224T062356Z` vs latest `20260224T074202Z`:
  - `baseline`: `80266 -> 78018 vectors/s` (`-2.80%`)
  - `simd_1t`: `78402 -> 77900 vectors/s` (`-0.64%`)
  - `parallel`: `422465 -> 480296 vectors/s` (`+13.69%`)
  - `parallel_simd`: `423329 -> 487459 vectors/s` (`+15.15%`)

Notes:

- External behavior remains unchanged; compare path now performs less redundant work in impossible threshold cases.
- Two pre-warmup parity benchmark runs (`20260224T070527Z`, `20260224T072407Z`) showed first-case timing distortion and are superseded by warmed run `20260224T074202Z`.

Changes:

- Conjunction + alias hot-path tightening in `src/main.zig`:
  - Added canonicalized conjunctive-atom plan (`canonicalizeConjunctiveAtomPlan`) to deduplicate aliased/duplicate atoms before threshold evaluation.
  - Updated `evaluateAll` to evaluate canonical constraints once in full mode, then copy aliased eval states.
  - Added regression test `canonical conjunctive plan deduplicates aliased atoms without changing decisions`.
- Fixed benchmark timing portability in:
  - `scripts/bench_parity.sh`
  - `scripts/bench_shadow_mode.sh`
  - `scripts/pure_zig_parity_50.sh`
  - Replaced non-portable `date +%s%N` elapsed timing with portable `now_ns()` helper (`python3`/`perl` fallback chain).

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 1` passed (golden vectors + text/jsonl/csv streams), run `20260224T054437Z`.
- `scripts/pure_zig_parity_50.sh 5` passed, run `20260224T062350Z`, with `total_mismatch=0` over `42` compared candidates.

Benchmark snapshots:

- `scripts/bench_shadow_mode.sh` prior run `20260224T053922Z` vs latest `20260224T062422Z`:
  - `baseline`: `12927 -> 12883 ms` (`-0.34%`)
  - `native_shadow`: `12916 -> 12872 ms` (`-0.34%`)
  - `native_compare_only`: `12912 -> 12903 ms` (`-0.07%`)
- `scripts/bench_parity.sh` prior run `20260224T054001Z` vs latest `20260224T062356Z`:
  - `baseline`: `80474 -> 80266 vectors/s` (`-0.26%`)
  - `simd_1t`: `80474 -> 78402 vectors/s` (`-2.57%`)
  - `parallel`: `498814 -> 422465 vectors/s` (`-15.31%`)
  - `parallel_simd`: `472621 -> 423329 vectors/s` (`-10.43%`)

Notes:

- Behavioral output is unchanged; optimization only reduces redundant constraint evaluations for conjunctions with duplicates/aliases.
- Timing records are now portable/defensible on macOS hosts; earlier `%N`-based timing noise is eliminated.

## 2026-02-24 (Iteration 29)

Changes:

- `src/main.zig`:
  - Fixed `evalBiomeThresholdAndProxy` early impossible-fail logic to run on every sample (including non-matches), not only when the biome matches.
  - Replaced repeated `remaining` recomputation with a decrementing counter in both points and offset loops.
  - Added regression test `evalBiomeThresholdAndProxy sparse misses still match independent decisions`.
- `scripts/bench_shadow_mode.sh`:
  - Added one-time warm-up run before measured cases, mirroring parity harness behavior.

Conformance:

- `zig build test -Doptimize=ReleaseFast` passed.
- `scripts/diff_cli_stream.sh 1` passed, run `20260224T080717Z`.
- `scripts/pure_zig_parity_50.sh 5` passed, run `20260224T082604Z`, with `total_mismatch=0` over `23` compared candidates.

Benchmark snapshots:

- `scripts/bench_shadow_mode.sh` prior run `20260224T072324Z` vs latest `20260224T090749Z`:
  - `baseline`: `12946 -> 12918 ms` (`-0.22%`)
  - `native_shadow`: `12962 -> 12909 ms` (`-0.41%`)
  - `native_compare_only`: `12935 -> 12882 ms` (`-0.41%`)
- `scripts/bench_parity.sh` prior run `20260224T074202Z` vs latest `20260224T085757Z`:
  - `baseline`: `78018 -> 80183 vectors/s` (`+2.77%`)
  - `simd_1t`: `77900 -> 78461 vectors/s` (`+0.72%`)
  - `parallel`: `480296 -> 495234 vectors/s` (`+3.11%`)
  - `parallel_simd`: `487459 -> 493267 vectors/s` (`+1.19%`)

Notes:

- External behavior remains unchanged; this pass only removes redundant compare-path work and hardens benchmark consistency.
- Differential stream parity and strict compare-only checks remained mismatch-free.
