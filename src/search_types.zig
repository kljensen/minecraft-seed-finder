const std = @import("std");
const c = @import("cubiomes_port.zig");
const bedrock = @import("bedrock.zig");

pub const BiomeOffset = struct {
    dx: i32,
    dz: i32,
    dist2: i64,
};

pub const BiomePoint = struct {
    x: i32,
    z: i32,
    dist2: i64,
};

pub const ClimateRange = struct {
    lo: i32,
    hi: i32,
};

pub const BiomeClimateBounds = struct {
    ranges: [6]ClimateRange,
    valid: bool = false,
};

pub const StructureRegion = struct {
    reg_x: i32,
    reg_z: i32,
};

pub const BiomeReq = struct {
    key: []const u8,
    label: []const u8,
    biome_id: i32,
    radius: i32,
    min_count: i32,
    radius2: i64,
    offsets: []BiomeOffset = &.{},
    points: []BiomePoint = &.{},
    climate_bounds: ?BiomeClimateBounds = null,
};

pub const StructureReq = struct {
    key: []const u8,
    label: []const u8,
    structure: bedrock.Structure,
    radius: i32,
    radius2: i64,
    structure_c: c_int,
    cfg: ?bedrock.StructureConfig,
    cfg_raw: ?c.StructureConfig = null,
    pos_mode: bedrock.StructurePosMode = .generic,
    regions: []StructureRegion = &.{},
};

pub const Constraint = union(enum) {
    biome: BiomeReq,
    structure: StructureReq,

    pub fn key(self: Constraint) []const u8 {
        return switch (self) {
            .biome => |v| v.key,
            .structure => |v| v.key,
        };
    }

    pub fn label(self: Constraint) []const u8 {
        return switch (self) {
            .biome => |v| v.label,
            .structure => |v| v.label,
        };
    }

    pub fn radius(self: Constraint) i32 {
        return switch (self) {
            .biome => |v| v.radius,
            .structure => |v| v.radius,
        };
    }
};

pub const EvalState = struct {
    epoch: u64 = 0,
    computed: bool = false,
    finalized: bool = false,
    matched: bool = false,
    best_dist2: i64 = std.math.maxInt(i64),
    count: i32 = 0,
};

pub const EvalMode = enum {
    threshold,
    full,
};

pub const OutputFormat = enum {
    text,
    jsonl,
    csv,
};

pub const Checkpoint = struct {
    next_seed: u64,
    tested: u64,
    found: usize,
};

pub const MatchCandidate = struct {
    seed: u64,
    spawn: c.Pos,
    anchor: c.Pos,
    score: f64,
    matched_constraints: usize,
    total_constraints: usize,
    diagnostics: []u8,
};

pub const NativeShadow = struct {
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

pub const NativeBackend = struct {
    compare_only: bool = false,
    strict: bool = false,
    compared: u64 = 0,
    mismatch: u64 = 0,
};

pub const BiomeCompareReq = struct {
    idx: usize,
    proxy_needed: i32,
    weight: u32,
};
