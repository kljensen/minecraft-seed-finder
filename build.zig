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

    // Production binary — pure Zig, no C dependencies
    const exe = b.addExecutable(.{
        .name = "seed-finder",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the seed finder");
    run_step.dependOn(&run_cmd.step);

    // Unit tests — pure Zig
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/all_tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_unit_tests.step);

    // Parity tests — links C cubiomes for differential testing against our Zig port.
    // Generate a de-exported copy of cubiomes_port.zig so symbols don't collide with C.
    const gen_noexport = b.addSystemCommand(&.{
        "python3", "scripts/gen_noexport.py",
    });

    const parity_tests = b.addTest(.{
        .root_source_file = b.path("src/parity_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkCubiomes(parity_tests, b);
    parity_tests.step.dependOn(&gen_noexport.step);

    const run_parity_tests = b.addRunArtifact(parity_tests);
    const parity_step = b.step("parity-test", "Run parity tests against C cubiomes");
    parity_step.dependOn(&run_parity_tests.step);

    const gen_vectors = b.addExecutable(.{
        .name = "gen-parity-vectors",
        .root_source_file = b.path("src/gen_parity_vectors.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_gen_vectors = b.addRunArtifact(gen_vectors);
    const gen_step = b.step("gen-parity-vectors", "Generate parity golden vectors");
    gen_step.dependOn(&run_gen_vectors.step);

    const perf_cmd = b.addSystemCommand(&.{ "sh", "scripts/perf_test.sh" });
    const perf_step = b.step("perf-test", "Run opt-in performance tests");
    perf_step.dependOn(&perf_cmd.step);

    const native_noise_perf_cmd = b.addSystemCommand(&.{ "sh", "scripts/bench_native_noise.sh" });
    const native_noise_perf_step = b.step("perf-native-noise", "Run native noise benchmark");
    native_noise_perf_step.dependOn(&native_noise_perf_cmd.step);
}
