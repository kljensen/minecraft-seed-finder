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
const structure_c_ids = blk: {
    var ids: [structures.len]c_int = undefined;
    for (structures, 0..) |st, i| {
        ids[i] = st.toC();
    }
    break :blk ids;
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
    st: bedrock.Structure,
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

const WorkerConfig = struct {
    mc: i32,
    seed_start: usize,
    seed_end: usize,
    seed_salt: u64,
    biome_samples_per_seed: usize,
    biome_span: i32,
    regions: []const RegionCoord,
    use_simd: bool,
    timing_enabled: bool,
};

const RegionCoord = struct {
    x: i32,
    z: i32,
};

const Timing = struct {
    total_ns: u64 = 0,
    spawn_ns: u64 = 0,
    biome_ns: u64 = 0,
    structure_ns: u64 = 0,
};

const WorkerResult = struct {
    spawns: []SpawnVector = &.{},
    biomes: []BiomeVector = &.{},
    structures: []StructureVector = &.{},
    timing: Timing = .{},
};

fn freeWorkerResult(result: *const WorkerResult, allocator: std.mem.Allocator) void {
    allocator.free(result.spawns);
    allocator.free(result.biomes);
    allocator.free(result.structures);
}

fn splitMix64(state: *u64) u64 {
    state.* +%= 0x9E3779B97F4A7C15;
    var z = state.*;
    z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

fn splitMix64Vec(comptime N: usize, state: @Vector(N, u64)) @Vector(N, u64) {
    const c1: @Vector(N, u64) = @splat(0xBF58476D1CE4E5B9);
    const c2: @Vector(N, u64) = @splat(0x94D049BB133111EB);
    const s30: @Vector(N, u6) = @splat(30);
    const s27: @Vector(N, u6) = @splat(27);
    const s31: @Vector(N, u6) = @splat(31);
    var z = state;
    z = (z ^ (z >> s30)) *% c1;
    z = (z ^ (z >> s27)) *% c2;
    return z ^ (z >> s31);
}

fn genSeedSalted(index: usize, salt: u64) u64 {
    var s: u64 = @as(u64, @intCast(index)) *% 0xD1342543DE82EF95;
    s ^= salt;
    return splitMix64(&s);
}

fn genSeedSaltedSimd4(index_start: usize, salt: u64) [4]u64 {
    const N = 4;
    const step: u64 = 0x9E3779B97F4A7C15;
    const mul: u64 = 0xD1342543DE82EF95;
    const lanes = @Vector(N, u64){ 0, 1, 2, 3 };
    const base_idx: @Vector(N, u64) = @splat(@as(u64, @intCast(index_start)));
    var s = (base_idx + lanes) *% @as(@Vector(N, u64), @splat(mul));
    s ^= @as(@Vector(N, u64), @splat(salt));
    s +%= @as(@Vector(N, u64), @splat(step));
    return @as([N]u64, splitMix64Vec(N, s));
}

fn sampleCoord(state: *u64, span: i32) i32 {
    const width: u64 = @as(u64, @intCast(span * 2 + 1));
    const v = splitMix64(state) % width;
    return @as(i32, @intCast(v)) - span;
}

fn sampleCoordWithWidth(state: *u64, width: u64, span: i32) i32 {
    const v = splitMix64(state) % width;
    return @as(i32, @intCast(v)) - span;
}

fn divFloorBy4(v: i32) i32 {
    // Arithmetic shift is equivalent to floor-division by 4 for signed two's-complement ints.
    return v >> 2;
}

fn fillCoordsSimd4(state: *u64, span: i32, width: u64, out_x: *[4]i32, out_z: *[4]i32) void {
    const N = 4;
    const step: u64 = 0x9E3779B97F4A7C15;

    const base = state.*;
    const lanes_x = @Vector(N, u64){ 1, 3, 5, 7 };
    const lanes_z = @Vector(N, u64){ 2, 4, 6, 8 };

    const s_x = @as(@Vector(N, u64), @splat(base)) +% (lanes_x *% @as(@Vector(N, u64), @splat(step)));
    const s_z = @as(@Vector(N, u64), @splat(base)) +% (lanes_z *% @as(@Vector(N, u64), @splat(step)));

    const r_x = splitMix64Vec(N, s_x);
    const r_z = splitMix64Vec(N, s_z);

    const m_x = r_x % @as(@Vector(N, u64), @splat(width));
    const m_z = r_z % @as(@Vector(N, u64), @splat(width));

    const arr_x: [N]u64 = m_x;
    const arr_z: [N]u64 = m_z;
    inline for (0..N) |i| {
        out_x[i] = @as(i32, @intCast(arr_x[i])) - span;
        out_z[i] = @as(i32, @intCast(arr_z[i])) - span;
    }

    state.* = base +% (step *% 8);
}

fn estimateStructures(seed_count: usize, region_count: usize) usize {
    return seed_count * structures.len * region_count;
}

fn buildRegions(allocator: std.mem.Allocator, region_radius: i32) ![]RegionCoord {
    const width: usize = @as(usize, @intCast(region_radius * 2 + 1));
    const region_count = width * width;
    var regions = try allocator.alloc(RegionCoord, region_count);
    var region_i: usize = 0;
    var reg_z: i32 = -region_radius;
    while (reg_z <= region_radius) : (reg_z += 1) {
        var reg_x: i32 = -region_radius;
        while (reg_x <= region_radius) : (reg_x += 1) {
            regions[region_i] = .{ .x = reg_x, .z = reg_z };
            region_i += 1;
        }
    }
    return regions;
}

fn appendBiomeVectors(
    cfg: WorkerConfig,
    seed: u64,
    gen: *c.Generator,
    biomes: *std.ArrayList(BiomeVector),
) void {
    const out_start = biomes.items.len;
    const out_end = out_start + cfg.biome_samples_per_seed;
    biomes.items.len = out_end;
    const out = biomes.items[out_start..out_end];

    var sample_state = seed ^ @as(u64, @intCast(cfg.mc)) ^ 0xA5A5A5A5A5A5A5A5;
    const biome_width: u64 = @as(u64, @intCast(cfg.biome_span * 2 + 1));
    if (cfg.use_simd and cfg.biome_samples_per_seed >= 4) {
        var bi: usize = 0;
        const simd_end = cfg.biome_samples_per_seed & ~@as(usize, 3);
        while (bi < simd_end) : (bi += 4) {
            var xs: [4]i32 = undefined;
            var zs: [4]i32 = undefined;
            fillCoordsSimd4(&sample_state, cfg.biome_span, biome_width, &xs, &zs);
            inline for (0..4) |lane| {
                const x = xs[lane];
                const z = zs[lane];
                const b1 = c.getBiomeAt(gen, 1, x, 0, z);
                const b4 = c.getBiomeAt(gen, 4, divFloorBy4(x), 0, divFloorBy4(z));
                out[bi + lane] = .{ .mc = cfg.mc, .seed = seed, .x = x, .z = z, .b1 = b1, .b4 = b4 };
            }
        }
        while (bi < cfg.biome_samples_per_seed) : (bi += 1) {
            const x = sampleCoordWithWidth(&sample_state, biome_width, cfg.biome_span);
            const z = sampleCoordWithWidth(&sample_state, biome_width, cfg.biome_span);
            const b1 = c.getBiomeAt(gen, 1, x, 0, z);
            const b4 = c.getBiomeAt(gen, 4, divFloorBy4(x), 0, divFloorBy4(z));
            out[bi] = .{ .mc = cfg.mc, .seed = seed, .x = x, .z = z, .b1 = b1, .b4 = b4 };
        }
        return;
    }

    var bi: usize = 0;
    while (bi < cfg.biome_samples_per_seed) : (bi += 1) {
        const x = sampleCoordWithWidth(&sample_state, biome_width, cfg.biome_span);
        const z = sampleCoordWithWidth(&sample_state, biome_width, cfg.biome_span);
        const b1 = c.getBiomeAt(gen, 1, x, 0, z);
        const b4 = c.getBiomeAt(gen, 4, divFloorBy4(x), 0, divFloorBy4(z));
        out[bi] = .{ .mc = cfg.mc, .seed = seed, .x = x, .z = z, .b1 = b1, .b4 = b4 };
    }
}

fn appendStructureVectors(
    cfg: WorkerConfig,
    seed: u64,
    regions: []const RegionCoord,
    gen: *c.Generator,
    structure_vectors: *std.ArrayList(StructureVector),
) void {
    for (structures, 0..) |st, i| {
        const st_c = structure_c_ids[i];
        for (regions) |reg| {
            var pos: c.Pos = undefined;
            if (!c.getBedrockStructurePos(st_c, cfg.mc, seed, reg.x, reg.z, &pos)) continue;
            const vp = c.isViableStructurePos(st_c, gen, pos.x, pos.z, 0) != 0;
            const vt = c.isViableStructureTerrain(st_c, gen, pos.x, pos.z) != 0;
            structure_vectors.appendAssumeCapacity(.{
                .mc = cfg.mc,
                .seed = seed,
                .st = st,
                .rx = reg.x,
                .rz = reg.z,
                .x = pos.x,
                .z = pos.z,
                .vp = vp,
                .vt = vt,
            });
        }
    }
}

fn processSeedFast(
    cfg: WorkerConfig,
    seed: u64,
    gen: *c.Generator,
    spawns: *std.ArrayList(SpawnVector),
    biomes: *std.ArrayList(BiomeVector),
    structure_vectors: *std.ArrayList(StructureVector),
) void {
    c.applySeed(gen, c.DIM_OVERWORLD, seed);
    const spawn = c.getSpawn(gen);
    spawns.appendAssumeCapacity(.{ .mc = cfg.mc, .seed = seed, .x = spawn.x, .z = spawn.z });
    appendBiomeVectors(cfg, seed, gen, biomes);
    appendStructureVectors(cfg, seed, cfg.regions, gen, structure_vectors);
}

fn processSeedTimed(
    cfg: WorkerConfig,
    seed: u64,
    gen: *c.Generator,
    spawns: *std.ArrayList(SpawnVector),
    biomes: *std.ArrayList(BiomeVector),
    structure_vectors: *std.ArrayList(StructureVector),
) Timing {
    var timing = Timing{};
    const seed_start_ns = std.time.nanoTimestamp();
    c.applySeed(gen, c.DIM_OVERWORLD, seed);
    const spawn = c.getSpawn(gen);
    spawns.appendAssumeCapacity(.{ .mc = cfg.mc, .seed = seed, .x = spawn.x, .z = spawn.z });
    const spawn_end_ns = std.time.nanoTimestamp();
    appendBiomeVectors(cfg, seed, gen, biomes);
    const biome_end_ns = std.time.nanoTimestamp();
    appendStructureVectors(cfg, seed, cfg.regions, gen, structure_vectors);
    const structure_end_ns = std.time.nanoTimestamp();
    timing.spawn_ns = @as(u64, @intCast(spawn_end_ns - seed_start_ns));
    timing.biome_ns = @as(u64, @intCast(biome_end_ns - spawn_end_ns));
    timing.structure_ns = @as(u64, @intCast(structure_end_ns - biome_end_ns));
    timing.total_ns = @as(u64, @intCast(structure_end_ns - seed_start_ns));
    return timing;
}

fn processRangeAppend(
    cfg: WorkerConfig,
    spawns: *std.ArrayList(SpawnVector),
    biomes: *std.ArrayList(BiomeVector),
    structure_vectors: *std.ArrayList(StructureVector),
    timing: *Timing,
) void {
    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, cfg.mc, 0);

    var si: usize = cfg.seed_start;
    const simd_seed_end = cfg.seed_end - ((cfg.seed_end - cfg.seed_start) & @as(usize, 3));
    if (cfg.timing_enabled) {
        while (si < simd_seed_end) : (si += 4) {
            const seeds = genSeedSaltedSimd4(si, cfg.seed_salt);
            inline for (0..4) |lane| {
                const lane_timing = processSeedTimed(cfg, seeds[lane], &gen, spawns, biomes, structure_vectors);
                appendTiming(timing, lane_timing);
            }
        }
        while (si < cfg.seed_end) : (si += 1) {
            const seed = genSeedSalted(si, cfg.seed_salt);
            const lane_timing = processSeedTimed(cfg, seed, &gen, spawns, biomes, structure_vectors);
            appendTiming(timing, lane_timing);
        }
    } else {
        while (si < simd_seed_end) : (si += 4) {
            const seeds = genSeedSaltedSimd4(si, cfg.seed_salt);
            inline for (0..4) |lane| {
                processSeedFast(cfg, seeds[lane], &gen, spawns, biomes, structure_vectors);
            }
        }
        while (si < cfg.seed_end) : (si += 1) {
            const seed = genSeedSalted(si, cfg.seed_salt);
            processSeedFast(cfg, seed, &gen, spawns, biomes, structure_vectors);
        }
    }
}

fn processRange(cfg: WorkerConfig, allocator: std.mem.Allocator) !WorkerResult {
    var spawns = std.ArrayList(SpawnVector).init(allocator);
    errdefer spawns.deinit();
    var biomes = std.ArrayList(BiomeVector).init(allocator);
    errdefer biomes.deinit();
    var structure_vectors = std.ArrayList(StructureVector).init(allocator);
    errdefer structure_vectors.deinit();

    const local_seed_count = cfg.seed_end - cfg.seed_start;
    try spawns.ensureTotalCapacity(local_seed_count);
    try biomes.ensureTotalCapacity(local_seed_count * cfg.biome_samples_per_seed);
    try structure_vectors.ensureTotalCapacity(local_seed_count * structures.len * cfg.regions.len);
    var timing = Timing{};

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, cfg.mc, 0);

    var si: usize = cfg.seed_start;
    const simd_seed_end = cfg.seed_end - ((cfg.seed_end - cfg.seed_start) & @as(usize, 3));
    if (cfg.timing_enabled) {
        while (si < simd_seed_end) : (si += 4) {
            const seeds = genSeedSaltedSimd4(si, cfg.seed_salt);
            inline for (0..4) |lane| {
                const lane_timing = processSeedTimed(cfg, seeds[lane], &gen, &spawns, &biomes, &structure_vectors);
                appendTiming(&timing, lane_timing);
            }
        }
        while (si < cfg.seed_end) : (si += 1) {
            const seed = genSeedSalted(si, cfg.seed_salt);
            const lane_timing = processSeedTimed(cfg, seed, &gen, &spawns, &biomes, &structure_vectors);
            appendTiming(&timing, lane_timing);
        }
    } else {
        while (si < simd_seed_end) : (si += 4) {
            const seeds = genSeedSaltedSimd4(si, cfg.seed_salt);
            inline for (0..4) |lane| {
                processSeedFast(cfg, seeds[lane], &gen, &spawns, &biomes, &structure_vectors);
            }
        }
        while (si < cfg.seed_end) : (si += 1) {
            const seed = genSeedSalted(si, cfg.seed_salt);
            processSeedFast(cfg, seed, &gen, &spawns, &biomes, &structure_vectors);
        }
    }

    return .{
        .spawns = try spawns.toOwnedSlice(),
        .biomes = try biomes.toOwnedSlice(),
        .structures = try structure_vectors.toOwnedSlice(),
        .timing = timing,
    };
}

