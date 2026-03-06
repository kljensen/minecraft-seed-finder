const std = @import("std");
const c = @import("cubiomes_port.zig");
const bedrock = @import("bedrock.zig");

// Verify bedrock.getStructurePos dispatches to the correct C function for each edition
// by comparing against direct C function calls.

test "java edition dispatch matches getStructurePos directly" {
    const mc: i32 = c.MC_1_21_1;
    const seeds = [_]u64{ 0, 42, 8675309, 123456789, 999999999 };
    const structures = [_]bedrock.Structure{
        .village, .desert_pyramid, .igloo, .jungle_pyramid,
        .mansion, .monument, .ocean_ruin, .outpost,
        .ruined_portal, .shipwreck, .swamp_hut, .treasure,
    };

    for (structures) |st| {
        const st_c = st.toC();
        for (seeds) |seed| {
            for ([_]i32{ -2, -1, 0, 1, 2 }) |rx| {
                for ([_]i32{ -2, -1, 0, 1, 2 }) |rz| {
                    var c_pos: c.Pos = undefined;
                    const c_ok = c.getStructurePos(st_c, mc, seed, rx, rz, &c_pos) != 0;
                    const zig_pos = bedrock.getStructurePos(.java, st_c, mc, seed, rx, rz);

                    if (c_ok) {
                        const pos = zig_pos orelse {
                            std.debug.print("java: zig returned null but C returned pos for st={d} seed={d} rx={d} rz={d}\n", .{ st_c, seed, rx, rz });
                            return error.TestExpectedEqual;
                        };
                        try std.testing.expectEqual(c_pos.x, pos.x);
                        try std.testing.expectEqual(c_pos.z, pos.z);
                    } else {
                        if (zig_pos != null) {
                            std.debug.print("java: zig returned pos but C returned null for st={d} seed={d} rx={d} rz={d}\n", .{ st_c, seed, rx, rz });
                            return error.TestExpectedEqual;
                        }
                    }
                }
            }
        }
    }
}

test "bedrock edition dispatch matches getBedrockStructurePos directly" {
    const mc: i32 = c.MC_1_21_1;
    const seeds = [_]u64{ 0, 42, 8675309, 123456789, 999999999 };
    const structures = [_]bedrock.Structure{
        .village, .desert_pyramid, .igloo, .jungle_pyramid,
        .mansion, .monument, .ocean_ruin, .outpost,
        .ruined_portal, .shipwreck, .swamp_hut, .treasure,
    };

    for (structures) |st| {
        const st_c = st.toC();
        for (seeds) |seed| {
            for ([_]i32{ -2, -1, 0, 1, 2 }) |rx| {
                for ([_]i32{ -2, -1, 0, 1, 2 }) |rz| {
                    var c_pos: c.Pos = undefined;
                    const c_ok = c.getBedrockStructurePos(st_c, mc, seed, rx, rz, &c_pos);
                    const zig_pos = bedrock.getStructurePos(.bedrock, st_c, mc, seed, rx, rz);

                    if (c_ok) {
                        const pos = zig_pos orelse {
                            std.debug.print("bedrock: zig returned null but C returned pos for st={d} seed={d} rx={d} rz={d}\n", .{ st_c, seed, rx, rz });
                            return error.TestExpectedEqual;
                        };
                        try std.testing.expectEqual(c_pos.x, pos.x);
                        try std.testing.expectEqual(c_pos.z, pos.z);
                    } else {
                        if (zig_pos != null) {
                            std.debug.print("bedrock: zig returned pos but C returned null for st={d} seed={d} rx={d} rz={d}\n", .{ st_c, seed, rx, rz });
                            return error.TestExpectedEqual;
                        }
                    }
                }
            }
        }
    }
}

test "java and bedrock produce different structure positions" {
    const mc: i32 = c.MC_1_21_1;
    // Village is supported on both editions with different configs
    const st_c = bedrock.Structure.village.toC();
    var differ_count: usize = 0;
    var total: usize = 0;

    for ([_]u64{ 0, 1, 42, 100, 8675309 }) |seed| {
        for ([_]i32{ -1, 0, 1 }) |rx| {
            for ([_]i32{ -1, 0, 1 }) |rz| {
                const java_pos = bedrock.getStructurePos(.java, st_c, mc, seed, rx, rz);
                const bedrock_pos = bedrock.getStructurePos(.bedrock, st_c, mc, seed, rx, rz);
                total += 1;
                if (java_pos != null and bedrock_pos != null) {
                    const j = java_pos.?;
                    const b = bedrock_pos.?;
                    if (j.x != b.x or j.z != b.z) {
                        differ_count += 1;
                    }
                }
            }
        }
    }

    // Editions should produce meaningfully different positions
    // (not ALL different since some could coincide, but most should differ)
    try std.testing.expect(differ_count > total / 4);
}

test "edition config dispatch matches C functions" {
    const mc: i32 = c.MC_1_21_1;
    const structures = [_]bedrock.Structure{
        .village, .desert_pyramid, .monument, .outpost,
    };

    for (structures) |st| {
        var java_raw: c.StructureConfig = undefined;
        const java_ok = c.getStructureConfig(st.toC(), mc, &java_raw) != 0;
        const java_cfg = bedrock.getStructureConfig(.java, st, mc);

        if (java_ok) {
            const cfg = java_cfg orelse unreachable;
            try std.testing.expectEqual(java_raw.regionSize, cfg.spacing);
        }

        var bedrock_raw: c.StructureConfig = undefined;
        const bedrock_ok = c.getBedrockStructureConfig(st.toC(), mc, &bedrock_raw);
        const bedrock_cfg = bedrock.getStructureConfig(.bedrock, st, mc);

        if (bedrock_ok) {
            const cfg = bedrock_cfg orelse unreachable;
            try std.testing.expectEqual(bedrock_raw.regionSize, cfg.spacing);
        }
    }
}
