const std = @import("std");
const c = @import("cubiomes_port.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const mc = c.MC_1_21_1;
    const radius: i32 = 500;

    var g: c.Generator = undefined;
    c.setupGenerator(&g, mc, 0);

    var sconf: c.StructureConfig = undefined;
    _ = c.getStructureConfig(c.Village, mc, &sconf);
    const region_size: i32 = @intCast(@as(i64, sconf.regionSize) * 16);
    const min_reg: i32 = @divFloor(-radius, region_size) - 1;
    const max_reg: i32 = @divFloor(radius, region_size) + 1;

    const seeds = [_]u64{ 6, 8, 116 };
    for (seeds) |seed| {
        c.applySeed(&g, c.DIM_OVERWORLD, seed);
        try stdout.print("=== Seed {d} (regionSize={d} chunkRange={d}) ===\n", .{ seed, sconf.regionSize, sconf.chunkRange });
        try stdout.print("  Region range: [{d},{d}] x [{d},{d}]\n", .{ min_reg, max_reg, min_reg, max_reg });

        var rz: i32 = min_reg;
        while (rz <= max_reg) : (rz += 1) {
            var rx: i32 = min_reg;
            while (rx <= max_reg) : (rx += 1) {
                var pos: c.Pos = undefined;
                const got = c.getStructurePos(c.Village, mc, seed, rx, rz, &pos);
                if (got == 0) {
                    try stdout.print("  reg({d},{d}): no pos\n", .{ rx, rz });
                    continue;
                }
                const d2 = @as(i64, pos.x) * pos.x + @as(i64, pos.z) * pos.z;
                const inrange: bool = d2 <= @as(i64, radius) * radius;
                var viable: i32 = 0;
                if (inrange) {
                    viable = c.isViableStructurePos(c.Village, &g, pos.x, pos.z, 0);
                }
                try stdout.print("  reg({d},{d}): pos=({d},{d}) dist2={d} inrange={any} viable={d}\n", .{ rx, rz, pos.x, pos.z, d2, inrange, viable });
            }
        }
    }
}