fn workerMain(cfg: WorkerConfig, result: *WorkerResult) void {
    result.* = processRange(cfg, std.heap.page_allocator) catch |err| {
        std.debug.panic("worker failed: {}", .{err});
    };
}

fn appendAndFree(dst_spawns: *std.ArrayList(SpawnVector), dst_biomes: *std.ArrayList(BiomeVector), dst_structures: *std.ArrayList(StructureVector), src: *WorkerResult) !void {
    try dst_spawns.appendSlice(src.spawns);
    try dst_biomes.appendSlice(src.biomes);
    try dst_structures.appendSlice(src.structures);
    std.heap.page_allocator.free(src.spawns);
    std.heap.page_allocator.free(src.biomes);
    std.heap.page_allocator.free(src.structures);
}

fn appendTiming(dst: *Timing, src: Timing) void {
    dst.total_ns += src.total_ns;
    dst.spawn_ns += src.spawn_ns;
    dst.biome_ns += src.biome_ns;
    dst.structure_ns += src.structure_ns;
}

fn logTiming(mc: i32, stats: Timing, vectors: usize) void {
    if (stats.total_ns == 0) return;
    const total_ms = @as(f64, @floatFromInt(stats.total_ns)) / 1_000_000.0;
    const spawn_ms = @as(f64, @floatFromInt(stats.spawn_ns)) / 1_000_000.0;
    const biome_ms = @as(f64, @floatFromInt(stats.biome_ns)) / 1_000_000.0;
    const structure_ms = @as(f64, @floatFromInt(stats.structure_ns)) / 1_000_000.0;
    const vectors_per_sec = (@as(f64, @floatFromInt(vectors)) * 1_000_000_000.0) / @as(f64, @floatFromInt(stats.total_ns));
    std.debug.print(
        "timing mc={d} total={d:.2}ms spawn={d:.2}ms biome={d:.2}ms structure={d:.2}ms vectors={d} vps={d:.0}\n",
        .{ mc, total_ms, spawn_ms, biome_ms, structure_ms, vectors, vectors_per_sec },
    );
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
    defer structure_vectors.deinit();

    const seed_count = try readEnvUsize(allocator, "PARITY_SEED_COUNT", default_seed_count);
    const biome_samples_per_seed = try readEnvUsize(allocator, "PARITY_BIOME_SAMPLES", default_biome_samples_per_seed);
    const region_radius = try readEnvI32(allocator, "PARITY_REGION_RADIUS", default_region_radius);
    const biome_span = try readEnvI32(allocator, "PARITY_BIOME_SPAN", default_biome_span);
    const seed_salt = try readEnvU64(allocator, "PARITY_SEED_SALT", 0);
    const thread_setting = try readEnvUsize(allocator, "PARITY_THREADS", 0);
    const threads = if (thread_setting == 0) (std.Thread.getCpuCount() catch 1) else thread_setting;
    const use_simd = (try readEnvUsize(allocator, "PARITY_SIMD", 0)) != 0;
    const timing_enabled = (try readEnvUsize(allocator, "PARITY_TIMING", 0)) != 0;
    const pretty_json = (try readEnvUsize(allocator, "PARITY_PRETTY", 1)) != 0;
    const output_path = try readEnvString(allocator, "PARITY_OUTPUT_PATH", "tests/golden/parity_vectors.json");
    defer allocator.free(output_path);
    const regions = try buildRegions(allocator, region_radius);
    defer allocator.free(regions);

    try spawns.ensureTotalCapacity(seed_count * mc_versions.len);
    try biomes.ensureTotalCapacity(seed_count * biome_samples_per_seed * mc_versions.len);
    try structure_vectors.ensureTotalCapacity(estimateStructures(seed_count, regions.len) * mc_versions.len);

    for (mc_versions) |mc| {
        var mc_timing = Timing{};
        const mc_start_spawn = spawns.items.len;
        const mc_start_biome = biomes.items.len;
        const mc_start_structure = structure_vectors.items.len;
        const worker_count = if (threads == 0) @as(usize, 1) else @min(threads, @max(seed_count, 1));
        const cfg = WorkerConfig{
            .mc = mc,
            .seed_start = 0,
            .seed_end = seed_count,
            .seed_salt = seed_salt,
            .biome_samples_per_seed = biome_samples_per_seed,
            .biome_span = biome_span,
            .regions = regions,
            .use_simd = use_simd,
            .timing_enabled = timing_enabled,
        };

        if (worker_count == 1) {
            processRangeAppend(cfg, &spawns, &biomes, &structure_vectors, &mc_timing);
            if (timing_enabled) {
                const mc_vectors = (spawns.items.len - mc_start_spawn) + (biomes.items.len - mc_start_biome) + (structure_vectors.items.len - mc_start_structure);
                logTiming(mc, mc_timing, mc_vectors);
            }
            continue;
        }

        const chunk_size = (seed_count + worker_count - 1) / worker_count;
        var handles = try allocator.alloc(std.Thread, worker_count);
        defer allocator.free(handles);
        var results = try allocator.alloc(WorkerResult, worker_count);
        defer allocator.free(results);

        var spawned: usize = 0;
        var i: usize = 0;
        while (i < worker_count) : (i += 1) {
            const start = i * chunk_size;
            if (start >= seed_count) break;
            const end = @min(start + chunk_size, seed_count);
            const thread_cfg = WorkerConfig{
                .mc = cfg.mc,
                .seed_start = start,
                .seed_end = end,
                .seed_salt = cfg.seed_salt,
                .biome_samples_per_seed = cfg.biome_samples_per_seed,
                .biome_span = cfg.biome_span,
                .regions = cfg.regions,
                .use_simd = cfg.use_simd,
                .timing_enabled = cfg.timing_enabled,
            };
            handles[spawned] = try std.Thread.spawn(.{}, workerMain, .{ thread_cfg, &results[spawned] });
            spawned += 1;
        }

        i = 0;
        while (i < spawned) : (i += 1) handles[i].join();
        i = 0;
        while (i < spawned) : (i += 1) {
            try appendAndFree(&spawns, &biomes, &structure_vectors, &results[i]);
            appendTiming(&mc_timing, results[i].timing);
        }
        if (timing_enabled) {
            const mc_vectors = (spawns.items.len - mc_start_spawn) + (biomes.items.len - mc_start_biome) + (structure_vectors.items.len - mc_start_structure);
            logTiming(mc, mc_timing, mc_vectors);
        }
    }

    const out = Output{
        .seed_count = seed_count,
        .biome_samples_per_seed = biome_samples_per_seed,
        .spawns = spawns.items,
        .biomes = biomes.items,
        .structures = structure_vectors.items,
    };

    const file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });
    defer file.close();
    var buf = std.io.bufferedWriter(file.writer());
    try std.json.stringify(out, .{
        .whitespace = if (pretty_json) .indent_2 else .minified,
    }, buf.writer());
    try buf.flush();
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

