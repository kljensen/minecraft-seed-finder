#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PERF_ROOT="$ROOT_DIR/tmp/perf"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$PERF_ROOT/$RUN_ID"
OUT_JSONL="$RUN_DIR/shadow_perf.jsonl"

mkdir -p "$RUN_DIR"
mkdir -p "$ROOT_DIR/.zig-cache" "$ROOT_DIR/.zig-global-cache"

START_SEED="${SHADOW_BENCH_START_SEED:-0}"
MAX_SEED="${SHADOW_BENCH_MAX_SEED:-50000}"
COUNT="${SHADOW_BENCH_COUNT:-20}"
VERSION="${SHADOW_BENCH_VERSION:-1.21.1}"
FORMAT="${SHADOW_BENCH_FORMAT:-jsonl}"
BIOME_REQ="${SHADOW_BENCH_BIOME_REQ:-plains:4@200}"
STRUCT_REQ="${SHADOW_BENCH_STRUCT_REQ:-village:550}"
WHERE_EXPR="${SHADOW_BENCH_WHERE_EXPR:-b1 and s1}"

now_ns() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import time; print(time.time_ns())'
        return
    fi
    if command -v perl >/dev/null 2>&1; then
        perl -MTime::HiRes=time -e 'printf("%.0f\n", time() * 1000000000)'
        return
    fi
    echo $(( $(date +%s) * 1000000000 ))
}

run_case() {
    label="$1"
    shift

    start_ns="$(now_ns)"
    set +e
    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build run --build-file "$ROOT_DIR/build.zig" -- "$@" >/dev/null 2>&1
    rc=$?
    set -e
    end_ns="$(now_ns)"

    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
    echo "$label elapsed_ms=$elapsed_ms rc=$rc"
    printf '{"run_id":"%s","label":"%s","elapsed_ms":%d,"rc":%d,"start_seed":%d,"max_seed":%d,"count":%d}\n' \
        "$RUN_ID" "$label" "$elapsed_ms" "$rc" "$START_SEED" "$MAX_SEED" "$COUNT" >> "$OUT_JSONL"
}

# Warm up build/cache outside measured cases so baseline and experimental labels are comparable.
ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
zig build run --build-file "$ROOT_DIR/build.zig" -- \
    --version "$VERSION" \
    --start-seed 0 \
    --max-seed 1 \
    --count 1 \
    --format "$FORMAT" \
    --require-biome "$BIOME_REQ" \
    --require-structure "$STRUCT_REQ" \
    --where "$WHERE_EXPR" >/dev/null 2>&1

run_case baseline \
    --version "$VERSION" \
    --start-seed "$START_SEED" \
    --max-seed "$MAX_SEED" \
    --count "$COUNT" \
    --format "$FORMAT" \
    --require-biome "$BIOME_REQ" \
    --require-structure "$STRUCT_REQ" \
    --where "$WHERE_EXPR"

run_case native_shadow \
    --version "$VERSION" \
    --start-seed "$START_SEED" \
    --max-seed "$MAX_SEED" \
    --count "$COUNT" \
    --format "$FORMAT" \
    --require-biome "$BIOME_REQ" \
    --require-structure "$STRUCT_REQ" \
    --where "$WHERE_EXPR" \
    --experimental-native-shadow

run_case native_compare_only \
    --version "$VERSION" \
    --start-seed "$START_SEED" \
    --max-seed "$MAX_SEED" \
    --count "$COUNT" \
    --format "$FORMAT" \
    --require-biome "$BIOME_REQ" \
    --require-structure "$STRUCT_REQ" \
    --where "$WHERE_EXPR" \
    --experimental-native-backend-compare-only

echo "run_dir: $RUN_DIR"
echo "result: $OUT_JSONL"
