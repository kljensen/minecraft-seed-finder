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
pub const ClimateParam = types.ClimateParam;
pub const ClimateReq = types.ClimateReq;
pub const TerrainStat = types.TerrainStat;
pub const TerrainReq = types.TerrainReq;
pub const NativeShadow = types.NativeShadow;
pub const NativeBackend = types.NativeBackend;
pub const ExprNode = expr.ExprNode;
const max_biome_climate_leaves = types.max_biome_climate_leaves;

const BiomeScanResult = struct {
    best_dist2: i64,
    count: i32,
};

const BiomeTreeDef = struct {
    params: []const [2]i32,
    nodes: []const u64,
    len: u32,
};

pub fn selectBiomeTree(mc: i32) BiomeTreeDef {
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

/// Compute the global (union-over-all-biomes) parameter ranges for a biome tree,
/// per dimension.  These are the outer bounds of the climate parameter space that
/// any leaf node covers.  Values outside these bounds exceed the tree's nominal
/// range entirely; the nearest-neighbour metric then assigns whatever biome has
/// its leaf closest to the boundary.
fn treeGlobalBounds(tree: anytype) [6]ClimateRange {
    var global: [6]ClimateRange = [_]ClimateRange{
        .{ .lo = std.math.maxInt(i32), .hi = std.math.minInt(i32) },
    } ** 6;
    for (tree.nodes) |node| {
        for (0..6) |dim| {
            const shift: u6 = @intCast(dim * 8);
            const param_idx: usize = @intCast((node >> shift) & 0xff);
            const p = tree.params[param_idx];
            global[dim].lo = @min(global[dim].lo, p[0]);
            global[dim].hi = @max(global[dim].hi, p[1]);
        }
    }
    return global;
}

pub fn precomputeBiomeClimateBounds(mc: i32, biome_id: i32) ?BiomeClimateBounds {
    if (biome_id < 0 or biome_id > 255) return null;
    const tree = selectBiomeTree(mc);
    const biome_u8: u8 = @intCast(biome_id);

    var out = BiomeClimateBounds{
        .ranges = undefined,
        .valid = false,
        .leaves = undefined,
        .leaf_count = 0,
        .leaf_overflow = false,
    };

    for (tree.nodes) |node| {
        const node_biome: u8 = @truncate((node >> 48) & 0xff);
        if (node_biome != biome_u8) continue;

        var leaf: [6]ClimateRange = undefined;
        for (0..6) |dim| {
            const shift: u6 = @intCast(dim * 8);
            const param_idx: usize = @intCast((node >> shift) & 0xff);
            const p = tree.params[param_idx];
            leaf[dim] = .{ .lo = p[0], .hi = p[1] };
        }

        if (!out.valid) {
            out.ranges = leaf;
            out.valid = true;
        } else {
            for (0..6) |dim| {
                out.ranges[dim].lo = @min(out.ranges[dim].lo, leaf[dim].lo);
                out.ranges[dim].hi = @max(out.ranges[dim].hi, leaf[dim].hi);
            }
        }

        if (!out.leaf_overflow) {
            if (out.leaf_count < max_biome_climate_leaves) {
                out.leaves[out.leaf_count] = leaf;
                out.leaf_count += 1;
            } else {
                out.leaf_overflow = true;
            }
        }
    }
    if (!out.valid) return null;

    // Store the per-dimension global tree bounds in the upper 32 bits of each
    // ClimateRange field — we reuse the struct by storing them in a separate
    // array that is carried along in BiomeClimateBounds.global_lo/global_hi.
    // (We store it inline to avoid adding fields to BiomeClimateBounds.)
    //
    // The bounds are used in isBiomeFeasible to clamp noise values that exceed
    // the tree's nominal range before the union-range check.  See that function
    // for the full rationale.
    out.global = treeGlobalBounds(tree);

    return out;
}

pub inline fn npBit(dim: usize) u6 {
    return @as(u6, 1) << @as(std.math.Log2Int(u6), @intCast(dim));
}

pub fn isBiomeFeasible(bounds: BiomeClimateBounds, np_values: [6]i64, np_known: u6) bool {
    if (!bounds.valid) return true;
    // Use union bounds only. Per-leaf checks are too strict because the biome
    // tree uses nearest-neighbor (minimum L2 distance), not exact containment.
    // A point between two leaves (e.g. depth=6760 when leaves have depth=0 or
    // depth=10000) can still be assigned to this biome as the closest match.
    //
    // Additionally, climate noise can produce values outside the tree's nominal
    // parameter range (e.g. T=10457 when the tree's max T is 10000).  When v
    // exceeds the global range in some dimension, *every* biome is equidistant
    // from the tree's boundary in that dimension — the winner is determined by
    // the other five dimensions.  We therefore clamp v to [global_lo, global_hi]
    // before comparing against the biome's union range.  If the clamped value is
    // within the union range, we cannot reject on this dimension alone.
    //
    // Concrete example: eroded_badlands has T leaves up to 10000 (the global
    // tree max).  A noise value of T=10457 clamped to 10000 falls within
    // eroded_badlands' T union [-10000, 10000], so the early-exit does NOT fire,
    // and climateToBiome correctly returns eroded_badlands.
    for (0..6) |dim| {
        const bit = npBit(dim);
        if ((np_known & bit) == 0) continue;
        const raw_v = np_values[dim];
        // Clamp to the global tree range for this dimension.
        const g_lo = @as(i64, bounds.global[dim].lo);
        const g_hi = @as(i64, bounds.global[dim].hi);
        const v = @max(g_lo, @min(g_hi, raw_v));
        const lo = @as(i64, bounds.ranges[dim].lo);
        const hi = @as(i64, bounds.ranges[dim].hi);
        if (v < lo or v > hi) return false;
    }
    return true;
}

/// Check whether a single climate dimension is within the biome's feasible
/// range, clamping to the global tree bounds first.  This is the single-dim
/// specialization of isBiomeFeasible — used inline in the fast path to avoid
/// redundantly re-checking already-verified dimensions.
inline fn isDimFeasible(bounds: BiomeClimateBounds, dim: usize, raw_v: i64) bool {
    const g_lo = @as(i64, bounds.global[dim].lo);
    const g_hi = @as(i64, bounds.global[dim].hi);
    const v = @max(g_lo, @min(g_hi, raw_v));
    return v >= @as(i64, bounds.ranges[dim].lo) and v <= @as(i64, bounds.ranges[dim].hi);
}

pub fn fastBiomeIdWithFeasibility(g: *c.Generator, x: i32, z: i32, bounds: BiomeClimateBounds) i32 {
    const bn = &g.unnamed_0.unnamed_1.bn;
    var np: [6]i64 = undefined;
    const c_idx = @as(usize, @intCast(c.NP_CONTINENTALNESS));
    const e_idx = @as(usize, @intCast(c.NP_EROSION));
    const w_idx = @as(usize, @intCast(c.NP_WEIRDNESS));
    const d_idx = @as(usize, @intCast(c.NP_DEPTH));
    const t_idx = @as(usize, @intCast(c.NP_TEMPERATURE));
    const h_idx = @as(usize, @intCast(c.NP_HUMIDITY));

    var sx: c_int = undefined;
    var sy: c_int = undefined;
    var sz: c_int = undefined;
    c.voronoiAccess3D(g.sha, x, 0, z, &sx, &sy, &sz);

    var px = @as(f64, @floatFromInt(sx));
    var pz = @as(f64, @floatFromInt(sz));

    px += c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_SHIFT))], @as(f64, @floatFromInt(sx)), 0.0, @as(f64, @floatFromInt(sz))) * 4.0;
    pz += c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_SHIFT))], @as(f64, @floatFromInt(sz)), @as(f64, @floatFromInt(sx)), 0.0) * 4.0;

    const c_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[c_idx], px, 0.0, pz)));
    np[c_idx] = @as(i64, @intFromFloat(10000.0 * c_val));
    if (!isDimFeasible(bounds, c_idx, np[c_idx])) return c.none;

    const e_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[e_idx], px, 0.0, pz)));
    np[e_idx] = @as(i64, @intFromFloat(10000.0 * e_val));
    if (!isDimFeasible(bounds, e_idx, np[e_idx])) return c.none;

    const w_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[w_idx], px, 0.0, pz)));
    np[w_idx] = @as(i64, @intFromFloat(10000.0 * w_val));
    if (!isDimFeasible(bounds, w_idx, np[w_idx])) return c.none;

    const np_param: [4]f32 = .{
        c_val,
        e_val,
        -3.0 * (@abs(@abs(w_val) - 0.6666666865348816) - 0.3333333432674408),
        w_val,
    };
    const off = @as(f64, @floatCast(c.getSpline(bn.sp, @constCast(@ptrCast(&np_param))) + 0.014999999664723873));
    const d_val = @as(f32, @floatCast(((1.0 - (@as(f64, @floatFromInt(sy * 4)) / 128.0)) - (83.0 / 160.0)) + off));
    np[d_idx] = @as(i64, @intFromFloat(10000.0 * d_val));
    if (!isDimFeasible(bounds, d_idx, np[d_idx])) return c.none;

    const t_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[t_idx], px, 0.0, pz)));
    np[t_idx] = @as(i64, @intFromFloat(10000.0 * t_val));
    if (!isDimFeasible(bounds, t_idx, np[t_idx])) return c.none;

    const h_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[h_idx], px, 0.0, pz)));
    np[h_idx] = @as(i64, @intFromFloat(10000.0 * h_val));

    return c.climateToBiome(bn.mc, @ptrCast(@alignCast(&np)), null);
}

