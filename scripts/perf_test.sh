#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ "${SEED_FINDER_PERF_TEST:-0}" != "1" ]; then
    echo "perf-test skipped (set SEED_FINDER_PERF_TEST=1 to enable)."
    exit 0
fi

echo "Running opt-in perf tests (SEED_FINDER_PERF_TEST=1)..."
mkdir -p "$ROOT_DIR/.zig-cache" "$ROOT_DIR/.zig-global-cache"
SEED_FINDER_PERF_TEST=1 \
ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
zig build test --build-file "$ROOT_DIR/build.zig" -Doptimize=ReleaseFast

echo "Running parity benchmark and recording into tmp/perf..."
"$ROOT_DIR/scripts/bench_parity.sh"
