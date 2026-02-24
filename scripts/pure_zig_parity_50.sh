#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUNS="${1:-50}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="tmp/perf/$RUN_ID"
OUT_JSONL="tmp/perf/pure_zig_parity_50.jsonl"

mkdir -p "$OUT_DIR"
mkdir -p tmp/perf
mkdir -p "$ROOT_DIR/.zig-cache" "$ROOT_DIR/.zig-global-cache"

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

rand_u32() {
    od -An -N4 -tu4 /dev/urandom | tr -d ' \n'
}

iter=1
while [ "$iter" -le "$RUNS" ]; do
    r="$(rand_u32)"
    start_seed=$((r % 300000))
    width=$((2000 + (r % 18000)))
    max_seed=$((start_seed + width))
    out_file="$OUT_DIR/iter_${iter}.log"

    start_ns="$(now_ns)"
    set +e
    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build run --build-file "$ROOT_DIR/build.zig" -Doptimize=ReleaseFast -- \
        --version 1.21.1 \
        --start-seed "$start_seed" \
        --max-seed "$max_seed" \
        --count 2 \
        --require-biome "plains:4@200" \
        --require-structure "village:500" \
        --where "b1 and s1" \
        --experimental-native-backend-compare-only \
        --experimental-native-backend-strict >"$out_file" 2>&1
    rc=$?
    set -e
    end_ns="$(now_ns)"
    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))

    native_line="$(grep 'native-backend:' "$out_file" | tail -n 1 || true)"
    compared="$(echo "$native_line" | sed -n 's/.*compared=\([0-9][0-9]*\).*/\1/p')"
    mismatch="$(echo "$native_line" | sed -n 's/.*mismatch=\([0-9][0-9]*\).*/\1/p')"
    [ -n "$compared" ] || compared=0
    [ -n "$mismatch" ] || mismatch=0

    printf "%02d/%02d start=%d max=%d compared=%d mismatch=%d elapsed_ms=%d rc=%d\n" \
        "$iter" "$RUNS" "$start_seed" "$max_seed" "$compared" "$mismatch" "$elapsed_ms" "$rc"

    printf '{"run_id":"%s","iteration":%d,"runs":%d,"start_seed":%d,"max_seed":%d,"compared":%d,"mismatch":%d,"elapsed_ms":%d,"rc":%d}\n' \
        "$RUN_ID" "$iter" "$RUNS" "$start_seed" "$max_seed" "$compared" "$mismatch" "$elapsed_ms" "$rc" >> "$OUT_JSONL"

    if [ "$rc" -ne 0 ]; then
        echo "Failure on iteration $iter. Log: $out_file"
        exit "$rc"
    fi

    iter=$((iter + 1))
done

echo "All $RUNS iterations passed."
echo "Logs: $OUT_DIR"
echo "History: $OUT_JSONL"
