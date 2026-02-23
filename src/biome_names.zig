const std = @import("std");
const c = @import("c_bindings.zig");

pub const SupportedBiome = struct {
    name: []const u8,
    biome_id: i32,
};

pub const supported_biomes = [_]SupportedBiome{
    // Forests
    .{ .name = "flower_forest", .biome_id = c.flower_forest },
    .{ .name = "forest", .biome_id = c.forest },
    .{ .name = "birch_forest", .biome_id = c.birch_forest },
    .{ .name = "dark_forest", .biome_id = c.dark_forest },
    .{ .name = "old_growth_birch_forest", .biome_id = c.old_growth_birch_forest },
    .{ .name = "old_growth_pine_taiga", .biome_id = c.old_growth_pine_taiga },
    .{ .name = "old_growth_spruce_taiga", .biome_id = c.old_growth_spruce_taiga },
    // Mountains
    .{ .name = "extreme_hills", .biome_id = c.mountains },
    .{ .name = "mountains", .biome_id = c.mountains },
    .{ .name = "windswept_hills", .biome_id = c.mountains },
    .{ .name = "meadow", .biome_id = c.meadow },
    .{ .name = "stony_peaks", .biome_id = c.stony_peaks },
    .{ .name = "jagged_peaks", .biome_id = c.jagged_peaks },
    .{ .name = "frozen_peaks", .biome_id = c.frozen_peaks },
    .{ .name = "snowy_slopes", .biome_id = c.snowy_slopes },
    .{ .name = "grove", .biome_id = c.grove },
    .{ .name = "cherry_grove", .biome_id = c.cherry_grove },
    // Plains & basic
    .{ .name = "plains", .biome_id = c.plains },
    .{ .name = "sunflower_plains", .biome_id = c.sunflower_plains },
    .{ .name = "desert", .biome_id = c.desert },
    .{ .name = "savanna", .biome_id = c.savanna },
    .{ .name = "savanna_plateau", .biome_id = c.savanna_plateau },
    // Jungle
    .{ .name = "jungle", .biome_id = c.jungle },
    .{ .name = "sparse_jungle", .biome_id = c.sparse_jungle },
    .{ .name = "bamboo_jungle", .biome_id = c.bamboo_jungle },
    // Swamp
    .{ .name = "swamp", .biome_id = c.swamp },
    .{ .name = "mangrove_swamp", .biome_id = c.mangrove_swamp },
    // Taiga & cold
    .{ .name = "taiga", .biome_id = c.taiga },
    .{ .name = "snowy_taiga", .biome_id = c.snowy_taiga },
    .{ .name = "snowy_plains", .biome_id = c.snowy_plains },
    .{ .name = "ice_spikes", .biome_id = c.ice_spikes },
    // Badlands
    .{ .name = "badlands", .biome_id = c.badlands },
    .{ .name = "eroded_badlands", .biome_id = c.eroded_badlands },
    .{ .name = "wooded_badlands", .biome_id = c.wooded_badlands },
    // Ocean
    .{ .name = "ocean", .biome_id = c.ocean },
    .{ .name = "deep_ocean", .biome_id = c.deep_ocean },
    .{ .name = "warm_ocean", .biome_id = c.warm_ocean },
    .{ .name = "lukewarm_ocean", .biome_id = c.lukewarm_ocean },
    .{ .name = "cold_ocean", .biome_id = c.cold_ocean },
    .{ .name = "frozen_ocean", .biome_id = c.frozen_ocean },
    .{ .name = "deep_lukewarm_ocean", .biome_id = c.deep_lukewarm_ocean },
    .{ .name = "deep_cold_ocean", .biome_id = c.deep_cold_ocean },
    .{ .name = "deep_frozen_ocean", .biome_id = c.deep_frozen_ocean },
    // Beach & river
    .{ .name = "beach", .biome_id = c.beach },
    .{ .name = "snowy_beach", .biome_id = c.snowy_beach },
    .{ .name = "stony_shore", .biome_id = c.stony_shore },
    .{ .name = "river", .biome_id = c.river },
    .{ .name = "frozen_river", .biome_id = c.frozen_river },
    // Special
    .{ .name = "mushroom_fields", .biome_id = c.mushroom_fields },
    // Cave biomes
    .{ .name = "lush_caves", .biome_id = c.lush_caves },
    .{ .name = "dripstone_caves", .biome_id = c.dripstone_caves },
    .{ .name = "deep_dark", .biome_id = c.deep_dark },
    // Nether (may not work for overworld searches)
    .{ .name = "nether_wastes", .biome_id = c.nether_wastes },
    .{ .name = "soul_sand_valley", .biome_id = c.soul_sand_valley },
    .{ .name = "crimson_forest", .biome_id = c.crimson_forest },
    .{ .name = "warped_forest", .biome_id = c.warped_forest },
    .{ .name = "basalt_deltas", .biome_id = c.basalt_deltas },
    // End
    .{ .name = "the_end", .biome_id = c.the_end },
    .{ .name = "end_highlands", .biome_id = c.end_highlands },
    .{ .name = "end_midlands", .biome_id = c.end_midlands },
    .{ .name = "small_end_islands", .biome_id = c.small_end_islands },
    .{ .name = "end_barrens", .biome_id = c.end_barrens },
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
