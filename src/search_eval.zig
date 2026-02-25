const std = @import("std");
const c = @import("cubiomes_port.zig");
const bedrock = @import("bedrock.zig");
const expr = @import("expr.zig");
const types = @import("search_types.zig");

pub const BiomeReq = types.BiomeReq;
pub const StructureReq = types.StructureReq;
pub const Constraint = types.Constraint;
pub const EvalState = types.EvalState;
pub const EvalMode = types.EvalMode;
pub const BiomeOffset = types.BiomeOffset;
pub const BiomePoint = types.BiomePoint;
pub const ClimateRange = types.ClimateRange;
pub const BiomeClimateBounds = types.BiomeClimateBounds;
pub const StructureRegion = types.StructureRegion;
pub const BiomeCompareReq = types.BiomeCompareReq;
pub const NativeShadow = types.NativeShadow;
pub const NativeBackend = types.NativeBackend;
pub const ExprNode = expr.ExprNode;

const BiomeScanResult = struct {
    best_dist2: i64,
    count: i32,
};

const BiomeTreeDef = struct {
    params: []const [2]i32,
    nodes: []const u64,
    len: u32,
};

fn selectBiomeTree(mc: i32) BiomeTreeDef {
    if (mc >= c.MC_1_21_WD) {
        return .{ .params = &c.btree21wd_param, .nodes = &c.btree21wd_nodes, .len = c.btree21wd_nodes.len };
    }
    if (mc >= c.MC_1_20_6) {
        return .{ .params = &c.btree20_param, .nodes = &c.btree20_nodes, .len = c.btree20_nodes.len };
    }
    if (mc >= c.MC_1_19_4) {
        return .{ .params = &c.btree19_param, .nodes = &c.btree19_nodes, .len = c.btree19_nodes.len };
    }
    if (mc >= c.MC_1_19_2) {
        return .{ .params = &c.btree192_param, .nodes = &c.btree192_nodes, .len = c.btree192_nodes.len };
    }
    return .{ .params = &c.btree18_param, .nodes = &c.btree18_nodes, .len = c.btree18_nodes.len };
}

pub fn precomputeBiomeClimateBounds(mc: i32, biome_id: i32) ?BiomeClimateBounds {
    if (biome_id < 0 or biome_id > 255) return null;
    const tree = selectBiomeTree(mc);
    const biome_u8: u8 = @intCast(biome_id);

    var out = BiomeClimateBounds{
        .ranges = undefined,
        .valid = false,
    };

    for (tree.nodes) |node| {
        const node_biome: u8 = @truncate((node >> 48) & 0xff);
        if (node_biome != biome_u8) continue;

        if (!out.valid) {
            for (0..6) |dim| {
                const shift: u6 = @intCast(dim * 8);
                const param_idx: usize = @intCast((node >> shift) & 0xff);
                const p = tree.params[param_idx];
                out.ranges[dim] = .{ .lo = p[0], .hi = p[1] };
            }
            out.valid = true;
            continue;
        }

        for (0..6) |dim| {
            const shift: u6 = @intCast(dim * 8);
            const param_idx: usize = @intCast((node >> shift) & 0xff);
            const p = tree.params[param_idx];
            out.ranges[dim].lo = @min(out.ranges[dim].lo, p[0]);
            out.ranges[dim].hi = @max(out.ranges[dim].hi, p[1]);
        }
    }
    if (!out.valid) return null;
    return out;
}

inline fn npBit(dim: usize) u6 {
    return @as(u6, 1) << @as(std.math.Log2Int(u6), @intCast(dim));
}

fn isBiomeFeasible(bounds: BiomeClimateBounds, np_values: [6]i64, np_known: u6) bool {
    if (!bounds.valid) return true;
    for (0..6) |dim| {
        const bit = npBit(dim);
        if ((np_known & bit) == 0) continue;
        const v = np_values[dim];
        const lo = @as(i64, bounds.ranges[dim].lo);
        const hi = @as(i64, bounds.ranges[dim].hi);
        if (v < lo or v > hi) return false;
    }
    return true;
}

fn fastBiomeIdWithFeasibility(g: *c.Generator, x: i32, z: i32, bounds: BiomeClimateBounds) i32 {
    const bn = &g.unnamed_0.unnamed_1.bn;
    var np: [6]i64 = undefined;
    var np_known: u6 = 0;

    var sx: c_int = undefined;
    var sy: c_int = undefined;
    var sz: c_int = undefined;
    c.voronoiAccess3D(g.sha, x, 0, z, &sx, &sy, &sz);

    var px = @as(f64, @floatFromInt(sx));
    var pz = @as(f64, @floatFromInt(sz));

    px += c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_SHIFT))], @as(f64, @floatFromInt(sx)), 0.0, @as(f64, @floatFromInt(sz))) * 4.0;
    pz += c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_SHIFT))], @as(f64, @floatFromInt(sz)), @as(f64, @floatFromInt(sx)), 0.0) * 4.0;

    const c_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_CONTINENTALNESS))], px, 0.0, pz)));
    np[@as(usize, @intCast(c.NP_CONTINENTALNESS))] = @as(i64, @intFromFloat(10000.0 * c_val));
    np_known |= npBit(@as(usize, @intCast(c.NP_CONTINENTALNESS)));
    if (!isBiomeFeasible(bounds, np, np_known)) return c.none;

    const e_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_EROSION))], px, 0.0, pz)));
    np[@as(usize, @intCast(c.NP_EROSION))] = @as(i64, @intFromFloat(10000.0 * e_val));
    np_known |= npBit(@as(usize, @intCast(c.NP_EROSION)));
    if (!isBiomeFeasible(bounds, np, np_known)) return c.none;

    const w_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_WEIRDNESS))], px, 0.0, pz)));
    np[@as(usize, @intCast(c.NP_WEIRDNESS))] = @as(i64, @intFromFloat(10000.0 * w_val));
    np_known |= npBit(@as(usize, @intCast(c.NP_WEIRDNESS)));
    if (!isBiomeFeasible(bounds, np, np_known)) return c.none;

    const np_param: [4]f32 = .{
        c_val,
        e_val,
        -3.0 * (@abs(@abs(w_val) - 0.6666666865348816) - 0.3333333432674408),
        w_val,
    };
    const off = @as(f64, @floatCast(c.getSpline(bn.sp, @constCast(@ptrCast(&np_param))) + 0.014999999664723873));
    const d_val = @as(f32, @floatCast(((1.0 - (@as(f64, @floatFromInt(sy * 4)) / 128.0)) - (83.0 / 160.0)) + off));
    np[@as(usize, @intCast(c.NP_DEPTH))] = @as(i64, @intFromFloat(10000.0 * d_val));
    np_known |= npBit(@as(usize, @intCast(c.NP_DEPTH)));
    if (!isBiomeFeasible(bounds, np, np_known)) return c.none;

    const t_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_TEMPERATURE))], px, 0.0, pz)));
    np[@as(usize, @intCast(c.NP_TEMPERATURE))] = @as(i64, @intFromFloat(10000.0 * t_val));
    np_known |= npBit(@as(usize, @intCast(c.NP_TEMPERATURE)));
    if (!isBiomeFeasible(bounds, np, np_known)) return c.none;

    const h_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_HUMIDITY))], px, 0.0, pz)));
    np[@as(usize, @intCast(c.NP_HUMIDITY))] = @as(i64, @intFromFloat(10000.0 * h_val));

    return c.climateToBiome(bn.mc, @ptrCast(@alignCast(&np)), null);
}

