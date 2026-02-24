const std = @import("std");
const c = @import("cubiomes_port.zig");
const bedrock = @import("bedrock.zig");
const biome_names = @import("biome_names.zig");
const native_noise = @import("native_noise.zig");
const nbt = @import("nbt.zig");

const BiomeReq = struct {
    key: []const u8,
    label: []const u8,
    biome_id: i32,
    radius: i32,
    min_count: i32,
    radius2: i64,
    offsets: []BiomeOffset = &.{},
    points: []BiomePoint = &.{},
};

const StructureReq = struct {
    key: []const u8,
    label: []const u8,
    structure: bedrock.Structure,
    radius: i32,
    radius2: i64,
    structure_c: c_int,
    cfg: ?bedrock.StructureConfig,
    regions: []StructureRegion = &.{},
};

const Constraint = union(enum) {
    biome: BiomeReq,
    structure: StructureReq,

    fn key(self: Constraint) []const u8 {
        return switch (self) {
            .biome => |v| v.key,
            .structure => |v| v.key,
        };
    }

    fn label(self: Constraint) []const u8 {
        return switch (self) {
            .biome => |v| v.label,
            .structure => |v| v.label,
        };
    }

    fn radius(self: Constraint) i32 {
        return switch (self) {
            .biome => |v| v.radius,
            .structure => |v| v.radius,
        };
    }
};

const EvalState = struct {
    computed: bool = false,
    finalized: bool = false,
    matched: bool = false,
    best_dist2: i64 = std.math.maxInt(i64),
    count: i32 = 0,
};

const EvalMode = enum {
    threshold,
    full,
};

const ExprNode = union(enum) {
    literal_true,
    atom: usize,
    not: usize,
    and_op: struct { lhs: usize, rhs: usize },
    or_op: struct { lhs: usize, rhs: usize },
};

const ExprParser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize,
    constraints_len: usize,
    biome_ids: []const usize,
    structure_ids: []const usize,
    nodes: std.ArrayList(ExprNode),

    fn init(
        allocator: std.mem.Allocator,
        input: []const u8,
        constraints_len: usize,
        biome_ids: []const usize,
        structure_ids: []const usize,
    ) ExprParser {
        return .{
            .allocator = allocator,
            .input = input,
            .pos = 0,
            .constraints_len = constraints_len,
            .biome_ids = biome_ids,
            .structure_ids = structure_ids,
            .nodes = std.ArrayList(ExprNode).init(allocator),
        };
    }

    fn deinit(self: *ExprParser) void {
        self.nodes.deinit();
    }

    fn parse(self: *ExprParser) anyerror!usize {
        const root = try self.parseOr();
        self.skipSpace();
        if (self.pos != self.input.len) return error.InvalidFilterExpression;
        return root;
    }

    fn parseOr(self: *ExprParser) anyerror!usize {
        var left = try self.parseAnd();
        while (true) {
            self.skipSpace();
            if (self.consumeKeyword("or") or self.consumeSymbol("||")) {
                const right = try self.parseAnd();
                left = try self.push(.{ .or_op = .{ .lhs = left, .rhs = right } });
                continue;
            }
            break;
        }
        return left;
    }

    fn parseAnd(self: *ExprParser) anyerror!usize {
        var left = try self.parseUnary();
        while (true) {
            self.skipSpace();
            if (self.consumeKeyword("and") or self.consumeSymbol("&&")) {
                const right = try self.parseUnary();
                left = try self.push(.{ .and_op = .{ .lhs = left, .rhs = right } });
                continue;
            }
            break;
        }
        return left;
    }

    fn parseUnary(self: *ExprParser) anyerror!usize {
        self.skipSpace();
        if (self.consumeKeyword("not") or self.consumeSymbol("!")) {
            const child = try self.parseUnary();
            return self.push(.{ .not = child });
        }
        return self.parsePrimary();
    }

    fn parsePrimary(self: *ExprParser) anyerror!usize {
        self.skipSpace();
        if (self.consumeSymbol("(")) {
            const inner = try self.parseOr();
            self.skipSpace();
            if (!self.consumeSymbol(")")) return error.InvalidFilterExpression;
            return inner;
        }

        const ident = self.parseIdentifier() orelse return error.InvalidFilterExpression;
        const atom_index = self.resolveIdentifier(ident) orelse return error.InvalidFilterExpression;
        return self.push(.{ .atom = atom_index });
    }

    fn parseIdentifier(self: *ExprParser) ?[]const u8 {
        self.skipSpace();
        const start = self.pos;
        while (self.pos < self.input.len) : (self.pos += 1) {
            const ch = self.input[self.pos];
            if (std.ascii.isAlphanumeric(ch) or ch == '_') {
                continue;
            }
            break;
        }
        if (self.pos == start) return null;
        return self.input[start..self.pos];
    }

    fn resolveIdentifier(self: *ExprParser, ident: []const u8) ?usize {
        if (ident.len < 2) return null;
        const ord = std.fmt.parseInt(usize, ident[1..], 10) catch return null;
        if (ord == 0) return null;

        if (ident[0] == 'c') {
            if (ord > self.constraints_len) return null;
            return ord - 1;
        }
        if (ident[0] == 'b') {
            if (ord > self.biome_ids.len) return null;
            return self.biome_ids[ord - 1];
        }
        if (ident[0] == 's') {
            if (ord > self.structure_ids.len) return null;
            return self.structure_ids[ord - 1];
        }
        return null;
    }

    fn push(self: *ExprParser, node: ExprNode) anyerror!usize {
        try self.nodes.append(node);
        return self.nodes.items.len - 1;
    }

    fn skipSpace(self: *ExprParser) void {
        while (self.pos < self.input.len and std.ascii.isWhitespace(self.input[self.pos])) : (self.pos += 1) {}
    }

    fn consumeSymbol(self: *ExprParser, sym: []const u8) bool {
        self.skipSpace();
        if (!std.mem.startsWith(u8, self.input[self.pos..], sym)) return false;
        self.pos += sym.len;
        return true;
    }

    fn consumeKeyword(self: *ExprParser, kw: []const u8) bool {
        self.skipSpace();
        if (!std.mem.startsWith(u8, self.input[self.pos..], kw)) return false;
        const end = self.pos + kw.len;
        if (end < self.input.len) {
            const ch = self.input[end];
            if (std.ascii.isAlphanumeric(ch) or ch == '_') return false;
        }
        self.pos = end;
        return true;
    }
};

const OutputFormat = enum {
    text,
    jsonl,
    csv,
};

const Checkpoint = struct {
    next_seed: u64,
    tested: u64,
    found: usize,
};

const MatchCandidate = struct {
    seed: u64,
    spawn: c.Pos,
    anchor: c.Pos,
    score: f64,
    matched_constraints: usize,
    total_constraints: usize,
    diagnostics: []u8,
};

const NativeShadow = struct {
    enabled: bool = false,
    native_checksum: f64 = 0,
    c_checksum: f64 = 0,
    samples: u64 = 0,
    compared: u64 = 0,
    sign_mismatch: u64 = 0,
    abs_diff_sum: f64 = 0,
    max_abs_diff: f64 = 0,
    biome_proxy_compared: u64 = 0,
    biome_proxy_mismatch: u64 = 0,
};

const NativeBackend = struct {
    compare_only: bool = false,
    strict: bool = false,
    compared: u64 = 0,
    mismatch: u64 = 0,
};

const BiomeOffset = struct {
    dx: i32,
    dz: i32,
    dist2: i64,
};

const BiomePoint = struct {
    x: i32,
    z: i32,
    dist2: i64,
};

const StructureRegion = struct {
    reg_x: i32,
    reg_z: i32,
};

const BiomeCompareReq = struct {
    idx: usize,
    proxy_needed: i32,
    weight: u32,
};

fn parseVersion(v: []const u8) ?i32 {
    if (std.mem.eql(u8, v, "1.18")) return c.MC_1_18;
    if (std.mem.eql(u8, v, "1.19") or std.mem.eql(u8, v, "1.19.4")) return c.MC_1_19;
    if (std.mem.eql(u8, v, "1.20") or std.mem.eql(u8, v, "1.20.6")) return c.MC_1_20;
    if (std.mem.eql(u8, v, "1.21") or std.mem.eql(u8, v, "1.21.1")) return c.MC_1_21_1;
    if (std.mem.eql(u8, v, "1.21.3")) return c.MC_1_21_3;
    return null;
}

fn parseOutputFormat(v: []const u8) ?OutputFormat {
    if (std.mem.eql(u8, v, "text")) return .text;
    if (std.mem.eql(u8, v, "jsonl")) return .jsonl;
    if (std.mem.eql(u8, v, "csv")) return .csv;
    return null;
}

fn parseNameRadius(spec: []const u8) ?struct { name: []const u8, radius: i32, min_count: i32 } {
    const sep = std.mem.indexOfScalar(u8, spec, ':') orelse return null;
    const name = std.mem.trim(u8, spec[0..sep], " ");
    const rest = spec[sep + 1 ..];

    // Check for count@radius syntax (e.g., "5@500")
    if (std.mem.indexOfScalar(u8, rest, '@')) |at_pos| {
        const count_str = std.mem.trim(u8, rest[0..at_pos], " ");
        const radius_str = std.mem.trim(u8, rest[at_pos + 1 ..], " ");
        const min_count = std.fmt.parseInt(i32, count_str, 10) catch return null;
        const radius = std.fmt.parseInt(i32, radius_str, 10) catch return null;
        if (name.len == 0 or radius <= 0 or min_count <= 0) return null;
        return .{ .name = name, .radius = radius, .min_count = min_count };
    }

    // Legacy syntax: just radius (e.g., "500")
    const radius_str = std.mem.trim(u8, rest, " ");
    const radius = std.fmt.parseInt(i32, radius_str, 10) catch return null;
    if (name.len == 0 or radius <= 0) return null;
    return .{ .name = name, .radius = radius, .min_count = 1 };
}

fn parseAnchor(spec: []const u8) ?c.Pos {
    const sep = std.mem.indexOfScalar(u8, spec, ':') orelse return null;
    const x_str = std.mem.trim(u8, spec[0..sep], " ");
    const z_str = std.mem.trim(u8, spec[sep + 1 ..], " ");
    const x = std.fmt.parseInt(i32, x_str, 10) catch return null;
    const z = std.fmt.parseInt(i32, z_str, 10) catch return null;
    return .{ .x = x, .z = z };
}

