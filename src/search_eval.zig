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
pub const StructureRegion = types.StructureRegion;
pub const BiomeCompareReq = types.BiomeCompareReq;
pub const NativeShadow = types.NativeShadow;
pub const NativeBackend = types.NativeBackend;
pub const ExprNode = expr.ExprNode;

const BiomeScanResult = struct {
    best_dist2: i64,
    count: i32,
};

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

fn sampleBiomeScalar(g: *c.Generator, sampler_opt: *?CachedBiomeSampler, x: i32, z: i32) i32 {
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
            try out.append(.{ .reg_x = reg_x, .reg_z = reg_z });
        }
    }
    return out.toOwnedSlice();
}

pub fn buildBiomeOffsets(allocator: std.mem.Allocator, radius: i32) ![]BiomeOffset {
    const step: i32 = 4;
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

pub fn scanBiomeWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, offsets: []const BiomeOffset) BiomeScanResult {
    var best: i64 = std.math.maxInt(i64);
    var count: i32 = 0;
    var sampler_opt = CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt = CachedBiomeRowSampler.init(g, 1, 0, maxOffsetRunWidth(center, offsets));
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
                sampleBiomeScalar(g, &sampler_opt, x, run.z);
            if (id != biome_id) continue;
            count += 1;
            if (off.dist2 < best) best = off.dist2;
        }
        i = run.end;
    }

    return .{ .best_dist2 = best, .count = count };
}

pub fn scanBiomePoints(g: *c.Generator, biome_id: i32, points: []const BiomePoint) BiomeScanResult {
    var best: i64 = std.math.maxInt(i64);
    var count: i32 = 0;
    var sampler_opt = CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt = CachedBiomeRowSampler.init(g, 1, 0, maxPointRunWidth(points));
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
                sampleBiomeScalar(g, &sampler_opt, pt.x, pt.z);
            if (id != biome_id) continue;
            count += 1;
            if (pt.dist2 < best) best = pt.dist2;
        }
        i = run.end;
    }
    return .{ .best_dist2 = best, .count = count };
}

pub fn biomeMatchesWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, min_count: i32, offsets: []const BiomeOffset) bool {
    if (min_count <= 0) return true;
    var count: i32 = 0;
    var sampler_opt = CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt = CachedBiomeRowSampler.init(g, 1, 0, maxOffsetRunWidth(center, offsets));
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
                sampleBiomeScalar(g, &sampler_opt, x, run.z);
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

pub fn biomeMatchesPoints(g: *c.Generator, biome_id: i32, min_count: i32, points: []const BiomePoint) bool {
    if (min_count <= 0) return true;
    var count: i32 = 0;
    var sampler_opt = CachedBiomeSampler.init(g, 1, 0);
    defer if (sampler_opt) |*sampler| sampler.deinit();
    var row_sampler_opt = CachedBiomeRowSampler.init(g, 1, 0, maxPointRunWidth(points));
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
                sampleBiomeScalar(g, &sampler_opt, pt.x, pt.z);
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

pub fn bestBiomeDistanceWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, offsets: []const BiomeOffset) ?i64 {
    const result = scanBiomeWithinRadius(g, center, biome_id, offsets);
    if (result.count == 0) return null;
    return result.best_dist2;
}

pub fn bestStructureDistanceWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) ?i64 {
    const r2 = req.radius2;
    var best: i64 = std.math.maxInt(i64);

    if (req.regions.len != 0) {
        for (req.regions) |reg| {
            const pos = bedrock.getStructurePosC(req.structure_c, mc, seed, reg.reg_x, reg.reg_z) orelse continue;
            const dx = pos.x - center.x;
            const dz = pos.z - center.z;
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
            if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
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
                const pos = bedrock.getStructurePosC(req.structure_c, mc, seed, reg_x, reg_z) orelse continue;
                const dx = pos.x - center.x;
                const dz = pos.z - center.z;
                const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
                if (dist2 > r2) continue;
                if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
                if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
                if (dist2 < best) best = dist2;
            }
        }
    }

    if (best == std.math.maxInt(i64)) return null;
    return best;
}

pub fn anyStructureWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) bool {
    const r2 = req.radius2;

    if (req.regions.len != 0) {
        for (req.regions) |reg| {
            const pos = bedrock.getStructurePosC(req.structure_c, mc, seed, reg.reg_x, reg.reg_z) orelse continue;
            const dx = pos.x - center.x;
            const dz = pos.z - center.z;
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
            if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
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
            const pos = bedrock.getStructurePosC(req.structure_c, mc, seed, reg_x, reg_z) orelse continue;
            const dx = pos.x - center.x;
            const dz = pos.z - center.z;
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            if (c.isViableStructurePos(req.structure_c, g, pos.x, pos.z, 0) == 0) continue;
            if (c.isViableStructureTerrain(req.structure_c, g, pos.x, pos.z) == 0) continue;
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

    const cst = constraints[idx];
    switch (cst) {
        .biome => |req| {
            if (mode == .full) {
                const result = if (req.points.len > 0)
                    scanBiomePoints(g, req.biome_id, req.points)
                else
                    scanBiomeWithinRadius(g, anchor, req.biome_id, req.offsets);
                evals[idx].count = result.count;
                evals[idx].matched = result.count >= req.min_count;
                if (evals[idx].matched) evals[idx].best_dist2 = result.best_dist2;
                evals[idx].finalized = true;
            } else {
                const matched = if (req.points.len > 0)
                    biomeMatchesPoints(g, req.biome_id, req.min_count, req.points)
                else
                    biomeMatchesWithinRadius(g, anchor, req.biome_id, req.min_count, req.offsets);
                evals[idx].matched = matched;
                evals[idx].count = if (matched) req.min_count else 0;
                evals[idx].best_dist2 = std.math.maxInt(i64);
                evals[idx].finalized = false;
            }
        },
        .structure => |req| {
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
        },
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
