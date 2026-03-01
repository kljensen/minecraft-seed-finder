const std = @import("std");
const c = @import("cubiomes_port.zig");
const bedrock = @import("bedrock.zig");
const biome_names = @import("biome_names.zig");
const nbt = @import("nbt.zig");
const app = @import("main.zig");

const BiomeReq = app.BiomeReq;
const StructureReq = app.StructureReq;
const Constraint = app.Constraint;
const EvalState = app.EvalState;
const ExprNode = app.ExprNode;
const ExprParser = app.ExprParser;
const OutputFormat = app.OutputFormat;
const MatchCandidate = app.MatchCandidate;
const NativeShadow = app.NativeShadow;
const NativeBackend = app.NativeBackend;
const BiomeOffset = app.BiomeOffset;
const BiomePoint = app.BiomePoint;
const BiomeCompareReq = app.BiomeCompareReq;
const buildConjunctiveAtomPlan = app.buildConjunctiveAtomPlan;
const canonicalizeConjunctiveAtomPlan = app.canonicalizeConjunctiveAtomPlan;
const nativeBiomeProxyCount = app.nativeBiomeProxyCount;
const nativeCompareNeeded = app.nativeCompareNeeded;
const evalBiomeThresholdAndProxy = app.evalBiomeThresholdAndProxy;
const buildBiomeCompareReqs = app.buildBiomeCompareReqs;
const runNativeComparePass = app.runNativeComparePass;
const buildStructureRegionsForAnchor = app.buildStructureRegionsForAnchor;
const buildBiomeOffsets = app.buildBiomeOffsets;
const buildBiomePointsForAnchor = app.buildBiomePointsForAnchor;
const scanBiomeWithinRadius = app.scanBiomeWithinRadius;
const scanBiomePoints = app.scanBiomePoints;
const biomeMatchesWithinRadius = app.biomeMatchesWithinRadius;
const biomeMatchesPoints = app.biomeMatchesPoints;
const bestStructureDistanceWithinRadius = app.bestStructureDistanceWithinRadius;
const evalConstraintAt = app.evalConstraintAt;
const evalExpr = app.evalExpr;
const evalConjunctiveAtoms = app.evalConjunctiveAtoms;
const evaluateAll = app.evaluateAll;
const buildConstraintAliases = app.buildConstraintAliases;
const reorderConjunctiveAtomsByEstimatedCost = app.reorderConjunctiveAtomsByEstimatedCost;
const summarize = app.summarize;
const diagnosticsString = app.diagnosticsString;
const emitResult = app.emitResult;
const betterCandidate = app.betterCandidate;
const keepTopK = app.keepTopK;
const splitMix64 = app.splitMix64;
const nativeShadowProbe = app.nativeShadowProbe;
const cShadowProbe = app.cShadowProbe;
const envFlagEnabled = app.envFlagEnabled;
const freeConstraints = app.freeConstraints;

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
        const threshold = evalConstraintAt(&constraints, aliases, 0, evals, 1, &gen, seed, mc, anchor, .threshold);

        @memset(evals, .{});
        const full = evalConstraintAt(&constraints, aliases, 0, evals, 1, &gen, seed, mc, anchor, .full);

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
        const threshold = evalConstraintAt(&constraints, aliases, 0, evals, 1, &gen, seed, mc, anchor, .threshold);

        @memset(evals, .{});
        const full = evalConstraintAt(&constraints, aliases, 0, evals, 1, &gen, seed, mc, anchor, .full);

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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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
        const recursive = evalExpr(parser.nodes.items, root, constraints.items, aliases, evals_expr, 1, &gen, seed, mc, anchor);
        const planned = evalConjunctiveAtoms(canonical_plan, constraints.items, aliases, evals_plan, 1, &gen, seed, mc, anchor);
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

    var parser = ExprParser.init(allocator, "b1 and b2 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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
        const recursive = evalExpr(parser.nodes.items, root, constraints.items, aliases, evals_expr, 1, &gen, seed, mc, anchor);
        const planned = evalConjunctiveAtoms(canonical_plan, constraints.items, aliases, evals_plan, 1, &gen, seed, mc, anchor);
        try std.testing.expectEqual(recursive, planned);
    }
}

