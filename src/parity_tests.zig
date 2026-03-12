// Parity tests: compare our pure-Zig cubiomes port against the actual C cubiomes library.
// Built with `zig build parity-test` which links C cubiomes and a de-exported copy
// of cubiomes_port.zig (see build.zig).
//
// The de-exported copy (cubiomes_port_noexport.zig) is identical to cubiomes_port.zig
// but with `export` linkage removed so symbols don't collide with the C library.

const std = @import("std");
const zig = @import("cubiomes_port_noexport.zig"); // our Zig port, no C export linkage
const c = @cImport({
    @cInclude("biomes.h");
    @cInclude("generator.h");
    @cInclude("finders.h");
    @cInclude("Bfinders.h");
});

// ---------- helpers ----------

fn initZigGenerator(g: *zig.Generator, mc: i32, seed: u64) void {
    zig.setupGenerator(g, mc, 0);
    zig.applySeed(g, zig.DIM_OVERWORLD, seed);
}

fn initCGenerator(g: *c.Generator, mc: i32, seed: u64) void {
    c.setupGenerator(g, mc, 0);
    c.applySeed(g, c.DIM_OVERWORLD, seed);
}

fn testSeed(i: usize, salt: u64) u64 {
    var x = @as(u64, i) *% 6364136223846793005 +% salt;
    x ^= x >> 33;
    x *%= 0xff51afd7ed558ccd;
    x ^= x >> 33;
    return x;
}

const test_structures = [_]c_int{
    c.Village,        c.Desert_Pyramid, c.Igloo,
    c.Jungle_Temple,  c.Mansion,        c.Monument,
    c.Ocean_Ruin,     c.Outpost,        c.Ruined_Portal,
    c.Shipwreck,      c.Swamp_Hut,      c.Treasure,
};

// ---------- biome parity ----------

