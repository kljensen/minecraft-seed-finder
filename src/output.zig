const std = @import("std");
const types = @import("search_types.zig");

pub const OutputFormat = types.OutputFormat;
pub const Checkpoint = types.Checkpoint;
pub const MatchCandidate = types.MatchCandidate;

pub fn writeCsvEscaped(writer: anytype, value: []const u8) !void {
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

pub fn emitResult(writer: anytype, fmt: OutputFormat, item: MatchCandidate) !void {
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

pub fn betterCandidate(lhs: MatchCandidate, rhs: MatchCandidate) bool {
    if (lhs.score > rhs.score) return true;
    if (lhs.score < rhs.score) return false;
    return lhs.seed < rhs.seed;
}

pub fn keepTopK(list: *std.ArrayList(MatchCandidate), candidate: MatchCandidate, top_k: usize, allocator: std.mem.Allocator) !void {
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

pub fn writeCheckpoint(path: []const u8, checkpoint: Checkpoint) !void {
    const f = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer f.close();
    try std.json.stringify(checkpoint, .{ .whitespace = .minified }, f.writer());
}

pub fn readCheckpoint(allocator: std.mem.Allocator, path: []const u8) !Checkpoint {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 4 * 1024 * 1024);
    defer allocator.free(data);
    const parsed = try std.json.parseFromSlice(Checkpoint, allocator, data, .{});
    defer parsed.deinit();
    return parsed.value;
}