fn maybeFastBiomeId(g: *c.Generator, x: i32, z: i32, climate_bounds: ?BiomeClimateBounds) ?i32 {
    if (!biome_climate_early_exit_enabled) return null;
    const bounds = climate_bounds orelse return null;
    if (!bounds.valid) return null;
    if (g.mc < c.MC_1_18) return null;
    if (g.dim != c.DIM_OVERWORLD) return null;
    if (g.unnamed_0.unnamed_1.bn.nptype != -1) return null;
    return fastBiomeIdWithFeasibility(g, x, z, bounds);
}

const CachedBiomeSampler = struct {
    g: *c.Generator,
    cache: [*c]c_int,
    range: c.Range,

    fn init(g: *c.Generator, scale: c_int, y: c_int) ?CachedBiomeSampler {
        const r = c.Range{
            .scale = scale,
            .x = 0,
            .z = 0,
            .sx = 1,
            .sz = 1,
            .y = y,
            .sy = 1,
        };
        const cache = c.allocCache(g, r);
        if (cache == null) return null;
        return .{
            .g = g,
            .cache = cache,
            .range = r,
        };
    }

    fn deinit(self: *CachedBiomeSampler) void {
        c.free(@as(?*anyopaque, @ptrCast(self.cache)));
    }

    fn getBiomeAt(self: *CachedBiomeSampler, x: i32, z: i32) i32 {
        self.range.x = x;
        self.range.z = z;
        if (c.genBiomes(self.g, self.cache, self.range) == 0) {
            return self.cache[0];
        }
        return c.getBiomeAt(self.g, self.range.scale, x, self.range.y, z);
    }
};

const CachedBiomeRowSampler = struct {
    g: *c.Generator,
    cache: [*c]c_int,
    range: c.Range,

    fn init(g: *c.Generator, scale: c_int, y: c_int, max_width: i32) ?CachedBiomeRowSampler {
        if (max_width <= 0) return null;
        const r = c.Range{
            .scale = scale,
            .x = 0,
            .z = 0,
            .sx = max_width,
            .sz = 1,
            .y = y,
            .sy = 1,
        };
        const cache = c.allocCache(g, r);
        if (cache == null) return null;
        return .{
            .g = g,
            .cache = cache,
            .range = r,
        };
    }

    fn deinit(self: *CachedBiomeRowSampler) void {
        c.free(@as(?*anyopaque, @ptrCast(self.cache)));
    }

    fn sampleRow(self: *CachedBiomeRowSampler, start_x: i32, z: i32, width: i32) bool {
        self.range.x = start_x;
        self.range.z = z;
        self.range.sx = width;
        self.range.sz = 1;
        return c.genBiomes(self.g, self.cache, self.range) == 0;
    }

    fn getBiomeAt(self: *const CachedBiomeRowSampler, dx: i32) i32 {
        return self.cache[@as(usize, @intCast(dx))];
    }
};

const RowRun = struct {
    start: usize,
    end: usize,
    z: i32,
    min_x: i32,
    max_x: i32,
};

fn rowRunWidth(run: RowRun) i32 {
    return run.max_x - run.min_x + 1;
}

fn sampleBiomeScalar(g: *c.Generator, sampler_opt: *?CachedBiomeSampler, x: i32, z: i32, climate_bounds: ?BiomeClimateBounds) i32 {
    if (maybeFastBiomeId(g, x, z, climate_bounds)) |id| return id;
    return if (sampler_opt.*) |*sampler|
        sampler.getBiomeAt(x, z)
    else
        c.getBiomeAt(g, 1, x, 0, z);
}

fn nextOffsetRun(center: c.Pos, offsets: []const BiomeOffset, start: usize) RowRun {
    const first = offsets[start];
    const z = center.z + first.dz;
    const min_x = center.x + first.dx;
    var max_x = min_x;
    var prev_x = min_x;
    var i = start + 1;
    while (i < offsets.len) : (i += 1) {
        const off = offsets[i];
        const x = center.x + off.dx;
        const row_z = center.z + off.dz;
        if (row_z != z or x != prev_x + 4) break;
        prev_x = x;
        max_x = x;
    }
    return .{
        .start = start,
        .end = i,
        .z = z,
        .min_x = min_x,
        .max_x = max_x,
    };
}

fn nextPointRun(points: []const BiomePoint, start: usize) RowRun {
    const first = points[start];
    const z = first.z;
    const min_x = first.x;
    var max_x = min_x;
    var prev_x = min_x;
    var i = start + 1;
    while (i < points.len) : (i += 1) {
        const pt = points[i];
        if (pt.z != z or pt.x != prev_x + 4) break;
        prev_x = pt.x;
        max_x = pt.x;
    }
    return .{
        .start = start,
        .end = i,
        .z = z,
        .min_x = min_x,
        .max_x = max_x,
    };
}

fn maxOffsetRunWidth(center: c.Pos, offsets: []const BiomeOffset) i32 {
    if (offsets.len == 0) return 0;
    var i: usize = 0;
    var max_width: i32 = 1;
    while (i < offsets.len) {
        const run = nextOffsetRun(center, offsets, i);
        const width = rowRunWidth(run);
        if (width > max_width) max_width = width;
        i = run.end;
    }
    return max_width;
}

