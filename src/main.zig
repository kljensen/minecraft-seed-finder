const std = @import("std");
const c = @import("c_bindings.zig");
const bedrock = @import("bedrock.zig");
const biome_names = @import("biome_names.zig");

const BiomeReq = struct {
    name: []const u8,
    biome_id: i32,
    radius: i32,
};

const StructureReq = struct {
    name: []const u8,
    structure: bedrock.Structure,
    radius: i32,
};

fn parseVersion(v: []const u8) ?i32 {
    if (std.mem.eql(u8, v, "1.18")) return c.MC_1_18;
    if (std.mem.eql(u8, v, "1.19") or std.mem.eql(u8, v, "1.19.4")) return c.MC_1_19;
    if (std.mem.eql(u8, v, "1.20") or std.mem.eql(u8, v, "1.20.6")) return c.MC_1_20;
    if (std.mem.eql(u8, v, "1.21") or std.mem.eql(u8, v, "1.21.1")) return c.MC_1_21_1;
    if (std.mem.eql(u8, v, "1.21.3")) return c.MC_1_21_3;
    return null;
}

fn parseNameRadius(spec: []const u8) ?struct { name: []const u8, radius: i32 } {
    const sep = std.mem.indexOfScalar(u8, spec, ':') orelse return null;
    const name = std.mem.trim(u8, spec[0..sep], " ");
    const radius_str = std.mem.trim(u8, spec[sep + 1 ..], " ");
    const radius = std.fmt.parseInt(i32, radius_str, 10) catch return null;
    if (name.len == 0 or radius <= 0) return null;
    return .{ .name = name, .radius = radius };
}

fn floorDiv(a: i32, b: i32) i32 {
    return std.math.divFloor(i32, a, b) catch unreachable;
}

fn ceilDiv(a: i32, b: i32) i32 {
    return std.math.divCeil(i32, a, b) catch unreachable;
}

fn hasBiomeWithinRadius(g: *c.Generator, spawn: c.Pos, biome_id: i32, radius: i32) bool {
    const step: i32 = 4;
    const r2: i64 = @as(i64, radius) * radius;

    var dz: i32 = -radius;
    while (dz <= radius) : (dz += step) {
        var dx: i32 = -radius;
        while (dx <= radius) : (dx += step) {
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            const id = c.getBiomeAt(g, 1, spawn.x + dx, 0, spawn.z + dz);
            if (id == biome_id) return true;
        }
    }
    return false;
}

fn hasStructureWithinRadius(g: *c.Generator, seed: u64, mc: i32, spawn: c.Pos, req: StructureReq) bool {
    const cfg = bedrock.getStructureConfig(req.structure, mc) orelse return false;

    const min_x = spawn.x - req.radius;
    const max_x = spawn.x + req.radius;
    const min_z = spawn.z - req.radius;
    const max_z = spawn.z + req.radius;

    const min_attempt_chunk_x = floorDiv(min_x - 8, 16);
    const max_attempt_chunk_x = floorDiv(max_x - 8, 16);
    const min_attempt_chunk_z = floorDiv(min_z - 8, 16);
    const max_attempt_chunk_z = floorDiv(max_z - 8, 16);

    const min_reg_x = floorDiv(min_attempt_chunk_x - (cfg.spacing - 1), cfg.spacing);
    const max_reg_x = floorDiv(max_attempt_chunk_x, cfg.spacing);
    const min_reg_z = floorDiv(min_attempt_chunk_z - (cfg.spacing - 1), cfg.spacing);
    const max_reg_z = floorDiv(max_attempt_chunk_z, cfg.spacing);

    const r2: i64 = @as(i64, req.radius) * req.radius;
    var reg_z = min_reg_z;
    while (reg_z <= max_reg_z) : (reg_z += 1) {
        var reg_x = min_reg_x;
        while (reg_x <= max_reg_x) : (reg_x += 1) {
            const pos = bedrock.getStructurePos(req.structure, mc, seed, reg_x, reg_z) orelse continue;
            const dx = pos.x - spawn.x;
            const dz = pos.z - spawn.z;
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;

            if (c.isViableStructurePos(req.structure.toC(), g, pos.x, pos.z, 0) == 0) continue;
            if (c.isViableStructureTerrain(req.structure.toC(), g, pos.x, pos.z) == 0) continue;
            return true;
        }
    }

    return false;
}

fn printUsage(writer: anytype) !void {
    try writer.print(
        "Usage:\n" ++
            "  seed-finder --count <N> [options]\n\n" ++
            "Options:\n" ++
            "  --version <1.18|1.19|1.20|1.21.1>   Minecraft version (default: 1.21.1)\n" ++
            "  --start-seed <u64>                   First seed to test (default: 0)\n" ++
            "  --max-seed <u64>                     Stop scanning after this seed\n" ++
            "  --count <N>                          Number of matches to output\n" ++
            "  --require-biome <name:radius>        Repeatable biome filter\n" ++
            "  --require-structure <name:radius>    Repeatable structure filter\n" ++
            "  --list-biomes                        List accepted biome names\n" ++
            "  --list-structures                    List accepted structure names\n" ++
            "  --output <path>                      Optional output file\n" ++
            "  --help                               Show help\n\n" ++
            "Example:\n" ++
            "  seed-finder --count 5 --require-biome \"flower forest:100\" --require-biome \"extreme hills:100\"\n",
        .{},
    );
}

