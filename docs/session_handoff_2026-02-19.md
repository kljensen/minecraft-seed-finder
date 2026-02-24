# Session Handoff (2026-02-19)

## Stop Point
Safe to pause now. Main feature block is implemented and compiling; remaining work is polish + one requested feature gap.

## What Was Completed

1. Performance/instrumentation track (existing work continued)
- Added opt-in timing instrumentation in parity vector generation (`PARITY_TIMING=1`).
- Timing output includes per-version phase timing + throughput.
- Differential fuzz script updated to copy `src/bedrock.zig` into reference workspace.
- Added `Justfile` recipes for perf/dev loops (`test`, `gen-parity`, `gen-parity-timing`, `fuzz-quick`).

2. Major CLI feature expansion in seed finder (`src/main.zig`)
- Boolean filter expressions via `--where`:
  - operators: `and` / `or` / `not` and `&&` / `||` / `!`
  - parentheses supported
  - identifiers: `bN`, `sN`, `cN`
- Location/anchor mode via `--anchor x:z` (constraints evaluated around fixed location instead of spawn).
- Ranked results mode:
  - `--ranked` + `--top-k`
  - score derived from matched constraints + proximity.
- Structured output formats:
  - `--format text|jsonl|csv`
  - includes diagnostics field per result.
- Progress + checkpoint/resume:
  - `--progress-every`
  - `--checkpoint`, `--checkpoint-every`, `--resume`

3. Documentation updates
- `README.md` updated with new examples/options/expression grammar.

## Validation Performed

Build/tests:
- `zig build --build-file /workspace/build.zig --cache-dir /tmp/zig-local-build-main4 --global-cache-dir /tmp/zig-global-build-main4` (pass)
- `zig build test --build-file /workspace/build.zig --cache-dir /tmp/zig-local-test-main2 --global-cache-dir /tmp/zig-global-test-main2` (pass)

CLI smoke tests (pass):
- Boolean expression with biome+structure.
- Ranked mode with JSONL output.
- Anchor mode with CSV output.
- Checkpoint write + resume behavior.

Note: default workspace Zig cache sometimes throws transient `FileNotFound` for build/run artifacts. Workaround used above: isolated `--cache-dir` and `--global-cache-dir` under `/tmp`.

## Open Gap vs Requested Feature List

Still not implemented:
- `level.dat` import path.

Everything else from the requested list is implemented in `src/main.zig`.

## Suggested Next Steps (when resuming)

1. Add `--level-dat <path>`
- Parse Bedrock/Java seed from `level.dat` (likely gzipped NBT).
- Set initial seed/start context from file where possible.
- Add clear error if parse fails.

2. Add focused tests for new parser/logic
- Expression parser unit tests (`--where` grammar and id resolution).
- Ranking comparator/top-k retention behavior.
- Checkpoint read/write roundtrip.

3. Final cleanup before commit
- Review `git diff` for unrelated perf files already in-progress.
- Decide commit boundary:
  - CLI feature commit (`src/main.zig`, `README.md`, maybe `Justfile`).
  - Perf/instrumentation commit separately.

## Current Working Tree (at pause)

From `git status --short`:
- `M Justfile`
- `M README.md`
- `M scripts/diff_fuzz.sh`
- `M src/bedrock.zig`
- `M src/gen_parity_vectors.zig`
- `M src/main.zig`
- `M tests/golden/parity_vectors.json`
- `?? docs/`
- `?? scripts/bench_parity.sh`

