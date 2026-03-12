#!/bin/sh
# bench_vs_c_ref.sh -- Reproduce the README vs-C performance benchmarks.
#
# Builds bench/c_reference.c (C baseline: getBiomeAt per point, no climate
# early-exit, biome-first ordering) and the Zig seed-finder, then runs the
# three README queries, verifies seed agreement, and reports timing.
#
# Usage:
#   sh scripts/bench_vs_c_ref.sh
#
# Output: timing table + seed-agreement verdict.
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

ZIG="zig"
CC="${CC:-cc}"
OPT="${BENCH_OPT:-ReleaseFast}"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="tmp/perf/bench_vs_c_ref_${RUN_ID}"
mkdir -p "$OUT_DIR"
mkdir -p .zig-cache .zig-global-cache

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

# ─── Build ───────────────────────────────────────────────────────────────────

echo "Building C reference..."
"$CC" -O3 -fwrapv \
    -o "$OUT_DIR/c_reference" \
    bench/c_reference.c \
    lib/cubiomes/noise.c lib/cubiomes/biomes.c lib/cubiomes/layers.c \
    lib/cubiomes/biomenoise.c lib/cubiomes/generator.c \
    lib/cubiomes/finders.c lib/cubiomes/util.c lib/cubiomes/quadbase.c \
    -Ilib/cubiomes -lm
C_REF="$OUT_DIR/c_reference"

echo "Building Zig seed-finder (-Doptimize=$OPT)..."
ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
"$ZIG" build -Doptimize="$OPT" \
    --build-file "$ROOT_DIR/build.zig" >/dev/null
ZIG_BIN="./zig-out/bin/seed-finder"

echo ""
echo "machine: $(uname -srm)"
echo "compiler: $(cc --version 2>&1 | head -1)"
echo "zig: $("$ZIG" version)"
echo ""

# ─── Benchmark helper ────────────────────────────────────────────────────────

run_case() {
    label="$1"
    description="$2"
    zig_args="$3"
    c_args="$4"
    expect_seeds="$5"   # expected seed list (space-separated), empty = skip check

    echo "--- $label: $description ---"

    # Zig
    t0="$(now_ns)"
    zig_seeds=$("$ZIG_BIN" $zig_args --format text 2>&1 \
        | grep '^seed=' | sed 's/seed=\([0-9]*\) .*/\1/' | tr '\n' ' ' | sed 's/ $//')
    zig_elapsed_ms=$(( ($(now_ns) - t0) / 1000000 ))

    # C reference
    t0="$(now_ns)"
    c_seeds=$("$C_REF" $c_args 2>/dev/null \
        | grep '^seed=' | sed 's/seed=\([0-9]*\)$/\1/' | tr '\n' ' ' | sed 's/ $//')
    c_elapsed_ms=$(( ($(now_ns) - t0) / 1000000 ))

    zig_s=$(echo "scale=1; $zig_elapsed_ms / 1000" | bc)
    c_s=$(echo "scale=1; $c_elapsed_ms / 1000" | bc)
    speedup=$(python3 -c "print(f'{$c_elapsed_ms/$zig_elapsed_ms:.2f}x')")

    # Seed agreement
    agree="MISMATCH"
    if [ "$zig_seeds" = "$c_seeds" ]; then
        agree="AGREE"
    fi

    if [ -n "$expect_seeds" ] && [ "$zig_seeds" != "$expect_seeds" ]; then
        echo "  WARNING: Zig seeds differ from expected!"
        echo "    expected: $expect_seeds"
        echo "    actual:   $zig_seeds"
    fi

    echo "  seed-finder:  ${zig_s}s"
    echo "  C reference:  ${c_s}s"
    echo "  speedup:      ${speedup}"
    echo "  seeds:        ${agree}  ($zig_seeds)"
    echo ""

    printf '{"label":"%s","zig_ms":%d,"c_ms":%d,"seeds_agree":%s}\n' \
        "$label" "$zig_elapsed_ms" "$c_elapsed_ms" \
        "$([ "$agree" = "AGREE" ] && echo true || echo false)" \
        >> "$OUT_DIR/results.jsonl"
}

# ─── Queries ─────────────────────────────────────────────────────────────────
# All queries: --edition java, --anchor 0:0, --version 1.21.1, single-threaded
# "500 seeds" = scan seeds 0..499 (--max-seed 499)

BASE_ZIG="--edition java --anchor 0:0 --version 1.21.1 --count 1000"
BASE_C="--anchor 0:0 --version 1.21.1 --count 1000"

echo "=== README benchmark queries ==="
echo ""

run_case "q1_cherry_grove_2struct" \
    "cherry_grove:1@300 + village:400 + outpost:800  (first 5 matches)" \
    "--edition java --anchor 0:0 --version 1.21.1 --count 5 --start-seed 0 --max-seed 50000000 --require-biome 'cherry_grove:1@300' --require-structure 'village:400' --require-structure 'outpost:800'" \
    "--anchor 0:0 --version 1.21.1 --count 5 --max-seed 50000000 --require-biome 'cherry_grove:1@300' --require-structure 'village:400' --require-structure 'outpost:800'" \
    "23 322 383 395 447"

run_case "q2_ice_spikes_2struct" \
    "ice_spikes:1@500 + village:400 + outpost:600  (first 5 matches)" \
    "--edition java --anchor 0:0 --version 1.21.1 --count 5 --start-seed 0 --max-seed 50000000 --require-biome 'ice_spikes:1@500' --require-structure 'village:400' --require-structure 'outpost:600'" \
    "--anchor 0:0 --version 1.21.1 --count 5 --max-seed 50000000 --require-biome 'ice_spikes:1@500' --require-structure 'village:400' --require-structure 'outpost:600'" \
    "24 282 383 661 808"

echo "Results written to: $OUT_DIR/results.jsonl"
