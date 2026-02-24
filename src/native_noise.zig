const std = @import("std");

pub const V4f = @Vector(4, f64);
pub const V4f32 = @Vector(4, f32);
const V4i = @Vector(4, i32);

pub const Noise2 = struct {
    perm: [512]u8,

    pub fn init(seed: u64) Noise2 {
        var base: [256]u8 = undefined;
        for (0..256) |i| base[i] = @as(u8, @intCast(i));

        var s = seed;
        var i: usize = 255;
        while (true) {
            const j = @as(usize, @intCast(splitMix64(&s) % @as(u64, @intCast(i + 1))));
            const tmp = base[i];
            base[i] = base[j];
            base[j] = tmp;
            if (i == 0) break;
            i -= 1;
        }

        var perm: [512]u8 = undefined;
        for (0..512) |k| perm[k] = base[k & 255];
        return .{ .perm = perm };
    }

    pub fn perlin2(self: *const Noise2, x: f64, y: f64) f64 {
        const x_floor = @floor(x);
        const y_floor = @floor(y);
        const xi = @as(i32, @intFromFloat(x_floor)) & 255;
        const yi = @as(i32, @intFromFloat(y_floor)) & 255;
        const xf = x - x_floor;
        const yf = y - y_floor;
        const u = fade(xf);
        const v = fade(yf);
        const one: i32 = 1;

        const aa = hash2(&self.perm, xi, yi);
        const ab = hash2(&self.perm, xi, yi + one);
        const ba = hash2(&self.perm, xi + one, yi);
        const bb = hash2(&self.perm, xi + one, yi + one);

        const x1 = lerp(grad2(aa, xf, yf), grad2(ba, xf - 1.0, yf), u);
        const x2 = lerp(grad2(ab, xf, yf - 1.0), grad2(bb, xf - 1.0, yf - 1.0), u);
        return lerp(x1, x2, v);
    }

    pub fn perlin2_x4(self: *const Noise2, xs: V4f, ys: V4f) V4f {
        const xfloor = @floor(xs);
        const yfloor = @floor(ys);
        const xi = @as(V4i, @intFromFloat(xfloor)) & @as(V4i, @splat(255));
        const yi = @as(V4i, @intFromFloat(yfloor)) & @as(V4i, @splat(255));
        const xf = xs - xfloor;
        const yf = ys - yfloor;
        const u = fade4(xf);
        const v = fade4(yf);

        const aa4 = hash2_4(&self.perm, xi, yi);
        const ab4 = hash2_4(&self.perm, xi, yi + @as(V4i, @splat(1)));
        const ba4 = hash2_4(&self.perm, xi + @as(V4i, @splat(1)), yi);
        const bb4 = hash2_4(&self.perm, xi + @as(V4i, @splat(1)), yi + @as(V4i, @splat(1)));

        const x1 = lerp4(grad2_4(aa4, xf, yf), grad2_4(ba4, xf - @as(V4f, @splat(1.0)), yf), u);
        const x2 = lerp4(grad2_4(ab4, xf, yf - @as(V4f, @splat(1.0))), grad2_4(bb4, xf - @as(V4f, @splat(1.0)), yf - @as(V4f, @splat(1.0))), u);
        return lerp4(x1, x2, v);
    }

    pub fn perlin2f(self: *const Noise2, x: f32, y: f32) f32 {
        const x_floor = @floor(x);
        const y_floor = @floor(y);
        const xi = @as(i32, @intFromFloat(x_floor)) & 255;
        const yi = @as(i32, @intFromFloat(y_floor)) & 255;
        const xf = x - x_floor;
        const yf = y - y_floor;
        const u = fadef(xf);
        const v = fadef(yf);
        const one: i32 = 1;

        const aa = hash2(&self.perm, xi, yi);
        const ab = hash2(&self.perm, xi, yi + one);
        const ba = hash2(&self.perm, xi + one, yi);
        const bb = hash2(&self.perm, xi + one, yi + one);

        const x1 = lerpf(grad2f(aa, xf, yf), grad2f(ba, xf - 1.0, yf), u);
        const x2 = lerpf(grad2f(ab, xf, yf - 1.0), grad2f(bb, xf - 1.0, yf - 1.0), u);
        return lerpf(x1, x2, v);
    }

    pub fn perlin2f_x4(self: *const Noise2, xs: V4f32, ys: V4f32) V4f32 {
        const xfloor = @floor(xs);
        const yfloor = @floor(ys);
        const xi = @as(V4i, @intFromFloat(xfloor)) & @as(V4i, @splat(255));
        const yi = @as(V4i, @intFromFloat(yfloor)) & @as(V4i, @splat(255));
        const xf = xs - xfloor;
        const yf = ys - yfloor;
        const u = fade4f(xf);
        const v = fade4f(yf);

        const aa4 = hash2_4(&self.perm, xi, yi);
        const ab4 = hash2_4(&self.perm, xi, yi + @as(V4i, @splat(1)));
        const ba4 = hash2_4(&self.perm, xi + @as(V4i, @splat(1)), yi);
        const bb4 = hash2_4(&self.perm, xi + @as(V4i, @splat(1)), yi + @as(V4i, @splat(1)));

        const x1 = lerp4f(grad2_4f(aa4, xf, yf), grad2_4f(ba4, xf - @as(V4f32, @splat(1.0)), yf), u);
        const x2 = lerp4f(grad2_4f(ab4, xf, yf - @as(V4f32, @splat(1.0))), grad2_4f(bb4, xf - @as(V4f32, @splat(1.0)), yf - @as(V4f32, @splat(1.0))), u);
        return lerp4f(x1, x2, v);
    }
};

