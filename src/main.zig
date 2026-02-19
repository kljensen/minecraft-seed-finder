const std = @import("std");
const c = @import("c_bindings.zig");
const bedrock = @import("bedrock.zig");
const biome_names = @import("biome_names.zig");

const BiomeReq = struct {
    key: []const u8,
    label: []const u8,
    biome_id: i32,
    radius: i32,
};

const StructureReq = struct {
    key: []const u8,
    label: []const u8,
    structure: bedrock.Structure,
    radius: i32,
    structure_c: c_int,
    cfg: ?bedrock.StructureConfig,
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
    matched: bool = false,
    best_dist2: i64 = std.math.maxInt(i64),
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

const Endian = enum {
    big,
    little,
};

const NbtSeedInfo = struct {
    random_seed: ?i64 = null,
    worldgen_seed: ?i64 = null,
    any_seed: ?i64 = null,
};

const NbtReader = struct {
    data: []const u8,
    pos: usize = 0,
    endian: Endian,

    fn init(data: []const u8, endian: Endian) NbtReader {
        return .{ .data = data, .endian = endian };
    }

    fn readU8(self: *NbtReader) !u8 {
        if (self.pos >= self.data.len) return error.InvalidLevelDat;
        const v = self.data[self.pos];
        self.pos += 1;
        return v;
    }

    fn readU16(self: *NbtReader) !u16 {
        if (self.pos + 2 > self.data.len) return error.InvalidLevelDat;
        const b0 = self.data[self.pos];
        const b1 = self.data[self.pos + 1];
        const v: u16 = switch (self.endian) {
            .big => (@as(u16, b0) << 8) | b1,
            .little => (@as(u16, b1) << 8) | b0,
        };
        self.pos += 2;
        return v;
    }

    fn readI32(self: *NbtReader) !i32 {
        if (self.pos + 4 > self.data.len) return error.InvalidLevelDat;
        const b0 = self.data[self.pos];
        const b1 = self.data[self.pos + 1];
        const b2 = self.data[self.pos + 2];
        const b3 = self.data[self.pos + 3];
        const raw: u32 = switch (self.endian) {
            .big => (@as(u32, b0) << 24) | (@as(u32, b1) << 16) | (@as(u32, b2) << 8) | b3,
            .little => (@as(u32, b3) << 24) | (@as(u32, b2) << 16) | (@as(u32, b1) << 8) | b0,
        };
        const v: i32 = @bitCast(raw);
        self.pos += 4;
        return v;
    }

    fn readI64(self: *NbtReader) !i64 {
        if (self.pos + 8 > self.data.len) return error.InvalidLevelDat;
        const raw: u64 = switch (self.endian) {
            .big => (@as(u64, self.data[self.pos]) << 56) |
                (@as(u64, self.data[self.pos + 1]) << 48) |
                (@as(u64, self.data[self.pos + 2]) << 40) |
                (@as(u64, self.data[self.pos + 3]) << 32) |
                (@as(u64, self.data[self.pos + 4]) << 24) |
                (@as(u64, self.data[self.pos + 5]) << 16) |
                (@as(u64, self.data[self.pos + 6]) << 8) |
                @as(u64, self.data[self.pos + 7]),
            .little => (@as(u64, self.data[self.pos + 7]) << 56) |
                (@as(u64, self.data[self.pos + 6]) << 48) |
                (@as(u64, self.data[self.pos + 5]) << 40) |
                (@as(u64, self.data[self.pos + 4]) << 32) |
                (@as(u64, self.data[self.pos + 3]) << 24) |
                (@as(u64, self.data[self.pos + 2]) << 16) |
                (@as(u64, self.data[self.pos + 1]) << 8) |
                @as(u64, self.data[self.pos]),
        };
        const v: i64 = @bitCast(raw);
        self.pos += 8;
        return v;
    }

    fn skip(self: *NbtReader, len: usize) !void {
        if (self.pos + len > self.data.len) return error.InvalidLevelDat;
        self.pos += len;
    }

    fn readName(self: *NbtReader) ![]const u8 {
        const len = try self.readU16();
        if (self.pos + len > self.data.len) return error.InvalidLevelDat;
        const out = self.data[self.pos .. self.pos + len];
        self.pos += len;
        return out;
    }
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

fn parseNameRadius(spec: []const u8) ?struct { name: []const u8, radius: i32 } {
    const sep = std.mem.indexOfScalar(u8, spec, ':') orelse return null;
    const name = std.mem.trim(u8, spec[0..sep], " ");
    const radius_str = std.mem.trim(u8, spec[sep + 1 ..], " ");
    const radius = std.fmt.parseInt(i32, radius_str, 10) catch return null;
    if (name.len == 0 or radius <= 0) return null;
    return .{ .name = name, .radius = radius };
}

fn parseAnchor(spec: []const u8) ?c.Pos {
    const sep = std.mem.indexOfScalar(u8, spec, ':') orelse return null;
    const x_str = std.mem.trim(u8, spec[0..sep], " ");
    const z_str = std.mem.trim(u8, spec[sep + 1 ..], " ");
    const x = std.fmt.parseInt(i32, x_str, 10) catch return null;
    const z = std.fmt.parseInt(i32, z_str, 10) catch return null;
    return .{ .x = x, .z = z };
}

fn parseNbtTagPayload(
    reader: *NbtReader,
    tag_id: u8,
    name: []const u8,
    in_worldgen: bool,
    out: *NbtSeedInfo,
) !void {
    switch (tag_id) {
        0 => {},
        1 => try reader.skip(1),
        2 => try reader.skip(2),
        3 => try reader.skip(4),
        4 => {
            const v = try reader.readI64();
            if (std.mem.eql(u8, name, "RandomSeed") and out.random_seed == null) {
                out.random_seed = v;
            } else if (std.mem.eql(u8, name, "seed")) {
                if (in_worldgen and out.worldgen_seed == null) {
                    out.worldgen_seed = v;
                }
                if (out.any_seed == null) out.any_seed = v;
            }
        },
        5 => try reader.skip(4),
        6 => try reader.skip(8),
        7 => {
            const n = try reader.readI32();
            if (n < 0) return error.InvalidLevelDat;
            try reader.skip(@intCast(n));
        },
        8 => {
            const n = try reader.readU16();
            try reader.skip(n);
        },
        9 => {
            const elem_type = try reader.readU8();
            const n = try reader.readI32();
            if (n < 0) return error.InvalidLevelDat;
            var i: i32 = 0;
            while (i < n) : (i += 1) {
                try parseNbtTagPayload(reader, elem_type, "", in_worldgen, out);
            }
        },
        10 => {
            const next_in_worldgen = in_worldgen or std.mem.eql(u8, name, "WorldGenSettings");
            while (true) {
                const child_type = try reader.readU8();
                if (child_type == 0) break;
                const child_name = try reader.readName();
                try parseNbtTagPayload(reader, child_type, child_name, next_in_worldgen, out);
            }
        },
        11 => {
            const n = try reader.readI32();
            if (n < 0) return error.InvalidLevelDat;
            const byte_len = @as(usize, @intCast(n)) * 4;
            try reader.skip(byte_len);
        },
        12 => {
            const n = try reader.readI32();
            if (n < 0) return error.InvalidLevelDat;
            const byte_len = @as(usize, @intCast(n)) * 8;
            try reader.skip(byte_len);
        },
        else => return error.InvalidLevelDat,
    }
}

fn parseNbtForSeed(data: []const u8, endian: Endian) !?u64 {
    var reader = NbtReader.init(data, endian);
    const root_type = try reader.readU8();
    if (root_type != 10) return error.InvalidLevelDat;
    _ = try reader.readName();

    var info = NbtSeedInfo{};
    try parseNbtTagPayload(&reader, 10, "", false, &info);

    if (info.random_seed) |v| return @bitCast(v);
    if (info.worldgen_seed) |v| return @bitCast(v);
    if (info.any_seed) |v| return @bitCast(v);
    return null;
}

fn readU32Le(bytes: []const u8) !u32 {
    if (bytes.len < 4) return error.InvalidLevelDat;
    return @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16) |
        (@as(u32, bytes[3]) << 24);
}

fn extractSeedFromLevelDatBytes(allocator: std.mem.Allocator, data: []const u8) !u64 {
    if (data.len >= 2 and data[0] == 0x1f and data[1] == 0x8b) {
        var compressed_stream = std.io.fixedBufferStream(data);
        var decompressed = std.ArrayList(u8).init(allocator);
        defer decompressed.deinit();
        try std.compress.gzip.decompress(compressed_stream.reader(), decompressed.writer());
        if (try parseNbtForSeed(decompressed.items, .big)) |seed| return seed;
        return error.LevelDatSeedNotFound;
    }

    if (parseNbtForSeed(data, .big) catch null) |seed| return seed;

    if (data.len >= 8) {
        const payload_len = readU32Le(data[4..8]) catch 0;
        const end = 8 + @as(usize, payload_len);
        if (payload_len > 0 and end <= data.len) {
            const nbt = data[8..end];
            if (parseNbtForSeed(nbt, .little) catch null) |seed| return seed;
        }
    }

    if (parseNbtForSeed(data, .little) catch null) |seed| return seed;
    return error.LevelDatSeedNotFound;
}

fn seedFromLevelDatPath(allocator: std.mem.Allocator, path: []const u8) !u64 {
    const bytes = try std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024 * 1024);
    defer allocator.free(bytes);
    return extractSeedFromLevelDatBytes(allocator, bytes);
}