fn maxPointRunWidth(points: []const BiomePoint) i32 {
    if (points.len == 0) return 0;
    var i: usize = 0;
    var max_width: i32 = 1;
    while (i < points.len) {
        const run = nextPointRun(points, i);
        const width = rowRunWidth(run);
        if (width > max_width) max_width = width;
        i = run.end;
    }
    return max_width;
}

fn floorDiv(a: i32, b: i32) i32 {
    return std.math.divFloor(i32, a, b) catch unreachable;
}

pub const EvalTelemetry = struct {
    seeds_tested: u64 = 0,
    eval_total_ns: u128 = 0,
    biome_eval_ns: u128 = 0,
    structure_eval_ns: u128 = 0,
    biome_constraint_evals: u64 = 0,
    structure_constraint_evals: u64 = 0,
    structure_region_candidates: u64 = 0,
    structure_region_bbox_rejects: u64 = 0,
    structure_get_pos_calls: u64 = 0,
    structure_within_radius: u64 = 0,
    structure_viable_pos_checks: u64 = 0,
    structure_viable_terrain_checks: u64 = 0,
    structure_matches: u64 = 0,
};

var active_eval_telemetry: ?*EvalTelemetry = null;
var structure_bbox_prune_enabled = true;
var conjunctive_cost_order_enabled = true;
var structure_fast_pos_enabled = true;
var biome_climate_early_exit_enabled = true;

pub fn setEvalTelemetry(telemetry: ?*EvalTelemetry) void {
    active_eval_telemetry = telemetry;
}

pub fn noteEvalSeedTested() void {
    if (active_eval_telemetry) |telemetry| {
        telemetry.seeds_tested +%= 1;
    }
}

pub fn setOptimizationToggles(structure_bbox_prune: bool, conjunctive_cost_order: bool) void {
    structure_bbox_prune_enabled = structure_bbox_prune;
    conjunctive_cost_order_enabled = conjunctive_cost_order;
}

pub fn setStructureFastPosEnabled(enabled: bool) void {
    structure_fast_pos_enabled = enabled;
}

pub fn setBiomeClimateEarlyExitEnabled(enabled: bool) void {
    biome_climate_early_exit_enabled = enabled;
}

inline fn getStructurePosForReq(req: StructureReq, mc: i32, seed: u64, reg_x: i32, reg_z: i32) ?bedrock.Pos {
    if (!structure_fast_pos_enabled) {
        return bedrock.getStructurePosC(req.structure_c, mc, seed, reg_x, reg_z);
    }
    return bedrock.getStructurePosFast(req.structure_c, mc, seed, reg_x, reg_z, req.pos_mode, req.cfg_raw);
}

fn chunkRange(cfg: bedrock.StructureConfig) i32 {
    return cfg.spacing - cfg.separation;
}

fn axisDistanceToInterval(point: i64, lo: i64, hi: i64) i64 {
    if (point < lo) return lo - point;
    if (point > hi) return point - hi;
    return 0;
}

fn regionMayIntersectRadius(center: c.Pos, cfg: bedrock.StructureConfig, reg_x: i32, reg_z: i32, radius2: i64) bool {
    const range = chunkRange(cfg);
    if (range <= 0) return false;

    const spacing_i64 = @as(i64, cfg.spacing);
    const reg_x_base = @as(i64, reg_x) * spacing_i64;
    const reg_z_base = @as(i64, reg_z) * spacing_i64;

    const min_x = (reg_x_base << 4) + 8;
    const min_z = (reg_z_base << 4) + 8;
    const max_x = ((reg_x_base + @as(i64, range - 1)) << 4) + 8;
    const max_z = ((reg_z_base + @as(i64, range - 1)) << 4) + 8;

    const dx = axisDistanceToInterval(@as(i64, center.x), min_x, max_x);
    const dz = axisDistanceToInterval(@as(i64, center.z), min_z, max_z);
    return (dx * dx) + (dz * dz) <= radius2;
}

fn regionMinDistance2ToCenter(center: c.Pos, cfg: bedrock.StructureConfig, reg: StructureRegion) i64 {
    const range = chunkRange(cfg);
    if (range <= 0) return std.math.maxInt(i64);

    const spacing_i64 = @as(i64, cfg.spacing);
    const reg_x_base = @as(i64, reg.reg_x) * spacing_i64;
    const reg_z_base = @as(i64, reg.reg_z) * spacing_i64;

    const min_x = (reg_x_base << 4) + 8;
    const min_z = (reg_z_base << 4) + 8;
    const max_x = ((reg_x_base + @as(i64, range - 1)) << 4) + 8;
    const max_z = ((reg_z_base + @as(i64, range - 1)) << 4) + 8;

    const dx = axisDistanceToInterval(@as(i64, center.x), min_x, max_x);
    const dz = axisDistanceToInterval(@as(i64, center.z), min_z, max_z);
    return (dx * dx) + (dz * dz);
}

pub fn nativeBiomeProxyCount(req: BiomeReq, g: *c.Generator, anchor: c.Pos, needed: i32) i32 {
    if (needed <= 0) return 0;
    var count: i32 = 0;
    var sampler_opt = CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();

    if (req.points.len > 0) {
        for (req.points) |pt| {
            const id = if (sampler_opt) |*sampler|
                sampler.getBiomeAt(pt.x, pt.z)
            else
                c.getBiomeAt(g, 1, pt.x, 0, pt.z);
            if (id == req.biome_id) count += 1;
            if (count >= needed) break;
        }
    } else {
        for (req.offsets) |off| {
            const x = anchor.x + off.dx;
            const z = anchor.z + off.dz;
            const id = if (sampler_opt) |*sampler|
                sampler.getBiomeAt(x, z)
            else
                c.getBiomeAt(g, 1, x, 0, z);
            if (id == req.biome_id) count += 1;
            if (count >= needed) break;
        }
    }
    return count;
}

pub fn biomeProxyNeeded(req: BiomeReq) i32 {
    const points_len = if (req.points.len > 0) req.points.len else req.offsets.len;
    if (points_len > 1024 and req.min_count <= 8) return 1;
    return req.min_count;
}

pub fn nativeCompareNeeded(req: BiomeReq, cmp_req: BiomeCompareReq, strict: bool) i32 {
    return if (strict) req.min_count else cmp_req.proxy_needed;
}

