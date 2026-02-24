const std = @import("std");

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

pub fn parseNbtForSeed(data: []const u8, endian: Endian) !?u64 {
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

pub fn extractSeedFromLevelDatBytes(allocator: std.mem.Allocator, data: []const u8) !u64 {
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

pub fn seedFromLevelDatPath(allocator: std.mem.Allocator, path: []const u8) !u64 {
    const bytes = try std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024 * 1024);
    defer allocator.free(bytes);
    return extractSeedFromLevelDatBytes(allocator, bytes);
}