fn splitMix64(state: *u64) u64 {
    state.* +%= 0x9E3779B97F4A7C15;
    var z = state.*;
    z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

fn envFlagEnabled(allocator: std.mem.Allocator, name: []const u8) bool {
    const v = std.process.getEnvVarOwned(allocator, name) catch return false;
    defer allocator.free(v);
    return std.mem.eql(u8, v, "1") or std.ascii.eqlIgnoreCase(v, "true") or std.ascii.eqlIgnoreCase(v, "yes");
}

fn fade(t: f64) f64 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

fn fade4(t: V4f) V4f {
    return t * t * t * (t * (t * @as(V4f, @splat(6.0)) - @as(V4f, @splat(15.0))) + @as(V4f, @splat(10.0)));
}

fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + t * (b - a);
}

fn lerp4(a: V4f, b: V4f, t: V4f) V4f {
    return a + t * (b - a);
}

fn fadef(t: f32) f32 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

fn fade4f(t: V4f32) V4f32 {
    return t * t * t * (t * (t * @as(V4f32, @splat(6.0)) - @as(V4f32, @splat(15.0))) + @as(V4f32, @splat(10.0)));
}

fn lerpf(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

fn lerp4f(a: V4f32, b: V4f32, t: V4f32) V4f32 {
    return a + t * (b - a);
}

fn hash2(perm: *const [512]u8, xi: i32, yi: i32) u8 {
    const x = @as(usize, @intCast(xi & 255));
    const y = @as(usize, @intCast(yi & 255));
    return perm[@as(usize, perm[x]) + y];
}

fn hash2_4(perm: *const [512]u8, xi: V4i, yi: V4i) @Vector(4, u8) {
    var out: [4]u8 = undefined;
    inline for (0..4) |i| {
        const x = @as(usize, @intCast(xi[i] & 255));
        const y = @as(usize, @intCast(yi[i] & 255));
        out[i] = perm[@as(usize, perm[x]) + y];
    }
    return out;
}

fn grad2(h: u8, x: f64, y: f64) f64 {
    const hh = h & 7;
    const u = if ((hh & 1) == 0) x else -x;
    const v = if ((hh & 2) == 0) y else -y;
    return u + v;
}

fn grad2_4(h: @Vector(4, u8), x: V4f, y: V4f) V4f {
    const hh = h & @as(@Vector(4, u8), @splat(7));
    const u = @select(f64, (hh & @as(@Vector(4, u8), @splat(1))) != @as(@Vector(4, u8), @splat(0)), -x, x);
    const v = @select(f64, (hh & @as(@Vector(4, u8), @splat(2))) != @as(@Vector(4, u8), @splat(0)), -y, y);
    return u + v;
}

fn grad2f(h: u8, x: f32, y: f32) f32 {
    const hh = h & 7;
    const u = if ((hh & 1) == 0) x else -x;
    const v = if ((hh & 2) == 0) y else -y;
    return u + v;
}

fn grad2_4f(h: @Vector(4, u8), x: V4f32, y: V4f32) V4f32 {
    const hh = h & @as(@Vector(4, u8), @splat(7));
    const u = @select(f32, (hh & @as(@Vector(4, u8), @splat(1))) != @as(@Vector(4, u8), @splat(0)), -x, x);
    const v = @select(f32, (hh & @as(@Vector(4, u8), @splat(2))) != @as(@Vector(4, u8), @splat(0)), -y, y);
    return u + v;
}

test "native noise deterministic" {
    const n = Noise2.init(42424242);
    const a = n.perlin2(12.5, -8.25);
    const b = n.perlin2(12.5, -8.25);
    try std.testing.expectEqual(a, b);
}

test "native noise fixtures remain stable" {
    const n = Noise2.init(0xDEADBEEFCAFEBABE);
    const expected64 = [_]f64{
        0.0,
        0.5,
        -0.269678795710206,
        -0.351518738083541,
    };
    const points64 = [_][2]f64{
        .{ 0.0, 0.0 },
        .{ 1.25, -3.5 },
        .{ 123.875, -987.125 },
        .{ -42.75, 999.0625 },
    };
    for (points64, 0..) |p, i| {
        try std.testing.expectApproxEqAbs(expected64[i], n.perlin2(p[0], p[1]), 1e-12);
    }

    const expected32 = [_]f32{
        0.0,
        0.5,
        -0.26967877,
        -0.35151875,
    };
    const points32 = [_][2]f32{
        .{ 0.0, 0.0 },
        .{ 1.25, -3.5 },
        .{ 123.875, -987.125 },
        .{ -42.75, 999.0625 },
    };
    for (points32, 0..) |p, i| {
        try std.testing.expectApproxEqAbs(expected32[i], n.perlin2f(p[0], p[1]), 1e-6);
    }
}

test "native noise x4 matches scalar" {
    const n = Noise2.init(123456789);
    const xs = V4f{ -12.125, 0.5, 18.75, 101.0 };
    const ys = V4f{ 7.25, -44.0, 0.125, 2.0 };
    const v = n.perlin2_x4(xs, ys);
    inline for (0..4) |i| {
        const s = n.perlin2(xs[i], ys[i]);
        try std.testing.expectApproxEqAbs(s, v[i], 1e-12);
    }
}

test "native noise f32 x4 matches scalar" {
    const n = Noise2.init(0x1234);
    const xs = V4f32{ -12.125, 0.5, 18.75, 101.0 };
    const ys = V4f32{ 7.25, -44.0, 0.125, 2.0 };
    const v = n.perlin2f_x4(xs, ys);
    inline for (0..4) |i| {
        const s = n.perlin2f(xs[i], ys[i]);
        try std.testing.expectApproxEqAbs(s, v[i], 1e-5);
    }
}

test "opt-in perf: native noise scalar vs x4" {
    if (!envFlagEnabled(std.testing.allocator, "SEED_FINDER_PERF_TEST")) return error.SkipZigTest;
    const n = Noise2.init(0xDEADBEEFCAFEBABE);
    const rounds: usize = 200_000;

    var scalar_acc: f64 = 0;
    const start_scalar = std.time.nanoTimestamp();
    var i: usize = 0;
    while (i < rounds) : (i += 1) {
        const x = @as(f64, @floatFromInt(i)) * 0.001;
        const y = @as(f64, @floatFromInt(i)) * -0.0023;
        scalar_acc += n.perlin2(x, y);
    }
    const scalar_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_scalar));

    var simd_acc: f64 = 0;
    const start_simd = std.time.nanoTimestamp();
    i = 0;
    while (i + 4 <= rounds) : (i += 4) {
        const base = @as(f64, @floatFromInt(i));
        const xs = V4f{ (base + 0.0) * 0.001, (base + 1.0) * 0.001, (base + 2.0) * 0.001, (base + 3.0) * 0.001 };
        const ys = V4f{ (base + 0.0) * -0.0023, (base + 1.0) * -0.0023, (base + 2.0) * -0.0023, (base + 3.0) * -0.0023 };
        const v = n.perlin2_x4(xs, ys);
        simd_acc += v[0] + v[1] + v[2] + v[3];
    }
    while (i < rounds) : (i += 1) {
        const x = @as(f64, @floatFromInt(i)) * 0.001;
        const y = @as(f64, @floatFromInt(i)) * -0.0023;
        simd_acc += n.perlin2(x, y);
    }
    const simd_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_simd));
    try std.testing.expectApproxEqAbs(scalar_acc, simd_acc, 1e-8);

    try std.fs.cwd().makePath("tmp/perf");
    var file = std.fs.cwd().openFile("tmp/perf/native_noise_perf.jsonl", .{ .mode = .read_write }) catch try std.fs.cwd().createFile("tmp/perf/native_noise_perf.jsonl", .{});
    defer file.close();
    try file.seekFromEnd(0);
    const Rec = struct {
        tag: []const u8,
        rounds: usize,
        scalar_ns: u64,
        simd_ns: u64,
        scalar_per_op_ns: f64,
        simd_per_op_ns: f64,
    };
    try std.json.stringify(Rec{
        .tag = "native_noise_perlin2",
        .rounds = rounds,
        .scalar_ns = scalar_ns,
        .simd_ns = simd_ns,
        .scalar_per_op_ns = @as(f64, @floatFromInt(scalar_ns)) / @as(f64, @floatFromInt(rounds)),
        .simd_per_op_ns = @as(f64, @floatFromInt(simd_ns)) / @as(f64, @floatFromInt(rounds)),
    }, .{ .whitespace = .minified }, file.writer());
    try file.writer().writeByte('\n');

    var scalar32_acc: f32 = 0;
    const start_scalar32 = std.time.nanoTimestamp();
    i = 0;
    while (i < rounds) : (i += 1) {
        const x = @as(f32, @floatFromInt(i)) * 0.001;
        const y = @as(f32, @floatFromInt(i)) * -0.0023;
        scalar32_acc += n.perlin2f(x, y);
    }
    const scalar32_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_scalar32));

    var simd32_acc: f32 = 0;
    const start_simd32 = std.time.nanoTimestamp();
    i = 0;
    while (i + 4 <= rounds) : (i += 4) {
        const base = @as(f32, @floatFromInt(i));
        const xs32 = V4f32{ (base + 0.0) * 0.001, (base + 1.0) * 0.001, (base + 2.0) * 0.001, (base + 3.0) * 0.001 };
        const ys32 = V4f32{ (base + 0.0) * -0.0023, (base + 1.0) * -0.0023, (base + 2.0) * -0.0023, (base + 3.0) * -0.0023 };
        const vv = n.perlin2f_x4(xs32, ys32);
        simd32_acc += vv[0] + vv[1] + vv[2] + vv[3];
    }
    while (i < rounds) : (i += 1) {
        const x = @as(f32, @floatFromInt(i)) * 0.001;
        const y = @as(f32, @floatFromInt(i)) * -0.0023;
        simd32_acc += n.perlin2f(x, y);
    }
    const simd32_ns = @as(u64, @intCast(std.time.nanoTimestamp() - start_simd32));
    try std.testing.expectApproxEqAbs(scalar32_acc, simd32_acc, 1e-1);

    const Rec32 = struct {
        tag: []const u8,
        rounds: usize,
        scalar_ns: u64,
        simd_ns: u64,
        scalar_per_op_ns: f64,
        simd_per_op_ns: f64,
    };
    try std.json.stringify(Rec32{
        .tag = "native_noise_perlin2f",
        .rounds = rounds,
        .scalar_ns = scalar32_ns,
        .simd_ns = simd32_ns,
        .scalar_per_op_ns = @as(f64, @floatFromInt(scalar32_ns)) / @as(f64, @floatFromInt(rounds)),
        .simd_per_op_ns = @as(f64, @floatFromInt(simd32_ns)) / @as(f64, @floatFromInt(rounds)),
    }, .{ .whitespace = .minified }, file.writer());
    try file.writer().writeByte('\n');
}