fn floorDiv(a: i32, b: i32) i32 {
    return std.math.divFloor(i32, a, b) catch unreachable;
}

fn bestBiomeDistanceWithinRadius(g: *c.Generator, center: c.Pos, biome_id: i32, radius: i32) ?i64 {
    const step: i32 = 4;
    const r2: i64 = @as(i64, radius) * radius;
    var best: i64 = std.math.maxInt(i64);

    var dz: i32 = -radius;
    while (dz <= radius) : (dz += step) {
        var dx: i32 = -radius;
        while (dx <= radius) : (dx += step) {
            const dist2 = @as(i64, dx) * dx + @as(i64, dz) * dz;
            if (dist2 > r2) continue;
            const id = c.getBiomeAt(g, 1, center.x + dx, 0, center.z + dz);
            if (id != biome_id) continue;
            if (dist2 < best) best = dist2;
        }
    }

    if (best == std.math.maxInt(i64)) return null;
    return best;
}

fn bestStructureDistanceWithinRadius(g: *c.Generator, seed: u64, mc: i32, center: c.Pos, req: StructureReq) ?i64 {
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

    const r2: i64 = @as(i64, req.radius) * req.radius;
    var best: i64 = std.math.maxInt(i64);

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

    if (best == std.math.maxInt(i64)) return null;
    return best;
}