pub fn evalBiomeThresholdAndProxy(
    req: BiomeReq,
    eval: *EvalState,
    eval_epoch: u64,
    g: *c.Generator,
    anchor: c.Pos,
    needed: i32,
) struct { c_pass: bool, native_pass: bool } {
    var count: i32 = 0;
    var c_pass = false;
    var native_pass = false;
    var sampler_opt = CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();

    if (req.points.len > 0) {
        var remaining: i32 = @intCast(req.points.len);
        for (req.points) |pt| {
            remaining -= 1;
            const id = if (sampler_opt) |*sampler|
                sampler.getBiomeAt(pt.x, pt.z)
            else
                c.getBiomeAt(g, 1, pt.x, 0, pt.z);
            if (id == req.biome_id) {
                count += 1;
                if (!native_pass and count >= needed) native_pass = true;
                if (count >= req.min_count) {
                    c_pass = true;
                    break;
                }
            }
            if (count + remaining < req.min_count) break;
        }
    } else {
        var remaining: i32 = @intCast(req.offsets.len);
        for (req.offsets) |off| {
            remaining -= 1;
            const x = anchor.x + off.dx;
            const z = anchor.z + off.dz;
            const id = if (sampler_opt) |*sampler|
                sampler.getBiomeAt(x, z)
            else
                c.getBiomeAt(g, 1, x, 0, z);
            if (id == req.biome_id) {
                count += 1;
                if (!native_pass and count >= needed) native_pass = true;
                if (count >= req.min_count) {
                    c_pass = true;
                    break;
                }
            }
            if (count + remaining < req.min_count) break;
        }
    }

    eval.* = .{
        .epoch = eval_epoch,
        .computed = true,
        .finalized = false,
        .matched = c_pass,
        .best_dist2 = std.math.maxInt(i64),
        .count = if (c_pass) req.min_count else 0,
    };
    return .{ .c_pass = c_pass, .native_pass = native_pass };
}

pub fn buildBiomeCompareReqs(
    allocator: std.mem.Allocator,
    constraints: []const Constraint,
    aliases: []const usize,
    biome_indices: []const usize,
) ![]BiomeCompareReq {
    var out = std.ArrayList(BiomeCompareReq).init(allocator);
    defer out.deinit();

    for (biome_indices) |bi| {
        const alias_idx = aliases[bi];
        var found = false;
        for (out.items) |*entry| {
            if (entry.idx != alias_idx) continue;
            entry.weight +%= 1;
            found = true;
            break;
        }
        if (found) continue;
        const req = constraints[alias_idx].biome;
        try out.append(.{
            .idx = alias_idx,
            .proxy_needed = biomeProxyNeeded(req),
            .weight = 1,
        });
    }
    return out.toOwnedSlice();
}

pub fn runNativeComparePass(
    constraints: []const Constraint,
    evals: []EvalState,
    eval_epoch: u64,
    g: *c.Generator,
    anchor: c.Pos,
    biome_compare_reqs: []const BiomeCompareReq,
    native_shadow: *NativeShadow,
    native_backend: *NativeBackend,
) !void {
    if (!native_shadow.enabled and !native_backend.compare_only) return;

    for (biome_compare_reqs) |cmp_req| {
        const bi = cmp_req.idx;
        const req = constraints[bi].biome;
        const needed = nativeCompareNeeded(req, cmp_req, native_backend.strict);
        const compare = evalBiomeThresholdAndProxy(req, &evals[bi], eval_epoch, g, anchor, needed);
        const c_pass = compare.c_pass;
        const native_pass = compare.native_pass;
        const mismatch = c_pass != native_pass;
        const weight: u64 = cmp_req.weight;

        if (native_shadow.enabled) {
            native_shadow.biome_proxy_compared +%= weight;
            if (mismatch) native_shadow.biome_proxy_mismatch +%= weight;
        }
        if (native_backend.compare_only) {
            native_backend.compared +%= weight;
            if (mismatch) {
                native_backend.mismatch +%= weight;
                if (native_backend.strict) return error.NativeBackendParityFailed;
            }
        }
    }
}

pub fn buildStructureRegionsForAnchor(
    allocator: std.mem.Allocator,
    center: c.Pos,
    req: StructureReq,
) ![]StructureRegion {
    const cfg = req.cfg orelse return allocator.alloc(StructureRegion, 0);

    const min_x = center.x - req.radius;
    const max_x = center.x + req.radius;
    const min_z = center.z - req.radius;
    const max_z = center.z + req.radius;

    const min_attempt_chunk_x = floorDiv(min_x - 8, 16);
    const max_attempt_chunk_x = floorDiv(max_x - 8, 16);
    const min_attempt_chunk_z = floorDiv(min_z - 8, 16);
    const max_attempt_chunk_z = floorDiv(max_z - 8, 16);

    const min_reg_x = floorDiv(min_attempt_chunk_x - (cfg.spacing - 1), cfg.spacing);
    const max_reg_x = floorDiv(max_attempt_chunk_x, cfg.spacing);
    const min_reg_z = floorDiv(min_attempt_chunk_z - (cfg.spacing - 1), cfg.spacing);
    const max_reg_z = floorDiv(max_attempt_chunk_z, cfg.spacing);

    var out = std.ArrayList(StructureRegion).init(allocator);
    errdefer out.deinit();
    var reg_z = min_reg_z;
    while (reg_z <= max_reg_z) : (reg_z += 1) {
        var reg_x = min_reg_x;
        while (reg_x <= max_reg_x) : (reg_x += 1) {
            if (structure_bbox_prune_enabled and !regionMayIntersectRadius(center, cfg, reg_x, reg_z, req.radius2)) continue;
            try out.append(.{ .reg_x = reg_x, .reg_z = reg_z });
        }
    }

    if (out.items.len > 1) {
        const SortCtx = struct { center: c.Pos, cfg: bedrock.StructureConfig };
        const sort_ctx = SortCtx{ .center = center, .cfg = cfg };
        std.sort.heap(StructureRegion, out.items, sort_ctx, struct {
            fn lessThan(ctx: SortCtx, a: StructureRegion, b: StructureRegion) bool {
                const da = regionMinDistance2ToCenter(ctx.center, ctx.cfg, a);
                const db = regionMinDistance2ToCenter(ctx.center, ctx.cfg, b);
                if (da == db) {
                    if (a.reg_z == b.reg_z) return a.reg_x < b.reg_x;
                    return a.reg_z < b.reg_z;
                }
                return da < db;
            }
        }.lessThan);
    }
    return out.toOwnedSlice();
}