fn splitMix64(state: *u64) u64 {
    state.* +%= 0x9E3779B97F4A7C15;
    var z = state.*;
    z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

fn nativeShadowProbe(seed: u64, anchor: c.Pos) f64 {
    const n = native_noise.Noise2.init(seed);
    const base_x = @as(f32, @floatFromInt(anchor.x)) * 0.001;
    const base_z = @as(f32, @floatFromInt(anchor.z)) * 0.001;
    const xs = native_noise.V4f32{ base_x, base_x + 0.03125, base_x - 0.0625, base_x + 0.125 };
    const zs = native_noise.V4f32{ base_z, base_z - 0.03125, base_z + 0.0625, base_z - 0.125 };
    const v = n.perlin2f_x4(xs, zs);
    return @as(f64, v[0]) + @as(f64, v[1]) + @as(f64, v[2]) + @as(f64, v[3]);
}

fn cProbeMapBiome(id: i32) f64 {
    // Stable, bounded projection of biome IDs into [-1, 1] for signal comparison.
    const u = @as(u64, @intCast(@as(u32, @bitCast(id))));
    const h = (u *% 1103515245 +% 12345) & 1023;
    return (@as(f64, @floatFromInt(h)) / 511.5) - 1.0;
}

fn cShadowProbe(g: *c.Generator, anchor: c.Pos) f64 {
    const coords = [_]struct { dx: i32, dz: i32 }{
        .{ .dx = 0, .dz = 0 },
        .{ .dx = 16, .dz = -16 },
        .{ .dx = -32, .dz = 32 },
        .{ .dx = 64, .dz = -64 },
    };
    var out: f64 = 0;
    for (coords) |off| {
        const id = c.getBiomeAt(g, 1, anchor.x + off.dx, 0, anchor.z + off.dz);
        out += cProbeMapBiome(id);
    }
    return out;
}

fn nativeBiomeProxyCount(req: BiomeReq, g: *c.Generator, anchor: c.Pos, needed: i32) i32 {
    if (needed <= 0) return 0;
    var count: i32 = 0;

    if (req.points.len > 0) {
        for (req.points) |pt| {
            const id = c.getBiomeAt(g, 1, pt.x, 0, pt.z);
            if (id == req.biome_id) count += 1;
            if (count >= needed) break;
        }
    } else {
        for (req.offsets) |off| {
            const id = c.getBiomeAt(g, 1, anchor.x + off.dx, 0, anchor.z + off.dz);
            if (id == req.biome_id) count += 1;
            if (count >= needed) break;
        }
    }
    return count;
}

fn biomeProxyNeeded(req: BiomeReq) i32 {
    const points_len = if (req.points.len > 0) req.points.len else req.offsets.len;
    if (points_len > 1024 and req.min_count <= 8) return 1;
    return req.min_count;
}

fn nativeCompareNeeded(req: BiomeReq, cmp_req: BiomeCompareReq, strict: bool) i32 {
    return if (strict) req.min_count else cmp_req.proxy_needed;
}

fn evalBiomeThresholdAndProxy(
    req: BiomeReq,
    eval: *EvalState,
    g: *c.Generator,
    anchor: c.Pos,
    needed: i32,
) struct { c_pass: bool, native_pass: bool } {
    var count: i32 = 0;
    var c_pass = false;
    var native_pass = false;

    if (req.points.len > 0) {
        var remaining: i32 = @intCast(req.points.len);
        for (req.points) |pt| {
            remaining -= 1;
            const id = c.getBiomeAt(g, 1, pt.x, 0, pt.z);
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
            const id = c.getBiomeAt(g, 1, anchor.x + off.dx, 0, anchor.z + off.dz);
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

    eval.computed = true;
    eval.finalized = false;
    eval.matched = c_pass;
    eval.count = if (c_pass) req.min_count else 0;
    eval.best_dist2 = std.math.maxInt(i64);
    return .{ .c_pass = c_pass, .native_pass = native_pass };
}

fn buildBiomeCompareReqs(
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

fn runNativeComparePass(
    constraints: []const Constraint,
    evals: []EvalState,
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
        const compare = evalBiomeThresholdAndProxy(req, &evals[bi], g, anchor, needed);
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

fn envFlagEnabled(allocator: std.mem.Allocator, name: []const u8) bool {
    const v = std.process.getEnvVarOwned(allocator, name) catch return false;
    defer allocator.free(v);
    return std.mem.eql(u8, v, "1") or std.ascii.eqlIgnoreCase(v, "true") or std.ascii.eqlIgnoreCase(v, "yes");
}

fn floorDiv(a: i32, b: i32) i32 {
    return std.math.divFloor(i32, a, b) catch unreachable;
}

fn buildStructureRegionsForAnchor(
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

const BiomeScanResult = struct {
    best_dist2: i64,
    count: i32,
};

fn buildBiomeOffsets(allocator: std.mem.Allocator, radius: i32) ![]BiomeOffset {
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

fn buildBiomePointsForAnchor(allocator: std.mem.Allocator, center: c.Pos, offsets: []const BiomeOffset) ![]BiomePoint {
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

fn scanBiomeWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, offsets: []const BiomeOffset) BiomeScanResult {
    var best: i64 = std.math.maxInt(i64);
    var count: i32 = 0;

    if (offsets.len > 0) {
        for (offsets) |off| {
            const id = c.getBiomeAt(g, 1, center.x + off.dx, 0, center.z + off.dz);
            if (id != biome_id) continue;
            count += 1;
            if (off.dist2 < best) best = off.dist2;
        }
    }

    return .{ .best_dist2 = best, .count = count };
}

fn scanBiomePoints(g: *c.Generator, biome_id: i32, points: []const BiomePoint) BiomeScanResult {
    var best: i64 = std.math.maxInt(i64);
    var count: i32 = 0;
    for (points) |pt| {
        const id = c.getBiomeAt(g, 1, pt.x, 0, pt.z);
        if (id != biome_id) continue;
        count += 1;
        if (pt.dist2 < best) best = pt.dist2;
    }
    return .{ .best_dist2 = best, .count = count };
}

fn biomeMatchesWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, min_count: i32, offsets: []const BiomeOffset) bool {
    if (min_count <= 0) return true;
    var count: i32 = 0;
    for (offsets, 0..) |off, i| {
        const id = c.getBiomeAt(g, 1, center.x + off.dx, 0, center.z + off.dz);
        if (id == biome_id) {
            count += 1;
            if (count >= min_count) return true;
        }
        const remaining = offsets.len - i - 1;
        if (count + @as(i32, @intCast(remaining)) < min_count) return false;
    }
    return false;
}

fn biomeMatchesPoints(g: *c.Generator, biome_id: i32, min_count: i32, points: []const BiomePoint) bool {
    if (min_count <= 0) return true;
    var count: i32 = 0;
    for (points, 0..) |pt, i| {
        const id = c.getBiomeAt(g, 1, pt.x, 0, pt.z);
        if (id == biome_id) {
            count += 1;
            if (count >= min_count) return true;
        }
        const remaining = points.len - i - 1;
        if (count + @as(i32, @intCast(remaining)) < min_count) return false;
    }
    return false;
}

fn bestBiomeDistanceWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, offsets: []const BiomeOffset) ?i64 {
    const result = scanBiomeWithinRadius(g, center, biome_id, offsets);
    if (result.count == 0) return null;
    return result.best_dist2;
}

fn bestStructureDistanceWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) ?i64 {
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

fn anyStructureWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) bool {
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

fn evalConstraintAt(
    constraints: []const Constraint,
    aliases: []const usize,
    idx: usize,
    evals: []EvalState,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
    mode: EvalMode,
) bool {
    const alias_idx = aliases[idx];
    if (alias_idx != idx) {
        _ = evalConstraintAt(constraints, aliases, alias_idx, evals, g, seed, mc, anchor, mode);
        evals[idx] = evals[alias_idx];
        return evals[idx].matched;
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

fn evalExpr(
    nodes: []const ExprNode,
    root: usize,
    constraints: []const Constraint,
    aliases: []const usize,
    evals: []EvalState,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) bool {
    return switch (nodes[root]) {
        .literal_true => true,
        .atom => |idx| evalConstraintAt(constraints, aliases, idx, evals, g, seed, mc, anchor, .threshold),
        .not => |child| !evalExpr(nodes, child, constraints, aliases, evals, g, seed, mc, anchor),
        .and_op => |pair| evalExpr(nodes, pair.lhs, constraints, aliases, evals, g, seed, mc, anchor) and evalExpr(nodes, pair.rhs, constraints, aliases, evals, g, seed, mc, anchor),
        .or_op => |pair| evalExpr(nodes, pair.lhs, constraints, aliases, evals, g, seed, mc, anchor) or evalExpr(nodes, pair.rhs, constraints, aliases, evals, g, seed, mc, anchor),
    };
}

fn collectConjunctiveAtoms(
    dst: *std.ArrayList(usize),
    nodes: []const ExprNode,
    root: usize,
) !bool {
    return switch (nodes[root]) {
        .literal_true => true,
        .atom => |idx| blk: {
            try dst.append(idx);
            break :blk true;
        },
        .and_op => |pair| blk: {
            if (!try collectConjunctiveAtoms(dst, nodes, pair.lhs)) break :blk false;
            break :blk try collectConjunctiveAtoms(dst, nodes, pair.rhs);
        },
        else => false,
    };
}

fn buildConjunctiveAtomPlan(
    allocator: std.mem.Allocator,
    nodes: []const ExprNode,
    root: usize,
) !?[]usize {
    var atoms = std.ArrayList(usize).init(allocator);
    errdefer atoms.deinit();
    if (!try collectConjunctiveAtoms(&atoms, nodes, root)) {
        atoms.deinit();
        return null;
    }
    const owned = try atoms.toOwnedSlice();
    return owned;
}

fn canonicalizeConjunctiveAtomPlan(
    allocator: std.mem.Allocator,
    atom_indices: []const usize,
    aliases: []const usize,
) ![]usize {
    var seen = try allocator.alloc(bool, aliases.len);
    defer allocator.free(seen);
    @memset(seen, false);

    var out = std.ArrayList(usize).init(allocator);
    defer out.deinit();

    for (atom_indices) |idx| {
        const canonical = aliases[idx];
        if (seen[canonical]) continue;
        seen[canonical] = true;
        try out.append(canonical);
    }

    return out.toOwnedSlice();
}

fn evalConjunctiveAtoms(
    atom_indices: []const usize,
    constraints: []const Constraint,
    aliases: []const usize,
    evals: []EvalState,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) bool {
    for (atom_indices) |idx| {
        if (!evalConstraintAt(constraints, aliases, idx, evals, g, seed, mc, anchor, .threshold)) return false;
    }
    return true;
}

fn evaluateAll(
    constraints: []const Constraint,
    aliases: []const usize,
    evals: []EvalState,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) void {
    for (constraints, 0..) |_, i| {
        if (aliases[i] != i) continue;
        _ = evalConstraintAt(constraints, aliases, i, evals, g, seed, mc, anchor, .full);
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

fn buildConstraintAliases(allocator: std.mem.Allocator, constraints: []const Constraint) ![]usize {
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

fn summarize(constraints: []const Constraint, evals: []const EvalState) struct { matched: usize, score: f64 } {
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

fn diagnosticsString(allocator: std.mem.Allocator, constraints: []const Constraint, evals: []const EvalState) ![]u8 {
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

fn writeCsvEscaped(writer: anytype, value: []const u8) !void {
    var needs_quotes = false;
    for (value) |ch| {
        if (ch == ',' or ch == '"' or ch == '\n' or ch == '\r') {
            needs_quotes = true;
            break;
        }
    }

    if (!needs_quotes) {
        try writer.writeAll(value);
        return;
    }

    try writer.writeByte('"');
    for (value) |ch| {
        if (ch == '"') {
            try writer.writeAll("\"\"");
        } else {
            try writer.writeByte(ch);
        }
    }
    try writer.writeByte('"');
}

fn emitResult(writer: anytype, fmt: OutputFormat, item: MatchCandidate) !void {
    switch (fmt) {
        .text => {
            try writer.print(
                "seed={d} spawn=({d},{d}) anchor=({d},{d}) score={d:.3} matched={d}/{d} diagnostics={s}\n",
                .{
                    item.seed,
                    item.spawn.x,
                    item.spawn.z,
                    item.anchor.x,
                    item.anchor.z,
                    item.score,
                    item.matched_constraints,
                    item.total_constraints,
                    item.diagnostics,
                },
            );
        },
        .jsonl => {
            const Record = struct {
                seed: u64,
                spawn_x: i32,
                spawn_z: i32,
                anchor_x: i32,
                anchor_z: i32,
                score: f64,
                matched_constraints: usize,
                total_constraints: usize,
                diagnostics: []const u8,
            };
            try std.json.stringify(Record{
                .seed = item.seed,
                .spawn_x = item.spawn.x,
                .spawn_z = item.spawn.z,
                .anchor_x = item.anchor.x,
                .anchor_z = item.anchor.z,
                .score = item.score,
                .matched_constraints = item.matched_constraints,
                .total_constraints = item.total_constraints,
                .diagnostics = item.diagnostics,
            }, .{ .whitespace = .minified }, writer);
            try writer.writeByte('\n');
        },
        .csv => {
            try writer.print(
                "{d},{d},{d},{d},{d},{d:.6},{d},{d},",
                .{
                    item.seed,
                    item.spawn.x,
                    item.spawn.z,
                    item.anchor.x,
                    item.anchor.z,
                    item.score,
                    item.matched_constraints,
                    item.total_constraints,
                },
            );
            try writeCsvEscaped(writer, item.diagnostics);
            try writer.writeByte('\n');
        },
    }
}

fn betterCandidate(lhs: MatchCandidate, rhs: MatchCandidate) bool {
    if (lhs.score > rhs.score) return true;
    if (lhs.score < rhs.score) return false;
    return lhs.seed < rhs.seed;
}

fn keepTopK(list: *std.ArrayList(MatchCandidate), candidate: MatchCandidate, top_k: usize, allocator: std.mem.Allocator) !void {
    if (list.items.len < top_k) {
        try list.append(candidate);
        return;
    }

    var worst_idx: usize = 0;
    var i: usize = 1;
    while (i < list.items.len) : (i += 1) {
        if (betterCandidate(list.items[worst_idx], list.items[i])) {
            worst_idx = i;
        }
    }

    if (betterCandidate(candidate, list.items[worst_idx])) {
        allocator.free(list.items[worst_idx].diagnostics);
        list.items[worst_idx] = candidate;
    } else {
        allocator.free(candidate.diagnostics);
    }
}

fn writeCheckpoint(path: []const u8, checkpoint: Checkpoint) !void {
    const f = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer f.close();
    try std.json.stringify(checkpoint, .{ .whitespace = .minified }, f.writer());
}

fn readCheckpoint(allocator: std.mem.Allocator, path: []const u8) !Checkpoint {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 4 * 1024 * 1024);
    defer allocator.free(data);
    const parsed = try std.json.parseFromSlice(Checkpoint, allocator, data, .{});
    defer parsed.deinit();
    return parsed.value;
}

fn appendNativeShadowRecord(
    mc: i32,
    tested: u64,
    found: usize,
    start_seed: u64,
    end_seed: u64,
    shadow: NativeShadow,
) !void {
    try std.fs.cwd().makePath("tmp/perf");
    var file = std.fs.cwd().openFile("tmp/perf/native_shadow.jsonl", .{ .mode = .read_write }) catch try std.fs.cwd().createFile("tmp/perf/native_shadow.jsonl", .{});
    defer file.close();
    try file.seekFromEnd(0);

    const mean_abs_diff = if (shadow.compared == 0) 0.0 else shadow.abs_diff_sum / @as(f64, @floatFromInt(shadow.compared));
    const Rec = struct {
        mc: i32,
        tested: u64,
        found: usize,
        start_seed: u64,
        end_seed: u64,
        samples: u64,
        native_checksum: f64,
        c_checksum: f64,
        compared: u64,
        sign_mismatch: u64,
        mean_abs_diff: f64,
        max_abs_diff: f64,
        biome_proxy_compared: u64,
        biome_proxy_mismatch: u64,
    };
    try std.json.stringify(Rec{
        .mc = mc,
        .tested = tested,
        .found = found,
        .start_seed = start_seed,
        .end_seed = end_seed,
        .samples = shadow.samples,
        .native_checksum = shadow.native_checksum,
        .c_checksum = shadow.c_checksum,
        .compared = shadow.compared,
        .sign_mismatch = shadow.sign_mismatch,
        .mean_abs_diff = mean_abs_diff,
        .max_abs_diff = shadow.max_abs_diff,
        .biome_proxy_compared = shadow.biome_proxy_compared,
        .biome_proxy_mismatch = shadow.biome_proxy_mismatch,
    }, .{ .whitespace = .minified }, file.writer());
    try file.writer().writeByte('\n');
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
            "  --random                             Sample random seeds instead of linear scan\n" ++
            "  --random-samples <N>                 Test N random samples (requires --random)\n" ++
            "  --require-biome <name:N@radius>      Biome with N+ chunks within radius (keys b1,b2,...)\n" ++
            "  --require-structure <name:radius>    Structure within radius (keys s1,s2,...)\n" ++
            "  --where <expr>                       Boolean expression over bN/sN/cN\n" ++
            "  --anchor <x:z>                       Evaluate constraints around fixed location\n" ++
            "  --level-dat <path>                   Import seed from Java/Bedrock level.dat\n" ++
            "  --ranked                             Keep top results by score across scan range\n" ++
            "  --top-k <N>                          Ranked-mode result count (default: --count)\n" ++
            "  --format <text|jsonl|csv>            Result output format (default: text)\n" ++
            "  --progress-every <N>                 Print throughput/progress every N tested seeds\n" ++
            "  --checkpoint <path>                  Save checkpoint state to path\n" ++
            "  --checkpoint-every <N>               Write checkpoint every N tested seeds\n" ++
            "  --resume                             Resume from checkpoint state\n" ++
            "  --list-biomes                        List accepted biome names\n" ++
            "  --list-structures                    List accepted structure names\n" ++
            "  --output <path>                      Optional output file\n" ++
            "  --experimental-native-shadow         Run native Zig noise in shadow mode (no filtering impact)\n" ++
            "  --experimental-native-shadow-max-mismatch-rate <f64>\n" ++
            "                                       Optional gate: fail if biome proxy mismatch rate exceeds threshold\n" ++
            "  --experimental-native-backend-compare-only\n" ++
            "                                       Compare native biome proxy against C decisions (no filtering impact)\n" ++
            "  --experimental-native-backend-strict\n" ++
            "                                       Fail run on first native-backend compare mismatch\n" ++
            "  --help                               Show help\n\n" ++
            "Expression examples:\n" ++
            "  --where \"b1 and (s1 or s2) and not b3\"\n" ++
            "  --where \"c1 and c2 and (c3 or c4)\"\n\n" ++
            "Random sampling examples:\n" ++
            "  --random --random-samples 1000000    Test 1M random seeds\n" ++
            "  --random --count 10                  Find 10 matches from random seeds\n\n" ++
            "Biome count examples:\n" ++
            "  --require-biome 'jagged_peaks:5@300' 5+ chunks of jagged peaks within 300\n" ++
            "  --require-biome 'ocean:400'          At least 1 ocean chunk within 400 (default)\n",
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

fn freeConstraints(allocator: std.mem.Allocator, constraints: []Constraint) void {
    for (constraints) |cst| {
        switch (cst) {
            .biome => |v| {
                allocator.free(v.key);
                allocator.free(v.label);
                allocator.free(v.offsets);
                allocator.free(v.points);
            },
            .structure => |v| {
                allocator.free(v.key);
                allocator.free(v.label);
                allocator.free(v.regions);
            },
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }

    var biome_constraint_ids = std.ArrayList(usize).init(allocator);
    defer biome_constraint_ids.deinit();
    var structure_constraint_ids = std.ArrayList(usize).init(allocator);
    defer structure_constraint_ids.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    var mc: i32 = c.MC_1_21_1;
    var start_seed: u64 = 0;
    var max_seed: u64 = std.math.maxInt(u64);
    var count: usize = 0;
    var top_k_opt: ?usize = null;
    var ranked = false;
    var output_path: ?[]const u8 = null;
    var output_format: OutputFormat = .text;
    var list_biomes = false;
    var list_structures = false;
    var where_expr: ?[]const u8 = null;
    var anchor_override: ?c.Pos = null;
    var progress_every: u64 = 0;
    var checkpoint_path: ?[]const u8 = null;
    var checkpoint_every: u64 = 100_000;
    var do_resume = false;
    var level_dat_path: ?[]const u8 = null;
    var start_seed_explicit = false;
    var random_mode = false;
    var random_samples: ?u64 = null;
    var native_shadow = NativeShadow{};
    var native_shadow_max_mismatch_rate: ?f64 = null;
    var native_backend = NativeBackend{};

    var biome_idx: usize = 0;
    var structure_idx: usize = 0;

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
            start_seed_explicit = true;
        } else if (std.mem.eql(u8, arg, "--max-seed")) {
            const s = args.next() orelse return error.InvalidArguments;
            max_seed = try std.fmt.parseInt(u64, s, 10);
        } else if (std.mem.eql(u8, arg, "--count")) {
            const s = args.next() orelse return error.InvalidArguments;
            count = try std.fmt.parseInt(usize, s, 10);
        } else if (std.mem.eql(u8, arg, "--top-k")) {
            const s = args.next() orelse return error.InvalidArguments;
            top_k_opt = try std.fmt.parseInt(usize, s, 10);
        } else if (std.mem.eql(u8, arg, "--ranked")) {
            ranked = true;
        } else if (std.mem.eql(u8, arg, "--output")) {
            output_path = args.next() orelse return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--format")) {
            const s = args.next() orelse return error.InvalidArguments;
            output_format = parseOutputFormat(s) orelse return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--where")) {
            where_expr = args.next() orelse return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--anchor")) {
            const s = args.next() orelse return error.InvalidArguments;
            anchor_override = parseAnchor(s) orelse return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--level-dat")) {
            level_dat_path = args.next() orelse return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--progress-every")) {
            const s = args.next() orelse return error.InvalidArguments;
            progress_every = try std.fmt.parseInt(u64, s, 10);
        } else if (std.mem.eql(u8, arg, "--checkpoint")) {
            checkpoint_path = args.next() orelse return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--checkpoint-every")) {
            const s = args.next() orelse return error.InvalidArguments;
            checkpoint_every = try std.fmt.parseInt(u64, s, 10);
        } else if (std.mem.eql(u8, arg, "--resume")) {
            do_resume = true;
        } else if (std.mem.eql(u8, arg, "--random")) {
            random_mode = true;
        } else if (std.mem.eql(u8, arg, "--random-samples")) {
            const s = args.next() orelse return error.InvalidArguments;
            random_samples = try std.fmt.parseInt(u64, s, 10);
        } else if (std.mem.eql(u8, arg, "--experimental-native-shadow")) {
            native_shadow.enabled = true;
        } else if (std.mem.eql(u8, arg, "--experimental-native-shadow-max-mismatch-rate")) {
            const s = args.next() orelse return error.InvalidArguments;
            native_shadow_max_mismatch_rate = try std.fmt.parseFloat(f64, s);
        } else if (std.mem.eql(u8, arg, "--experimental-native-backend-compare-only")) {
            native_backend.compare_only = true;
        } else if (std.mem.eql(u8, arg, "--experimental-native-backend-strict")) {
            native_backend.strict = true;
        } else if (std.mem.eql(u8, arg, "--require-biome")) {
            const spec = args.next() orelse return error.InvalidArguments;
            const parsed = parseNameRadius(spec) orelse return error.InvalidArguments;
            const biome_id = try biome_names.biomeIdFromName(allocator, parsed.name) orelse {
                std.debug.print("error: unknown biome '{s}'\n", .{parsed.name});
                return error.UnknownBiome;
            };

            biome_idx += 1;
            const key = try std.fmt.allocPrint(allocator, "b{d}", .{biome_idx});
            const label = try std.fmt.allocPrint(allocator, "biome:{s}:{d}@{d}", .{ parsed.name, parsed.min_count, parsed.radius });
            try constraints.append(.{ .biome = .{
                .key = key,
                .label = label,
                .biome_id = biome_id,
                .radius = parsed.radius,
                .min_count = parsed.min_count,
                .radius2 = @as(i64, parsed.radius) * parsed.radius,
                .offsets = try buildBiomeOffsets(allocator, parsed.radius),
                .points = &.{},
            } });
            try biome_constraint_ids.append(constraints.items.len - 1);
        } else if (std.mem.eql(u8, arg, "--require-structure")) {
            const spec = args.next() orelse return error.InvalidArguments;
            const parsed = parseNameRadius(spec) orelse return error.InvalidArguments;
            const st = try bedrock.parseStructure(allocator, parsed.name) orelse return error.UnknownStructure;

            structure_idx += 1;
            const key = try std.fmt.allocPrint(allocator, "s{d}", .{structure_idx});
            const label = try std.fmt.allocPrint(allocator, "structure:{s}:{d}", .{ parsed.name, parsed.radius });
            try constraints.append(.{ .structure = .{
                .key = key,
                .label = label,
                .structure = st,
                .radius = parsed.radius,
                .radius2 = @as(i64, parsed.radius) * parsed.radius,
                .structure_c = st.toC(),
                .cfg = null,
                .regions = &.{},
            } });
            try structure_constraint_ids.append(constraints.items.len - 1);
        } else {
            return error.InvalidArguments;
        }
    }

    const stdout = std.io.getStdOut().writer();
    if (list_biomes) try printSupportedBiomes(stdout);
    if (list_structures) try printSupportedStructures(stdout);
    if (list_biomes or list_structures) return;

    if (level_dat_path) |path| {
        if (start_seed_explicit) return error.InvalidArguments;
        start_seed = try nbt.seedFromLevelDatPath(allocator, path);
    }

    if (count == 0) return error.InvalidArguments;
    if (random_mode and start_seed_explicit) return error.InvalidArguments;
    if (random_mode and do_resume) return error.InvalidArguments;
    if (!random_mode and start_seed > max_seed) return error.InvalidArguments;
    if (!random_mode and ranked and max_seed == std.math.maxInt(u64)) return error.InvalidArguments;

    var idx: usize = 0;
    while (idx < constraints.items.len) : (idx += 1) {
        switch (constraints.items[idx]) {
            .biome => |*req| {
                if (anchor_override) |anchor| {
                    req.points = try buildBiomePointsForAnchor(allocator, anchor, req.offsets);
                }
            },
            .structure => |*req| {
                req.cfg = bedrock.getStructureConfig(req.structure, mc);
                if (anchor_override) |anchor| {
                    req.regions = try buildStructureRegionsForAnchor(allocator, anchor, req.*);
                }
            },
        }
    }

    var parser_or_nodes = std.ArrayList(ExprNode).init(allocator);
    defer parser_or_nodes.deinit();
    var expr_root: usize = 0;
    var expr_is_literal_true = false;
    var conjunctive_atoms: ?[]usize = null;
    defer if (conjunctive_atoms) |atoms| allocator.free(atoms);
    var conjunctive_eval_atoms: ?[]usize = null;
    defer if (conjunctive_eval_atoms) |atoms| allocator.free(atoms);

    if (where_expr) |expr| {
        var parser = ExprParser.init(allocator, expr, constraints.items.len, biome_constraint_ids.items, structure_constraint_ids.items);
        defer parser.deinit();
        expr_root = try parser.parse();
        try parser_or_nodes.appendSlice(parser.nodes.items);
    } else {
        if (constraints.items.len == 0) {
            try parser_or_nodes.append(.literal_true);
            expr_root = 0;
        } else {
            try parser_or_nodes.append(.{ .atom = 0 });
            expr_root = 0;
            var i: usize = 1;
            while (i < constraints.items.len) : (i += 1) {
                try parser_or_nodes.append(.{ .atom = i });
                const rhs = parser_or_nodes.items.len - 1;
                try parser_or_nodes.append(.{ .and_op = .{ .lhs = expr_root, .rhs = rhs } });
                expr_root = parser_or_nodes.items.len - 1;
            }
        }
    }
    expr_is_literal_true = parser_or_nodes.items[expr_root] == .literal_true;
    if (!expr_is_literal_true) {
        conjunctive_atoms = try buildConjunctiveAtomPlan(allocator, parser_or_nodes.items, expr_root);
    }

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    var out_file: ?std.fs.File = null;
    defer if (out_file) |f| f.close();

    var output_writer = std.io.getStdOut().writer();
    var file_writer: ?std.fs.File.Writer = null;
    if (output_path) |path| {
        const f = try std.fs.cwd().createFile(path, .{ .truncate = true });
        out_file = f;
        file_writer = f.writer();
        output_writer = f.writer();
    }

    if (output_format == .csv) {
        try output_writer.writeAll("seed,spawn_x,spawn_z,anchor_x,anchor_z,score,matched_constraints,total_constraints,diagnostics\n");
    }

    var found: usize = 0;
    var tested: u64 = 0;
    var seed = start_seed;

    if (do_resume) {
        const path = checkpoint_path orelse return error.InvalidArguments;
        const checkpoint = try readCheckpoint(allocator, path);
        if (checkpoint.next_seed > seed) seed = checkpoint.next_seed;
        tested = checkpoint.tested;
        found = checkpoint.found;
    }

    const top_k = top_k_opt orelse count;
    if (ranked and top_k == 0) return error.InvalidArguments;

    var top = std.ArrayList(MatchCandidate).init(allocator);
    defer {
        for (top.items) |item| allocator.free(item.diagnostics);
        top.deinit();
    }

    const evals = try allocator.alloc(EvalState, constraints.items.len);
    defer allocator.free(evals);
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);
    if (conjunctive_atoms) |atoms| {
        conjunctive_eval_atoms = try canonicalizeConjunctiveAtomPlan(allocator, atoms, aliases);
    }

    const start_ns = std.time.nanoTimestamp();

    var rng_state: u64 = @as(u64, @bitCast(std.time.milliTimestamp()));
    const max_iterations = if (random_mode) (random_samples orelse std.math.maxInt(u64)) else max_seed - start_seed + 1;
    var iteration: u64 = 0;
    const native_compare_active = native_shadow.enabled or native_backend.compare_only;
    var biome_compare_reqs: []BiomeCompareReq = &.{};
    defer if (biome_compare_reqs.len != 0) allocator.free(biome_compare_reqs);
    if (native_compare_active) {
        var biome_indices = std.ArrayList(usize).init(allocator);
        defer biome_indices.deinit();
        for (constraints.items, 0..) |cst, i| {
            if (cst == .biome) {
                try biome_indices.append(i);
            }
        }
        biome_compare_reqs = try buildBiomeCompareReqs(allocator, constraints.items, aliases, biome_indices.items);
    }

    while (iteration < max_iterations and (!ranked and found < count or ranked)) : (iteration += 1) {
        if (random_mode) {
            seed = splitMix64(&rng_state);
        } else {
            seed = start_seed +% iteration;
            if (seed > max_seed) break;
        }
        @memset(evals, .{});

        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const spawn = c.getSpawn(&gen);
        const anchor = anchor_override orelse spawn;
        if (native_shadow.enabled) {
            const native_sig = nativeShadowProbe(seed, anchor);
            const c_sig = cShadowProbe(&gen, anchor);
            const abs_diff = @abs(native_sig - c_sig);
            native_shadow.native_checksum += native_sig;
            native_shadow.c_checksum += c_sig;
            native_shadow.samples +%= 4;
            native_shadow.compared +%= 1;
            native_shadow.abs_diff_sum += abs_diff;
            if (abs_diff > native_shadow.max_abs_diff) native_shadow.max_abs_diff = abs_diff;
            if ((native_sig < 0) != (c_sig < 0)) native_shadow.sign_mismatch +%= 1;
        }
        if (native_compare_active) {
            try runNativeComparePass(
                constraints.items,
                evals,
                &gen,
                anchor,
                biome_compare_reqs,
                &native_shadow,
                &native_backend,
            );
        }

        const matches_expr = if (expr_is_literal_true)
            true
        else if (conjunctive_eval_atoms) |atoms|
            evalConjunctiveAtoms(atoms, constraints.items, aliases, evals, &gen, seed, mc, anchor)
        else
            evalExpr(parser_or_nodes.items, expr_root, constraints.items, aliases, evals, &gen, seed, mc, anchor);

        tested +%= 1;

        if (matches_expr) {
            evaluateAll(constraints.items, aliases, evals, &gen, seed, mc, anchor);
            const summary = summarize(constraints.items, evals);
            const diagnostics = try diagnosticsString(allocator, constraints.items, evals);

            const candidate = MatchCandidate{
                .seed = seed,
                .spawn = spawn,
                .anchor = anchor,
                .score = summary.score,
                .matched_constraints = summary.matched,
                .total_constraints = constraints.items.len,
                .diagnostics = diagnostics,
            };

            if (ranked) {
                try keepTopK(&top, candidate, top_k, allocator);
            } else {
                try emitResult(output_writer, output_format, candidate);
                allocator.free(candidate.diagnostics);
                found += 1;
            }
        }

        if (progress_every > 0 and tested % progress_every == 0) {
            const elapsed_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_ns));
            const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            const rate = @as(f64, @floatFromInt(tested)) / @max(0.001, elapsed_s);
            if (random_mode) {
                const remaining = if (random_samples) |rs| rs - tested else 0;
                const eta_s = if (rate > 0 and random_samples != null) @as(f64, @floatFromInt(remaining)) / rate else 0;
                try stdout.print("progress: tested={d} found={d} rate={d:.0}/s eta={d:.0}s [random]\n", .{ tested, found, rate, eta_s });
            } else {
                const remaining = if (seed < max_seed) max_seed - seed else 0;
                const eta_s = if (rate > 0) @as(f64, @floatFromInt(remaining)) / rate else 0;
                try stdout.print("progress: tested={d} found={d} current_seed={d} rate={d:.0}/s eta={d:.0}s\n", .{ tested, found, seed, rate, eta_s });
            }
        }

        if (checkpoint_path) |path| {
            if (checkpoint_every > 0 and tested % checkpoint_every == 0) {
                try writeCheckpoint(path, .{ .next_seed = seed + 1, .tested = tested, .found = found });
            }
        }
    }

    if (ranked) {
        std.sort.heap(MatchCandidate, top.items, {}, struct {
            fn lessThan(_: void, a: MatchCandidate, b: MatchCandidate) bool {
                return betterCandidate(a, b);
            }
        }.lessThan);

        for (top.items, 0..) |item, i| {
            if (i >= top_k) break;
            try emitResult(output_writer, output_format, item);
        }
        found = @min(top.items.len, top_k);
    }

    if (file_writer) |*fw| {
        _ = fw;
    }

    if (checkpoint_path) |path| {
        try writeCheckpoint(path, .{ .next_seed = seed, .tested = tested, .found = found });
    }

    if (random_mode) {
        try stdout.print("summary: found={d} tested={d} mode=random\n", .{ found, tested });
    } else {
        try stdout.print("summary: found={d} tested={d} start_seed={d} end_seed={d}\n", .{ found, tested, start_seed, if (seed == 0) 0 else seed - 1 });
    }
    if (native_shadow.enabled) {
        const mean_abs_diff = if (native_shadow.compared == 0) 0.0 else native_shadow.abs_diff_sum / @as(f64, @floatFromInt(native_shadow.compared));
        try stdout.print(
            "native-shadow: samples={d} native_checksum={d:.8} c_checksum={d:.8} compared={d} sign_mismatch={d} mean_abs_diff={d:.6} max_abs_diff={d:.6} biome_proxy_mismatch={d}/{d}\n",
            .{
                native_shadow.samples,
                native_shadow.native_checksum,
                native_shadow.c_checksum,
                native_shadow.compared,
                native_shadow.sign_mismatch,
                mean_abs_diff,
                native_shadow.max_abs_diff,
                native_shadow.biome_proxy_mismatch,
                native_shadow.biome_proxy_compared,
            },
        );
        try appendNativeShadowRecord(mc, tested, found, start_seed, if (seed == 0) 0 else seed - 1, native_shadow);
        if (native_shadow_max_mismatch_rate) |max_rate| {
            if (native_shadow.biome_proxy_compared > 0) {
                const rate = @as(f64, @floatFromInt(native_shadow.biome_proxy_mismatch)) / @as(f64, @floatFromInt(native_shadow.biome_proxy_compared));
                if (rate > max_rate) return error.NativeShadowGateFailed;
            }
        }
    }
    if (native_backend.compare_only) {
        try stdout.print("native-backend: compared={d} mismatch={d}\n", .{ native_backend.compared, native_backend.mismatch });
    }
}

test "extract seed from java-style big-endian NBT" {
    const be_nbt = [_]u8{
        10,   0,    0,
        4,    0,    10,
        'R',  'a',  'n',
        'd',  'o',  'm',
        'S',  'e',  'e',
        'd',  0x11, 0x22,
        0x33, 0x44, 0x55,
        0x66, 0x77, 0x88,
        0,
    };
    const seed = try nbt.extractSeedFromLevelDatBytes(std.testing.allocator, &be_nbt);
    try std.testing.expectEqual(@as(u64, 0x1122334455667788), seed);
}

test "native shadow probe deterministic" {
    const anchor = c.Pos{ .x = 128, .z = -256 };
    const a = nativeShadowProbe(42424242, anchor);
    const b = nativeShadowProbe(42424242, anchor);
    try std.testing.expectApproxEqAbs(a, b, 1e-9);
}

test "c shadow probe deterministic" {
    var g: c.Generator = undefined;
    c.setupGenerator(&g, c.MC_1_21_1, 0);
    c.applySeed(&g, c.DIM_OVERWORLD, 42424242);
    const anchor = c.Pos{ .x = 128, .z = -256 };
    const a = cShadowProbe(&g, anchor);
    const b = cShadowProbe(&g, anchor);
    try std.testing.expectApproxEqAbs(a, b, 1e-12);
}

test "precomputed structure regions match dynamic region scan" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 128, .z = -256 };

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    const req_dynamic = StructureReq{
        .key = "",
        .label = "",
        .structure = st,
        .radius = 700,
        .radius2 = @as(i64, 700) * 700,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    };
    var req_precomputed = req_dynamic;
    req_precomputed.regions = try buildStructureRegionsForAnchor(allocator, anchor, req_precomputed);
    defer allocator.free(req_precomputed.regions);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    const seeds = [_]u64{ 0, 1, 42424242, 987654321, 0xDEADBEEFCAFEBABE };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const dyn = bestStructureDistanceWithinRadius(&gen, seed, mc, anchor, req_dynamic);
        const pre = bestStructureDistanceWithinRadius(&gen, seed, mc, anchor, req_precomputed);
        try std.testing.expectEqual(dyn, pre);
    }
}

test "precomputed biome points match dynamic biome scan" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 320, .z = -640 };
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    const offsets = try buildBiomeOffsets(allocator, 256);
    defer allocator.free(offsets);
    const points = try buildBiomePointsForAnchor(allocator, anchor, offsets);
    defer allocator.free(points);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    const seeds = [_]u64{ 0, 1, 42424242, 987654321, 0xDEADBEEFCAFEBABE };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const dyn = scanBiomeWithinRadius(&gen, anchor, biome_id, offsets);
        const pre = scanBiomePoints(&gen, biome_id, points);
        try std.testing.expectEqualDeep(dyn, pre);
    }
}

test "biome threshold evaluation matches full evaluation decisions" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 96, .z = -160 };
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    const offsets = try buildBiomeOffsets(allocator, 180);
    defer allocator.free(offsets);

    var constraints = [_]Constraint{
        .{ .biome = .{
            .key = "",
            .label = "",
            .biome_id = biome_id,
            .radius = 180,
            .min_count = 4,
            .radius2 = @as(i64, 180) * 180,
            .offsets = offsets,
            .points = &.{},
        } },
    };
    const aliases = try buildConstraintAliases(allocator, &constraints);
    defer allocator.free(aliases);

    const evals = try allocator.alloc(EvalState, constraints.len);
    defer allocator.free(evals);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    const seeds = [_]u64{ 0, 1, 2, 3, 5, 8, 13, 21, 42, 42424242 };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);

        @memset(evals, .{});
        const threshold = evalConstraintAt(&constraints, aliases, 0, evals, &gen, seed, mc, anchor, .threshold);

        @memset(evals, .{});
        const full = evalConstraintAt(&constraints, aliases, 0, evals, &gen, seed, mc, anchor, .full);

        try std.testing.expectEqual(full, threshold);
    }
}

