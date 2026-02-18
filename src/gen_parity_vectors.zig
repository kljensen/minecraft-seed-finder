const std = @import("std");
const c = @import("c_bindings.zig");
const bedrock = @import("bedrock.zig");

const mc_versions = [_]i32{ c.MC_1_18, c.MC_1_19, c.MC_1_20, c.MC_1_21_1, c.MC_1_21_3 };
const structures = [_]bedrock.Structure{
    .ancient_city,
    .desert_pyramid,
    .igloo,
    .jungle_pyramid,
    .mansion,
    .monument,
    .ocean_ruin,
    .outpost,
    .ruined_portal,
    .shipwreck,
    .swamp_hut,
    .treasure,
    .village,
};

const default_seed_count: usize = 64;
const default_biome_samples_per_seed: usize = 128;
const default_region_radius: i32 = 2;
const default_biome_span: i32 = 4096;

const SpawnVector = struct { mc: i32, seed: u64, x: i32, z: i32 };
const BiomeVector = struct { mc: i32, seed: u64, x: i32, z: i32, b1: i32, b4: i32 };
const StructureVector = struct {
    mc: i32,
    seed: u64,
    st: []const u8,
    rx: i32,
    rz: i32,
    x: i32,
    z: i32,
    vp: bool,
    vt: bool,
};

const Output = struct {
    seed_count: usize,
    biome_samples_per_seed: usize,
    spawns: []SpawnVector,
    biomes: []BiomeVector,
    structures: []StructureVector,
};

fn splitMix64(state: *u64) u64 {
    state.* +%= 0x9E3779B97F4A7C15;
    var z = state.*;
    z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

fn genSeed(index: usize) u64 {
    var s: u64 = @as(u64, @intCast(index)) *% 0xD1342543DE82EF95;
    return splitMix64(&s);
}

fn genSeedSalted(index: usize, salt: u64) u64 {
    var s: u64 = @as(u64, @intCast(index)) *% 0xD1342543DE82EF95;
    s ^= salt;
    return splitMix64(&s);
}

fn sampleCoord(state: *u64, span: i32) i32 {
    const width: u64 = @as(u64, @intCast(span * 2 + 1));
    const v = splitMix64(state) % width;
    return @as(i32, @intCast(v)) - span;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var spawns = std.ArrayList(SpawnVector).init(allocator);
    defer spawns.deinit();

    var biomes = std.ArrayList(BiomeVector).init(allocator);
    defer biomes.deinit();

    var structure_vectors = std.ArrayList(StructureVector).init(allocator);
    defer {
        for (structure_vectors.items) |v| allocator.free(v.st);
        structure_vectors.deinit();
    }

    const seed_count = try readEnvUsize(allocator, "PARITY_SEED_COUNT", default_seed_count);
    const biome_samples_per_seed = try readEnvUsize(allocator, "PARITY_BIOME_SAMPLES", default_biome_samples_per_seed);
    const region_radius = try readEnvI32(allocator, "PARITY_REGION_RADIUS", default_region_radius);
    const biome_span = try readEnvI32(allocator, "PARITY_BIOME_SPAN", default_biome_span);
    const seed_salt = try readEnvU64(allocator, "PARITY_SEED_SALT", 0);
    const output_path = try readEnvString(allocator, "PARITY_OUTPUT_PATH", "tests/golden/parity_vectors.json");
    defer allocator.free(output_path);

    for (mc_versions) |mc| {
        var gen: c.Generator = undefined;
        c.setupGenerator(&gen, mc, 0);

        var si: usize = 0;
        while (si < seed_count) : (si += 1) {
            const seed = genSeedSalted(si, seed_salt);
            c.applySeed(&gen, c.DIM_OVERWORLD, seed);
            const spawn = c.getSpawn(&gen);
            try spawns.append(.{ .mc = mc, .seed = seed, .x = spawn.x, .z = spawn.z });

            var sample_state = seed ^ @as(u64, @intCast(mc)) ^ 0xA5A5A5A5A5A5A5A5;
            var bi: usize = 0;
            while (bi < biome_samples_per_seed) : (bi += 1) {
                const x = sampleCoord(&sample_state, biome_span);
                const z = sampleCoord(&sample_state, biome_span);
                const b1 = c.getBiomeAt(&gen, 1, x, 0, z);
                const b4 = c.getBiomeAt(&gen, 4, @divFloor(x, 4), 0, @divFloor(z, 4));
                try biomes.append(.{ .mc = mc, .seed = seed, .x = x, .z = z, .b1 = b1, .b4 = b4 });
            }

            for (structures) |st| {
                var reg_z: i32 = -region_radius;
                while (reg_z <= region_radius) : (reg_z += 1) {
                    var reg_x: i32 = -region_radius;
                    while (reg_x <= region_radius) : (reg_x += 1) {
                        const pos = bedrock.getStructurePos(st, mc, seed, reg_x, reg_z) orelse continue;
                        const vp = c.isViableStructurePos(st.toC(), &gen, pos.x, pos.z, 0) != 0;
                        const vt = c.isViableStructureTerrain(st.toC(), &gen, pos.x, pos.z) != 0;
                        try structure_vectors.append(.{
                            .mc = mc,
                            .seed = seed,
                            .st = try allocator.dupe(u8, @tagName(st)),
                            .rx = reg_x,
                            .rz = reg_z,
                            .x = pos.x,
                            .z = pos.z,
                            .vp = vp,
                            .vt = vt,
                        });
                    }
                }
            }
        }
    }

    const out = Output{
        .seed_count = seed_count,
        .biome_samples_per_seed = biome_samples_per_seed,
        .spawns = spawns.items,
        .biomes = biomes.items,
        .structures = structure_vectors.items,
    };

    const bytes = try std.json.stringifyAlloc(allocator, out, .{ .whitespace = .indent_2 });
    defer allocator.free(bytes);

    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = bytes });
}

fn readEnvUsize(allocator: std.mem.Allocator, name: []const u8, default_value: usize) !usize {
    const v = std.process.getEnvVarOwned(allocator, name) catch return default_value;
    defer allocator.free(v);
    return std.fmt.parseInt(usize, v, 10);
}

fn readEnvI32(allocator: std.mem.Allocator, name: []const u8, default_value: i32) !i32 {
    const v = std.process.getEnvVarOwned(allocator, name) catch return default_value;
    defer allocator.free(v);
    return std.fmt.parseInt(i32, v, 10);
}

fn readEnvString(allocator: std.mem.Allocator, name: []const u8, default_value: []const u8) ![]u8 {
    const v = std.process.getEnvVarOwned(allocator, name) catch return try allocator.dupe(u8, default_value);
    return v;
}

fn readEnvU64(allocator: std.mem.Allocator, name: []const u8, default_value: u64) !u64 {
    const v = std.process.getEnvVarOwned(allocator, name) catch return default_value;
    defer allocator.free(v);
    return std.fmt.parseInt(u64, v, 10);
}