fn canUseFastBiomePath(g: *const c.Generator) bool {
    if (!biome_climate_early_exit_enabled) return false;
    if (g.mc < c.MC_1_18) return false;
    if (g.dim != c.DIM_OVERWORLD) return false;
    if (g.unnamed_0.unnamed_1.bn.nptype != -1) return false;
    return true;
}

fn maybeFastBiomeId(g: *c.Generator, x: i32, z: i32, climate_bounds: ?BiomeClimateBounds) ?i32 {
    if (!canUseFastBiomePath(g)) return null;
    const bounds = climate_bounds orelse return null;
    if (!bounds.valid) return null;
    return fastBiomeIdWithFeasibility(g, x, z, bounds);
}

inline fn fastBiomeSamplingEligible(g: *const c.Generator, climate_bounds: ?BiomeClimateBounds) bool {
    if (!canUseFastBiomePath(g)) return false;
    const bounds = climate_bounds orelse return false;
    return bounds.valid;
}

/// Sample all 6 climate noise parameters at a biome-scale coordinate.
/// Returns [T, H, C, E, depth, W] as raw floats (not scaled by 10000).
/// Only valid for MC >= 1.18, DIM_OVERWORLD; returns null otherwise.
pub fn sampleClimateParams(g: *c.Generator, x: i32, z: i32) ?[6]f32 {
    if (g.mc < c.MC_1_18) return null;
    if (g.dim != c.DIM_OVERWORLD) return null;
    const bn = &g.unnamed_0.unnamed_1.bn;

    var sx: c_int = undefined;
    var sy: c_int = undefined;
    var sz: c_int = undefined;
    c.voronoiAccess3D(g.sha, x, 0, z, &sx, &sy, &sz);

    var px = @as(f64, @floatFromInt(sx));
    var pz = @as(f64, @floatFromInt(sz));

    px += c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_SHIFT))], @as(f64, @floatFromInt(sx)), 0.0, @as(f64, @floatFromInt(sz))) * 4.0;
    pz += c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_SHIFT))], @as(f64, @floatFromInt(sz)), @as(f64, @floatFromInt(sx)), 0.0) * 4.0;

    const c_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_CONTINENTALNESS))], px, 0.0, pz)));
    const e_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_EROSION))], px, 0.0, pz)));
    const w_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_WEIRDNESS))], px, 0.0, pz)));

    const np_param: [4]f32 = .{
        c_val,
        e_val,
        -3.0 * (@abs(@abs(w_val) - 0.6666666865348816) - 0.3333333432674408),
        w_val,
    };
    const off = @as(f64, @floatCast(c.getSpline(bn.sp, @constCast(@ptrCast(&np_param))) + 0.014999999664723873));
    const d_val = @as(f32, @floatCast(((1.0 - (@as(f64, @floatFromInt(sy * 4)) / 128.0)) - (83.0 / 160.0)) + off));

    const t_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_TEMPERATURE))], px, 0.0, pz)));
    const h_val = @as(f32, @floatCast(c.sampleDoublePerlin(&bn.climate[@as(usize, @intCast(c.NP_HUMIDITY))], px, 0.0, pz)));

    return .{ t_val, h_val, c_val, e_val, d_val, w_val };
}

