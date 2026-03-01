const std = @import("std");

pub const ExprNode = union(enum) {
    literal_true,
    atom: usize,
    not: usize,
    and_op: struct { lhs: usize, rhs: usize },
    or_op: struct { lhs: usize, rhs: usize },
};

pub const ExprParser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize,
    constraints_len: usize,
    biome_ids: []const usize,
    structure_ids: []const usize,
    climate_ids: []const usize,
    terrain_ids: []const usize,
    nodes: std.ArrayList(ExprNode),

    pub fn init(
        allocator: std.mem.Allocator,
        input: []const u8,
        constraints_len: usize,
        biome_ids: []const usize,
        structure_ids: []const usize,
        climate_ids: []const usize,
        terrain_ids: []const usize,
    ) ExprParser {
        return .{
            .allocator = allocator,
            .input = input,
            .pos = 0,
            .constraints_len = constraints_len,
            .biome_ids = biome_ids,
            .structure_ids = structure_ids,
            .climate_ids = climate_ids,
            .terrain_ids = terrain_ids,
            .nodes = std.ArrayList(ExprNode).init(allocator),
        };
    }

    pub fn deinit(self: *ExprParser) void {
        self.nodes.deinit();
    }

    pub fn parse(self: *ExprParser) anyerror!usize {
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

        // Try "cl" prefix first (before "c") for climate constraints
        if (ident.len >= 3 and ident[0] == 'c' and ident[1] == 'l') {
            const ord = std.fmt.parseInt(usize, ident[2..], 10) catch return null;
            if (ord == 0 or ord > self.climate_ids.len) return null;
            return self.climate_ids[ord - 1];
        }

        const ord = std.fmt.parseInt(usize, ident[1..], 10) catch return null;
        if (ord == 0) return null;

        // "c" prefix: overall constraint index
        if (ident[0] == 'c') {
            if (ord > self.constraints_len) return null;
            return ord - 1;
        }
        // "b" prefix: biome constraint index
        if (ident[0] == 'b') {
            if (ord > self.biome_ids.len) return null;
            return self.biome_ids[ord - 1];
        }
        // "s" prefix: structure constraint index
        if (ident[0] == 's') {
            if (ord > self.structure_ids.len) return null;
            return self.structure_ids[ord - 1];
        }
        // "t" prefix: terrain constraint index
        if (ident[0] == 't') {
            if (ord > self.terrain_ids.len) return null;
            return self.terrain_ids[ord - 1];
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

pub fn buildConjunctiveAtomPlan(
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

pub fn canonicalizeConjunctiveAtomPlan(
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
