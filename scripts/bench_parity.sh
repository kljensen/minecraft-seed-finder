#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PERF_ROOT="$ROOT_DIR/tmp/perf"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$PERF_ROOT/$RUN_ID"
OUT_DIR="$RUN_DIR/artifacts"
RUN_JSONL="$RUN_DIR/results.jsonl"
HISTORY_JSONL="$PERF_ROOT/history.jsonl"

mkdir -p "$OUT_DIR"
mkdir -p "$ROOT_DIR/.zig-cache" "$ROOT_DIR/.zig-global-cache"

SEEDS="${PARITY_BENCH_SEEDS:-96}"
BIOMES="${PARITY_BENCH_BIOMES:-256}"
RADIUS="${PARITY_BENCH_RADIUS:-4}"
SPAN="${PARITY_BENCH_SPAN:-8192}"
SALT="${PARITY_BENCH_SALT:-42424242}"
OPT="${PARITY_BENCH_OPT:-ReleaseFast}"

threads_auto() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
        return
    fi
    getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4
}

THREADS="$(threads_auto)"
GIT_REV="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
HOST_INFO="$(uname -srm 2>/dev/null || echo unknown)"

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
    threads="$2"
    simd="$3"
    out="$OUT_DIR/$label.json"

    start_ns="$(now_ns)"
    PARITY_SEED_COUNT="$SEEDS" \
    PARITY_BIOME_SAMPLES="$BIOMES" \
    PARITY_REGION_RADIUS="$RADIUS" \
    PARITY_BIOME_SPAN="$SPAN" \
    PARITY_SEED_SALT="$SALT" \
    PARITY_PRETTY=0 \
    PARITY_THREADS="$threads" \
    PARITY_SIMD="$simd" \
    PARITY_OUTPUT_PATH="$out" \
    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build gen-parity-vectors --build-file "$ROOT_DIR/build.zig" -Doptimize="$OPT" >/dev/null
    end_ns="$(now_ns)"

    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
    total_vectors="$(jq '(.spawns|length)+(.biomes|length)+(.structures|length)' "$out")"
    vps=$(( (total_vectors * 1000) / (elapsed_ms == 0 ? 1 : elapsed_ms) ))

    echo "$label elapsed_ms=$elapsed_ms total_vectors=$total_vectors vectors_per_sec=$vps threads=$threads simd=$simd"

    jq -nc \
      --arg run_id "$RUN_ID" \
      --arg git_rev "$GIT_REV" \
      --arg host "$HOST_INFO" \
      --arg label "$label" \
      --arg optimize "$OPT" \
      --argjson seeds "$SEEDS" \
      --argjson biomes "$BIOMES" \
      --argjson radius "$RADIUS" \
      --argjson span "$SPAN" \
      --argjson salt "$SALT" \
      --argjson threads "$threads" \
      --argjson simd "$simd" \
      --argjson elapsed_ms "$elapsed_ms" \
      --argjson total_vectors "$total_vectors" \
      --argjson vectors_per_sec "$vps" \
      '{
        run_id: $run_id,
        git_rev: $git_rev,
        host: $host,
        label: $label,
        optimize: $optimize,
        seeds: $seeds,
        biomes: $biomes,
        radius: $radius,
        span: $span,
        salt: $salt,
        threads: $threads,
        simd: $simd,
        elapsed_ms: $elapsed_ms,
        total_vectors: $total_vectors,
        vectors_per_sec: $vectors_per_sec
      }' >> "$RUN_JSONL"
}

echo "Parity benchmark params: seeds=$SEEDS biomes=$BIOMES radius=$RADIUS span=$SPAN salt=$SALT optimize=$OPT"
# Warm up build/cache outside measured cases so label timings are comparable.
PARITY_SEED_COUNT=1 \
PARITY_BIOME_SAMPLES=1 \
PARITY_REGION_RADIUS=0 \
PARITY_BIOME_SPAN=16 \
PARITY_SEED_SALT="$SALT" \
PARITY_PRETTY=0 \
PARITY_THREADS=1 \
PARITY_SIMD=0 \
PARITY_OUTPUT_PATH="$OUT_DIR/_warmup.json" \
ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
zig build gen-parity-vectors --build-file "$ROOT_DIR/build.zig" -Doptimize="$OPT" >/dev/null
run_case baseline 1 0
run_case simd_1t 1 1
run_case parallel "${THREADS}" 0
run_case parallel_simd "${THREADS}" 1

cat "$RUN_JSONL" >> "$HISTORY_JSONL"
echo "Recorded benchmark run:"
echo "  run_dir: $RUN_DIR"
echo "  history: $HISTORY_JSONL"
