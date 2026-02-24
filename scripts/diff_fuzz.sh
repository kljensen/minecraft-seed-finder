#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ROUNDS="${1:-8}"
REF_REV="${PARITY_REF_REV:-HEAD~1}"

rand_u32() {
    od -An -N4 -tu4 /dev/urandom | tr -d ' \n'
}

pick_range() {
    min="$1"
    max="$2"
    r="$(rand_u32)"
    echo $((min + (r % (max - min + 1))))
}

REF_DIR="$(mktemp -d /tmp/seed-ref.XXXXXX)"
OUT_DIR="$(mktemp -d /tmp/seed-diff.XXXXXX)"

echo "Using reference workspace: $REF_DIR"
echo "Using output workspace:    $OUT_DIR"

(
    cd "$ROOT_DIR"
    git archive "$REF_REV" | tar -x -C "$REF_DIR"
)

cp "$ROOT_DIR/src/gen_parity_vectors.zig" "$REF_DIR/src/gen_parity_vectors.zig"
cp "$ROOT_DIR/src/bedrock.zig" "$REF_DIR/src/bedrock.zig"

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

round=1
while [ "$round" -le "$ROUNDS" ]; do
    seed_count="$(pick_range 24 96)"
    biome_samples="$(pick_range 48 320)"
    region_radius="$(pick_range 1 6)"
    biome_span="$(pick_range 1024 16384)"
    seed_salt="$(rand_u32)"

    ref_json="$OUT_DIR/ref.$round.json"
    zig_json="$OUT_DIR/zig.$round.json"

    echo "Round $round/$ROUNDS: seeds=$seed_count biomes=$biome_samples radius=$region_radius span=$biome_span salt=$seed_salt"

    PARITY_SEED_COUNT="$seed_count" \
    PARITY_BIOME_SAMPLES="$biome_samples" \
    PARITY_REGION_RADIUS="$region_radius" \
    PARITY_BIOME_SPAN="$biome_span" \
    PARITY_SEED_SALT="$seed_salt" \
    PARITY_PRETTY=0 \
    PARITY_OUTPUT_PATH="$ref_json" \
    zig build gen-parity-vectors --build-file "$REF_DIR/build.zig" >/dev/null

    PARITY_SEED_COUNT="$seed_count" \
    PARITY_BIOME_SAMPLES="$biome_samples" \
    PARITY_REGION_RADIUS="$region_radius" \
    PARITY_BIOME_SPAN="$biome_span" \
    PARITY_SEED_SALT="$seed_salt" \
    PARITY_PRETTY=0 \
    PARITY_OUTPUT_PATH="$zig_json" \
    zig build gen-parity-vectors --build-file "$ROOT_DIR/build.zig" >/dev/null

    if ! cmp -s "$ref_json" "$zig_json"; then
        echo "Mismatch detected in round $round"
        sha256sum "$ref_json" "$zig_json"
        exit 1
    fi

    round=$((round + 1))
done

echo "All $ROUNDS differential fuzz rounds passed."