fn evalConstraintAt(
    constraints: []const Constraint,
    idx: usize,
    evals: []EvalState,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) bool {
    if (evals[idx].computed) return evals[idx].matched;
    evals[idx].computed = true;

    const cst = constraints[idx];
    switch (cst) {
        .biome => |req| {
            if (bestBiomeDistanceWithinRadius(g, anchor, req.biome_id, req.radius)) |best| {
                evals[idx].matched = true;
                evals[idx].best_dist2 = best;
            }
        },
        .structure => |req| {
            if (bestStructureDistanceWithinRadius(g, seed, mc, anchor, req)) |best| {
                evals[idx].matched = true;
                evals[idx].best_dist2 = best;
            }
        },
    }

    return evals[idx].matched;
}

fn evalExpr(
    nodes: []const ExprNode,
    root: usize,
    constraints: []const Constraint,
    evals: []EvalState,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) bool {
    return switch (nodes[root]) {
        .literal_true => true,
        .atom => |idx| evalConstraintAt(constraints, idx, evals, g, seed, mc, anchor),
        .not => |child| !evalExpr(nodes, child, constraints, evals, g, seed, mc, anchor),
        .and_op => |pair| evalExpr(nodes, pair.lhs, constraints, evals, g, seed, mc, anchor) and evalExpr(nodes, pair.rhs, constraints, evals, g, seed, mc, anchor),
        .or_op => |pair| evalExpr(nodes, pair.lhs, constraints, evals, g, seed, mc, anchor) or evalExpr(nodes, pair.rhs, constraints, evals, g, seed, mc, anchor),
    };
}

fn evaluateAll(
    constraints: []const Constraint,
    evals: []EvalState,
    g: *c.Generator,
    seed: u64,
    mc: i32,
    anchor: c.Pos,
) void {
    for (constraints, 0..) |_, i| {
        _ = evalConstraintAt(constraints, i, evals, g, seed, mc, anchor);
    }
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
            try w.writeAll("miss");
            continue;
        }
        const dist = std.math.sqrt(@as(f64, @floatFromInt(evals[i].best_dist2)));
        try w.print("ok@{d:.1}", .{dist});
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