pub fn buildBiomeOffsets(allocator: std.mem.Allocator, radius: i32) ![]BiomeOffset {
    return buildBiomeOffsetsStrided(allocator, radius, 1);
}

pub fn buildBiomeOffsetsStrided(allocator: std.mem.Allocator, radius: i32, stride: i32) ![]BiomeOffset {
    if (stride <= 0) return error.InvalidStride;
    const step: i32 = 4 * stride;
    const r2: i64 = @as(i64, radius) * radius;
    var out = std.ArrayList(BiomeOffset).init(allocator);
    errdefer out.deinit();

    var dz: i32 = -radius;
    while (dz <= radius) : (dz += step) {
        var dx: i32 = -radius;
        while (dx <= radius) : (dx += step) {
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            try out.append(.{ .dx = dx, .dz = dz, .dist2 = dist2 });
        }
    }
    return out.toOwnedSlice();
}

fn selectBiomeMatchStride(min_count: i32) i32 {
    if (min_count >= 16) return 4;
    if (min_count >= 4) return 2;
    return 1;
}

pub fn buildBiomePointsForAnchor(allocator: std.mem.Allocator, center: c.Pos, offsets: []const BiomeOffset) ![]BiomePoint {
    var out = try allocator.alloc(BiomePoint, offsets.len);
    for (offsets, 0..) |off, i| {
        out[i] = .{
            .x = center.x + off.dx,
            .z = center.z + off.dz,
            .dist2 = off.dist2,
        };
    }
    return out;
}

fn scanBiomeWithinRadiusWithBounds(g: *c.Generator, center: c.Pos, biome_id: i32, offsets: []const BiomeOffset, climate_bounds: ?BiomeClimateBounds) BiomeScanResult {
    var best: i64 = std.math.maxInt(i64);
    var count: i32 = 0;
    const fast_enabled = maybeFastBiomeId(g, center.x, center.z, climate_bounds) != null;
    var sampler_opt: ?CachedBiomeSampler = if (fast_enabled) null else CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt: ?CachedBiomeRowSampler = if (fast_enabled) null else CachedBiomeRowSampler.init(g, 1, 0, maxOffsetRunWidth(center, offsets));
    defer if (row_sampler_opt) |*sampler| sampler.deinit();

    var i: usize = 0;
    while (i < offsets.len) {
        const run = nextOffsetRun(center, offsets, i);
        const run_width = rowRunWidth(run);
        var row_ready = false;
        var row_sampler_ptr: ?*CachedBiomeRowSampler = null;
        if (row_sampler_opt) |*row_sampler| {
            row_sampler_ptr = row_sampler;
            row_ready = row_sampler.sampleRow(run.min_x, run.z, run_width);
        }
        var j = run.start;
        while (j < run.end) : (j += 1) {
            const off = offsets[j];
            const x = center.x + off.dx;
            const id = if (row_ready)
                row_sampler_ptr.?.getBiomeAt(x - run.min_x)
            else
                sampleBiomeScalar(g, &sampler_opt, x, run.z, climate_bounds);
            if (id != biome_id) continue;
            count += 1;
            if (off.dist2 < best) best = off.dist2;
        }
        i = run.end;
    }

    return .{ .best_dist2 = best, .count = count };
}

pub fn scanBiomeWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, offsets: []const BiomeOffset) BiomeScanResult {
    return scanBiomeWithinRadiusWithBounds(g, center, biome_id, offsets, null);
}

fn scanBiomePointsWithBounds(g: *c.Generator, biome_id: i32, points: []const BiomePoint, climate_bounds: ?BiomeClimateBounds) BiomeScanResult {
    var best: i64 = std.math.maxInt(i64);
    var count: i32 = 0;
    const fast_enabled = points.len > 0 and maybeFastBiomeId(g, points[0].x, points[0].z, climate_bounds) != null;
    var sampler_opt: ?CachedBiomeSampler = if (fast_enabled) null else CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt: ?CachedBiomeRowSampler = if (fast_enabled) null else CachedBiomeRowSampler.init(g, 1, 0, maxPointRunWidth(points));
    defer if (row_sampler_opt) |*sampler| sampler.deinit();

    var i: usize = 0;
    while (i < points.len) {
        const run = nextPointRun(points, i);
        const run_width = rowRunWidth(run);
        var row_ready = false;
        var row_sampler_ptr: ?*CachedBiomeRowSampler = null;
        if (row_sampler_opt) |*row_sampler| {
            row_sampler_ptr = row_sampler;
            row_ready = row_sampler.sampleRow(run.min_x, run.z, run_width);
        }
        var j = run.start;
        while (j < run.end) : (j += 1) {
            const pt = points[j];
            const id = if (row_ready)
                row_sampler_ptr.?.getBiomeAt(pt.x - run.min_x)
            else
                sampleBiomeScalar(g, &sampler_opt, pt.x, pt.z, climate_bounds);
            if (id != biome_id) continue;
            count += 1;
            if (pt.dist2 < best) best = pt.dist2;
        }
        i = run.end;
    }
    return .{ .best_dist2 = best, .count = count };
}

pub fn scanBiomePoints(g: *c.Generator, biome_id: i32, points: []const BiomePoint) BiomeScanResult {
    return scanBiomePointsWithBounds(g, biome_id, points, null);
}

fn biomeMatchesWithinRadiusWithBounds(g: *c.Generator, center: c.Pos, biome_id: i32, min_count: i32, offsets: []const BiomeOffset, climate_bounds: ?BiomeClimateBounds) bool {
    if (min_count <= 0) return true;
    var count: i32 = 0;
    const fast_enabled = maybeFastBiomeId(g, center.x, center.z, climate_bounds) != null;
    var sampler_opt: ?CachedBiomeSampler = if (fast_enabled) null else CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt: ?CachedBiomeRowSampler = if (fast_enabled) null else CachedBiomeRowSampler.init(g, 1, 0, maxOffsetRunWidth(center, offsets));
    defer if (row_sampler_opt) |*sampler| sampler.deinit();

    var i: usize = 0;
    while (i < offsets.len) {
        const run = nextOffsetRun(center, offsets, i);
        const run_width = rowRunWidth(run);
        var row_ready = false;
        var row_sampler_ptr: ?*CachedBiomeRowSampler = null;
        if (row_sampler_opt) |*row_sampler| {
            row_sampler_ptr = row_sampler;
            row_ready = row_sampler.sampleRow(run.min_x, run.z, run_width);
        }
        var j = run.start;
        while (j < run.end) : (j += 1) {
            const off = offsets[j];
            const x = center.x + off.dx;
            const id = if (row_ready)
                row_sampler_ptr.?.getBiomeAt(x - run.min_x)
            else
                sampleBiomeScalar(g, &sampler_opt, x, run.z, climate_bounds);
            if (id == biome_id) {
                count += 1;
                if (count >= min_count) return true;
            }
            const remaining = offsets.len - j - 1;
            if (count + @as(i32, @intCast(remaining)) < min_count) return false;
        }
        i = run.end;
    }
    return false;
}