test "structure threshold evaluation matches full evaluation decisions" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 128, .z = -256 };
    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    const cfg = bedrock.getStructureConfig(st, mc) orelse unreachable;

    const req = StructureReq{
        .key = "",
        .label = "",
        .structure = st,
        .radius = 700,
        .radius2 = @as(i64, 700) * 700,
        .structure_c = st.toC(),
        .cfg = cfg,
        .regions = &.{},
    };
    var constraints = [_]Constraint{
        .{ .structure = req },
    };
    const aliases = try buildConstraintAliases(allocator, &constraints);
    defer allocator.free(aliases);

    const evals = try allocator.alloc(EvalState, constraints.len);
    defer allocator.free(evals);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    const seeds = [_]u64{ 0, 1, 2, 3, 5, 8, 13, 21, 42, 42424242 };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);

        @memset(evals, .{});
        const threshold = evalConstraintAt(&constraints, aliases, 0, evals, &gen, seed, mc, anchor, .threshold);

        @memset(evals, .{});
        const full = evalConstraintAt(&constraints, aliases, 0, evals, &gen, seed, mc, anchor, .full);

        try std.testing.expectEqual(full, threshold);
    }
}

test "conjunctive expression plan matches recursive evaluator" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 128, .z = -256 };

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const plan = (try buildConjunctiveAtomPlan(allocator, parser.nodes.items, root)) orelse unreachable;
    defer allocator.free(plan);

    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);
    const canonical_plan = try canonicalizeConjunctiveAtomPlan(allocator, plan, aliases);
    defer allocator.free(canonical_plan);

    const evals_expr = try allocator.alloc(EvalState, constraints.items.len);
    defer allocator.free(evals_expr);
    const evals_plan = try allocator.alloc(EvalState, constraints.items.len);
    defer allocator.free(evals_plan);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    const seeds = [_]u64{ 0, 1, 2, 3, 5, 8, 13, 21, 42, 42424242 };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        @memset(evals_expr, .{});
        @memset(evals_plan, .{});
        const recursive = evalExpr(parser.nodes.items, root, constraints.items, aliases, evals_expr, &gen, seed, mc, anchor);
        const planned = evalConjunctiveAtoms(canonical_plan, constraints.items, aliases, evals_plan, &gen, seed, mc, anchor);
        try std.testing.expectEqual(recursive, planned);
    }
}