test "biome parity: Zig getBiomeAt matches C" {
    const mc: i32 = c.MC_1_21_1;
    var mismatches: usize = 0;

    for ([_]u64{ 0, 42, 8675309, 999999 }) |seed| {
        var zg: zig.Generator = undefined;
        initZigGenerator(&zg, mc, seed);
        var cg: c.Generator = undefined;
        initCGenerator(&cg, mc, seed);

        var i: usize = 0;
        while (i < 200) : (i += 1) {
            const x = @as(i32, @intCast(i % 20)) * 64 - 640;
            const z = @as(i32, @intCast(i / 20)) * 64 - 320;
            const zig_biome = zig.getBiomeAt(&zg, 1, x, 0, z);
            const c_biome = c.getBiomeAt(&cg, 1, x, 0, z);
            if (zig_biome != c_biome) {
                std.debug.print("biome@1 mismatch: seed={d} x={d} z={d} zig={d} c={d}\n", .{ seed, x, z, zig_biome, c_biome });
                mismatches += 1;
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

// ---------- eroded_badlands climate boundary regression ----------

test "biome parity: eroded_badlands at out-of-tree-range climate (seed 55)" {
    // Regression test for the climate early-exit false-negative bug.
    //
    // At Java seed 55, block (224, 0, -328) maps to eroded_badlands in the C
    // library.  The climate noise at the corresponding voronoi sample point
    // produces T=10457, which exceeds the global T range of the 1.21.1 biome
    // tree (max T=10000 in any leaf).  The old code rejected this point via the
    // union-range feasibility check (T > union T-hi = 10000).  The fix clamps
    // the noise value to the global tree range before the check, so T=10457 is
    // treated as T=10000, which IS within eroded_badlands' union T-range.
    //
    // This test verifies that:
    //   1. Both Zig and C return eroded_badlands at this exact location.
    //   2. getBiomeAt agrees across seeds 0..99 for radius-400 eroded_badlands
    //      scans (catches any new false negatives in the neighbourhood).
    const mc: i32 = c.MC_1_21_1;
    const eroded_badlands_id: c_int = 165;

    // 1. Spot-check the exact failing location.
    {
        const seed: u64 = 55;
        var zg: zig.Generator = undefined;
        initZigGenerator(&zg, mc, seed);
        var cg: c.Generator = undefined;
        initCGenerator(&cg, mc, seed);
        const x: i32 = 224;
        const z: i32 = -328;
        const zig_biome = zig.getBiomeAt(&zg, 1, x, 0, z);
        const c_biome = c.getBiomeAt(&cg, 1, x, 0, z);
        if (c_biome != eroded_badlands_id) {
            std.debug.print("C library does not return eroded_badlands at seed={d} ({d},{d}); got {d}\n", .{ seed, x, z, c_biome });
            return error.TestExpectedEqual;
        }
        if (zig_biome != c_biome) {
            std.debug.print("eroded_badlands mismatch: seed={d} ({d},{d}) zig={d} c={d}\n", .{ seed, x, z, zig_biome, c_biome });
            return error.TestExpectedEqual;
        }
    }

    // 2. Scan seeds 0-99 at radius 400 and check for biome agreement.
    var mismatches: usize = 0;
    for (0..100) |si| {
        const seed: u64 = @intCast(si);
        var zg: zig.Generator = undefined;
        initZigGenerator(&zg, mc, seed);
        var cg: c.Generator = undefined;
        initCGenerator(&cg, mc, seed);
        var i: usize = 0;
        while (i < 40) : (i += 1) {
            const angle = @as(f64, @floatFromInt(i)) * (2.0 * std.math.pi / 40.0);
            const x: i32 = @intFromFloat(@round(400.0 * @cos(angle) / 4.0) * 4);
            const z: i32 = @intFromFloat(@round(400.0 * @sin(angle) / 4.0) * 4);
            const zb = zig.getBiomeAt(&zg, 1, x, 0, z);
            const cb = c.getBiomeAt(&cg, 1, x, 0, z);
            if (zb != cb) {
                std.debug.print("eroded_badlands scan mismatch: seed={d} ({d},{d}) zig={d} c={d}\n", .{ seed, x, z, zb, cb });
                mismatches += 1;
            }
        }
    }
    std.debug.print("eroded_badlands boundary: 100 seeds × 40 points matched\n", .{});
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

// ---------- spawn parity ----------

test "spawn parity: Zig getSpawn matches C" {
    const mc: i32 = c.MC_1_21_1;

    for ([_]u64{ 0, 1, 42, 100, 8675309, 123456789 }) |seed| {
        var zg: zig.Generator = undefined;
        initZigGenerator(&zg, mc, seed);
        var cg: c.Generator = undefined;
        initCGenerator(&cg, mc, seed);
        const zs = zig.getSpawn(&zg);
        const cs = c.getSpawn(&cg);
        if (zs.x != cs.x or zs.z != cs.z) {
            std.debug.print("spawn mismatch: seed={d} zig=({d},{d}) c=({d},{d})\n", .{ seed, zs.x, zs.z, cs.x, cs.z });
            return error.TestExpectedEqual;
        }
    }
}

// ---------- Java structure parity ----------

test "java structure position parity: Zig matches C" {
    const mc: i32 = c.MC_1_21_1;
    var mismatches: usize = 0;
    var total: usize = 0;

    for (test_structures) |st| {
        var si: usize = 0;
        while (si < 20) : (si += 1) {
            const seed = testSeed(si, 0);
            for ([_]i32{ -3, -2, -1, 0, 1, 2, 3 }) |rx| {
                for ([_]i32{ -3, -2, -1, 0, 1, 2, 3 }) |rz| {
                    total += 1;
                    var cp: c.Pos = undefined;
                    const co = c.getStructurePos(st, mc, seed, rx, rz, &cp) != 0;
                    var zp: zig.Pos = undefined;
                    const zo = zig.getStructurePos(st, mc, seed, rx, rz, &zp) != 0;

                    if (co != zo) {
                        mismatches += 1;
                    } else if (co and (cp.x != zp.x or cp.z != zp.z)) {
                        std.debug.print("java pos mismatch: st={d} seed={d} rx={d} rz={d} c=({d},{d}) zig=({d},{d})\n", .{ st, seed, rx, rz, cp.x, cp.z, zp.x, zp.z });
                        mismatches += 1;
                    }
                }
            }
        }
    }
    std.debug.print("java structure pos: {d}/{d} matched\n", .{ total - mismatches, total });
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

// ---------- Bedrock structure parity ----------

test "bedrock structure position parity: Zig matches C" {
    const mc: i32 = c.MC_1_21_1;
    var mismatches: usize = 0;
    var total: usize = 0;

    for (test_structures) |st| {
        var si: usize = 0;
        while (si < 20) : (si += 1) {
            const seed = testSeed(si, 0);
            for ([_]i32{ -3, -2, -1, 0, 1, 2, 3 }) |rx| {
                for ([_]i32{ -3, -2, -1, 0, 1, 2, 3 }) |rz| {
                    total += 1;
                    var cp: c.Pos = undefined;
                    const co = c.getBedrockStructurePos(st, mc, seed, rx, rz, &cp);
                    var zp: zig.Pos = undefined;
                    const zo = zig.getBedrockStructurePos(st, mc, seed, rx, rz, &zp);

                    if (co != zo) {
                        mismatches += 1;
                    } else if (co and (cp.x != zp.x or cp.z != zp.z)) {
                        std.debug.print("bedrock pos mismatch: st={d} seed={d} rx={d} rz={d} c=({d},{d}) zig=({d},{d})\n", .{ st, seed, rx, rz, cp.x, cp.z, zp.x, zp.z });
                        mismatches += 1;
                    }
                }
            }
        }
    }
    std.debug.print("bedrock structure pos: {d}/{d} matched\n", .{ total - mismatches, total });
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

// ---------- config parity ----------

test "java structure config parity" {
    for ([_]i32{ c.MC_1_18, c.MC_1_19, c.MC_1_20, c.MC_1_21_1 }) |mc| {
        for (test_structures) |st| {
            var cc: c.StructureConfig = undefined;
            const co = c.getStructureConfig(st, mc, &cc) != 0;
            var zc: zig.StructureConfig = undefined;
            const zo = zig.getStructureConfig(st, mc, &zc) != 0;
            try std.testing.expectEqual(co, zo);
            if (co) {
                try std.testing.expectEqual(cc.regionSize, zc.regionSize);
                try std.testing.expectEqual(cc.chunkRange, zc.chunkRange);
                try std.testing.expectEqual(cc.salt, zc.salt);
            }
        }
    }
}

test "bedrock structure config parity" {
    for ([_]i32{ c.MC_1_18, c.MC_1_19, c.MC_1_20, c.MC_1_21_1 }) |mc| {
        for (test_structures) |st| {
            var cc: c.StructureConfig = undefined;
            const co = c.getBedrockStructureConfig(st, mc, &cc);
            var zc: zig.StructureConfig = undefined;
            const zo = zig.getBedrockStructureConfig(st, mc, &zc);
            try std.testing.expectEqual(co, zo);
            if (co) {
                try std.testing.expectEqual(cc.regionSize, zc.regionSize);
                try std.testing.expectEqual(cc.chunkRange, zc.chunkRange);
                try std.testing.expectEqual(cc.salt, zc.salt);
            }
        }
    }
}

// ---------- viability parity ----------

test "isViableStructurePos parity: Zig matches C" {
    const mc: i32 = c.MC_1_21_1;
    var mismatches: usize = 0;
    var total: usize = 0;

    for ([_]c_int{ c.Village, c.Desert_Pyramid, c.Monument, c.Outpost }) |st| {
        var si: usize = 0;
        while (si < 10) : (si += 1) {
            const seed = testSeed(si, 42);
            var zg: zig.Generator = undefined;
            initZigGenerator(&zg, mc, seed);
            var cg: c.Generator = undefined;
            initCGenerator(&cg, mc, seed);

            for ([_]i32{ -2, -1, 0, 1, 2 }) |rx| {
                for ([_]i32{ -2, -1, 0, 1, 2 }) |rz| {
                    var cp: c.Pos = undefined;
                    if (c.getStructurePos(st, mc, seed, rx, rz, &cp) == 0) continue;

                    total += 1;
                    const cv = c.isViableStructurePos(st, &cg, cp.x, cp.z, 0);
                    const zv = zig.isViableStructurePos(st, &zg, cp.x, cp.z, 0);
                    if (cv != zv) {
                        std.debug.print("viability mismatch: st={d} seed={d} pos=({d},{d}) c={d} zig={d}\n", .{ st, seed, cp.x, cp.z, cv, zv });
                        mismatches += 1;
                    }
                }
            }
        }
    }
    std.debug.print("viability: {d}/{d} matched\n", .{ total - mismatches, total });
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

// ---------- fuzz ----------

test "fuzz: Zig vs C parity across 50 random seeds" {
    const mc: i32 = c.MC_1_21_1;
    var mismatches: usize = 0;
    var total: usize = 0;

    var si: usize = 0;
    while (si < 50) : (si += 1) {
        const seed = testSeed(si, 12345);
        var zg: zig.Generator = undefined;
        initZigGenerator(&zg, mc, seed);
        var cg: c.Generator = undefined;
        initCGenerator(&cg, mc, seed);

        // Biome at 20 points
        var bi: usize = 0;
        while (bi < 20) : (bi += 1) {
            const x = @as(i32, @intCast(bi * 137 % 40)) * 32 - 640;
            const z = @as(i32, @intCast(bi * 251 % 40)) * 32 - 640;
            total += 1;
            if (zig.getBiomeAt(&zg, 1, x, 0, z) != c.getBiomeAt(&cg, 1, x, 0, z)) mismatches += 1;
        }

        // Spawn
        {
            total += 1;
            const zs = zig.getSpawn(&zg);
            const cs = c.getSpawn(&cg);
            if (zs.x != cs.x or zs.z != cs.z) mismatches += 1;
        }

        // Java structures
        for ([_]c_int{ c.Village, c.Desert_Pyramid, c.Monument }) |st| {
            for ([_]i32{ -1, 0, 1 }) |rx| {
                for ([_]i32{ -1, 0, 1 }) |rz| {
                    total += 1;
                    var cp: c.Pos = undefined;
                    var zp: zig.Pos = undefined;
                    const co = c.getStructurePos(st, mc, seed, rx, rz, &cp) != 0;
                    const zo = zig.getStructurePos(st, mc, seed, rx, rz, &zp) != 0;
                    if (co != zo or (co and (cp.x != zp.x or cp.z != zp.z))) mismatches += 1;
                }
            }
        }

        // Bedrock structures
        for ([_]c_int{ c.Village, c.Desert_Pyramid, c.Monument }) |st| {
            for ([_]i32{ -1, 0, 1 }) |rx| {
                for ([_]i32{ -1, 0, 1 }) |rz| {
                    total += 1;
                    var cp: c.Pos = undefined;
                    var zp: zig.Pos = undefined;
                    const co = c.getBedrockStructurePos(st, mc, seed, rx, rz, &cp);
                    const zo = zig.getBedrockStructurePos(st, mc, seed, rx, rz, &zp);
                    if (co != zo or (co and (cp.x != zp.x or cp.z != zp.z))) mismatches += 1;
                }
            }
        }
    }

    std.debug.print("fuzz parity: {d}/{d} matched across 50 seeds\n", .{ total - mismatches, total });
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}