fn envFlagEnabled(allocator: std.mem.Allocator, name: []const u8) bool {
    const v = std.process.getEnvVarOwned(allocator, name) catch return false;
    defer allocator.free(v);
    return std.mem.eql(u8, v, "1") or std.ascii.eqlIgnoreCase(v, "true") or std.ascii.eqlIgnoreCase(v, "yes");
}

test "simd seed generation matches scalar" {
    const starts = [_]usize{ 0, 1, 7, 64, 1024, 65535 };
    const salts = [_]u64{
        0,
        1,
        0xA5A5A5A5A5A5A5A5,
        42424242,
        0xFFFFFFFFFFFFFFFF,
    };

    for (starts) |start| {
        for (salts) |salt| {
            const simd = genSeedSaltedSimd4(start, salt);
            inline for (0..4) |lane| {
                const scalar = genSeedSalted(start + lane, salt);
                try std.testing.expectEqual(scalar, simd[lane]);
            }
        }
    }
}

test "simd coordinate generation matches scalar" {
    const spans = [_]i32{ 16, 128, 4096 };
    const states = [_]u64{
        0,
        1,
        123456789,
        0xDEADBEEFCAFEBABE,
    };

    for (spans) |span| {
        for (states) |seed_state| {
            var scalar_state = seed_state;
            var simd_state = seed_state;
            var xs: [4]i32 = undefined;
            var zs: [4]i32 = undefined;
            const width: u64 = @as(u64, @intCast(span * 2 + 1));
            fillCoordsSimd4(&simd_state, span, width, &xs, &zs);

            inline for (0..4) |lane| {
                const sx = sampleCoord(&scalar_state, span);
                const sz = sampleCoord(&scalar_state, span);
                try std.testing.expectEqual(sx, xs[lane]);
                try std.testing.expectEqual(sz, zs[lane]);
            }
            try std.testing.expectEqual(scalar_state, simd_state);
        }
    }
}