test "canonical conjunctive plan deduplicates aliased atoms without changing decisions" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 128, .z = -256 };

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b2"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(1);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(2);

    var parser = ExprParser.init(allocator, "b1 and b2 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const plan = (try buildConjunctiveAtomPlan(allocator, parser.nodes.items, root)) orelse unreachable;
    defer allocator.free(plan);

    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);
    try std.testing.expectEqual(@as(usize, 0), aliases[1]);

    const canonical_plan = try canonicalizeConjunctiveAtomPlan(allocator, plan, aliases);
    defer allocator.free(canonical_plan);
    try std.testing.expectEqual(@as(usize, 2), canonical_plan.len);

    const evals_expr = try allocator.alloc(EvalState, constraints.items.len);
    defer allocator.free(evals_expr);
    const evals_plan = try allocator.alloc(EvalState, constraints.items.len);
    defer allocator.free(evals_plan);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    const seeds = [_]u64{ 0, 1, 2, 3, 5, 8, 13, 21, 42, 42424242 };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        @memset(evals_expr, .{});
        @memset(evals_plan, .{});
        const recursive = evalExpr(parser.nodes.items, root, constraints.items, aliases, evals_expr, &gen, seed, mc, anchor);
        const planned = evalConjunctiveAtoms(canonical_plan, constraints.items, aliases, evals_plan, &gen, seed, mc, anchor);
        try std.testing.expectEqual(recursive, planned);
    }
}