fn extractClimateParam(np: [6]f32, param: ClimateParam) f32 {
    return switch (param) {
        .temperature => np[@as(usize, @intCast(c.NP_TEMPERATURE))],
        .humidity => np[@as(usize, @intCast(c.NP_HUMIDITY))],
        .continentalness => np[@as(usize, @intCast(c.NP_CONTINENTALNESS))],
        .erosion => np[@as(usize, @intCast(c.NP_EROSION))],
        .weirdness => np[@as(usize, @intCast(c.NP_WEIRDNESS))],
        .peaks_valleys => blk: {
            const w = np[@as(usize, @intCast(c.NP_WEIRDNESS))];
            break :blk 1.0 - @abs(3.0 * @abs(w) - 2.0);
        },
    };
}

fn depthToHeight(d_val: f32) f32 {
    return d_val * 10000.0 / 76.0;
}

pub fn evalClimateConstraint(
    g: *c.Generator,
    anchor: c.Pos,
    req: ClimateReq,
) struct { matched: bool, mean_val: f32, in_range_frac: f32 } {
    const use_points = req.points.len > 0;
    const total: usize = if (use_points) req.points.len else req.offsets.len;
    if (total == 0) return .{ .matched = false, .mean_val = 0, .in_range_frac = 0 };

    var sum: f64 = 0;
    var in_range: usize = 0;
    const min_needed = @as(usize, @intFromFloat(@ceil(@as(f64, @floatFromInt(total)) * req.min_fraction)));

    var i: usize = 0;
    while (i < total) : (i += 1) {
        const x = if (use_points) req.points[i].x else anchor.x + req.offsets[i].dx;
        const z = if (use_points) req.points[i].z else anchor.z + req.offsets[i].dz;

        const np = sampleClimateParams(g, x, z) orelse return .{ .matched = false, .mean_val = 0, .in_range_frac = 0 };
        const val = extractClimateParam(np, req.param);
        sum += @as(f64, val);

        const above_min = if (req.min_val) |lo| val >= lo else true;
        const below_max = if (req.max_val) |hi| val <= hi else true;
        if (above_min and below_max) in_range += 1;

        // Early-fail: impossible to reach threshold
        const remaining = total - i - 1;
        if (in_range + remaining < min_needed) {
            const sampled = i + 1;
            return .{
                .matched = false,
                .mean_val = @as(f32, @floatCast(sum / @as(f64, @floatFromInt(sampled)))),
                .in_range_frac = @as(f32, @floatFromInt(in_range)) / @as(f32, @floatFromInt(sampled)),
            };
        }
    }

    const mean = @as(f32, @floatCast(sum / @as(f64, @floatFromInt(total))));
    const frac = @as(f32, @floatFromInt(in_range)) / @as(f32, @floatFromInt(total));
    return .{ .matched = frac >= req.min_fraction, .mean_val = mean, .in_range_frac = frac };
}

