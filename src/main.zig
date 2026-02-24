const std = @import("std");
const c = @import("cubiomes_port.zig");
const bedrock = @import("bedrock.zig");
const biome_names = @import("biome_names.zig");
const native_noise = @import("native_noise.zig");
const nbt = @import("nbt.zig");
const types = @import("search_types.zig");
const expr = @import("expr.zig");
const search_eval = @import("search_eval.zig");
const output = @import("output.zig");

pub const BiomeReq = types.BiomeReq;
pub const StructureReq = types.StructureReq;
pub const Constraint = types.Constraint;
pub const EvalState = types.EvalState;
pub const EvalMode = types.EvalMode;
pub const ExprNode = expr.ExprNode;
pub const ExprParser = expr.ExprParser;
pub const OutputFormat = types.OutputFormat;
pub const Checkpoint = types.Checkpoint;
pub const MatchCandidate = types.MatchCandidate;
pub const NativeShadow = types.NativeShadow;
pub const NativeBackend = types.NativeBackend;
pub const BiomeOffset = types.BiomeOffset;
pub const BiomePoint = types.BiomePoint;
pub const StructureRegion = types.StructureRegion;
pub const BiomeCompareReq = types.BiomeCompareReq;
pub const buildConjunctiveAtomPlan = expr.buildConjunctiveAtomPlan;
pub const canonicalizeConjunctiveAtomPlan = expr.canonicalizeConjunctiveAtomPlan;
pub const nativeBiomeProxyCount = search_eval.nativeBiomeProxyCount;
pub const nativeCompareNeeded = search_eval.nativeCompareNeeded;
pub const evalBiomeThresholdAndProxy = search_eval.evalBiomeThresholdAndProxy;
pub const buildBiomeCompareReqs = search_eval.buildBiomeCompareReqs;
pub const runNativeComparePass = search_eval.runNativeComparePass;
pub const buildStructureRegionsForAnchor = search_eval.buildStructureRegionsForAnchor;
pub const buildBiomeOffsets = search_eval.buildBiomeOffsets;
pub const buildBiomePointsForAnchor = search_eval.buildBiomePointsForAnchor;
pub const scanBiomeWithinRadius = search_eval.scanBiomeWithinRadius;
pub const scanBiomePoints = search_eval.scanBiomePoints;
pub const biomeMatchesWithinRadius = search_eval.biomeMatchesWithinRadius;
pub const biomeMatchesPoints = search_eval.biomeMatchesPoints;
pub const bestStructureDistanceWithinRadius = search_eval.bestStructureDistanceWithinRadius;
pub const evalConstraintAt = search_eval.evalConstraintAt;
pub const evalExpr = search_eval.evalExpr;
pub const evalConjunctiveAtoms = search_eval.evalConjunctiveAtoms;
pub const evaluateAll = search_eval.evaluateAll;
pub const buildConstraintAliases = search_eval.buildConstraintAliases;
pub const summarize = search_eval.summarize;
pub const diagnosticsString = search_eval.diagnosticsString;
pub const emitResult = output.emitResult;
pub const betterCandidate = output.betterCandidate;
pub const keepTopK = output.keepTopK;
pub const writeCheckpoint = output.writeCheckpoint;
pub const readCheckpoint = output.readCheckpoint;

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