pub fn biomeMatchesWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, min_count: i32, offsets: []const BiomeOffset) bool {
    return biomeMatchesWithinRadiusWithBounds(g, center, biome_id, min_count, offsets, null);
}

fn biomeMatchesPointsWithBounds(g: *c.Generator, biome_id: i32, min_count: i32, points: []const BiomePoint, climate_bounds: ?BiomeClimateBounds) bool {
    if (min_count <= 0) return true;
    var count: i32 = 0;
    const fast_enabled = points.len > 0 and maybeFastBiomeId(g, points[0].x, points[0].z, climate_bounds) != null;
    var sampler_opt: ?CachedBiomeSampler = if (fast_enabled) null else CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt: ?CachedBiomeRowSampler = if (fast_enabled) null else CachedBiomeRowSampler.init(g, 1, 0, maxPointRunWidth(points));
    defer if (row_sampler_opt) |*sampler| sampler.deinit();

    var i: usize = 0;
    while (i < points.len) {
        const run = nextPointRun(points, i);
        const run_width = rowRunWidth(run);
        var row_ready = false;
        var row_sampler_ptr: ?*CachedBiomeRowSampler = null;
        if (row_sampler_opt) |*row_sampler| {
            row_sampler_ptr = row_sampler;
            row_ready = row_sampler.sampleRow(run.min_x, run.z, run_width);
        }
        var j = run.start;
        while (j < run.end) : (j += 1) {
            const pt = points[j];
            const id = if (row_ready)
                row_sampler_ptr.?.getBiomeAt(pt.x - run.min_x)
            else
                sampleBiomeScalar(g, &sampler_opt, pt.x, pt.z, climate_bounds);
            if (id == biome_id) {
                count += 1;
                if (count >= min_count) return true;
            }
            const remaining = points.len - j - 1;
            if (count + @as(i32, @intCast(remaining)) < min_count) return false;
        }
        i = run.end;
    }
    return false;
}

pub fn biomeMatchesPoints(g: *c.Generator, biome_id: i32, min_count: i32, points: []const BiomePoint) bool {
    return biomeMatchesPointsWithBounds(g, biome_id, min_count, points, null);
}

pub fn bestBiomeDistanceWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, offsets: []const BiomeOffset) ?i64 {
    const result = scanBiomeWithinRadius(g, center, biome_id, offsets);
    if (result.count == 0) return null;
    return result.best_dist2;
}

pub fn bestStructureDistanceWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) ?i64 {
    const r2 = req.radius2;
    var best: i64 = std.math.maxInt(i64);
    const telemetry = active_eval_telemetry;

    if (req.regions.len != 0) {
        for (req.regions) |reg| {
            if (telemetry) |t| t.structure_region_candidates +%= 1;
            if (telemetry) |t| t.structure_get_pos_calls +%= 1;
            const pos = getStructurePosForReq(req, mc, seed, reg.reg_x, reg.reg_z) orelse continue;
            const dx = pos.x - center.x;
            const dz = pos.z - center.z;
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            if (telemetry) |t| t.structure_within_radius +%= 1;
            if (telemetry) |t| t.structure_viable_pos_checks +%= 1;
            if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
            if (telemetry) |t| t.structure_viable_terrain_checks +%= 1;
            if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
            if (telemetry) |t| t.structure_matches +%= 1;
            if (dist2 < best) best = dist2;
        }
    } else {
        const cfg = req.cfg orelse return null;
        const min_x = center.x - req.radius;
        const max_x = center.x + req.radius;
        const min_z = center.z - req.radius;
        const max_z = center.z + req.radius;
        const min_attempt_chunk_x = floorDiv(min_x - 8, 16);
        const max_attempt_chunk_x = floorDiv(max_x - 8, 16);
        const min_attempt_chunk_z = floorDiv(min_z - 8, 16);
        const max_attempt_chunk_z = floorDiv(max_z - 8, 16);
        const min_reg_x = floorDiv(min_attempt_chunk_x - (cfg.spacing - 1), cfg.spacing);
        const max_reg_x = floorDiv(max_attempt_chunk_x, cfg.spacing);
        const min_reg_z = floorDiv(min_attempt_chunk_z - (cfg.spacing - 1), cfg.spacing);
        const max_reg_z = floorDiv(max_attempt_chunk_z, cfg.spacing);
        var reg_z = min_reg_z;
        while (reg_z <= max_reg_z) : (reg_z += 1) {
            var reg_x = min_reg_x;
            while (reg_x <= max_reg_x) : (reg_x += 1) {
                if (telemetry) |t| t.structure_region_candidates +%= 1;
                if (structure_bbox_prune_enabled and !regionMayIntersectRadius(center, cfg, reg_x, reg_z, r2)) {
                    if (telemetry) |t| t.structure_region_bbox_rejects +%= 1;
                    continue;
                }
                if (telemetry) |t| t.structure_get_pos_calls +%= 1;
                const pos = getStructurePosForReq(req, mc, seed, reg_x, reg_z) orelse continue;
                const dx = pos.x - center.x;
                const dz = pos.z - center.z;
                const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
                if (dist2 > r2) continue;
                if (telemetry) |t| t.structure_within_radius +%= 1;
                if (telemetry) |t| t.structure_viable_pos_checks +%= 1;
                if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
                if (telemetry) |t| t.structure_viable_terrain_checks +%= 1;
                if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
                if (telemetry) |t| t.structure_matches +%= 1;
                if (dist2 < best) best = dist2;
            }
        }
    }

    if (best == std.math.maxInt(i64)) return null;
    return best;
}

