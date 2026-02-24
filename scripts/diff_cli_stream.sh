#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ROUNDS="${1:-6}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
PERF_DIR="$ROOT_DIR/tmp/perf"
OUT_DIR="$PERF_DIR/cli_diff_$RUN_ID"
HISTORY_JSONL="$PERF_DIR/conformance_history.jsonl"
RUN_JSONL="$OUT_DIR/results.jsonl"

mkdir -p "$OUT_DIR"
mkdir -p "$ROOT_DIR/.zig-cache" "$ROOT_DIR/.zig-global-cache"

rand_u32() {
    od -An -N4 -tu4 /dev/urandom | tr -d ' \n'
}

pick_range() {
    min="$1"
    max="$2"
    r="$(rand_u32)"
    echo $((min + (r % (max - min + 1))))
}

has_c_reference_sources() {
    [ -f "$ROOT_DIR/lib/cubiomes/noise.c" ] && [ -f "$ROOT_DIR/lib/bedrockref/Bfinders.c" ]
}

run_strict_c_reference() {
REF_DIR="$(mktemp -d /tmp/seed-c-ref.XXXXXX)"
cleanup() {
    rm -rf "$REF_DIR"
}
trap cleanup EXIT INT TERM

cp -R "$ROOT_DIR/." "$REF_DIR/"

cat > "$REF_DIR/src/c_bindings.zig" <<'EOF'
pub const c = @cImport({
    @cInclude("biomes.h");
    @cInclude("generator.h");
    @cInclude("finders.h");
    @cInclude("Bfinders.h");
});
pub usingnamespace c;
EOF

cat > "$REF_DIR/build.zig" <<'EOF'
const std = @import("std");

const cubiomes_sources = [_][]const u8{
    "lib/cubiomes/noise.c",
    "lib/cubiomes/biomes.c",
    "lib/cubiomes/layers.c",
    "lib/cubiomes/biomenoise.c",
    "lib/cubiomes/generator.c",
    "lib/cubiomes/finders.c",
    "lib/cubiomes/util.c",
    "lib/cubiomes/quadbase.c",
    "lib/bedrockref/Bfinders.c",
};

fn linkCubiomes(step: *std.Build.Step.Compile, b: *std.Build) void {
    step.linkLibC();
    step.addIncludePath(b.path("lib/cubiomes"));
    step.addIncludePath(b.path("lib/bedrockref"));
    step.addIncludePath(b.path("lib"));
    step.addCSourceFiles(.{
        .files = &cubiomes_sources,
        .flags = &.{ "-O3", "-fwrapv" },
    });
    step.linkSystemLibrary("m");
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "seed-finder",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkCubiomes(exe, b);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the seed finder");
    run_step.dependOn(&run_cmd.step);

    const gen_vectors = b.addExecutable(.{
        .name = "gen-parity-vectors",
        .root_source_file = b.path("src/gen_parity_vectors.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkCubiomes(gen_vectors, b);
    const run_gen_vectors = b.addRunArtifact(gen_vectors);
    const gen_step = b.step("gen-parity-vectors", "Generate parity golden vectors");
    gen_step.dependOn(&run_gen_vectors.step);
}
EOF

run_cli_case() {
    label="$1"
    shift
    zig_out="$OUT_DIR/zig_${label}.out"
    ref_out="$OUT_DIR/ref_${label}.out"
    zig_rc=0
    ref_rc=0

    set +e
    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build run --build-file "$ROOT_DIR/build.zig" -- "$@" >"$zig_out" 2>&1
    zig_rc=$?

    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build run --build-file "$REF_DIR/build.zig" -- "$@" >"$ref_out" 2>&1
    ref_rc=$?
    set -e

    if [ "$zig_rc" -ne "$ref_rc" ]; then
        echo "Exit code mismatch for case $label: zig=$zig_rc ref=$ref_rc"
        exit 1
    fi
    if ! cmp -s "$zig_out" "$ref_out"; then
        echo "Output mismatch for case $label"
        exit 1
    fi
}

round=1
while [ "$round" -le "$ROUNDS" ]; do
    seed_count="$(pick_range 20 80)"
    biome_samples="$(pick_range 48 256)"
    region_radius="$(pick_range 1 4)"
    biome_span="$(pick_range 1024 12288)"
    seed_salt="$(rand_u32)"

    ref_vec="$OUT_DIR/ref_vectors.$round.json"
    zig_vec="$OUT_DIR/zig_vectors.$round.json"

    PARITY_SEED_COUNT="$seed_count" \
    PARITY_BIOME_SAMPLES="$biome_samples" \
    PARITY_REGION_RADIUS="$region_radius" \
    PARITY_BIOME_SPAN="$biome_span" \
    PARITY_SEED_SALT="$seed_salt" \
    PARITY_PRETTY=0 \
    PARITY_OUTPUT_PATH="$ref_vec" \
    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build gen-parity-vectors --build-file "$REF_DIR/build.zig" -Doptimize=ReleaseFast >/dev/null

    PARITY_SEED_COUNT="$seed_count" \
    PARITY_BIOME_SAMPLES="$biome_samples" \
    PARITY_REGION_RADIUS="$region_radius" \
    PARITY_BIOME_SPAN="$biome_span" \
    PARITY_SEED_SALT="$seed_salt" \
    PARITY_PRETTY=0 \
    PARITY_OUTPUT_PATH="$zig_vec" \
    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build gen-parity-vectors --build-file "$ROOT_DIR/build.zig" -Doptimize=ReleaseFast >/dev/null

    if ! cmp -s "$ref_vec" "$zig_vec"; then
        echo "Vector mismatch in round $round"
        exit 1
    fi

    start_seed="$(pick_range 0 300000)"
    span="$(pick_range 2500 25000)"
    max_seed=$((start_seed + span))
    start_seed_b="$(pick_range 0 250000)"
    span_b="$(pick_range 2000 20000)"
    max_seed_b=$((start_seed_b + span_b))
    anchor_x="$(pick_range -4096 4096)"
    anchor_z="$(pick_range -4096 4096)"

    run_cli_case "r${round}_stream" \
        --version 1.21.1 \
        --start-seed "$start_seed" \
        --max-seed "$max_seed" \
        --count 5 \
        --format jsonl \
        --require-biome "plains:4@200" \
        --require-structure "village:550" \
        --where "b1 and s1"

    run_cli_case "r${round}_ranked" \
        --version 1.21.1 \
        --start-seed "$start_seed_b" \
        --max-seed "$max_seed_b" \
        --count 10 \
        --ranked \
        --top-k 6 \
        --format jsonl \
        --require-biome "forest:3@170" \
        --require-structure "outpost:900" \
        --where "b1 or s1"

    run_cli_case "r${round}_anchored" \
        --version 1.21.1 \
        --start-seed "$start_seed_b" \
        --max-seed "$max_seed_b" \
        --count 5 \
        --format text \
        --anchor "${anchor_x}:${anchor_z}" \
        --require-biome "flower forest:2@140" \
        --require-structure "village:600" \
        --where "b1 and s1"

    printf "%02d/%02d vectors+cli parity ok seeds=%d biomes=%d radius=%d span=%d salt=%d\n" \
        "$round" "$ROUNDS" "$seed_count" "$biome_samples" "$region_radius" "$biome_span" "$seed_salt"

    printf '{"run_id":"%s","round":%d,"seed_count":%d,"biome_samples":%d,"region_radius":%d,"biome_span":%d,"seed_salt":%d,"cases":["stream","ranked","anchored"],"vector_match":true,"stream_match":true}\n' \
        "$RUN_ID" "$round" "$seed_count" "$biome_samples" "$region_radius" "$biome_span" "$seed_salt" >> "$RUN_JSONL"

    round=$((round + 1))
done

cat "$RUN_JSONL" >> "$HISTORY_JSONL"
echo "All $ROUNDS strict diff rounds passed."
echo "run_dir: $OUT_DIR"
echo "history: $HISTORY_JSONL"
}

run_golden_reference_mode() {
    tmp_vec="$OUT_DIR/vectors.golden.check.json"
    tmp_stream="$OUT_DIR/stream.golden.check.out"
    tmp_ranked="$OUT_DIR/ranked.golden.check.out"
    tmp_csv="$OUT_DIR/csv.golden.check.out"
    seed_count=64
    biome_samples=128

    PARITY_SEED_COUNT="$seed_count" \
    PARITY_BIOME_SAMPLES="$biome_samples" \
    PARITY_REGION_RADIUS=2 \
    PARITY_BIOME_SPAN=4096 \
    PARITY_SEED_SALT=0 \
    PARITY_PRETTY=1 \
    PARITY_OUTPUT_PATH="$tmp_vec" \
    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build gen-parity-vectors --build-file "$ROOT_DIR/build.zig" -Doptimize=ReleaseFast >/dev/null

    if ! cmp -s "$tmp_vec" "$ROOT_DIR/tests/golden/parity_vectors.json"; then
        echo "Golden vector mismatch (reference corpus drift)"
        exit 1
    fi

    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build run --build-file "$ROOT_DIR/build.zig" -- \
        --version 1.21.1 \
        --start-seed 0 \
        --max-seed 500 \
        --count 8 \
        --format text \
        --require-biome "plains:4@200" \
        --require-structure "village:500" \
        --where "b1 and s1" >"$tmp_stream" 2>&1

    if ! cmp -s "$tmp_stream" "$ROOT_DIR/tests/golden/search_stream_spawn_anchor.txt"; then
        echo "Golden stream mismatch (candidate/summary drift)"
        exit 1
    fi

    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build run --build-file "$ROOT_DIR/build.zig" -- \
        --version 1.21.1 \
        --start-seed 0 \
        --max-seed 500 \
        --count 8 \
        --ranked \
        --top-k 6 \
        --format jsonl \
        --require-biome "plains:4@200" \
        --require-structure "village:500" \
        --where "b1 and s1" >"$tmp_ranked" 2>&1

    if ! cmp -s "$tmp_ranked" "$ROOT_DIR/tests/golden/search_ranked_jsonl.txt"; then
        echo "Golden ranked stream mismatch (candidate/summary drift)"
        exit 1
    fi

    ZIG_LOCAL_CACHE_DIR="$ROOT_DIR/.zig-cache" \
    ZIG_GLOBAL_CACHE_DIR="$ROOT_DIR/.zig-global-cache" \
    zig build run --build-file "$ROOT_DIR/build.zig" -- \
        --version 1.21.1 \
        --start-seed 0 \
        --max-seed 500 \
        --count 8 \
        --format csv \
        --require-biome "plains:4@200" \
        --require-structure "village:500" \
        --where "b1 and s1" >"$tmp_csv" 2>&1

    if ! cmp -s "$tmp_csv" "$ROOT_DIR/tests/golden/search_stream_spawn_anchor.csv"; then
        echo "Golden csv stream mismatch (candidate/summary drift)"
        exit 1
    fi

    printf '{"run_id":"%s","round":1,"reference_mode":"golden","seed_count":%d,"biome_samples":%d,"vector_match":true,"stream_match":true,"ranked_stream_match":true,"csv_stream_match":true}\n' \
        "$RUN_ID" "$seed_count" "$biome_samples" > "$RUN_JSONL"
    cat "$RUN_JSONL" >> "$HISTORY_JSONL"
    echo "Golden-reference conformance checks passed."
    echo "run_dir: $OUT_DIR"
    echo "history: $HISTORY_JSONL"
}

if has_c_reference_sources; then
    run_strict_c_reference
else
    run_golden_reference_mode
fi
