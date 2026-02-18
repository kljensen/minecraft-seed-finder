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

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/bedrock_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkCubiomes(unit_tests, b);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_unit_tests.step);
}