pub fn anyStructureWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) bool {
    const r2 = req.radius2;
    const telemetry = active_eval_telemetry;

    if (req.regions.len != 0) {
        for (req.regions) |reg| {
            if (telemetry) |t| t.structure_region_candidates +%= 1;
            if (telemetry) |t| t.structure_get_pos_calls +%= 1;
            const pos = getStructurePosForReq(req, mc, seed, reg.reg_x, reg.reg_z) orelse continue;
            const dx = pos.x - center.x;
            const dz = pos.z - center.z;
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            if (telemetry) |t| t.structure_within_radius +%= 1;
            if (telemetry) |t| t.structure_viable_pos_checks +%= 1;
            if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
            if (telemetry) |t| t.structure_viable_terrain_checks +%= 1;
            if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
            if (telemetry) |t| {
                t.structure_matches +%= 1;
            }
            return true;
        }
        return false;
    }

    const cfg = req.cfg orelse return false;
    const min_x = center.x - req.radius;
    const max_x = center.x + req.radius;
    const min_z = center.z - req.radius;
    const max_z = center.z + req.radius;
    const min_attempt_chunk_x = floorDiv(min_x - 8, 16);
    const max_attempt_chunk_x = floorDiv(max_x - 8, 16);
    const min_attempt_chunk_z = floorDiv(min_z - 8, 16);
    const max_attempt_chunk_z = floorDiv(max_z - 8, 16);
    const min_reg_x = floorDiv(min_attempt_chunk_x - (cfg.spacing - 1), cfg.spacing);
    const max_reg_x = floorDiv(max_attempt_chunk_x, cfg.spacing);
    const min_reg_z = floorDiv(min_attempt_chunk_z - (cfg.spacing - 1), cfg.spacing);
    const max_reg_z = floorDiv(max_attempt_chunk_z, cfg.spacing);
    var reg_z = min_reg_z;
    while (reg_z <= max_reg_z) : (reg_z += 1) {
        var reg_x = min_reg_x;
        while (reg_x <= max_reg_x) : (reg_x += 1) {
            if (telemetry) |t| t.structure_region_candidates +%= 1;
            if (structure_bbox_prune_enabled and !regionMayIntersectRadius(center, cfg, reg_x, reg_z, r2)) {
                if (telemetry) |t| t.structure_region_bbox_rejects +%= 1;
                continue;
            }
            if (telemetry) |t| t.structure_get_pos_calls +%= 1;
            const pos = getStructurePosForReq(req, mc, seed, reg_x, reg_z) orelse continue;
            const dx = pos.x - center.x;
            const dz = pos.z - center.z;
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            if (telemetry) |t| t.structure_within_radius +%= 1;
            if (telemetry) |t| t.structure_viable_pos_checks +%= 1;
            if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
            if (telemetry) |t| t.structure_viable_terrain_checks +%= 1;
            if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
            if (telemetry) |t| {
                t.structure_matches +%= 1;
            }
            return true;
        }
    }
    return false;
}

pub fn evalConstraintAt(
    constraints: []const Constraint,
    aliases: []const usize,
    idx: usize,
    evals: []EvalState,
    eval_epoch: u64,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
    mode: EvalMode,
) bool {
    const alias_idx = aliases[idx];
    if (alias_idx != idx) {
        _ = evalConstraintAt(constraints, aliases, alias_idx, evals, eval_epoch, g, seed, mc, anchor, mode);
        evals[idx] = evals[alias_idx];
        return evals[idx].matched;
    }
    if (evals[idx].epoch != eval_epoch) {
        evals[idx] = .{ .epoch = eval_epoch };
    }
    if (evals[idx].computed and (mode == .threshold or evals[idx].finalized)) return evals[idx].matched;
    evals[idx].computed = true;
    const total_start = if (active_eval_telemetry != null) std.time.nanoTimestamp() else 0;

    const cst = constraints[idx];
    switch (cst) {
        .biome => |req| {
            const biome_start = if (active_eval_telemetry != null) std.time.nanoTimestamp() else 0;
            if (mode == .full) {
                const result = if (req.points.len > 0)
                    scanBiomePointsWithBounds(g, req.biome_id, req.points, req.climate_bounds)
                else
                    scanBiomeWithinRadiusWithBounds(g, anchor, req.biome_id, req.offsets, req.climate_bounds);
                evals[idx].count = result.count;
                evals[idx].matched = result.count >= req.min_count;
                if (evals[idx].matched) evals[idx].best_dist2 = result.best_dist2;
                evals[idx].finalized = true;
            } else {
                const matched = if (req.points.len > 0)
                    biomeMatchesPointsWithBounds(g, req.biome_id, req.min_count, req.points, req.climate_bounds)
                else blk: {
                    const stride = selectBiomeMatchStride(req.min_count);
                    const offsets = switch (stride) {
                        4 => if (req.coarse_offsets_4.len > 0) req.coarse_offsets_4 else req.offsets,
                        2 => if (req.coarse_offsets_2.len > 0) req.coarse_offsets_2 else req.offsets,
                        else => req.offsets,
                    };
                    break :blk biomeMatchesWithinRadiusWithBounds(g, anchor, req.biome_id, req.min_count, offsets, req.climate_bounds);
                };
                evals[idx].matched = matched;
                evals[idx].count = if (matched) req.min_count else 0;
                evals[idx].best_dist2 = std.math.maxInt(i64);
                evals[idx].finalized = false;
            }
            if (active_eval_telemetry) |telemetry| {
                telemetry.biome_constraint_evals +%= 1;
                telemetry.biome_eval_ns +%= @as(u128, @intCast(std.time.nanoTimestamp() - biome_start));
            }
        },
        .structure => |req| {
            const structure_start = if (active_eval_telemetry != null) std.time.nanoTimestamp() else 0;
            if (mode == .full) {
                evals[idx].matched = false;
                evals[idx].count = 0;
                evals[idx].best_dist2 = std.math.maxInt(i64);
                evals[idx].finalized = true;
                if (bestStructureDistanceWithinRadius(g, seed, mc, anchor, req)) |best| {
                    evals[idx].matched = true;
                    evals[idx].best_dist2 = best;
                }
            } else {
                evals[idx].matched = anyStructureWithinRadius(g, seed, mc, anchor, req);
                evals[idx].best_dist2 = std.math.maxInt(i64);
                evals[idx].finalized = false;
            }
            if (active_eval_telemetry) |telemetry| {
                telemetry.structure_constraint_evals +%= 1;
                telemetry.structure_eval_ns +%= @as(u128, @intCast(std.time.nanoTimestamp() - structure_start));
            }
        },
    }
    if (active_eval_telemetry) |telemetry| {
        telemetry.eval_total_ns +%= @as(u128, @intCast(std.time.nanoTimestamp() - total_start));
    }

    return evals[idx].matched;
}

