const std = @import("std");
const bedrock = @import("bedrock.zig");

const Vector = struct {
    seed: u64,
    version: i32,
    structure: []const u8,
    reg_x: i32,
    reg_z: i32,
    x: i32,
    z: i32,
};

test "bedrock structure positions match reference vectors" {
    const allocator = std.testing.allocator;
    const sanity = bedrock.getStructurePos(.village, 22, 8675309, 0, 0) orelse unreachable;
    try std.testing.expectEqual(@as(i32, 120), sanity.x);
    try std.testing.expectEqual(@as(i32, 248), sanity.z);

    const data = try std.fs.cwd().readFileAlloc(allocator, "tests/golden/bedrock_vectors.json", 8 * 1024 * 1024);
    defer allocator.free(data);

    const parsed = try std.json.parseFromSlice([]Vector, allocator, data, .{});
    defer parsed.deinit();

    for (parsed.value) |v| {
        const st = try bedrock.parseStructure(allocator, v.structure) orelse {
            std.debug.panic("unknown structure in vector: {s}", .{v.structure});
        };
        const pos = bedrock.getStructurePos(st, v.version, v.seed, v.reg_x, v.reg_z) orelse {
            std.debug.panic("no position for structure {s}", .{v.structure});
        };
        try std.testing.expectEqual(v.x, pos.x);
        try std.testing.expectEqual(v.z, pos.z);
    }
}