test "native biome proxy count matches biome scan count on seeded generator" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 320, .z = -640 };
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    const offsets = try buildBiomeOffsets(allocator, 200);
    defer allocator.free(offsets);
    const points = try buildBiomePointsForAnchor(allocator, anchor, offsets);
    defer allocator.free(points);

    const req = BiomeReq{
        .key = "",
        .label = "",
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4096,
        .radius2 = @as(i64, 200) * 200,
        .offsets = offsets,
        .points = points,
    };

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);
    const seeds = [_]u64{ 0, 1, 42424242, 987654321, 0xDEADBEEFCAFEBABE };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const expected = @min(scanBiomePoints(&gen, biome_id, points).count, req.min_count);
        const actual = nativeBiomeProxyCount(req, &gen, anchor, req.min_count);
        try std.testing.expectEqual(expected, actual);
    }
}

test "native biome proxy count respects comparison threshold" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 320, .z = -640 };
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    const offsets = try buildBiomeOffsets(allocator, 200);
    defer allocator.free(offsets);
    const points = try buildBiomePointsForAnchor(allocator, anchor, offsets);
    defer allocator.free(points);

    const req = BiomeReq{
        .key = "",
        .label = "",
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4096,
        .radius2 = @as(i64, 200) * 200,
        .offsets = offsets,
        .points = points,
    };

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);
    const seeds = [_]u64{ 0, 1, 42424242, 987654321, 0xDEADBEEFCAFEBABE };
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const expected = @min(scanBiomePoints(&gen, biome_id, points).count, @as(i32, 1));
        const actual = nativeBiomeProxyCount(req, &gen, anchor, 1);
        try std.testing.expectEqual(expected, actual);
    }
}