pub fn evalExpr(
    nodes: []const ExprNode,
    root: usize,
    constraints: []const Constraint,
    aliases: []const usize,
    evals: []EvalState,
    eval_epoch: u64,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) bool {
    return switch (nodes[root]) {
        .literal_true => true,
        .atom => |idx| evalConstraintAt(constraints, aliases, idx, evals, eval_epoch, g, seed, mc, anchor, .threshold),
        .not => |child| !evalExpr(nodes, child, constraints, aliases, evals, eval_epoch, g, seed, mc, anchor),
        .and_op => |pair| evalExpr(nodes, pair.lhs, constraints, aliases, evals, eval_epoch, g, seed, mc, anchor) and evalExpr(nodes, pair.rhs, constraints, aliases, evals, eval_epoch, g, seed, mc, anchor),
        .or_op => |pair| evalExpr(nodes, pair.lhs, constraints, aliases, evals, eval_epoch, g, seed, mc, anchor) or evalExpr(nodes, pair.rhs, constraints, aliases, evals, eval_epoch, g, seed, mc, anchor),
    };
}

pub fn evalConjunctiveAtoms(
    atom_indices: []const usize,
    constraints: []const Constraint,
    aliases: []const usize,
    evals: []EvalState,
    eval_epoch: u64,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) bool {
    for (atom_indices) |idx| {
        if (!evalConstraintAt(constraints, aliases, idx, evals, eval_epoch, g, seed, mc, anchor, .threshold)) return false;
    }
    return true;
}

fn estimateConstraintEvalCost(cst: Constraint) u64 {
    return switch (cst) {
        .biome => |req| blk: {
            const n = if (req.points.len > 0) req.points.len else req.offsets.len;
            break :blk @as(u64, @intCast(@max(@as(usize, 1), n)));
        },
        .structure => |req| blk: {
            if (req.regions.len != 0) break :blk @as(u64, @intCast(@max(@as(usize, 1), req.regions.len)));
            if (req.cfg) |cfg| {
                const step = @as(i64, cfg.spacing) * 16;
                if (step <= 0) break :blk 64;
                const span = (@as(i64, req.radius) * 2) + (@as(i64, chunkRange(cfg)) * 16);
                const axis = @divTrunc(span + step - 1, step) + 2;
                const est = @max(@as(i64, 1), axis * axis);
                break :blk @as(u64, @intCast(est));
            }
            break :blk 128;
        },
    };
}

pub fn reorderConjunctiveAtomsByEstimatedCost(atom_indices: []usize, constraints: []const Constraint) void {
    if (!conjunctive_cost_order_enabled) return;
    std.sort.heap(usize, atom_indices, constraints, struct {
        fn lessThan(ctx: []const Constraint, a: usize, b: usize) bool {
            const ca = estimateConstraintEvalCost(ctx[a]);
            const cb = estimateConstraintEvalCost(ctx[b]);
            if (ca == cb) return a < b;
            return ca < cb;
        }
    }.lessThan);
}

pub fn evaluateAll(
    constraints: []const Constraint,
    aliases: []const usize,
    evals: []EvalState,
    eval_epoch: u64,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) void {
    for (constraints, 0..) |_, i| {
        if (aliases[i] != i) continue;
        _ = evalConstraintAt(constraints, aliases, i, evals, eval_epoch, g, seed, mc, anchor, .full);
    }
    for (constraints, 0..) |_, i| {
        const alias_idx = aliases[i];
        if (alias_idx == i) continue;
        evals[i] = evals[alias_idx];
    }
}

fn constraintsEquivalent(a: Constraint, b: Constraint) bool {
    return switch (a) {
        .biome => |x| switch (b) {
            .biome => |y| x.biome_id == y.biome_id and x.radius == y.radius and x.min_count == y.min_count,
            else => false,
        },
        .structure => |x| switch (b) {
            .structure => |y| x.structure == y.structure and x.radius == y.radius,
            else => false,
        },
    };
}

pub fn buildConstraintAliases(allocator: std.mem.Allocator, constraints: []const Constraint) ![]usize {
    var aliases = try allocator.alloc(usize, constraints.len);
    for (constraints, 0..) |cst, i| {
        aliases[i] = i;
        var j: usize = 0;
        while (j < i) : (j += 1) {
            if (constraintsEquivalent(cst, constraints[j])) {
                aliases[i] = j;
                break;
            }
        }
    }
    return aliases;
}

pub fn summarize(constraints: []const Constraint, evals: []const EvalState) struct { matched: usize, score: f64 } {
    var matched: usize = 0;
    var score: f64 = 0;

    for (constraints, 0..) |cst, i| {
        if (!evals[i].matched) continue;
        matched += 1;

        const radius = @as(f64, @floatFromInt(cst.radius()));
        const dist = std.math.sqrt(@as(f64, @floatFromInt(evals[i].best_dist2)));
        const closeness = @max(0.0, 1.0 - (dist / radius));
        score += 1.0 + closeness;
    }

    return .{ .matched = matched, .score = score };
}

pub fn diagnosticsString(allocator: std.mem.Allocator, constraints: []const Constraint, evals: []const EvalState) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    const w = out.writer();
    for (constraints, 0..) |cst, i| {
        if (i != 0) try w.writeAll(";");
        try w.print("{s}=", .{cst.key()});
        if (!evals[i].matched) {
            switch (cst) {
                .biome => |req| try w.print("miss({d}/{d})", .{ evals[i].count, req.min_count }),
                .structure => try w.writeAll("miss"),
            }
            continue;
        }
        const dist = std.math.sqrt(@as(f64, @floatFromInt(evals[i].best_dist2)));
        switch (cst) {
            .biome => try w.print("ok({d})@{d:.1}", .{ evals[i].count, dist }),
            .structure => try w.print("ok@{d:.1}", .{dist}),
        }
    }

    return out.toOwnedSlice();
}