test "divFloorBy4 matches @divFloor for representative signed range" {
    var v: i32 = -65_536;
    while (v <= 65_536) : (v += 1) {
        try std.testing.expectEqual(@divFloor(v, 4), divFloorBy4(v));
    }
}

test "simd parity output matches scalar" {
    const regions = try buildRegions(std.heap.page_allocator, 1);
    defer std.heap.page_allocator.free(regions);

    const cfg_scalar = WorkerConfig{
        .mc = c.MC_1_21_1,
        .seed_start = 0,
        .seed_end = 12,
        .seed_salt = 42424242,
        .biome_samples_per_seed = 24,
        .biome_span = 2048,
        .regions = regions,
        .use_simd = false,
        .timing_enabled = false,
    };
    const cfg_simd = WorkerConfig{
        .mc = c.MC_1_21_1,
        .seed_start = cfg_scalar.seed_start,
        .seed_end = cfg_scalar.seed_end,
        .seed_salt = cfg_scalar.seed_salt,
        .biome_samples_per_seed = cfg_scalar.biome_samples_per_seed,
        .biome_span = cfg_scalar.biome_span,
        .regions = cfg_scalar.regions,
        .use_simd = true,
        .timing_enabled = false,
    };

    var scalar = try processRange(cfg_scalar, std.heap.page_allocator);
    defer freeWorkerResult(&scalar, std.heap.page_allocator);
    var simd = try processRange(cfg_simd, std.heap.page_allocator);
    defer freeWorkerResult(&simd, std.heap.page_allocator);

    try std.testing.expectEqualDeep(scalar.spawns, simd.spawns);
    try std.testing.expectEqualDeep(scalar.biomes, simd.biomes);
    try std.testing.expectEqualDeep(scalar.structures, simd.structures);
}

