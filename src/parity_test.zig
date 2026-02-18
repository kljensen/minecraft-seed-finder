const std = @import("std");
const c = @import("c_bindings.zig");
const bedrock = @import("bedrock.zig");

const SpawnVector = struct { mc: i32, seed: u64, x: i32, z: i32 };
const BiomeVector = struct { mc: i32, seed: u64, x: i32, z: i32, b1: i32, b4: i32 };
const StructureVector = struct {
    mc: i32,
    seed: u64,
    st: []const u8,
    rx: i32,
    rz: i32,
    x: i32,
    z: i32,
    vp: bool,
    vt: bool,
};

const Corpus = struct {
    seed_count: usize,
    biome_samples_per_seed: usize,
    spawns: []SpawnVector,
    biomes: []BiomeVector,
    structures: []StructureVector,
};

const GenState = struct {
    gen: c.Generator = undefined,
    has_setup: bool = false,
    current_mc: i32 = 0,
    current_seed: u64 = 0,
    has_seed: bool = false,

    fn ensure(self: *GenState, mc: i32, seed: u64) void {
        if (!self.has_setup or self.current_mc != mc) {
            c.setupGenerator(&self.gen, mc, 0);
            self.current_mc = mc;
            self.has_setup = true;
            self.has_seed = false;
        }
        if (!self.has_seed or self.current_seed != seed) {
            c.applySeed(&self.gen, c.DIM_OVERWORLD, seed);
            self.current_seed = seed;
            self.has_seed = true;
        }
    }
};

test "full parity corpus matches reference outputs" {
    const data = try std.fs.cwd().readFileAlloc(std.testing.allocator, "tests/golden/parity_vectors.json", 512 * 1024 * 1024);
    defer std.testing.allocator.free(data);

    const parsed = try std.json.parseFromSlice(Corpus, std.testing.allocator, data, .{});
    defer parsed.deinit();

    var state = GenState{};

    for (parsed.value.spawns) |v| {
        state.ensure(v.mc, v.seed);
        const spawn = c.getSpawn(&state.gen);
        try std.testing.expectEqual(v.x, spawn.x);
        try std.testing.expectEqual(v.z, spawn.z);
    }

    for (parsed.value.biomes) |v| {
        state.ensure(v.mc, v.seed);
        const b1 = c.getBiomeAt(&state.gen, 1, v.x, 0, v.z);
        const b4 = c.getBiomeAt(&state.gen, 4, @divFloor(v.x, 4), 0, @divFloor(v.z, 4));
        try std.testing.expectEqual(v.b1, b1);
        try std.testing.expectEqual(v.b4, b4);
    }

    for (parsed.value.structures) |v| {
        state.ensure(v.mc, v.seed);
        const st = try bedrock.parseStructure(std.testing.allocator, v.st) orelse {
            std.debug.panic("unknown structure tag in corpus: {s}", .{v.st});
        };
        const pos = bedrock.getStructurePos(st, v.mc, v.seed, v.rx, v.rz) orelse {
            std.debug.panic("missing structure pos for {s}", .{v.st});
        };
        try std.testing.expectEqual(v.x, pos.x);
        try std.testing.expectEqual(v.z, pos.z);

        const vp = c.isViableStructurePos(st.toC(), &state.gen, pos.x, pos.z, 0) != 0;
        const vt = c.isViableStructureTerrain(st.toC(), &state.gen, pos.x, pos.z) != 0;
        if (v.vp != vp) {
            std.debug.print(
                "vp mismatch mc={d} seed={d} st={s} rx={d} rz={d} pos=({d},{d}) expected={any} got={any}\\n",
                .{ v.mc, v.seed, v.st, v.rx, v.rz, pos.x, pos.z, v.vp, vp },
            );
            return error.TestExpectedEqual;
        }
        if (v.vt != vt) {
            std.debug.print(
                "vt mismatch mc={d} seed={d} st={s} rx={d} rz={d} pos=({d},{d}) expected={any} got={any}\\n",
                .{ v.mc, v.seed, v.st, v.rx, v.rz, pos.x, pos.z, v.vt, vt },
            );
            return error.TestExpectedEqual;
        }
        try std.testing.expectEqual(v.vp, vp);
        try std.testing.expectEqual(v.vt, vt);
    }
}