test "strict native compare uses full biome threshold" {
    const req = BiomeReq{
        .key = "",
        .label = "",
        .biome_id = 1,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = &.{},
        .points = &.{},
    };
    const cmp_req = BiomeCompareReq{
        .idx = 0,
        .proxy_needed = 1,
        .weight = 1,
    };
    try std.testing.expectEqual(@as(i32, 1), nativeCompareNeeded(req, cmp_req, false));
    try std.testing.expectEqual(@as(i32, 4), nativeCompareNeeded(req, cmp_req, true));
}

test "evalBiomeThresholdAndProxy matches independent threshold/proxy decisions" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 320, .z = -640 };
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    const offsets = try buildBiomeOffsets(allocator, 200);
    defer allocator.free(offsets);
    const points = try buildBiomePointsForAnchor(allocator, anchor, offsets);
    defer allocator.free(points);

    const req_points = BiomeReq{
        .key = "",
        .label = "",
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4096,
        .radius2 = @as(i64, 200) * 200,
        .offsets = offsets,
        .points = points,
    };
    const req_offsets = BiomeReq{
        .key = "",
        .label = "",
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4096,
        .radius2 = @as(i64, 200) * 200,
        .offsets = offsets,
        .points = &.{},
    };

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);
    const seeds = [_]u64{ 0, 1, 42424242, 987654321, 0xDEADBEEFCAFEBABE };
    const needs = [_]i32{ 1, 4, 64, 1024 };

    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        for (needs) |needed| {
            var eval_points: EvalState = .{};
            const actual_points = evalBiomeThresholdAndProxy(req_points, &eval_points, &gen, anchor, needed);
            const expected_points_c_pass = biomeMatchesPoints(&gen, biome_id, req_points.min_count, points);
            const expected_points_native_pass = nativeBiomeProxyCount(req_points, &gen, anchor, needed) >= needed;
            try std.testing.expectEqual(expected_points_c_pass, actual_points.c_pass);
            try std.testing.expectEqual(expected_points_native_pass, actual_points.native_pass);

            var eval_offsets: EvalState = .{};
            const actual_offsets = evalBiomeThresholdAndProxy(req_offsets, &eval_offsets, &gen, anchor, needed);
            const expected_offsets_c_pass = biomeMatchesWithinRadius(&gen, anchor, biome_id, req_offsets.min_count, offsets);
            const expected_offsets_native_pass = nativeBiomeProxyCount(req_offsets, &gen, anchor, needed) >= needed;
            try std.testing.expectEqual(expected_offsets_c_pass, actual_offsets.c_pass);
            try std.testing.expectEqual(expected_offsets_native_pass, actual_offsets.native_pass);
        }
    }
}

test "evalBiomeThresholdAndProxy sparse misses still match independent decisions" {
    const mc = c.MC_1_21_1;
    const seed: u64 = 129837451;
    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);
    c.applySeed(&gen, c.DIM_OVERWORLD, seed);
    const anchor = c.Pos{ .x = -512, .z = 768 };

    var points = [_]BiomePoint{
        .{ .x = -1200, .z = 1400, .dist2 = 0 },
        .{ .x = -1196, .z = 1404, .dist2 = 0 },
        .{ .x = -1192, .z = 1408, .dist2 = 0 },
        .{ .x = -1188, .z = 1412, .dist2 = 0 },
        .{ .x = -1184, .z = 1416, .dist2 = 0 },
        .{ .x = -1180, .z = 1420, .dist2 = 0 },
        .{ .x = -1176, .z = 1424, .dist2 = 0 },
        .{ .x = -1172, .z = 1428, .dist2 = 0 },
    };
    const req = BiomeReq{
        .key = "b_sparse",
        .label = "sparse-points",
        .biome_id = 1,
        .radius = 0,
        .min_count = 6,
        .radius2 = 0,
        .offsets = &.{},
        .points = &points,
    };

    var eval = EvalState{};
    const actual = evalBiomeThresholdAndProxy(req, &eval, &gen, anchor, 2);
    const expected_c = biomeMatchesPoints(&gen, req.biome_id, req.min_count, req.points);
    var proxy_count: i32 = 0;
    for (req.points) |pt| {
        if (c.getBiomeAt(&gen, 1, pt.x, 0, pt.z) == req.biome_id) proxy_count += 1;
        if (proxy_count >= 2) break;
    }
    const expected_native = proxy_count >= 2;
    try std.testing.expectEqual(expected_c, actual.c_pass);
    try std.testing.expectEqual(expected_native, actual.native_pass);
    try std.testing.expectEqual(expected_c, eval.matched);
}

test "constraint aliasing marks duplicate biome requirements" {
    const allocator = std.testing.allocator;
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;

    var constraints = [_]Constraint{
        .{ .biome = .{
            .key = "",
            .label = "",
            .biome_id = biome_id,
            .radius = 200,
            .min_count = 4,
            .radius2 = @as(i64, 200) * 200,
            .offsets = &.{},
            .points = &.{},
        } },
        .{ .biome = .{
            .key = "",
            .label = "",
            .biome_id = biome_id,
            .radius = 200,
            .min_count = 4,
            .radius2 = @as(i64, 200) * 200,
            .offsets = &.{},
            .points = &.{},
        } },
    };

    const aliases = try buildConstraintAliases(allocator, &constraints);
    defer allocator.free(aliases);
    try std.testing.expectEqual(@as(usize, 0), aliases[0]);
    try std.testing.expectEqual(@as(usize, 0), aliases[1]);
}

test "biome compare reqs deduplicate aliases and preserve weight" {
    const allocator = std.testing.allocator;
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;

    var constraints = [_]Constraint{
        .{ .biome = .{
            .key = "",
            .label = "",
            .biome_id = biome_id,
            .radius = 200,
            .min_count = 4,
            .radius2 = @as(i64, 200) * 200,
            .offsets = &.{},
            .points = &.{},
        } },
        .{ .biome = .{
            .key = "",
            .label = "",
            .biome_id = biome_id,
            .radius = 200,
            .min_count = 4,
            .radius2 = @as(i64, 200) * 200,
            .offsets = &.{},
            .points = &.{},
        } },
    };
    const aliases = try buildConstraintAliases(allocator, &constraints);
    defer allocator.free(aliases);

    const biome_indices = [_]usize{ 0, 1 };
    const reqs = try buildBiomeCompareReqs(allocator, &constraints, aliases, &biome_indices);
    defer allocator.free(reqs);

    try std.testing.expectEqual(@as(usize, 1), reqs.len);
    try std.testing.expectEqual(@as(usize, 0), reqs[0].idx);
    try std.testing.expectEqual(@as(u32, 2), reqs[0].weight);
    try std.testing.expectEqual(@as(i32, 4), reqs[0].proxy_needed);
}

