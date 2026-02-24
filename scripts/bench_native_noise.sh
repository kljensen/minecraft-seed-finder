#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PERF_ROOT="$ROOT_DIR/tmp/perf"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$PERF_ROOT/$RUN_ID"
OUT_JSONL="$RUN_DIR/native_noise_results.jsonl"
HISTORY_JSONL="$PERF_ROOT/native_noise_history.jsonl"

mkdir -p "$RUN_DIR" "$ROOT_DIR/.zig-cache" "$ROOT_DIR/.zig-global-cache"

echo "Running native-noise opt-in perf tests..."
SEED_FINDER_PERF_TEST=1 \
ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
zig build test --build-file "$ROOT_DIR/build.zig" -Doptimize=ReleaseFast >/dev/null

if [ ! -f "$ROOT_DIR/tmp/perf/native_noise_perf.jsonl" ]; then
    echo "missing tmp/perf/native_noise_perf.jsonl"
    exit 1
fi

tail -n 8 "$ROOT_DIR/tmp/perf/native_noise_perf.jsonl" > "$OUT_JSONL"
cat "$OUT_JSONL" >> "$HISTORY_JSONL"

echo "Recorded native noise perf:"
echo "  run_file: $OUT_JSONL"
echo "  history:  $HISTORY_JSONL"
