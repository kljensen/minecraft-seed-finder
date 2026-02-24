const std = @import("std");
const c = @import("cubiomes_port.zig");

pub const Pos = struct {
    x: i32,
    z: i32,
};

pub const SupportedStructure = struct {
    name: []const u8,
    structure: Structure,
};

pub const Structure = enum {
    ancient_city,
    desert_pyramid,
    igloo,
    jungle_pyramid,
    mansion,
    monument,
    ocean_ruin,
    outpost,
    ruined_portal,
    shipwreck,
    swamp_hut,
    treasure,
    village,

    pub fn toC(self: Structure) c_int {
        return switch (self) {
            .ancient_city => c.Ancient_City,
            .desert_pyramid => c.Desert_Pyramid,
            .igloo => c.Igloo,
            .jungle_pyramid => c.Jungle_Pyramid,
            .mansion => c.Mansion,
            .monument => c.Monument,
            .ocean_ruin => c.Ocean_Ruin,
            .outpost => c.Outpost,
            .ruined_portal => c.Ruined_Portal,
            .shipwreck => c.Shipwreck,
            .swamp_hut => c.Swamp_Hut,
            .treasure => c.Treasure,
            .village => c.Village,
        };
    }
};

pub const supported_structures = [_]SupportedStructure{
    .{ .name = "ancient_city", .structure = .ancient_city },
    .{ .name = "desert_pyramid", .structure = .desert_pyramid },
    .{ .name = "desert_temple", .structure = .desert_pyramid },
    .{ .name = "igloo", .structure = .igloo },
    .{ .name = "jungle_pyramid", .structure = .jungle_pyramid },
    .{ .name = "jungle_temple", .structure = .jungle_pyramid },
    .{ .name = "mansion", .structure = .mansion },
    .{ .name = "woodland_mansion", .structure = .mansion },
    .{ .name = "monument", .structure = .monument },
    .{ .name = "ocean_monument", .structure = .monument },
    .{ .name = "ocean_ruin", .structure = .ocean_ruin },
    .{ .name = "outpost", .structure = .outpost },
    .{ .name = "pillager_outpost", .structure = .outpost },
    .{ .name = "ruined_portal", .structure = .ruined_portal },
    .{ .name = "shipwreck", .structure = .shipwreck },
    .{ .name = "swamp_hut", .structure = .swamp_hut },
    .{ .name = "witch_hut", .structure = .swamp_hut },
    .{ .name = "treasure", .structure = .treasure },
    .{ .name = "buried_treasure", .structure = .treasure },
    .{ .name = "village", .structure = .village },
};

pub const StructureConfig = struct {
    spacing: i32,
    separation: i32,
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

pub fn parseStructure(allocator: std.mem.Allocator, name: []const u8) !?Structure {
    const n = try normalizeName(allocator, name);
    defer allocator.free(n);

    for (supported_structures) |entry| {
        if (std.mem.eql(u8, n, entry.name)) return entry.structure;
    }
    return null;
}

pub fn getStructureConfig(structure: Structure, mc: i32) ?StructureConfig {
    var raw: c.StructureConfig = undefined;
    if (!c.getBedrockStructureConfig(structure.toC(), mc, &raw)) return null;
    return .{
        .spacing = raw.regionSize,
        .separation = raw.regionSize - raw.chunkRange,
    };
}

pub fn getStructurePos(structure: Structure, mc: i32, seed: u64, reg_x: i32, reg_z: i32) ?Pos {
    return getStructurePosC(structure.toC(), mc, seed, reg_x, reg_z);
}

pub fn getStructurePosC(structure_c: c_int, mc: i32, seed: u64, reg_x: i32, reg_z: i32) ?Pos {
    var pos: c.Pos = undefined;
    if (!c.getBedrockStructurePos(structure_c, mc, seed, reg_x, reg_z, &pos)) return null;
    return .{ .x = pos.x, .z = pos.z };
}