fn printUsage(writer: anytype) !void {
    try writer.print(
        "Usage:\n" ++
            "  seed-finder --count <N> [options]\n\n" ++
            "Options:\n" ++
            "  --version <1.18|1.19|1.20|1.21.1>   Minecraft version (default: 1.21.1)\n" ++
            "  --start-seed <u64>                   First seed to test (default: 0)\n" ++
            "  --max-seed <u64>                     Stop scanning after this seed\n" ++
            "  --count <N>                          Number of matches to output\n" ++
            "  --require-biome <name:radius>        Repeatable biome filter (keys b1,b2,...)\n" ++
            "  --require-structure <name:radius>    Repeatable structure filter (keys s1,s2,...)\n" ++
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
            "  --help                               Show help\n\n" ++
            "Expression examples:\n" ++
            "  --where \"b1 and (s1 or s2) and not b3\"\n" ++
            "  --where \"c1 and c2 and (c3 or c4)\"\n",
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
            },
            .structure => |v| {
                allocator.free(v.key);
                allocator.free(v.label);
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
        } else if (std.mem.eql(u8, arg, "--require-biome")) {
            const spec = args.next() orelse return error.InvalidArguments;
            const parsed = parseNameRadius(spec) orelse return error.InvalidArguments;
            const biome_id = try biome_names.biomeIdFromName(allocator, parsed.name) orelse return error.UnknownBiome;

            biome_idx += 1;
            const key = try std.fmt.allocPrint(allocator, "b{d}", .{biome_idx});
            const label = try std.fmt.allocPrint(allocator, "biome:{s}:{d}", .{ parsed.name, parsed.radius });
            try constraints.append(.{ .biome = .{
                .key = key,
                .label = label,
                .biome_id = biome_id,
                .radius = parsed.radius,
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
                .structure_c = st.toC(),
                .cfg = null,
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
        start_seed = try seedFromLevelDatPath(allocator, path);
    }

    if (count == 0) return error.InvalidArguments;
    if (start_seed > max_seed) return error.InvalidArguments;
    if (ranked and max_seed == std.math.maxInt(u64)) return error.InvalidArguments;

    var idx: usize = 0;
    while (idx < constraints.items.len) : (idx += 1) {
        switch (constraints.items[idx]) {
            .structure => |*req| req.cfg = bedrock.getStructureConfig(req.structure, mc),
            else => {},
        }
    }

    var parser_or_nodes = std.ArrayList(ExprNode).init(allocator);
    defer parser_or_nodes.deinit();
    var expr_root: usize = 0;

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

    const start_ns = std.time.nanoTimestamp();

    while (seed <= max_seed and (!ranked and found < count or ranked)) : (seed +%= 1) {
        @memset(evals, .{});

        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        const spawn = c.getSpawn(&gen);
        const anchor = anchor_override orelse spawn;

        const matches_expr = evalExpr(parser_or_nodes.items, expr_root, constraints.items, evals, &gen, seed, mc, anchor);

        tested +%= 1;

        if (matches_expr) {
            evaluateAll(constraints.items, evals, &gen, seed, mc, anchor);
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
            const remaining = if (seed < max_seed) max_seed - seed else 0;
            const eta_s = if (rate > 0) @as(f64, @floatFromInt(remaining)) / rate else 0;
            try stdout.print("progress: tested={d} found={d} current_seed={d} rate={d:.0}/s eta={d:.0}s\n", .{ tested, found, seed, rate, eta_s });
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

    try stdout.print("summary: found={d} tested={d} start_seed={d} end_seed={d}\n", .{ found, tested, start_seed, if (seed == 0) 0 else seed - 1 });
}

test "extract seed from java-style big-endian NBT" {
    const be_nbt = [_]u8{
        10, 0, 0,
        4, 0, 10, 'R', 'a', 'n', 'd', 'o', 'm', 'S', 'e', 'e', 'd',
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
        0,
    };
    const seed = try extractSeedFromLevelDatBytes(std.testing.allocator, &be_nbt);
    try std.testing.expectEqual(@as(u64, 0x1122334455667788), seed);
}

test "extract seed from bedrock level.dat header + little-endian NBT" {
    const le_nbt = [_]u8{
        10, 0, 0,
        4, 10, 0, 'R', 'a', 'n', 'd', 'o', 'm', 'S', 'e', 'e', 'd',
        0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11,
        0,
    };
    const header = [_]u8{
        10, 0, 0, 0, // level.dat version
        @as(u8, le_nbt.len), 0, 0, 0,
    };

    var data = std.ArrayList(u8).init(std.testing.allocator);
    defer data.deinit();
    try data.appendSlice(&header);
    try data.appendSlice(&le_nbt);

    const seed = try extractSeedFromLevelDatBytes(std.testing.allocator, data.items);
    try std.testing.expectEqual(@as(u64, 0x1122334455667788), seed);
}