fn printSupportedBiomes(writer: anytype) !void {
    try writer.print("Supported biomes:\n", .{});
    for (biome_names.supported_biomes) |entry| {
        try writer.print("  {s}\n", .{entry.name});
    }
}

fn printSupportedStructures(writer: anytype) !void {
    try writer.print("Supported structures:\n", .{});
    for (bedrock.supported_structures) |entry| {
        try writer.print("  {s}\n", .{entry.name});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var biome_reqs = std.ArrayList(BiomeReq).init(allocator);
    defer biome_reqs.deinit();

    var structure_reqs = std.ArrayList(StructureReq).init(allocator);
    defer structure_reqs.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();

    var mc: i32 = c.MC_1_21_1;
    var start_seed: u64 = 0;
    var max_seed: u64 = std.math.maxInt(u64);
    var count: usize = 0;
    var output_path: ?[]const u8 = null;
    var list_biomes = false;
    var list_structures = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            try printUsage(std.io.getStdOut().writer());
            return;
        } else if (std.mem.eql(u8, arg, "--list-biomes")) {
            list_biomes = true;
        } else if (std.mem.eql(u8, arg, "--list-structures")) {
            list_structures = true;
        } else if (std.mem.eql(u8, arg, "--version")) {
            const v = args.next() orelse return error.InvalidArguments;
            mc = parseVersion(v) orelse return error.InvalidVersion;
        } else if (std.mem.eql(u8, arg, "--start-seed")) {
            const s = args.next() orelse return error.InvalidArguments;
            start_seed = try std.fmt.parseInt(u64, s, 10);
        } else if (std.mem.eql(u8, arg, "--max-seed")) {
            const s = args.next() orelse return error.InvalidArguments;
            max_seed = try std.fmt.parseInt(u64, s, 10);
        } else if (std.mem.eql(u8, arg, "--count")) {
            const s = args.next() orelse return error.InvalidArguments;
            count = try std.fmt.parseInt(usize, s, 10);
        } else if (std.mem.eql(u8, arg, "--output")) {
            output_path = args.next() orelse return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--require-biome")) {
            const spec = args.next() orelse return error.InvalidArguments;
            const parsed = parseNameRadius(spec) orelse return error.InvalidArguments;
            const biome_id = try biome_names.biomeIdFromName(allocator, parsed.name) orelse return error.UnknownBiome;
            try biome_reqs.append(.{ .name = parsed.name, .biome_id = biome_id, .radius = parsed.radius });
        } else if (std.mem.eql(u8, arg, "--require-structure")) {
            const spec = args.next() orelse return error.InvalidArguments;
            const parsed = parseNameRadius(spec) orelse return error.InvalidArguments;
            const st = try bedrock.parseStructure(allocator, parsed.name) orelse return error.UnknownStructure;
            try structure_reqs.append(.{ .name = parsed.name, .structure = st, .radius = parsed.radius });
        } else {
            return error.InvalidArguments;
        }
    }

    const stdout = std.io.getStdOut().writer();
    if (list_biomes) {
        try printSupportedBiomes(stdout);
    }
    if (list_structures) {
        try printSupportedStructures(stdout);
    }
    if (list_biomes or list_structures) {
        return;
    }

    if (count == 0) return error.InvalidArguments;
    if (start_seed > max_seed) return error.InvalidArguments;

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    var out_file: ?std.fs.File = null;
    defer if (out_file) |f| f.close();

    var writer = std.io.getStdOut().writer();
    var file_writer: ?std.fs.File.Writer = null;

    if (output_path) |path| {
        const f = try std.fs.cwd().createFile(path, .{ .truncate = true });
        out_file = f;
        file_writer = f.writer();
    }

    var found: usize = 0;
    var tested: u64 = 0;
    var seed = start_seed;

    while (seed <= max_seed and found < count) : (seed +%= 1) {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const spawn = c.getSpawn(&gen);

        var matches = true;

        for (biome_reqs.items) |req| {
            if (!hasBiomeWithinRadius(&gen, spawn, req.biome_id, req.radius)) {
                matches = false;
                break;
            }
        }
        if (!matches) {
            tested +%= 1;
            continue;
        }

        for (structure_reqs.items) |req| {
            if (!hasStructureWithinRadius(&gen, seed, mc, spawn, req)) {
                matches = false;
                break;
            }
        }
        if (!matches) {
            tested +%= 1;
            continue;
        }

        found += 1;
        tested +%= 1;

        try writer.print("seed={d} spawn=({d},{d})\n", .{ seed, spawn.x, spawn.z });
        if (file_writer) |*fw| {
            try fw.print("{d}\n", .{seed});
        }
    }

    try writer.print("summary: found={d} tested={d} start_seed={d} end_seed={d}\n", .{ found, tested, start_seed, seed - 1 });
}