test "conjunctive plan cost ordering places cheaper structure checks first" {
    const allocator = std.testing.allocator;
    const mc = c.MC_1_21_1;

    var constraints = std.ArrayList(Constraint).init(allocator);
    defer {
        freeConstraints(allocator, constraints.items);
        constraints.deinit();
    }

    const biome_id = try biome_names.biomeIdFromName(allocator, "plains") orelse unreachable;
    try constraints.append(.{ .biome = .{
        .key = try allocator.dupe(u8, "b1"),
        .label = try allocator.dupe(u8, "biome:plains:16@512"),
        .biome_id = biome_id,
        .radius = 512,
        .min_count = 16,
        .radius2 = @as(i64, 512) * 512,
        .offsets = try buildBiomeOffsets(allocator, 512),
        .points = &.{},
    } });

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

    var atom_plan = [_]usize{ 0, 1 };
    reorderConjunctiveAtomsByEstimatedCost(&atom_plan, constraints.items);
    try std.testing.expectEqual(@as(usize, 1), atom_plan[0]);
    try std.testing.expectEqual(@as(usize, 0), atom_plan[1]);
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
            const actual_points = evalBiomeThresholdAndProxy(req_points, &eval_points, 1, &gen, anchor, needed);
            const expected_points_c_pass = biomeMatchesPoints(&gen, biome_id, req_points.min_count, points);
            const expected_points_native_pass = nativeBiomeProxyCount(req_points, &gen, anchor, needed) >= needed;
            try std.testing.expectEqual(expected_points_c_pass, actual_points.c_pass);
            try std.testing.expectEqual(expected_points_native_pass, actual_points.native_pass);

            var eval_offsets: EvalState = .{};
            const actual_offsets = evalBiomeThresholdAndProxy(req_offsets, &eval_offsets, 1, &gen, anchor, needed);
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
    const actual = evalBiomeThresholdAndProxy(req, &eval, 1, &gen, anchor, 2);
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
        _ = evalConstraintAt(&constraints, aliases_on, 0, evals, 1, &gen, seed, mc, anchor, .threshold);
        _ = evalConstraintAt(&constraints, aliases_on, 1, evals, 1, &gen, seed, mc, anchor, .threshold);
        sum_on += @as(i128, @intFromBool(evals[0].matched)) + @as(i128, @intFromBool(evals[1].matched));
    }
    const on_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_on));

    var sum_off: i128 = 0;
    const start_off = std.time.nanoTimestamp();
    for (seeds) |seed| {
        @memset(evals, .{});
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        _ = evalConstraintAt(&constraints, aliases_off, 0, evals, 1, &gen, seed, mc, anchor, .threshold);
        _ = evalConstraintAt(&constraints, aliases_off, 1, evals, 1, &gen, seed, mc, anchor, .threshold);
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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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
        if (!evalExpr(parser.nodes.items, root, constraints.items, aliases, evals, 1, &gen, seed, mc, spawn)) continue;
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
        if (!evalConstraintAt(constraints.items, aliases, 0, evals, 1, &gen, seed, mc, anchor, .threshold)) continue;
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
                1,
                &gen,
                anchor,
                biome_compare_reqs,
                &native_shadow,
                &native_backend,
            );
        }

        const matched = evalExpr(expr_nodes, expr_root, constraints, aliases, evals, 1, &gen, seed, mc, anchor);
        tested +%= 1;
        if (!matched) continue;

        evaluateAll(constraints, aliases, evals, 1, &gen, seed, mc, anchor);
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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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

    var parser = ExprParser.init(allocator, "b1 and s1", constraints.items.len, biome_ids.items, structure_ids.items, &.{}, &.{});
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