test "opt-in perf: parity scalar vs simd" {
    if (!envFlagEnabled(std.testing.allocator, "SEED_FINDER_PERF_TEST")) return error.SkipZigTest;
    const regions = try buildRegions(std.heap.page_allocator, 4);
    defer std.heap.page_allocator.free(regions);

    const cfg_common = WorkerConfig{
        .mc = c.MC_1_21_1,
        .seed_start = 0,
        .seed_end = 96,
        .seed_salt = 42424242,
        .biome_samples_per_seed = 256,
        .biome_span = 8192,
        .regions = regions,
        .use_simd = false,
        .timing_enabled = false,
    };

    const start_scalar = std.time.nanoTimestamp();
    var scalar = try processRange(cfg_common, std.heap.page_allocator);
    const scalar_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_scalar));
    defer freeWorkerResult(&scalar, std.heap.page_allocator);

    var cfg_simd = cfg_common;
    cfg_simd.use_simd = true;
    const start_simd = std.time.nanoTimestamp();
    var simd = try processRange(cfg_simd, std.heap.page_allocator);
    const simd_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_simd));
    defer freeWorkerResult(&simd, std.heap.page_allocator);

    const scalar_vectors = scalar.spawns.len + scalar.biomes.len + scalar.structures.len;
    const simd_vectors = simd.spawns.len + simd.biomes.len + simd.structures.len;
    try std.testing.expectEqual(scalar_vectors, simd_vectors);
    try std.testing.expectEqualDeep(scalar.spawns, simd.spawns);
    try std.testing.expectEqualDeep(scalar.biomes, simd.biomes);
    try std.testing.expectEqualDeep(scalar.structures, simd.structures);

    try std.fs.cwd().makePath("tmp/perf");
    var file = std.fs.cwd().openFile("tmp/perf/perf_test.jsonl", .{ .mode = .read_write }) catch try std.fs.cwd().createFile("tmp/perf/perf_test.jsonl", .{});
    defer file.close();
    try file.seekFromEnd(0);

    const Rec = struct {
        tag: []const u8,
        scalar_ns: u64,
        simd_ns: u64,
        scalar_vectors: usize,
        simd_vectors: usize,
        scalar_vps: f64,
        simd_vps: f64,
    };
    const scalar_vps = (@as(f64, @floatFromInt(scalar_vectors)) * 1_000_000_000.0) / @as(f64, @floatFromInt(@max(scalar_ns, 1)));
    const simd_vps = (@as(f64, @floatFromInt(simd_vectors)) * 1_000_000_000.0) / @as(f64, @floatFromInt(@max(simd_ns, 1)));

    try std.json.stringify(Rec{
        .tag = "parity_perf_opt_in",
        .scalar_ns = scalar_ns,
        .simd_ns = simd_ns,
        .scalar_vectors = scalar_vectors,
        .simd_vectors = simd_vectors,
        .scalar_vps = scalar_vps,
        .simd_vps = simd_vps,
    }, .{ .whitespace = .minified }, file.writer());
    try file.writer().writeByte('\n');
}