test "opt-in perf: precomputed structure regions" {
    if (!envFlagEnabled(std.testing.allocator, "SEED_FINDER_PERF_TEST")) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 128, .z = -256 };
    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;

    const req_dynamic = StructureReq{
        .key = "",
        .label = "",
        .structure = st,
        .radius = 700,
        .radius2 = @as(i64, 700) * 700,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    };
    var req_precomputed = req_dynamic;
    req_precomputed.regions = try buildStructureRegionsForAnchor(allocator, anchor, req_precomputed);
    defer allocator.free(req_precomputed.regions);

    const rounds: usize = 256;
    var seeds: [rounds]u64 = undefined;
    var rng_state: u64 = 0x123456789ABCDEF0;
    for (0..rounds) |i| seeds[i] = splitMix64(&rng_state);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    var dyn_sum: i128 = 0;
    const start_dyn = std.time.nanoTimestamp();
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const v = bestStructureDistanceWithinRadius(&gen, seed, mc, anchor, req_dynamic);
        dyn_sum += if (v) |x| @as(i128, x) else -1;
    }
    const dyn_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_dyn));

    var pre_sum: i128 = 0;
    const start_pre = std.time.nanoTimestamp();
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const v = bestStructureDistanceWithinRadius(&gen, seed, mc, anchor, req_precomputed);
        pre_sum += if (v) |x| @as(i128, x) else -1;
    }
    const pre_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_pre));

    try std.testing.expectEqual(dyn_sum, pre_sum);

    try std.fs.cwd().makePath("tmp/perf");
    var file = std.fs.cwd().openFile("tmp/perf/perf_test_main.jsonl", .{ .mode = .read_write }) catch try std.fs.cwd().createFile("tmp/perf/perf_test_main.jsonl", .{});
    defer file.close();
    try file.seekFromEnd(0);

    const Rec = struct {
        tag: []const u8,
        rounds: usize,
        dynamic_ns: u64,
        precomputed_ns: u64,
        dynamic_per_op_ns: f64,
        precomputed_per_op_ns: f64,
    };
    try std.json.stringify(Rec{
        .tag = "structure_regions_opt_in",
        .rounds = rounds,
        .dynamic_ns = dyn_ns,
        .precomputed_ns = pre_ns,
        .dynamic_per_op_ns = @as(f64, @floatFromInt(dyn_ns)) / @as(f64, @floatFromInt(rounds)),
        .precomputed_per_op_ns = @as(f64, @floatFromInt(pre_ns)) / @as(f64, @floatFromInt(rounds)),
    }, .{ .whitespace = .minified }, file.writer());
    try file.writer().writeByte('\n');
}

test "opt-in perf: precomputed biome points" {
    if (!envFlagEnabled(std.testing.allocator, "SEED_FINDER_PERF_TEST")) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 320, .z = -640 };
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    const offsets = try buildBiomeOffsets(allocator, 512);
    defer allocator.free(offsets);
    const points = try buildBiomePointsForAnchor(allocator, anchor, offsets);
    defer allocator.free(points);

    const rounds: usize = 256;
    var seeds: [rounds]u64 = undefined;
    var rng_state: u64 = 0x23456789ABCDEF01;
    for (0..rounds) |i| seeds[i] = splitMix64(&rng_state);

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    var dyn_sum: i128 = 0;
    const start_dyn = std.time.nanoTimestamp();
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const res = scanBiomeWithinRadius(&gen, anchor, biome_id, offsets);
        dyn_sum += @as(i128, res.best_dist2) + @as(i128, res.count);
    }
    const dyn_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_dyn));

    var pre_sum: i128 = 0;
    const start_pre = std.time.nanoTimestamp();
    for (seeds) |seed| {
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const res = scanBiomePoints(&gen, biome_id, points);
        pre_sum += @as(i128, res.best_dist2) + @as(i128, res.count);
    }
    const pre_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_pre));

    try std.testing.expectEqual(dyn_sum, pre_sum);

    try std.fs.cwd().makePath("tmp/perf");
    var file = std.fs.cwd().openFile("tmp/perf/perf_test_main.jsonl", .{ .mode = .read_write }) catch try std.fs.cwd().createFile("tmp/perf/perf_test_main.jsonl", .{});
    defer file.close();
    try file.seekFromEnd(0);

    const Rec = struct {
        tag: []const u8,
        rounds: usize,
        dynamic_ns: u64,
        precomputed_ns: u64,
        dynamic_per_op_ns: f64,
        precomputed_per_op_ns: f64,
    };
    try std.json.stringify(Rec{
        .tag = "biome_points_opt_in",
        .rounds = rounds,
        .dynamic_ns = dyn_ns,
        .precomputed_ns = pre_ns,
        .dynamic_per_op_ns = @as(f64, @floatFromInt(dyn_ns)) / @as(f64, @floatFromInt(rounds)),
        .precomputed_per_op_ns = @as(f64, @floatFromInt(pre_ns)) / @as(f64, @floatFromInt(rounds)),
    }, .{ .whitespace = .minified }, file.writer());
    try file.writer().writeByte('\n');
}

test "opt-in perf: constraint aliasing duplicate-biome query" {
    if (!envFlagEnabled(std.testing.allocator, "SEED_FINDER_PERF_TEST")) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 0, .z = 0 };
    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    const rounds: usize = 256;

    var constraints = [_]Constraint{
        .{ .biome = .{
            .key = "",
            .label = "",
            .biome_id = biome_id,
            .radius = 220,
            .min_count = 4,
            .radius2 = @as(i64, 220) * 220,
            .offsets = try buildBiomeOffsets(allocator, 220),
            .points = &.{},
        } },
        .{ .biome = .{
            .key = "",
            .label = "",
            .biome_id = biome_id,
            .radius = 220,
            .min_count = 4,
            .radius2 = @as(i64, 220) * 220,
            .offsets = try buildBiomeOffsets(allocator, 220),
            .points = &.{},
        } },
    };
    defer allocator.free(constraints[0].biome.offsets);
    defer allocator.free(constraints[1].biome.offsets);

    const aliases_on = try buildConstraintAliases(allocator, &constraints);
    defer allocator.free(aliases_on);
    const aliases_off = try allocator.alloc(usize, constraints.len);
    defer allocator.free(aliases_off);
    for (0..aliases_off.len) |i| aliases_off[i] = i;

    var seeds: [rounds]u64 = undefined;
    var rng_state: u64 = 0xABCDEF0123456789;
    for (0..rounds) |i| seeds[i] = splitMix64(&rng_state);

    const evals = try allocator.alloc(EvalState, constraints.len);
    defer allocator.free(evals);
    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    var sum_on: i128 = 0;
    const start_on = std.time.nanoTimestamp();
    for (seeds) |seed| {
        @memset(evals, .{});
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        _ = evalConstraintAt(&constraints, aliases_on, 0, evals, &gen, seed, mc, anchor, .threshold);
        _ = evalConstraintAt(&constraints, aliases_on, 1, evals, &gen, seed, mc, anchor, .threshold);
        sum_on += @as(i128, @intFromBool(evals[0].matched)) + @as(i128, @intFromBool(evals[1].matched));
    }
    const on_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_on));

    var sum_off: i128 = 0;
    const start_off = std.time.nanoTimestamp();
    for (seeds) |seed| {
        @memset(evals, .{});
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        _ = evalConstraintAt(&constraints, aliases_off, 0, evals, &gen, seed, mc, anchor, .threshold);
        _ = evalConstraintAt(&constraints, aliases_off, 1, evals, &gen, seed, mc, anchor, .threshold);
        sum_off += @as(i128, @intFromBool(evals[0].matched)) + @as(i128, @intFromBool(evals[1].matched));
    }
    const off_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_off));

    try std.testing.expectEqual(sum_off, sum_on);

    try std.fs.cwd().makePath("tmp/perf");
    var file = std.fs.cwd().openFile("tmp/perf/perf_test_main.jsonl", .{ .mode = .read_write }) catch try std.fs.cwd().createFile("tmp/perf/perf_test_main.jsonl", .{});
    defer file.close();
    try file.seekFromEnd(0);
    const Rec = struct {
        tag: []const u8,
        rounds: usize,
        aliases_off_ns: u64,
        aliases_on_ns: u64,
        aliases_off_per_round_ns: f64,
        aliases_on_per_round_ns: f64,
    };
    try std.json.stringify(Rec{
        .tag = "constraint_aliasing_dup_biome",
        .rounds = rounds,
        .aliases_off_ns = off_ns,
        .aliases_on_ns = on_ns,
        .aliases_off_per_round_ns = @as(f64, @floatFromInt(off_ns)) / @as(f64, @floatFromInt(rounds)),
        .aliases_on_per_round_ns = @as(f64, @floatFromInt(on_ns)) / @as(f64, @floatFromInt(rounds)),
    }, .{ .whitespace = .minified }, file.writer());
    try file.writer().writeByte('\n');
}

test "search regression: spawn-anchor biome+structure query" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();

    const evals = try allocator.alloc(EvalState, constraints.items.len);
    defer allocator.free(evals);
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    var found = std.ArrayList(u64).init(allocator);
    defer found.deinit();
    const expected = [_]u64{ 2, 6, 9, 12, 15, 17, 18, 19 };

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    var seed: u64 = 0;
    while (seed <= 500_000 and found.items.len < expected.len) : (seed += 1) {
        @memset(evals, .{});
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const spawn = c.getSpawn(&gen);
        if (!evalExpr(parser.nodes.items, root, constraints.items, aliases, evals, &gen, seed, mc, spawn)) continue;
        try found.append(seed);
    }

    try std.testing.expectEqual(expected.len, found.items.len);
    try std.testing.expectEqualSlices(u64, &expected, found.items);
}