pub fn evalTerrainConstraint(
    g: *c.Generator,
    anchor: c.Pos,
    req: TerrainReq,
) struct { matched: bool, stat_val: f32 } {
    const use_points = req.points.len > 0;
    const total: usize = if (use_points) req.points.len else req.offsets.len;
    if (total == 0) return .{ .matched = false, .stat_val = 0 };

    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    var min_h: f32 = std.math.inf(f32);
    var max_h: f32 = -std.math.inf(f32);

    var i: usize = 0;
    while (i < total) : (i += 1) {
        const x = if (use_points) req.points[i].x else anchor.x + req.offsets[i].dx;
        const z = if (use_points) req.points[i].z else anchor.z + req.offsets[i].dz;

        const np = sampleClimateParams(g, x, z) orelse return .{ .matched = false, .stat_val = 0 };
        const h = depthToHeight(np[@as(usize, @intCast(c.NP_DEPTH))]);
        sum += @as(f64, h);
        sum_sq += @as(f64, h) * @as(f64, h);
        if (h < min_h) min_h = h;
        if (h > max_h) max_h = h;

        // Early-fail for min_height: any point below threshold fails immediately
        if (req.stat == .min_height) {
            if (req.min_val) |lo| {
                if (h < lo) return .{ .matched = false, .stat_val = h };
            }
        }
        // Early-fail for max_height with upper bound
        if (req.stat == .max_height) {
            if (req.max_val) |hi| {
                if (h > hi) return .{ .matched = false, .stat_val = h };
            }
        }
    }

    const n = @as(f64, @floatFromInt(total));
    const mean = @as(f32, @floatCast(sum / n));
    const stat_val: f32 = switch (req.stat) {
        .mean_height => mean,
        .min_height => min_h,
        .max_height => max_h,
        .height_range => max_h - min_h,
        .height_std => blk: {
            const variance = (sum_sq / n) - (@as(f64, mean) * @as(f64, mean));
            break :blk @as(f32, @floatCast(@sqrt(@max(0.0, variance))));
        },
    };

    const above_min = if (req.min_val) |lo| stat_val >= lo else true;
    const below_max = if (req.max_val) |hi| stat_val <= hi else true;
    return .{ .matched = above_min and below_max, .stat_val = stat_val };
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

fn inferOffsetRunStep(offsets: []const BiomeOffset) i32 {
    if (offsets.len < 2) return 4;
    var i: usize = 1;
    while (i < offsets.len) : (i += 1) {
        const prev = offsets[i - 1];
        const curr = offsets[i];
        if (curr.dz != prev.dz) continue;
        const step = curr.dx - prev.dx;
        if (step > 0) return step;
    }
    return 4;
}

fn nextOffsetRunWithStep(offsets: []const BiomeOffset, start: usize, x_step: i32) RowRun {
    const first = offsets[start];
    const z = first.dz;
    const min_x = first.dx;
    var max_x = min_x;
    var prev_x = min_x;
    var i = start + 1;
    while (i < offsets.len) : (i += 1) {
        const off = offsets[i];
        if (off.dz != z or off.dx != prev_x + x_step) break;
        prev_x = off.dx;
        max_x = off.dx;
    }
    return .{
        .start = start,
        .end = i,
        .z = z,
        .min_x = min_x,
        .max_x = max_x,
    };
}

fn nextOffsetRun(offsets: []const BiomeOffset, start: usize) RowRun {
    return nextOffsetRunWithStep(offsets, start, 4);
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

fn maxOffsetRunWidthWithStep(offsets: []const BiomeOffset, x_step: i32) i32 {
    if (offsets.len == 0) return 0;
    var i: usize = 0;
    var max_width: i32 = 1;
    while (i < offsets.len) {
        const run = nextOffsetRunWithStep(offsets, i, x_step);
        const width = rowRunWidth(run);
        if (width > max_width) max_width = width;
        i = run.end;
    }
    return max_width;
}

fn maxOffsetRunWidth(offsets: []const BiomeOffset) i32 {
    return maxOffsetRunWidthWithStep(offsets, 4);
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
var biome_climate_early_exit_enabled = true;
var active_edition: bedrock.Edition = .bedrock;

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

pub fn setEdition(edition: bedrock.Edition) void {
    active_edition = edition;
}

pub fn setBiomeClimateEarlyExitEnabled(enabled: bool) void {
    biome_climate_early_exit_enabled = enabled;
}

inline fn getStructurePosForReq(req: StructureReq, mc: i32, seed: u64, reg_x: i32, reg_z: i32) ?bedrock.Pos {
    return bedrock.getStructurePos(active_edition, req.structure_c, mc, seed, reg_x, reg_z);
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
    const bounds = computeStructureRegionBounds(center, req.radius, cfg);

    var out = std.ArrayList(StructureRegion).init(allocator);
    errdefer out.deinit();
    var reg_z = bounds.min_reg_z;
    while (reg_z <= bounds.max_reg_z) : (reg_z += 1) {
        var reg_x = bounds.min_reg_x;
        while (reg_x <= bounds.max_reg_x) : (reg_x += 1) {
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

fn minBiomeMatchStride(reqs: []const *const BiomeReq) i32 {
    var min_stride: i32 = 4;
    for (reqs) |req| {
        const stride = selectBiomeMatchStride(req.min_count);
        if (stride < min_stride) min_stride = stride;
    }
    return min_stride;
}

fn selectOffsetsForStride(req: *const BiomeReq, stride: i32) []const BiomeOffset {
    return switch (stride) {
        4 => if (req.coarse_offsets_4.len > 0) req.coarse_offsets_4 else req.offsets,
        2 => if (req.coarse_offsets_2.len > 0) req.coarse_offsets_2 else req.offsets,
        else => req.offsets,
    };
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
    const fast_enabled = fastBiomeSamplingEligible(g, climate_bounds);
    var sampler_opt: ?CachedBiomeSampler = if (fast_enabled) null else CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt: ?CachedBiomeRowSampler = if (fast_enabled) null else CachedBiomeRowSampler.init(g, 1, 0, maxOffsetRunWidth(offsets));
    defer if (row_sampler_opt) |*sampler| sampler.deinit();

    var i: usize = 0;
    while (i < offsets.len) {
        const run = nextOffsetRun(offsets, i);
        const run_width = rowRunWidth(run);
        const run_z = center.z + run.z;
        const run_min_x = center.x + run.min_x;
        var row_ready = false;
        var row_sampler_ptr: ?*CachedBiomeRowSampler = null;
        if (row_sampler_opt) |*row_sampler| {
            row_sampler_ptr = row_sampler;
            row_ready = row_sampler.sampleRow(run_min_x, run_z, run_width);
        }
        var j = run.start;
        while (j < run.end) : (j += 1) {
            const off = offsets[j];
            const x = center.x + off.dx;
            const id = if (row_ready)
                row_sampler_ptr.?.getBiomeAt(x - run_min_x)
            else
                sampleBiomeScalar(g, &sampler_opt, x, run_z, climate_bounds);
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
    const fast_enabled = points.len > 0 and fastBiomeSamplingEligible(g, climate_bounds);
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
    const fast_enabled = fastBiomeSamplingEligible(g, climate_bounds);
    var sampler_opt: ?CachedBiomeSampler = if (fast_enabled) null else CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt: ?CachedBiomeRowSampler = if (fast_enabled) null else CachedBiomeRowSampler.init(g, 1, 0, maxOffsetRunWidth(offsets));
    defer if (row_sampler_opt) |*sampler| sampler.deinit();

    var i: usize = 0;
    while (i < offsets.len) {
        const run = nextOffsetRun(offsets, i);
        const run_width = rowRunWidth(run);
        const run_z = center.z + run.z;
        const run_min_x = center.x + run.min_x;
        var row_ready = false;
        var row_sampler_ptr: ?*CachedBiomeRowSampler = null;
        if (row_sampler_opt) |*row_sampler| {
            row_sampler_ptr = row_sampler;
            row_ready = row_sampler.sampleRow(run_min_x, run_z, run_width);
        }
        var j = run.start;
        while (j < run.end) : (j += 1) {
            const off = offsets[j];
            const x = center.x + off.dx;
            const id = if (row_ready)
                row_sampler_ptr.?.getBiomeAt(x - run_min_x)
            else
                sampleBiomeScalar(g, &sampler_opt, x, run_z, climate_bounds);
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

/// Count biome matches up to max_needed, with early termination.
/// Returns the number of matches found (capped at max_needed).
fn countBiomeMatchesWithBounds(g: *c.Generator, center: c.Pos, biome_id: i32, max_needed: i32, offsets: []const BiomeOffset, climate_bounds: ?BiomeClimateBounds) i32 {
    var count: i32 = 0;
    const fast_enabled = fastBiomeSamplingEligible(g, climate_bounds);
    var sampler_opt: ?CachedBiomeSampler = if (fast_enabled) null else CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();

    // Row batching helps large coarse scans, but adds overhead for short scans
    // that usually hit min_count quickly.
    const use_row_sampler = !fast_enabled and offsets.len >= 8192;
    if (!use_row_sampler) {
        for (offsets) |off| {
            const x = center.x + off.dx;
            const z = center.z + off.dz;
            const id = sampleBiomeScalar(g, &sampler_opt, x, z, climate_bounds);
            if (id == biome_id) {
                count += 1;
                if (count >= max_needed) return count;
            }
        }
        return count;
    }

    const x_step = inferOffsetRunStep(offsets);
    var row_sampler_opt: ?CachedBiomeRowSampler = CachedBiomeRowSampler.init(g, 1, 0, maxOffsetRunWidthWithStep(offsets, x_step));
    defer if (row_sampler_opt) |*sampler| sampler.deinit();

    var i: usize = 0;
    while (i < offsets.len) {
        const run = nextOffsetRunWithStep(offsets, i, x_step);
        const run_width = rowRunWidth(run);
        const run_z = center.z + run.z;
        const run_min_x = center.x + run.min_x;
        var row_ready = false;
        if (row_sampler_opt) |*row_sampler| {
            row_ready = row_sampler.sampleRow(run_min_x, run_z, run_width);
        }

        var j = run.start;
        while (j < run.end) : (j += 1) {
            const off = offsets[j];
            const x = center.x + off.dx;
            const id = if (row_ready)
                row_sampler_opt.?.getBiomeAt(x - run_min_x)
            else
                sampleBiomeScalar(g, &sampler_opt, x, run_z, climate_bounds);
            if (id == biome_id) {
                count += 1;
                if (count >= max_needed) return count;
            }
        }
        i = run.end;
    }
    return count;
}

fn biomeMatchesPointsWithBounds(g: *c.Generator, biome_id: i32, min_count: i32, points: []const BiomePoint, climate_bounds: ?BiomeClimateBounds) bool {
    if (min_count <= 0) return true;
    var count: i32 = 0;
    const fast_enabled = points.len > 0 and fastBiomeSamplingEligible(g, climate_bounds);
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

const StructureRegionBounds = struct {
    min_reg_x: i32,
    max_reg_x: i32,
    min_reg_z: i32,
    max_reg_z: i32,
};

fn computeStructureRegionBounds(center: c.Pos, radius: i32, cfg: bedrock.StructureConfig) StructureRegionBounds {
    const min_x = center.x - radius;
    const max_x = center.x + radius;
    const min_z = center.z - radius;
    const max_z = center.z + radius;

    const min_attempt_chunk_x = floorDiv(min_x - 8, 16);
    const max_attempt_chunk_x = floorDiv(max_x - 8, 16);
    const min_attempt_chunk_z = floorDiv(min_z - 8, 16);
    const max_attempt_chunk_z = floorDiv(max_z - 8, 16);

    return .{
        .min_reg_x = floorDiv(min_attempt_chunk_x - (cfg.spacing - 1), cfg.spacing),
        .max_reg_x = floorDiv(max_attempt_chunk_x, cfg.spacing),
        .min_reg_z = floorDiv(min_attempt_chunk_z - (cfg.spacing - 1), cfg.spacing),
        .max_reg_z = floorDiv(max_attempt_chunk_z, cfg.spacing),
    };
}

fn evalStructureCandidateDistance2(
    g: *c.Generator,
    seed: u64,
    mc: i32,
    center: c.Pos,
    req: StructureReq,
    reg_x: i32,
    reg_z: i32,
    radius2: i64,
    telemetry: ?*EvalTelemetry,
) ?i64 {
    if (telemetry) |t| t.structure_get_pos_calls +%= 1;
    const pos = getStructurePosForReq(req, mc, seed, reg_x, reg_z) orelse return null;

    const dx = pos.x - center.x;
    const dz = pos.z - center.z;
    const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
    if (dist2 > radius2) return null;

    if (telemetry) |t| t.structure_within_radius +%= 1;
    if (telemetry) |t| t.structure_viable_pos_checks +%= 1;
    if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) return null;

    if (telemetry) |t| t.structure_viable_terrain_checks +%= 1;
    if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) return null;

    if (telemetry) |t| t.structure_matches +%= 1;
    return dist2;
}

pub fn bestStructureDistanceWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) ?i64 {
    const r2 = req.radius2;
    var best: i64 = std.math.maxInt(i64);
    const telemetry = active_eval_telemetry;

    if (req.regions.len != 0) {
        for (req.regions) |reg| {
            if (telemetry) |t| t.structure_region_candidates +%= 1;
            const dist2 = evalStructureCandidateDistance2(g, seed, mc, center, req, reg.reg_x, reg.reg_z, r2, telemetry) orelse continue;
            if (dist2 < best) best = dist2;
        }
    } else {
        const cfg = req.cfg orelse return null;
        const bounds = computeStructureRegionBounds(center, req.radius, cfg);

        var reg_z = bounds.min_reg_z;
        while (reg_z <= bounds.max_reg_z) : (reg_z += 1) {
            var reg_x = bounds.min_reg_x;
            while (reg_x <= bounds.max_reg_x) : (reg_x += 1) {
                if (telemetry) |t| t.structure_region_candidates +%= 1;
                if (structure_bbox_prune_enabled and !regionMayIntersectRadius(center, cfg, reg_x, reg_z, r2)) {
                    if (telemetry) |t| t.structure_region_bbox_rejects +%= 1;
                    continue;
                }

                const dist2 = evalStructureCandidateDistance2(g, seed, mc, center, req, reg_x, reg_z, r2, telemetry) orelse continue;
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
            if (evalStructureCandidateDistance2(g, seed, mc, center, req, reg.reg_x, reg.reg_z, r2, telemetry) != null) return true;
        }
        return false;
    }

    const cfg = req.cfg orelse return false;
    const bounds = computeStructureRegionBounds(center, req.radius, cfg);

    var reg_z = bounds.min_reg_z;
    while (reg_z <= bounds.max_reg_z) : (reg_z += 1) {
        var reg_x = bounds.min_reg_x;
        while (reg_x <= bounds.max_reg_x) : (reg_x += 1) {
            if (telemetry) |t| t.structure_region_candidates +%= 1;
            if (structure_bbox_prune_enabled and !regionMayIntersectRadius(center, cfg, reg_x, reg_z, r2)) {
                if (telemetry) |t| t.structure_region_bbox_rejects +%= 1;
                continue;
            }
            if (evalStructureCandidateDistance2(g, seed, mc, center, req, reg_x, reg_z, r2, telemetry) != null) return true;
        }
    }
    return false;
}

const MAX_COMBINED_BIOMES = 8;
const MAX_BIOME_CACHE_POINTS: usize = 65536;

fn storeCombinedBiomeThresholdStates(
    biome_reqs: []const *const BiomeReq,
    biome_eval_indices: []const usize,
    evals: []EvalState,
    eval_epoch: u64,
    counts: ?[]const i32,
    force_all_matched: bool,
) void {
    for (biome_reqs, biome_eval_indices, 0..) |req, eval_idx, bi| {
        const matched = if (force_all_matched)
            true
        else blk: {
            const count_slice = counts orelse unreachable;
            break :blk count_slice[bi] >= req.min_count;
        };
        evals[eval_idx] = .{
            .epoch = eval_epoch,
            .computed = true,
            .finalized = false,
            .matched = matched,
            .count = if (matched) req.min_count else 0,
            .best_dist2 = std.math.maxInt(i64),
        };
    }
}

fn propagateCombinedBiomeAliases(
    biome_atom_indices: []const usize,
    aliases: []const usize,
    evals: []EvalState,
    eval_epoch: u64,
) void {
    for (biome_atom_indices) |idx| {
        const alias_idx = aliases[idx];
        if (alias_idx != idx and evals[alias_idx].epoch == eval_epoch and evals[alias_idx].computed) {
            evals[idx] = evals[alias_idx];
        }
    }
}

fn finalizeCombinedBiomeThreshold(
    biome_atom_indices: []const usize,
    aliases: []const usize,
    evals: []EvalState,
    eval_epoch: u64,
    unique_biome_count: usize,
    biome_start: i128,
) void {
    propagateCombinedBiomeAliases(biome_atom_indices, aliases, evals, eval_epoch);
    if (active_eval_telemetry) |telemetry| {
        telemetry.biome_constraint_evals +%= @as(u64, @intCast(unique_biome_count));
        telemetry.biome_eval_ns +%= @as(u128, @intCast(std.time.nanoTimestamp() - biome_start));
    }
}

/// Cached sequential biome threshold: evaluates biome constraints sequentially
/// (preserving short-circuit) but caches biome_ids so subsequent biome scans
/// reuse noise computation from earlier scans. Each scan uses per-biome climate
/// bounds for strong early-exit. Returns null to signal fallback to sequential.
fn combinedBiomeThreshold(
    g: *c.Generator,
    anchor: c.Pos,
    constraints: []const Constraint,
    aliases: []const usize,
    biome_atom_indices: []const usize,
    evals: []EvalState,
    eval_epoch: u64,
) ?bool {
    // Collect unique biome reqs, dedup by alias
    var biome_reqs: [MAX_COMBINED_BIOMES]*const BiomeReq = undefined;
    var biome_eval_indices: [MAX_COMBINED_BIOMES]usize = undefined;
    var n: usize = 0;
    var max_radius_idx: usize = 0;
    var max_radius2: i64 = 0;

    for (biome_atom_indices) |idx| {
        const alias_idx = aliases[idx];
        var already = false;
        for (0..n) |j| {
            if (biome_eval_indices[j] == alias_idx) {
                already = true;
                break;
            }
        }
        if (already) continue;

        const req = &constraints[alias_idx].biome;
        biome_reqs[n] = req;
        biome_eval_indices[n] = alias_idx;
        if (req.radius2 > max_radius2) {
            max_radius2 = req.radius2;
            max_radius_idx = n;
        }
        n += 1;
    }

    if (n < 2) return null; // fallback to sequential

    const max_req = biome_reqs[max_radius_idx];
    const use_points = max_req.points.len > 0;
    const use_fast = canUseFastBiomePath(g);

    const min_stride = minBiomeMatchStride(biome_reqs[0..n]);
    const iter_offsets = selectOffsetsForStride(max_req, min_stride);
    const total_points = if (use_points) max_req.points.len else iter_offsets.len;

    if (total_points > MAX_BIOME_CACHE_POINTS or total_points == 0) return null;
    if (!use_fast) return null; // cache only helps with fast path (climate early-exit)

    const biome_start = if (active_eval_telemetry != null) std.time.nanoTimestamp() else 0;

    // --- Coarse prescan at stride 4 for quick accept/reject ---
    // Sample a sparse grid first; if any biome gets zero coarse hits we reject
    // early, and if every biome already meets its threshold we accept.
    if (!use_points and min_stride == 1 and max_req.coarse_offsets_4.len > 0 and
        max_req.coarse_offsets_4.len < iter_offsets.len)
    {
        const coarse4 = max_req.coarse_offsets_4;
        var coarse_counts: [MAX_COMBINED_BIOMES]i32 = [_]i32{0} ** MAX_COMBINED_BIOMES;
        var any_zero = false;

        for (coarse4) |off| {
            const x = anchor.x + off.dx;
            const z = anchor.z + off.dz;
            // Try each biome's bounds to resolve the point
            var resolved_id: i32 = c.none;
            for (0..n) |bi| {
                const b = biome_reqs[bi].climate_bounds;
                if (b) |bounds| {
                    if (bounds.valid) {
                        const id = fastBiomeIdWithFeasibility(g, x, z, bounds);
                        if (id != c.none) {
                            resolved_id = id;
                            break;
                        }
                    }
                }
            }
            if (resolved_id == c.none) continue;
            for (0..n) |bi| {
                if (resolved_id == biome_reqs[bi].biome_id and off.dist2 <= biome_reqs[bi].radius2) {
                    coarse_counts[bi] += 1;
                }
            }
        }

        // Check for quick accept/reject
        var all_satisfied = true;
        for (0..n) |bi| {
            if (coarse_counts[bi] == 0) {
                any_zero = true;
                break;
            }
            if (coarse_counts[bi] < biome_reqs[bi].min_count) {
                all_satisfied = false;
            }
        }
        if (any_zero) {
            // At least one biome has zero coarse hits → reject
            storeCombinedBiomeThresholdStates(
                biome_reqs[0..n],
                biome_eval_indices[0..n],
                evals,
                eval_epoch,
                coarse_counts[0..n],
                false,
            );
            finalizeCombinedBiomeThreshold(biome_atom_indices, aliases, evals, eval_epoch, n, biome_start);
            return false;
        }
        if (all_satisfied) {
            storeCombinedBiomeThresholdStates(
                biome_reqs[0..n],
                biome_eval_indices[0..n],
                evals,
                eval_epoch,
                null,
                true,
            );
            finalizeCombinedBiomeThreshold(biome_atom_indices, aliases, evals, eval_epoch, n, biome_start);
            return true;
        }
        // Uncertain: fall through to full-resolution evaluation
    }

    // Biome ID cache. We only cache resolved biome IDs; c.none (fast-path
    // infeasible) is intentionally left uncached so later biome phases can
    // resample with their own climate bounds.
    var biome_cache = [_]?i32{null} ** MAX_BIOME_CACHE_POINTS;

    // Sequential evaluation with caching: preserves short-circuit
    var all_matched = true;
    for (0..n) |phase| {
        const req = biome_reqs[phase];
        const bounds = req.climate_bounds;
        const has_valid_bounds = if (bounds) |b| b.valid else false;
        var count: i32 = 0;
        var matched = false;

        if (use_points) {
            for (max_req.points, 0..) |pt, pi| {
                const biome_id: i32 = biome_cache[pi] orelse blk: {
                    // Not cached: compute with this biome's bounds.
                    const sampled = if (has_valid_bounds)
                        fastBiomeIdWithFeasibility(g, pt.x, pt.z, bounds.?)
                    else
                        c.getBiomeAt(g, 1, pt.x, 0, pt.z);
                    if (sampled != c.none) biome_cache[pi] = sampled;
                    break :blk sampled;
                };
                if (biome_id == c.none) continue;
                if (biome_id == req.biome_id and pt.dist2 <= req.radius2) {
                    count += 1;
                    if (count >= req.min_count) {
                        matched = true;
                        break;
                    }
                }
                const remaining = total_points - pi - 1;
                if (count + @as(i32, @intCast(remaining)) < req.min_count) break;
            }
        } else {
            for (iter_offsets, 0..) |off, oi| {
                const x = anchor.x + off.dx;
                const z = anchor.z + off.dz;
                const biome_id: i32 = biome_cache[oi] orelse blk: {
                    const sampled = if (has_valid_bounds)
                        fastBiomeIdWithFeasibility(g, x, z, bounds.?)
                    else
                        c.getBiomeAt(g, 1, x, 0, z);
                    if (sampled != c.none) biome_cache[oi] = sampled;
                    break :blk sampled;
                };
                if (biome_id == c.none) continue;
                if (biome_id == req.biome_id and off.dist2 <= req.radius2) {
                    count += 1;
                    if (count >= req.min_count) {
                        matched = true;
                        break;
                    }
                }
                const remaining = total_points - oi - 1;
                if (count + @as(i32, @intCast(remaining)) < req.min_count) break;
            }
        }

        // Record eval for this biome
        evals[biome_eval_indices[phase]] = .{
            .epoch = eval_epoch,
            .computed = true,
            .finalized = false,
            .matched = matched,
            .count = if (matched) req.min_count else 0,
            .best_dist2 = std.math.maxInt(i64),
        };

        if (!matched) {
            all_matched = false;
            break; // Short-circuit: this biome failed, skip remaining
        }
    }

    finalizeCombinedBiomeThreshold(biome_atom_indices, aliases, evals, eval_epoch, n, biome_start);
    return all_matched;
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
                    // Multi-phase coarse scan: try progressively finer grids.
                    // Each phase either accepts (>= min_count), rejects (0),
                    // or is uncertain (0 < n < min_count) and falls through.
                    if (stride == 1 and req.min_count > 1) {
                        // Phase 1: stride=4 (coarsest, ~1/4 the points of stride=2)
                        if (req.coarse_offsets_4.len > 0 and
                            req.coarse_offsets_4.len < req.offsets.len)
                        {
                            const coarse4_count = countBiomeMatchesWithBounds(
                                g,
                                anchor,
                                req.biome_id,
                                req.min_count,
                                req.coarse_offsets_4,
                                req.climate_bounds,
                            );
                            if (coarse4_count >= req.min_count) break :blk true;
                            if (coarse4_count == 0) break :blk false;
                            // Uncertain: try stride=2
                        }
                        // Phase 2: stride=2
                        if (req.coarse_offsets_2.len > 0 and
                            req.coarse_offsets_2.len < req.offsets.len)
                        {
                            const coarse2_count = countBiomeMatchesWithBounds(
                                g,
                                anchor,
                                req.biome_id,
                                req.min_count,
                                req.coarse_offsets_2,
                                req.climate_bounds,
                            );
                            if (coarse2_count >= req.min_count) break :blk true;
                            if (coarse2_count == 0) break :blk false;
                            // Uncertain: fall through to full-resolution scan
                        }
                    }
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
        .climate => |req| {
            const result = evalClimateConstraint(g, anchor, req);
            evals[idx].matched = result.matched;
            evals[idx].count = 0;
            evals[idx].best_dist2 = 0;
            evals[idx].finalized = true;
            evals[idx].climate_mean = result.mean_val;
        },
        .terrain => |req| {
            const result = evalTerrainConstraint(g, anchor, req);
            evals[idx].matched = result.matched;
            evals[idx].count = 0;
            evals[idx].best_dist2 = 0;
            evals[idx].finalized = true;
            evals[idx].climate_mean = result.stat_val;
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
    // Count biome atoms and collect their indices
    var biome_atom_buf: [MAX_COMBINED_BIOMES]usize = undefined;
    var num_biome_atoms: usize = 0;
    var overflow = false;

    for (atom_indices) |idx| {
        const alias_idx = aliases[idx];
        switch (constraints[alias_idx]) {
            .biome => {
                if (num_biome_atoms < MAX_COMBINED_BIOMES) {
                    biome_atom_buf[num_biome_atoms] = idx;
                    num_biome_atoms += 1;
                } else {
                    overflow = true;
                }
            },
            .structure, .climate, .terrain => {},
        }
    }

    // Fall back to sequential if < 2 biome atoms or overflow
    if (num_biome_atoms < 2 or overflow) {
        for (atom_indices) |idx| {
            if (!evalConstraintAt(constraints, aliases, idx, evals, eval_epoch, g, seed, mc, anchor, .threshold)) return false;
        }
        return true;
    }

    // Evaluate non-biome atoms first (structures are cheap)
    for (atom_indices) |idx| {
        const alias_idx = aliases[idx];
        if (constraints[alias_idx] == .biome) continue;
        if (!evalConstraintAt(constraints, aliases, idx, evals, eval_epoch, g, seed, mc, anchor, .threshold)) return false;
    }

    // Cached sequential biome scan (falls back to sequential if conditions unmet)
    if (combinedBiomeThreshold(g, anchor, constraints, aliases, biome_atom_buf[0..num_biome_atoms], evals, eval_epoch)) |result| {
        return result;
    }

    // Fallback: evaluate biome atoms sequentially
    for (biome_atom_buf[0..num_biome_atoms]) |idx| {
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
        .climate => |req| blk: {
            const n = if (req.points.len > 0) req.points.len else req.offsets.len;
            break :blk @as(u64, @intCast(@max(@as(usize, 1), n)));
        },
        .terrain => |req| blk: {
            const n = if (req.points.len > 0) req.points.len else req.offsets.len;
            break :blk @as(u64, @intCast(@max(@as(usize, 1), n)));
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

const AdaptiveSortCtx = struct {
    constraints: []const Constraint,
    aliases: []const usize,
    eval_counts: []const u64,
    fail_counts: []const u64,
};

pub fn reorderConjunctiveAtomsByAdaptiveScore(
    atom_indices: []usize,
    constraints: []const Constraint,
    aliases: []const usize,
    eval_counts: []const u64,
    fail_counts: []const u64,
) void {
    const ctx = AdaptiveSortCtx{
        .constraints = constraints,
        .aliases = aliases,
        .eval_counts = eval_counts,
        .fail_counts = fail_counts,
    };
    std.sort.heap(usize, atom_indices, ctx, struct {
        fn lessThan(sort_ctx: AdaptiveSortCtx, a: usize, b: usize) bool {
            const a_alias = sort_ctx.aliases[a];
            const b_alias = sort_ctx.aliases[b];
            const a_is_biome = sort_ctx.constraints[a_alias] == .biome;
            const b_is_biome = sort_ctx.constraints[b_alias] == .biome;

            // Non-biomes before biomes (matches evalConjunctiveAtoms semantics)
            if (!a_is_biome and b_is_biome) return true;
            if (a_is_biome and !b_is_biome) return false;

            // Within same group: highest utility first (best rejectors)
            const a_util = adaptiveUtility(sort_ctx, a);
            const b_util = adaptiveUtility(sort_ctx, b);
            if (a_util > b_util) return true;
            if (b_util > a_util) return false;

            // Tie-break: lower cost, then lower index
            const a_cost = estimateConstraintEvalCost(sort_ctx.constraints[a_alias]);
            const b_cost = estimateConstraintEvalCost(sort_ctx.constraints[b_alias]);
            if (a_cost < b_cost) return true;
            if (b_cost < a_cost) return false;
            return a < b;
        }

        fn adaptiveUtility(sort_ctx: AdaptiveSortCtx, idx: usize) f64 {
            const eval_count = sort_ctx.eval_counts[idx];
            const fail_count = sort_ctx.fail_counts[idx];
            // Bayesian smoothing: (fail+1)/(eval+2)
            const p_reject = @as(f64, @floatFromInt(fail_count + 1)) / @as(f64, @floatFromInt(eval_count + 2));
            const cost = @max(1.0, @as(f64, @floatFromInt(estimateConstraintEvalCost(sort_ctx.constraints[sort_ctx.aliases[idx]]))));
            return p_reject / cost;
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
        .climate => |x| switch (b) {
            .climate => |y| x.param == y.param and x.min_val == y.min_val and x.max_val == y.max_val and x.radius == y.radius and x.min_fraction == y.min_fraction,
            else => false,
        },
        .terrain => |x| switch (b) {
            .terrain => |y| x.stat == y.stat and x.min_val == y.min_val and x.max_val == y.max_val and x.radius == y.radius,
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

        switch (cst) {
            .climate, .terrain => {
                score += 1.0;
            },
            else => {
                const radius = @as(f64, @floatFromInt(cst.radius()));
                const dist = std.math.sqrt(@as(f64, @floatFromInt(evals[i].best_dist2)));
                const closeness = @max(0.0, 1.0 - (dist / radius));
                score += 1.0 + closeness;
            },
        }
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
                .climate => try w.print("miss(mean={d:.3})", .{evals[i].climate_mean}),
                .terrain => try w.print("miss(val={d:.2})", .{evals[i].climate_mean}),
            }
            continue;
        }
        switch (cst) {
            .biome => {
                const dist = std.math.sqrt(@as(f64, @floatFromInt(evals[i].best_dist2)));
                try w.print("ok({d})@{d:.1}", .{ evals[i].count, dist });
            },
            .structure => {
                const dist = std.math.sqrt(@as(f64, @floatFromInt(evals[i].best_dist2)));
                try w.print("ok@{d:.1}", .{dist});
            },
            .climate => try w.print("ok(mean={d:.3})", .{evals[i].climate_mean}),
            .terrain => try w.print("ok(val={d:.2})", .{evals[i].climate_mean}),
        }
    }

    return out.toOwnedSlice();
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

test "precomputeBiomeClimateBounds: eroded_badlands global T bounds stored correctly" {
    // Regression for false-negative bug: seed 55 at block (224,0,-328) is
    // eroded_badlands in Java 1.21.1, but the climate noise produces T=10457
    // which exceeds the union of all eroded_badlands leaf T-ranges (max 10000).
    // The fix: store global per-dimension tree bounds in BiomeClimateBounds.global
    // so that isBiomeFeasible can clamp noise values to the global range before
    // checking the biome's union range.
    const mc = c.MC_1_21_WD; // 1.21.1
    const eroded_badlands: i32 = 165;
    const bounds = precomputeBiomeClimateBounds(mc, eroded_badlands) orelse
        return error.TestUnexpectedResult;

    const t_idx = @as(usize, @intCast(c.NP_TEMPERATURE));
    // Union T-range of eroded_badlands leaves tops out at 10000.
    try std.testing.expectEqual(@as(i32, 10000), bounds.ranges[t_idx].hi);
    // Global T-range for the tree also tops out at 10000
    // (no leaf has T hi > 10000 in the 1.21.1 tree).
    try std.testing.expectEqual(@as(i32, 10000), bounds.global[t_idx].hi);
    // The biome's T union hi equals the global T hi → isBiomeFeasible will
    // clamp T=10457 to 10000, which is within the union range → feasible.
}

test "isBiomeFeasible: T=10457 is feasible for eroded_badlands" {
    const mc = c.MC_1_21_WD;
    const eroded_badlands: i32 = 165;
    const bounds = precomputeBiomeClimateBounds(mc, eroded_badlands) orelse
        return error.TestUnexpectedResult;

    const t_idx = @as(usize, @intCast(c.NP_TEMPERATURE));
    var np = [6]i64{ 0, 0, 0, 0, 0, 0 };
    np[t_idx] = 10457;
    const np_known: u6 = npBit(t_idx);

    // With the fix, T=10457 must NOT be rejected by the feasibility check.
    try std.testing.expect(isBiomeFeasible(bounds, np, np_known));
}
