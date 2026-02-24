const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const gen_vectors = b.addExecutable(.{
        .name = "gen-parity-vectors",
        .root_source_file = b.path("src/gen_parity_vectors.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_gen_vectors = b.addRunArtifact(gen_vectors);
    const gen_step = b.step("gen-parity-vectors", "Generate parity golden vectors");
    gen_step.dependOn(&run_gen_vectors.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/all_tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_unit_tests.step);

    const perf_cmd = b.addSystemCommand(&.{ "sh", "scripts/perf_test.sh" });
    const perf_step = b.step("perf-test", "Run opt-in performance tests");
    perf_step.dependOn(&perf_cmd.step);

    const native_noise_perf_cmd = b.addSystemCommand(&.{ "sh", "scripts/bench_native_noise.sh" });
    const native_noise_perf_step = b.step("perf-native-noise", "Run native noise benchmark");
    native_noise_perf_step.dependOn(&native_noise_perf_cmd.step);
}