pub fn splitMix64(state: *u64) u64 {
    state.* +%= 0x9E3779B97F4A7C15;
    var z = state.*;
    z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

pub fn nativeShadowProbe(seed: u64, anchor: c.Pos) f64 {
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

pub fn cShadowProbe(g: *c.Generator, anchor: c.Pos) f64 {
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

pub fn envFlagEnabled(allocator: std.mem.Allocator, name: []const u8) bool {
    const v = std.process.getEnvVarOwned(allocator, name) catch return false;
    defer allocator.free(v);
    return std.mem.eql(u8, v, "1") or std.ascii.eqlIgnoreCase(v, "true") or std.ascii.eqlIgnoreCase(v, "yes");
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

const PerfBreakdown = struct {
    apply_seed_ns: u128 = 0,
    get_spawn_ns: u128 = 0,
    constraint_eval_ns: u128 = 0,
    output_ns: u128 = 0,
};

fn appendPerfBreakdownRecord(
    label: []const u8,
    tested: u64,
    found: usize,
    breakdown: PerfBreakdown,
) !void {
    try std.fs.cwd().makePath("tmp/perf");
    var file = std.fs.cwd().openFile("tmp/perf/hot_loop_breakdown.jsonl", .{ .mode = .read_write }) catch try std.fs.cwd().createFile("tmp/perf/hot_loop_breakdown.jsonl", .{});
    defer file.close();
    try file.seekFromEnd(0);

    const Rec = struct {
        label: []const u8,
        tested: u64,
        found: usize,
        apply_seed_ns: u128,
        get_spawn_ns: u128,
        constraint_eval_ns: u128,
        output_ns: u128,
    };
    try std.json.stringify(Rec{
        .label = label,
        .tested = tested,
        .found = found,
        .apply_seed_ns = breakdown.apply_seed_ns,
        .get_spawn_ns = breakdown.get_spawn_ns,
        .constraint_eval_ns = breakdown.constraint_eval_ns,
        .output_ns = breakdown.output_ns,
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
            "  --perf-breakdown <label>             Record/apply per-stage hot-loop timings into tmp/perf\n" ++
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

pub fn freeConstraints(allocator: std.mem.Allocator, constraints: []Constraint) void {
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
    var perf_breakdown_label: ?[]const u8 = null;

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
        } else if (std.mem.eql(u8, arg, "--perf-breakdown")) {
            perf_breakdown_label = args.next() orelse return error.InvalidArguments;
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

    if (where_expr) |where_filter| {
        var parser = ExprParser.init(allocator, where_filter, constraints.items.len, biome_constraint_ids.items, structure_constraint_ids.items);
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
    var eval_epoch: u64 = 1;
    const native_compare_active = native_shadow.enabled or native_backend.compare_only;
    const fixed_anchor = anchor_override != null;
    const lazy_spawn = fixed_anchor and !envFlagEnabled(allocator, "SEED_FINDER_DISABLE_LAZY_SPAWN");
    const perf_enabled = perf_breakdown_label != null;
    var perf_breakdown = PerfBreakdown{};
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
        eval_epoch +%= 1;
        if (eval_epoch == 0) {
            if (evals.len != 0) @memset(evals, .{});
            eval_epoch = 1;
        }

        var spawn: ?c.Pos = null;
        const apply_seed_start = if (perf_enabled) std.time.nanoTimestamp() else 0;
        c.applySeed(&gen, c.DIM_OVERWORLD, seed);
        if (perf_enabled) {
            perf_breakdown.apply_seed_ns += @as(u128, @intCast(std.time.nanoTimestamp() - apply_seed_start));
        }
        const anchor = if (anchor_override) |fixed| blk: {
            if (!lazy_spawn) {
                const get_spawn_start = if (perf_enabled) std.time.nanoTimestamp() else 0;
                spawn = c.getSpawn(&gen);
                if (perf_enabled) {
                    perf_breakdown.get_spawn_ns += @as(u128, @intCast(std.time.nanoTimestamp() - get_spawn_start));
                }
            }
            break :blk fixed;
        } else blk: {
            const get_spawn_start = if (perf_enabled) std.time.nanoTimestamp() else 0;
            const computed_spawn = c.getSpawn(&gen);
            if (perf_enabled) {
                perf_breakdown.get_spawn_ns += @as(u128, @intCast(std.time.nanoTimestamp() - get_spawn_start));
            }
            spawn = computed_spawn;
            break :blk computed_spawn;
        };
        const constraint_eval_start = if (perf_enabled) std.time.nanoTimestamp() else 0;
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
                eval_epoch,
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
            evalConjunctiveAtoms(atoms, constraints.items, aliases, evals, eval_epoch, &gen, seed, mc, anchor)
        else
            evalExpr(parser_or_nodes.items, expr_root, constraints.items, aliases, evals, eval_epoch, &gen, seed, mc, anchor);
        if (perf_enabled) {
            perf_breakdown.constraint_eval_ns += @as(u128, @intCast(std.time.nanoTimestamp() - constraint_eval_start));
        }

        tested +%= 1;

        if (matches_expr) {
            if (lazy_spawn and spawn == null) {
                const get_spawn_start = if (perf_enabled) std.time.nanoTimestamp() else 0;
                spawn = c.getSpawn(&gen);
                if (perf_enabled) {
                    perf_breakdown.get_spawn_ns += @as(u128, @intCast(std.time.nanoTimestamp() - get_spawn_start));
                }
            }
            const output_start = if (perf_enabled) std.time.nanoTimestamp() else 0;
            evaluateAll(constraints.items, aliases, evals, eval_epoch, &gen, seed, mc, anchor);
            const summary = summarize(constraints.items, evals);
            const diagnostics = try diagnosticsString(allocator, constraints.items, evals);

            const candidate = MatchCandidate{
                .seed = seed,
                .spawn = spawn.?,
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
            if (perf_enabled) {
                perf_breakdown.output_ns += @as(u128, @intCast(std.time.nanoTimestamp() - output_start));
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
    if (perf_breakdown_label) |label| {
        const total_hot_ns = perf_breakdown.apply_seed_ns + perf_breakdown.get_spawn_ns + perf_breakdown.constraint_eval_ns + perf_breakdown.output_ns;
        if (total_hot_ns > 0 and tested > 0) {
            const total_hot_f = @as(f64, @floatFromInt(total_hot_ns));
            try stdout.print(
                "perf-breakdown[{s}]: tested={d} applySeed={d:.2}% getSpawn={d:.2}% eval={d:.2}% output={d:.2}% ns/seed={d:.1}\n",
                .{
                    label,
                    tested,
                    @as(f64, @floatFromInt(perf_breakdown.apply_seed_ns)) * 100.0 / total_hot_f,
                    @as(f64, @floatFromInt(perf_breakdown.get_spawn_ns)) * 100.0 / total_hot_f,
                    @as(f64, @floatFromInt(perf_breakdown.constraint_eval_ns)) * 100.0 / total_hot_f,
                    @as(f64, @floatFromInt(perf_breakdown.output_ns)) * 100.0 / total_hot_f,
                    total_hot_f / @as(f64, @floatFromInt(tested)),
                },
            );
        }
        try appendPerfBreakdownRecord(label, tested, found, perf_breakdown);
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