test "search regression: fixed-anchor biome-only query" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;
    const anchor = c.Pos{ .x = 0, .z = 0 };

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }

    const biome_id = try biome_names.biomeIdFromName(allocator, "forest") orelse unreachable;
    const offsets = try buildBiomeOffsets(allocator, 180);
    const points = try buildBiomePointsForAnchor(allocator, anchor, offsets);
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:forest:3@180"),
        .biome_id = biome_id,
        .radius = 180,
        .min_count = 3,
        .radius2 = @as(i64, 180) * 180,
        .offsets = offsets,
        .points = points,
    } });

    const evals = try allocator.alloc(EvalState, constraints.items.len);
    defer allocator.free(evals);
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    var found = std.ArrayList(u64).init(allocator);
    defer found.deinit();
    const expected = [_]u64{ 0, 1, 2, 5, 6, 9, 12, 13 };

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    var seed: u64 = 0;
    while (seed <= 1_000_000 and found.items.len < expected.len) : (seed += 1) {
        @memset(evals, .{});
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        if (!evalConstraintAt(constraints.items, aliases, 0, evals, &gen, seed, mc, anchor, .threshold)) continue;
        try found.append(seed);
    }

    try std.testing.expectEqual(expected.len, found.items.len);
    try std.testing.expectEqualSlices(u64, &expected, found.items);
}

fn snapshotSearchOutput(
    allocator: std.mem.Allocator,
    mc: i32,
    constraints: []const Constraint,
    aliases: []const usize,
    expr_nodes: []const ExprNode,
    expr_root: usize,
    count: usize,
    max_seed: u64,
    ranked: bool,
    top_k: usize,
    output_format: OutputFormat,
    enable_shadow: bool,
    enable_backend_compare_only: bool,
) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();

    var gen: c.Generator = undefined;
    c.setupGenerator(&gen, mc, 0);

    const evals = try allocator.alloc(EvalState, constraints.len);
    defer allocator.free(evals);

    var native_shadow = NativeShadow{ .enabled = enable_shadow };
    var native_backend = NativeBackend{ .compare_only = enable_backend_compare_only };
    const native_compare_active = native_shadow.enabled or native_backend.compare_only;
    var biome_compare_reqs: []BiomeCompareReq = &.{};
    defer if (biome_compare_reqs.len != 0) allocator.free(biome_compare_reqs);
    if (native_compare_active) {
        var biome_indices = std.ArrayList(usize).init(allocator);
        defer biome_indices.deinit();
        for (constraints, 0..) |cst, i| {
            if (cst == .biome) try biome_indices.append(i);
        }
        biome_compare_reqs = try buildBiomeCompareReqs(allocator, constraints, aliases, biome_indices.items);
    }
    var top = std.ArrayList(MatchCandidate).init(allocator);
    defer {
        for (top.items) |item| allocator.free(item.diagnostics);
        top.deinit();
    }

    var tested: u64 = 0;
    var found: usize = 0;
    var seed: u64 = 0;
    var iteration: u64 = 0;
    const max_iterations = max_seed + 1;

    if (output_format == .csv) {
        try out.writer().writeAll("seed,spawn_x,spawn_z,anchor_x,anchor_z,score,matched_constraints,total_constraints,diagnostics\n");
    }

    while (iteration < max_iterations and ((!ranked and found < count) or ranked)) : (iteration += 1) {
        seed = iteration;
        @memset(evals, .{});
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const spawn = c.getSpawn(&gen);
        const anchor = spawn;

        if (native_shadow.enabled) {
            const native_sig = nativeShadowProbe(seed, anchor);
            const c_sig = cShadowProbe(&gen, anchor);
            const abs_diff = @abs(native_sig - c_sig);
            native_shadow.native_checksum += native_sig;
            native_shadow.c_checksum += c_sig;
            native_shadow.samples +%= 4;
            native_shadow.compared +%= 1;
            native_shadow.abs_diff_sum += abs_diff;
            if (abs_diff > native_shadow.max_abs_diff) native_shadow.max_abs_diff = abs_diff;
            if ((native_sig < 0) != (c_sig < 0)) native_shadow.sign_mismatch +%= 1;
        }
        if (native_compare_active) {
            try runNativeComparePass(
                constraints,
                evals,
                &gen,
                anchor,
                biome_compare_reqs,
                &native_shadow,
                &native_backend,
            );
        }

        const matched = evalExpr(expr_nodes, expr_root, constraints, aliases, evals, &gen, seed, mc, anchor);
        tested +%= 1;
        if (!matched) continue;

        evaluateAll(constraints, aliases, evals, &gen, seed, mc, anchor);
        const summary = summarize(constraints, evals);
        const diagnostics = try diagnosticsString(allocator, constraints, evals);
        const candidate = MatchCandidate{
            .seed = seed,
            .spawn = spawn,
            .anchor = anchor,
            .score = summary.score,
            .matched_constraints = summary.matched,
            .total_constraints = constraints.len,
            .diagnostics = diagnostics,
        };

        if (ranked) {
            try keepTopK(&top, candidate, top_k, allocator);
        } else {
            try emitResult(out.writer(), output_format, candidate);
            allocator.free(candidate.diagnostics);
            found += 1;
        }
    }

    if (ranked) {
        std.sort.heap(MatchCandidate, top.items, {}, struct {
            fn lessThan(_: void, a: MatchCandidate, b: MatchCandidate) bool {
                return betterCandidate(a, b);
            }
        }.lessThan);

        for (top.items, 0..) |item, i| {
            if (i >= top_k) break;
            try emitResult(out.writer(), output_format, item);
        }
        found = @min(top.items.len, top_k);
    }

    try out.writer().print(
        "summary: found={d} tested={d} start_seed={d} end_seed={d}\n",
        .{ found, tested, @as(u64, 0), if (seed == 0) 0 else seed - 1 },
    );
    return out.toOwnedSlice();
}

test "search regression fixture: full emitted stream + summary" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    const actual = try snapshotSearchOutput(
        allocator,
        mc,
        constraints.items,
        aliases,
        parser.nodes.items,
        root,
        8,
        500,
        false,
        0,
        .text,
        false,
        false,
    );
    defer allocator.free(actual);

    const expected = try std.fs.cwd().readFileAlloc(
        allocator,
        "tests/golden/search_stream_spawn_anchor.txt",
        1 * 1024 * 1024,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, actual);
}

test "search regression fixture: ranked jsonl stream + summary" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    const actual = try snapshotSearchOutput(
        allocator,
        mc,
        constraints.items,
        aliases,
        parser.nodes.items,
        root,
        8,
        500,
        true,
        6,
        .jsonl,
        false,
        false,
    );
    defer allocator.free(actual);

    const expected = try std.fs.cwd().readFileAlloc(
        allocator,
        "tests/golden/search_ranked_jsonl.txt",
        1 * 1024 * 1024,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, actual);
}

test "search regression fixture: csv stream + summary" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    const actual = try snapshotSearchOutput(
        allocator,
        mc,
        constraints.items,
        aliases,
        parser.nodes.items,
        root,
        8,
        500,
        false,
        0,
        .csv,
        false,
        false,
    );
    defer allocator.free(actual);

    const expected = try std.fs.cwd().readFileAlloc(
        allocator,
        "tests/golden/search_stream_spawn_anchor.csv",
        1 * 1024 * 1024,
    );
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, actual);
}

test "native shadow does not influence results" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    const baseline = try snapshotSearchOutput(allocator, mc, constraints.items, aliases, parser.nodes.items, root, 8, 500, false, 0, .text, false, false);
    defer allocator.free(baseline);
    const shadow = try snapshotSearchOutput(allocator, mc, constraints.items, aliases, parser.nodes.items, root, 8, 500, false, 0, .text, true, false);
    defer allocator.free(shadow);

    try std.testing.expectEqualStrings(baseline, shadow);
}

test "native compare-only backend does not influence results" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    for ([_]OutputFormat{ .text, .jsonl, .csv }) |fmt| {
        const baseline = try snapshotSearchOutput(allocator, mc, constraints.items, aliases, parser.nodes.items, root, 8, 500, false, 0, fmt, false, false);
        defer allocator.free(baseline);
        const compare_only = try snapshotSearchOutput(allocator, mc, constraints.items, aliases, parser.nodes.items, root, 8, 500, false, 0, fmt, false, true);
        defer allocator.free(compare_only);
        try std.testing.expectEqualStrings(baseline, compare_only);
    }
}

test "native shadow + compare-only together do not influence results" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }
    var biome_ids = std.ArrayList(usize).init(allocator);
    defer biome_ids.deinit();
    var structure_ids = std.ArrayList(usize).init(allocator);
    defer structure_ids.deinit();

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:4@200"),
        .biome_id = biome_id,
        .radius = 200,
        .min_count = 4,
        .radius2 = @as(i64, 200) * 200,
        .offsets = try buildBiomeOffsets(allocator, 200),
        .points = &.{},
    } });
    try biome_ids.append(0);

    const st = try bedrock.parseStructure(allocator, "village") orelse unreachable;
    try constraints.append(.{ .structure = .{
        .key = try allocator.dupe(u8, "s1"),
        .label = try allocator.dupe(u8, "structure:village:500"),
        .structure = st,
        .radius = 500,
        .radius2 = @as(i64, 500) * 500,
        .structure_c = st.toC(),
        .cfg = bedrock.getStructureConfig(st, mc),
        .regions = &.{},
    } });
    try structure_ids.append(1);

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items);
    defer parser.deinit();
    const root = try parser.parse();
    const aliases = try buildConstraintAliases(allocator, constraints.items);
    defer allocator.free(aliases);

    const baseline = try snapshotSearchOutput(allocator, mc, constraints.items, aliases, parser.nodes.items, root, 8, 500, false, 0, .text, false, false);
    defer allocator.free(baseline);
    const both = try snapshotSearchOutput(allocator, mc, constraints.items, aliases, parser.nodes.items, root, 8, 500, false, 0, .text, true, true);
    defer allocator.free(both);

    try std.testing.expectEqualStrings(baseline, both);
}

test "extract seed from bedrock level.dat header + little-endian NBT" {
    const le_nbt = [_]u8{
        10,   0,    0,
        4,    10,   0,
        'R',  'a',  'n',
        'd',  'o',  'm',
        'S',  'e',  'e',
        'd',  0x88, 0x77,
        0x66, 0x55, 0x44,
        0x33, 0x22, 0x11,
        0,
    };
    const header = [_]u8{
        10,                  0, 0, 0, // level.dat version
        @as(u8, le_nbt.len), 0, 0, 0,
    };

    var data = std.ArrayList(u8).init(std.testing.allocator);
    defer data.deinit();
    try data.appendSlice(&header);
    try data.appendSlice(&le_nbt);

    const seed = try nbt.extractSeedFromLevelDatBytes(std.testing.allocator, data.items);
    try std.testing.expectEqual(@as(u64, 0x1122334455667788), seed);
}
