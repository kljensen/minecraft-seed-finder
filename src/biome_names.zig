const std = @import("std");
const c = @import("c_bindings.zig");

pub const SupportedBiome = struct {
    name: []const u8,
    biome_id: i32,
};

pub const supported_biomes = [_]SupportedBiome{
    .{ .name = "flower_forest", .biome_id = c.flower_forest },
    .{ .name = "forest", .biome_id = c.forest },
    .{ .name = "extreme_hills", .biome_id = c.mountains },
    .{ .name = "mountains", .biome_id = c.mountains },
    .{ .name = "windswept_hills", .biome_id = c.mountains },
    .{ .name = "plains", .biome_id = c.plains },
    .{ .name = "desert", .biome_id = c.desert },
    .{ .name = "jungle", .biome_id = c.jungle },
    .{ .name = "savanna", .biome_id = c.savanna },
    .{ .name = "swamp", .biome_id = c.swamp },
    .{ .name = "taiga", .biome_id = c.taiga },
    .{ .name = "meadow", .biome_id = c.meadow },
    .{ .name = "stony_peaks", .biome_id = c.stony_peaks },
    .{ .name = "jagged_peaks", .biome_id = c.jagged_peaks },
    .{ .name = "frozen_peaks", .biome_id = c.frozen_peaks },
    .{ .name = "cherry_grove", .biome_id = c.cherry_grove },
    .{ .name = "mangrove_swamp", .biome_id = c.mangrove_swamp },
    .{ .name = "deep_dark", .biome_id = c.deep_dark },
};

fn normalizeName(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    var out = try allocator.alloc(u8, raw.len);
    for (raw, 0..) |ch, i| {
        out[i] = switch (ch) {
            'A'...'Z' => ch + 32,
            ' ', '-', '.' => '_',
            else => ch,
        };
    }
    return out;
}

pub fn biomeIdFromName(allocator: std.mem.Allocator, name: []const u8) !?i32 {
    const n = try normalizeName(allocator, name);
    defer allocator.free(n);

    for (supported_biomes) |entry| {
        if (std.mem.eql(u8, n, entry.name)) return entry.biome_id;
    }
    return null;
}
