// Note: stderr is not available in pure Zig builds. Error logging is disabled.
pub const stderr: ?*anyopaque = null;
const libc_shim = @import("libc_shim.zig");
const biome_tree = @import("biome_tree.zig");

pub const __builtin_bswap32 = @import("std").zig.c_builtins.__builtin_bswap32;
pub const __builtin_expect = @import("std").zig.c_builtins.__builtin_expect;
pub const __builtin_unreachable = @import("std").zig.c_builtins.__builtin_unreachable;


pub const malloc = libc_shim.malloc;
pub const calloc = libc_shim.calloc;
pub const free = libc_shim.free;
pub const exit = libc_shim.exit;
pub const abs = libc_shim.abs;
pub const uint_fast16_t = c_ulong;
pub const @"i8" = i8;
pub const @"u8" = u8;
pub const @"i16" = i16;
pub const @"u16" = u16;
pub const @"i32" = i32;
pub const @"u32" = u32;
pub const @"i64" = i64;
pub const @"u64" = u64;
pub const @"f32" = f32;
pub const @"f64" = f64;
pub inline fn rotl64(arg_x: u64, arg_b: u8) u64 {
    var x = arg_x;
    _ = &x;
    var b = arg_b;
    _ = &b;
    return (x << @intCast(@as(c_int, @bitCast(@as(c_uint, b))))) | (x >> @intCast(@as(c_int, 64) - @as(c_int, @bitCast(@as(c_uint, b)))));
}
pub inline fn rotr32(arg_a: u32, arg_b: u8) u32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return (a >> @intCast(@as(c_int, @bitCast(@as(c_uint, b))))) | (a << @intCast(@as(c_int, 32) - @as(c_int, @bitCast(@as(c_uint, b)))));
}
pub inline fn floordiv(arg_a: i32, arg_b: i32) i32 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var q: i32 = @divTrunc(a, b);
    _ = &q;
    var r: i32 = @import("std").zig.c_translation.signedRemainder(a, b);
    _ = &r;
    return q - @intFromBool(((a ^ b) < @as(c_int, 0)) and !!(r != 0));
}
pub fn setSeed(arg_seed: [*c]u64, arg_value: u64) void {
    var seed = arg_seed;
    _ = &seed;
    var value = arg_value;
    _ = &value;
    seed.* = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, @bitCast(@as(c_ulonglong, value ^ @as(u64, @bitCast(@as(c_long, 25214903917)))))) & ((@as(c_ulonglong, 1) << @intCast(48)) -% @as(c_ulonglong, @bitCast(@as(c_longlong, @as(c_int, 1)))))))));
}
pub fn next(arg_seed: [*c]u64, bits: c_int) c_int {
    var seed = arg_seed;
    _ = &seed;
    _ = &bits;
    seed.* = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, @bitCast(@as(c_ulonglong, (seed.* *% @as(u64, @bitCast(@as(c_long, 25214903917)))) +% @as(u64, @bitCast(@as(c_long, @as(c_int, 11))))))) & ((@as(c_ulonglong, 1) << @intCast(48)) -% @as(c_ulonglong, @bitCast(@as(c_longlong, @as(c_int, 1)))))))));
    return @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(seed.*)) >> @intCast(@as(c_int, 48) - bits)))));
}
pub fn nextInt(arg_seed: [*c]u64, n: c_int) c_int {
    var seed = arg_seed;
    _ = &seed;
    _ = &n;
    var bits: c_int = undefined;
    _ = &bits;
    var val: c_int = undefined;
    _ = &val;
    const m: c_int = n - @as(c_int, 1);
    _ = &m;
    if ((m & n) == @as(c_int, 0)) {
        var x: u64 = @as(u64, @bitCast(@as(c_long, n))) *% @as(u64, @bitCast(@as(c_long, next(seed, @as(c_int, 31)))));
        _ = &x;
        return @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(x)) >> @intCast(31)))));
    }
    while (true) {
        bits = next(seed, @as(c_int, 31));
        val = @import("std").zig.c_translation.signedRemainder(bits, n);
        if (!(@as(i32, @bitCast((@as(u32, @bitCast(bits)) -% @as(u32, @bitCast(val))) +% @as(u32, @bitCast(m)))) < @as(c_int, 0))) break;
    }
    return val;
}
pub fn nextLong(arg_seed: [*c]u64) u64 {
    var seed = arg_seed;
    _ = &seed;
    return (@as(u64, @bitCast(@as(c_long, next(seed, @as(c_int, 32))))) << @intCast(32)) +% @as(u64, @bitCast(@as(c_long, next(seed, @as(c_int, 32)))));
}
pub fn nextFloat(arg_seed: [*c]u64) f32 {
    var seed = arg_seed;
    _ = &seed;
    return @as(f32, @floatFromInt(next(seed, @as(c_int, 24)))) / @as(f32, @floatFromInt(@as(c_int, 1) << @intCast(24)));
}
pub fn nextDouble(arg_seed: [*c]u64) f64 {
    var seed = arg_seed;
    _ = &seed;
    var x: u64 = @as(u64, @bitCast(@as(c_long, next(seed, @as(c_int, 26)))));
    _ = &x;
    x <<= @intCast(@as(c_int, 27));
    x +%= @as(u64, @bitCast(@as(c_long, next(seed, @as(c_int, 27)))));
    return @as(f64, @floatFromInt(@as(i64, @bitCast(x)))) / @as(f64, @floatFromInt(@as(c_ulonglong, 1) << @intCast(53)));
}
pub fn skipNextN(arg_seed: [*c]u64, arg_n: u64) void {
    var seed = arg_seed;
    _ = &seed;
    var n = arg_n;
    _ = &n;
    var m: u64 = 1;
    _ = &m;
    var a: u64 = 0;
    _ = &a;
    var im: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 25214903917)))));
    _ = &im;
    var ia: u64 = 11;
    _ = &ia;
    var k: u64 = undefined;
    _ = &k;
    {
        k = n;
        while (k != 0) : (k >>= @intCast(@as(c_int, 1))) {
            if ((k & @as(u64, @bitCast(@as(c_long, @as(c_int, 1))))) != 0) {
                m *%= im;
                a = (im *% a) +% ia;
            }
            ia = (im +% @as(u64, @bitCast(@as(c_long, @as(c_int, 1))))) *% ia;
            im *%= im;
        }
    }
    seed.* = (seed.* *% m) +% a;
    seed.* &= @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 281474976710655)))));
}
pub const struct_Xoroshiro = extern struct {
    lo: u64 = @import("std").mem.zeroes(u64),
    hi: u64 = @import("std").mem.zeroes(u64),
};
pub const Xoroshiro = struct_Xoroshiro;
pub fn xSetSeed(arg_xr: [*c]Xoroshiro, arg_value: u64) void {
    var xr = arg_xr;
    _ = &xr;
    var value = arg_value;
    _ = &value;
    const XL: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 11400714819323198485)))));
    _ = &XL;
    const XH: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 7640891576956012809)))));
    _ = &XH;
    const A: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 13787848793156543929)))));
    _ = &A;
    const B: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 10723151780598845931)))));
    _ = &B;
    var l: u64 = value ^ XH;
    _ = &l;
    var h: u64 = l +% XL;
    _ = &h;
    l = (l ^ (l >> @intCast(30))) *% A;
    h = (h ^ (h >> @intCast(30))) *% A;
    l = (l ^ (l >> @intCast(27))) *% B;
    h = (h ^ (h >> @intCast(27))) *% B;
    l = l ^ (l >> @intCast(31));
    h = h ^ (h >> @intCast(31));
    xr.*.lo = l;
    xr.*.hi = h;
}
pub fn xNextLong(arg_xr: [*c]Xoroshiro) u64 {
    var xr = arg_xr;
    _ = &xr;
    var l: u64 = xr.*.lo;
    _ = &l;
    var h: u64 = xr.*.hi;
    _ = &h;
    var n: u64 = rotl64(l +% h, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 17)))))) +% l;
    _ = &n;
    h ^= l;
    xr.*.lo = (rotl64(l, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 49)))))) ^ h) ^ (h << @intCast(21));
    xr.*.hi = rotl64(h, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 28))))));
    return n;
}
pub fn xNextInt(arg_xr: [*c]Xoroshiro, arg_n: u32) c_int {
    var xr = arg_xr;
    _ = &xr;
    var n = arg_n;
    _ = &n;
    var r: u64 = (xNextLong(xr) & @as(u64, @bitCast(@as(c_ulong, @as(c_uint, 4294967295))))) *% @as(u64, @bitCast(@as(c_ulong, n)));
    _ = &r;
    if (@as(u32, @bitCast(@as(c_uint, @truncate(r)))) < n) {
        while (@as(u32, @bitCast(@as(c_uint, @truncate(r)))) < ((~n +% @as(u32, @bitCast(@as(c_int, 1)))) % n)) {
            r = (xNextLong(xr) & @as(u64, @bitCast(@as(c_ulong, @as(c_uint, 4294967295))))) *% @as(u64, @bitCast(@as(c_ulong, n)));
        }
    }
    return @as(c_int, @bitCast(@as(c_uint, @truncate(r >> @intCast(32)))));
}
pub fn xNextDouble(arg_xr: [*c]Xoroshiro) f64 {
    var xr = arg_xr;
    _ = &xr;
    return @as(f64, @floatFromInt(xNextLong(xr) >> @intCast(@as(c_int, 64) - @as(c_int, 53)))) * 0.00000000000000011102230246251565;
}
pub fn xNextFloat(arg_xr: [*c]Xoroshiro) f32 {
    var xr = arg_xr;
    _ = &xr;
    return @as(f32, @floatFromInt(xNextLong(xr) >> @intCast(@as(c_int, 64) - @as(c_int, 24)))) * 0.00000005960464477539063;
}
pub fn xSkipN(arg_xr: [*c]Xoroshiro, arg_count: c_int) void {
    var xr = arg_xr;
    _ = &xr;
    var count = arg_count;
    _ = &count;
    while ((blk: {
        const ref = &count;
        const tmp = ref.*;
        ref.* -= 1;
        break :blk tmp;
    }) > @as(c_int, 0)) {
        _ = xNextLong(xr);
    }
}
pub fn xNextLongJ(arg_xr: [*c]Xoroshiro) u64 {
    var xr = arg_xr;
    _ = &xr;
    var a: i32 = @as(i32, @bitCast(@as(c_uint, @truncate(xNextLong(xr) >> @intCast(32)))));
    _ = &a;
    var b: i32 = @as(i32, @bitCast(@as(c_uint, @truncate(xNextLong(xr) >> @intCast(32)))));
    _ = &b;
    return (@as(u64, @bitCast(@as(c_long, a))) << @intCast(32)) +% @as(u64, @bitCast(@as(c_long, b)));
}
pub fn xNextIntJ(arg_xr: [*c]Xoroshiro, arg_n: u32) c_int {
    var xr = arg_xr;
    _ = &xr;
    var n = arg_n;
    _ = &n;
    var bits: c_int = undefined;
    _ = &bits;
    var val: c_int = undefined;
    _ = &val;
    const m: c_int = @as(c_int, @bitCast(n -% @as(u32, @bitCast(@as(c_int, 1)))));
    _ = &m;
    if ((@as(u32, @bitCast(m)) & n) == @as(u32, @bitCast(@as(c_int, 0)))) {
        var x: u64 = @as(u64, @bitCast(@as(c_ulong, n))) *% (xNextLong(xr) >> @intCast(33));
        _ = &x;
        return @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(x)) >> @intCast(31)))));
    }
    while (true) {
        bits = @as(c_int, @bitCast(@as(c_uint, @truncate(xNextLong(xr) >> @intCast(33)))));
        val = @as(c_int, @bitCast(@as(u32, @bitCast(bits)) % n));
        if (!(@as(i32, @bitCast((@as(u32, @bitCast(bits)) -% @as(u32, @bitCast(val))) +% @as(u32, @bitCast(m)))) < @as(c_int, 0))) break;
    }
    return val;
}
pub fn mcStepSeed(arg_s: u64, arg_salt: u64) u64 {
    var s = arg_s;
    _ = &s;
    var salt = arg_salt;
    _ = &salt;
    return @as(u64, @bitCast(@as(c_ulong, @truncate((@as(c_ulonglong, @bitCast(@as(c_ulonglong, s))) *% ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, s))) *% @as(c_ulonglong, 6364136223846793005)) +% @as(c_ulonglong, 1442695040888963407))) +% @as(c_ulonglong, @bitCast(@as(c_ulonglong, salt)))))));
}
pub fn getLayerSalt(arg_salt: u64) u64 {
    var salt = arg_salt;
    _ = &salt;
    var ls: u64 = mcStepSeed(salt, salt);
    _ = &ls;
    ls = mcStepSeed(ls, salt);
    ls = mcStepSeed(ls, salt);
    return ls;
}
pub fn lerp(arg_part: f64, arg_from: f64, arg_to: f64) f64 {
    var part = arg_part;
    _ = &part;
    var from = arg_from;
    _ = &from;
    var to = arg_to;
    _ = &to;
    return from + (part * (to - from));
}
pub fn lerp2(arg_dx: f64, arg_dy: f64, arg_v00: f64, arg_v10: f64, arg_v01: f64, arg_v11: f64) f64 {
    var dx = arg_dx;
    _ = &dx;
    var dy = arg_dy;
    _ = &dy;
    var v00 = arg_v00;
    _ = &v00;
    var v10 = arg_v10;
    _ = &v10;
    var v01 = arg_v01;
    _ = &v01;
    var v11 = arg_v11;
    _ = &v11;
    return lerp(dy, lerp(dx, v00, v10), lerp(dx, v01, v11));
}
pub fn lerp3(arg_dx: f64, arg_dy: f64, arg_dz: f64, arg_v000: f64, arg_v100: f64, arg_v010: f64, arg_v110: f64, arg_v001: f64, arg_v101: f64, arg_v011: f64, arg_v111: f64) f64 {
    var dx = arg_dx;
    _ = &dx;
    var dy = arg_dy;
    _ = &dy;
    var dz = arg_dz;
    _ = &dz;
    var v000 = arg_v000;
    _ = &v000;
    var v100 = arg_v100;
    _ = &v100;
    var v010 = arg_v010;
    _ = &v010;
    var v110 = arg_v110;
    _ = &v110;
    var v001 = arg_v001;
    _ = &v001;
    var v101 = arg_v101;
    _ = &v101;
    var v011 = arg_v011;
    _ = &v011;
    var v111 = arg_v111;
    _ = &v111;
    v000 = lerp2(dx, dy, v000, v100, v010, v110);
    v001 = lerp2(dx, dy, v001, v101, v011, v111);
    return lerp(dz, v000, v001);
}
pub fn clampedLerp(arg_part: f64, arg_from: f64, arg_to: f64) f64 {
    var part = arg_part;
    _ = &part;
    var from = arg_from;
    _ = &from;
    var to = arg_to;
    _ = &to;
    if (part <= @as(f64, @floatFromInt(@as(c_int, 0)))) return from;
    if (part >= @as(f64, @floatFromInt(@as(c_int, 1)))) return to;
    return lerp(part, from, to);
}
pub inline fn cos(__x: f64) f64 { return @cos(__x); }
pub inline fn sin(__x: f64) f64 { return @sin(__x); }
// exp: removed (unused extern)
pub const pow = libc_shim.pow;
pub inline fn sqrt(__x: f64) f64 { return @sqrt(__x); }
pub inline fn ceil(__x: f64) f64 { return @ceil(__x); }
// fabs: removed (unused extern)
pub inline fn floor(__x: f64) f64 { return @floor(__x); }
pub const nan = libc_shim.nan;
// erfc: removed (unused extern)
// round: removed (unused extern)
pub inline fn sqrtf(__x: f32) f32 { return @sqrt(__x); }
pub inline fn fabsf(__x: f32) f32 { return @abs(__x); }
pub const struct_PerlinNoise = extern struct {
    d: [257]u8 = @import("std").mem.zeroes([257]u8),
    h2: u8 = @import("std").mem.zeroes(u8),
    a: f64 = @import("std").mem.zeroes(f64),
    b: f64 = @import("std").mem.zeroes(f64),
    c: f64 = @import("std").mem.zeroes(f64),
    amplitude: f64 = @import("std").mem.zeroes(f64),
    lacunarity: f64 = @import("std").mem.zeroes(f64),
    d2: f64 = @import("std").mem.zeroes(f64),
    t2: f64 = @import("std").mem.zeroes(f64),
};
pub const PerlinNoise = struct_PerlinNoise;
pub const struct_OctaveNoise = extern struct {
    octcnt: c_int = @import("std").mem.zeroes(c_int),
    octaves: [*c]PerlinNoise = @import("std").mem.zeroes([*c]PerlinNoise),
};
pub const OctaveNoise = struct_OctaveNoise;
pub const struct_DoublePerlinNoise = extern struct {
    amplitude: f64 = @import("std").mem.zeroes(f64),
    octA: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octB: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
};
pub const DoublePerlinNoise = struct_DoublePerlinNoise;
pub fn maintainPrecision(arg_x: f64) f64 {
    var x = arg_x;
    _ = &x;
    return x;
}
pub fn perlinInit(arg_noise: [*c]PerlinNoise, arg_seed: [*c]u64) void {
    var noise = arg_noise;
    _ = &noise;
    var seed = arg_seed;
    _ = &seed;
    var i: c_int = 0;
    _ = &i;
    noise.*.a = nextDouble(seed) * 256.0;
    noise.*.b = nextDouble(seed) * 256.0;
    noise.*.c = nextDouble(seed) * 256.0;
    noise.*.amplitude = 1.0;
    noise.*.lacunarity = 1.0;
    var idx: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(&noise.*.d)));
    _ = &idx;
    {
        i = 0;
        while (i < @as(c_int, 256)) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = @as(u8, @bitCast(@as(i8, @truncate(i))));
        }
    }
    {
        i = 0;
        while (i < @as(c_int, 256)) : (i += 1) {
            var j: c_int = nextInt(seed, @as(c_int, 256) - i) + i;
            _ = &j;
            var n: u8 = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &n;
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = j;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            (blk: {
                const tmp = j;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = n;
        }
    }
    idx[@as(c_uint, @intCast(@as(c_int, 256)))] = idx[@as(c_uint, @intCast(@as(c_int, 0)))];
    var @"i2": f64 = floor(noise.*.b);
    _ = &@"i2";
    var d2: f64 = noise.*.b - @"i2";
    _ = &d2;
    noise.*.h2 = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @intFromFloat(@"i2"))))));
    noise.*.d2 = d2;
    noise.*.t2 = ((d2 * d2) * d2) * ((d2 * ((d2 * 6.0) - 15.0)) + 10.0);
}
pub fn xPerlinInit(arg_noise: [*c]PerlinNoise, arg_xr: [*c]Xoroshiro) void {
    var noise = arg_noise;
    _ = &noise;
    var xr = arg_xr;
    _ = &xr;
    var i: c_int = 0;
    _ = &i;
    noise.*.a = xNextDouble(xr) * 256.0;
    noise.*.b = xNextDouble(xr) * 256.0;
    noise.*.c = xNextDouble(xr) * 256.0;
    noise.*.amplitude = 1.0;
    noise.*.lacunarity = 1.0;
    var idx: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(&noise.*.d)));
    _ = &idx;
    {
        i = 0;
        while (i < @as(c_int, 256)) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = @as(u8, @bitCast(@as(i8, @truncate(i))));
        }
    }
    {
        i = 0;
        while (i < @as(c_int, 256)) : (i += 1) {
            var j: c_int = xNextInt(xr, @as(u32, @bitCast(@as(c_int, 256) - i))) + i;
            _ = &j;
            var n: u8 = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &n;
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = j;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            (blk: {
                const tmp = j;
                if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = n;
        }
    }
    idx[@as(c_uint, @intCast(@as(c_int, 256)))] = idx[@as(c_uint, @intCast(@as(c_int, 0)))];
    var @"i2": f64 = floor(noise.*.b);
    _ = &@"i2";
    var d2: f64 = noise.*.b - @"i2";
    _ = &d2;
    noise.*.h2 = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @intFromFloat(@"i2"))))));
    noise.*.d2 = d2;
    noise.*.t2 = ((d2 * d2) * d2) * ((d2 * ((d2 * 6.0) - 15.0)) + 10.0);
}
pub fn samplePerlin(arg_noise: [*c]const PerlinNoise, arg_d1: f64, arg_d2: f64, arg_d3: f64, arg_yamp: f64, arg_ymin: f64) f64 {
    var noise = arg_noise;
    _ = &noise;
    var d1 = arg_d1;
    _ = &d1;
    var d2 = arg_d2;
    _ = &d2;
    var d3 = arg_d3;
    _ = &d3;
    var yamp = arg_yamp;
    _ = &yamp;
    var ymin = arg_ymin;
    _ = &ymin;
    var h1: u8 = undefined;
    _ = &h1;
    var h2: u8 = undefined;
    _ = &h2;
    var h3: u8 = undefined;
    _ = &h3;
    var t1: f64 = undefined;
    _ = &t1;
    var t2: f64 = undefined;
    _ = &t2;
    var t3: f64 = undefined;
    _ = &t3;
    if (d2 == 0.0) {
        d2 = noise.*.d2;
        h2 = noise.*.h2;
        t2 = noise.*.t2;
    } else {
        d2 += noise.*.b;
        var @"i2": f64 = floor(d2);
        _ = &@"i2";
        d2 -= @"i2";
        h2 = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @intFromFloat(@"i2"))))));
        t2 = ((d2 * d2) * d2) * ((d2 * ((d2 * 6.0) - 15.0)) + 10.0);
    }
    d1 += noise.*.a;
    d3 += noise.*.c;
    var @"i1": f64 = floor(d1);
    _ = &@"i1";
    var @"i3": f64 = floor(d3);
    _ = &@"i3";
    d1 -= @"i1";
    d3 -= @"i3";
    h1 = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @intFromFloat(@"i1"))))));
    h3 = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @intFromFloat(@"i3"))))));
    t1 = ((d1 * d1) * d1) * ((d1 * ((d1 * 6.0) - 15.0)) + 10.0);
    t3 = ((d3 * d3) * d3) * ((d3 * ((d3 * 6.0) - 15.0)) + 10.0);
    if (yamp != 0) {
        var yclamp: f64 = if (ymin < d2) ymin else d2;
        _ = &yclamp;
        d2 -= floor(yclamp / yamp) * yamp;
    }
    var idx: [*c]const u8 = @as([*c]const u8, @ptrCast(@alignCast(&noise.*.d)));
    _ = &idx;
    const struct_vec2 = extern struct {
        a: u8 = @import("std").mem.zeroes(u8),
        b: u8 = @import("std").mem.zeroes(u8),
    };
    _ = &struct_vec2;
    const vec2 = struct_vec2;
    _ = &vec2;
    var v1: vec2 = vec2{
        .a = idx[h1],
        .b = (blk: {
            const tmp = @as(c_int, @bitCast(@as(c_uint, h1))) + @as(c_int, 1);
            if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*,
    };
    _ = &v1;
    v1.a +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, h2)))))));
    v1.b +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, h2)))))));
    var v2: vec2 = vec2{
        .a = idx[v1.a],
        .b = (blk: {
            const tmp = @as(c_int, @bitCast(@as(c_uint, v1.a))) + @as(c_int, 1);
            if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*,
    };
    _ = &v2;
    var v3: vec2 = vec2{
        .a = idx[v1.b],
        .b = (blk: {
            const tmp = @as(c_int, @bitCast(@as(c_uint, v1.b))) + @as(c_int, 1);
            if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*,
    };
    _ = &v3;
    v2.a +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, h3)))))));
    v2.b +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, h3)))))));
    v3.a +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, h3)))))));
    v3.b +%= @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, @bitCast(@as(c_uint, h3)))))));
    var v4: vec2 = vec2{
        .a = idx[v2.a],
        .b = (blk: {
            const tmp = @as(c_int, @bitCast(@as(c_uint, v2.a))) + @as(c_int, 1);
            if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*,
    };
    _ = &v4;
    var v5: vec2 = vec2{
        .a = idx[v2.b],
        .b = (blk: {
            const tmp = @as(c_int, @bitCast(@as(c_uint, v2.b))) + @as(c_int, 1);
            if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*,
    };
    _ = &v5;
    var v6: vec2 = vec2{
        .a = idx[v3.a],
        .b = (blk: {
            const tmp = @as(c_int, @bitCast(@as(c_uint, v3.a))) + @as(c_int, 1);
            if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*,
    };
    _ = &v6;
    var v7: vec2 = vec2{
        .a = idx[v3.b],
        .b = (blk: {
            const tmp = @as(c_int, @bitCast(@as(c_uint, v3.b))) + @as(c_int, 1);
            if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*,
    };
    _ = &v7;
    var l1: f64 = indexedLerp(v4.a, d1, d2, d3);
    _ = &l1;
    var l5: f64 = indexedLerp(v4.b, d1, d2, d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
    _ = &l5;
    var l2: f64 = indexedLerp(v6.a, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2, d3);
    _ = &l2;
    var l6: f64 = indexedLerp(v6.b, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2, d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
    _ = &l6;
    var l3: f64 = indexedLerp(v5.a, d1, d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3);
    _ = &l3;
    var l7: f64 = indexedLerp(v5.b, d1, d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
    _ = &l7;
    var l4: f64 = indexedLerp(v7.a, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3);
    _ = &l4;
    var l8: f64 = indexedLerp(v7.b, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
    _ = &l8;
    l1 = lerp(t1, l1, l2);
    l3 = lerp(t1, l3, l4);
    l5 = lerp(t1, l5, l6);
    l7 = lerp(t1, l7, l8);
    l1 = lerp(t2, l1, l3);
    l5 = lerp(t2, l5, l7);
    return lerp(t3, l1, l5);
}
pub fn sampleSimplex2D(arg_noise: [*c]const PerlinNoise, arg_x: f64, arg_y: f64) f64 {
    var noise = arg_noise;
    _ = &noise;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    const SKEW: f64 = 0.5 * (sqrt(@as(f64, @floatFromInt(@as(c_int, 3)))) - 1.0);
    _ = &SKEW;
    const UNSKEW: f64 = (3.0 - sqrt(@as(f64, @floatFromInt(@as(c_int, 3))))) / 6.0;
    _ = &UNSKEW;
    var hf: f64 = (x + y) * SKEW;
    _ = &hf;
    var hx: c_int = @as(c_int, @intFromFloat(floor(x + hf)));
    _ = &hx;
    var hz: c_int = @as(c_int, @intFromFloat(floor(y + hf)));
    _ = &hz;
    var mhxz: f64 = @as(f64, @floatFromInt(hx + hz)) * UNSKEW;
    _ = &mhxz;
    var x0: f64 = x - (@as(f64, @floatFromInt(hx)) - mhxz);
    _ = &x0;
    var y0_1: f64 = y - (@as(f64, @floatFromInt(hz)) - mhxz);
    _ = &y0_1;
    var offx: c_int = @intFromBool(x0 > y0_1);
    _ = &offx;
    var offz: c_int = @intFromBool(!(offx != 0));
    _ = &offz;
    var x1: f64 = (x0 - @as(f64, @floatFromInt(offx))) + UNSKEW;
    _ = &x1;
    var y1_2: f64 = (y0_1 - @as(f64, @floatFromInt(offz))) + UNSKEW;
    _ = &y1_2;
    var x2: f64 = (x0 - 1.0) + (2.0 * UNSKEW);
    _ = &x2;
    var y2: f64 = (y0_1 - 1.0) + (2.0 * UNSKEW);
    _ = &y2;
    var gi0: c_int = @as(c_int, @bitCast(@as(c_uint, noise.*.d[@as(c_uint, @intCast(@as(c_int, 255) & hz))])));
    _ = &gi0;
    var gi1: c_int = @as(c_int, @bitCast(@as(c_uint, noise.*.d[@as(c_uint, @intCast(@as(c_int, 255) & (hz + offz)))])));
    _ = &gi1;
    var gi2: c_int = @as(c_int, @bitCast(@as(c_uint, noise.*.d[@as(c_uint, @intCast(@as(c_int, 255) & (hz + @as(c_int, 1))))])));
    _ = &gi2;
    gi0 = @as(c_int, @bitCast(@as(c_uint, noise.*.d[@as(c_uint, @intCast(@as(c_int, 255) & (gi0 + hx)))])));
    gi1 = @as(c_int, @bitCast(@as(c_uint, noise.*.d[@as(c_uint, @intCast(@as(c_int, 255) & ((gi1 + hx) + offx)))])));
    gi2 = @as(c_int, @bitCast(@as(c_uint, noise.*.d[@as(c_uint, @intCast(@as(c_int, 255) & ((gi2 + hx) + @as(c_int, 1))))])));
    var t: f64 = 0;
    _ = &t;
    t += simplexGrad(@import("std").zig.c_translation.signedRemainder(gi0, @as(c_int, 12)), x0, y0_1, 0.0, 0.5);
    t += simplexGrad(@import("std").zig.c_translation.signedRemainder(gi1, @as(c_int, 12)), x1, y1_2, 0.0, 0.5);
    t += simplexGrad(@import("std").zig.c_translation.signedRemainder(gi2, @as(c_int, 12)), x2, y2, 0.0, 0.5);
    return 70.0 * t;
}
pub fn octaveInit(arg_noise: [*c]OctaveNoise, arg_seed: [*c]u64, arg_octaves: [*c]PerlinNoise, arg_omin: c_int, arg_len: c_int) void {
    var noise = arg_noise;
    _ = &noise;
    var seed = arg_seed;
    _ = &seed;
    var octaves = arg_octaves;
    _ = &octaves;
    var omin = arg_omin;
    _ = &omin;
    var len = arg_len;
    _ = &len;
    var i: c_int = undefined;
    _ = &i;
    var end: c_int = (omin + len) - @as(c_int, 1);
    _ = &end;
    var persist: f64 = 1.0 / (@as(f64, @floatFromInt(@as(c_longlong, 1) << @intCast(len))) - 1.0);
    _ = &persist;
    var lacuna: f64 = pow(2.0, @as(f64, @floatFromInt(end)));
    _ = &lacuna;
    if ((len < @as(c_int, 1)) or (end > @as(c_int, 0))) {
        _ = printf("octavePerlinInit(): unsupported octave range\n");
        return;
    }
    if (end == @as(c_int, 0)) {
        perlinInit(&octaves[@as(c_uint, @intCast(@as(c_int, 0)))], seed);
        octaves[@as(c_uint, @intCast(@as(c_int, 0)))].amplitude = persist;
        octaves[@as(c_uint, @intCast(@as(c_int, 0)))].lacunarity = lacuna;
        persist *= 2.0;
        lacuna *= 0.5;
        i = 1;
    } else {
        skipNextN(seed, @as(u64, @bitCast(@as(c_long, -end * @as(c_int, 262)))));
        i = 0;
    }
    while (i < len) : (i += 1) {
        perlinInit(&(blk: {
            const tmp = i;
            if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*, seed);
        (blk: {
            const tmp = i;
            if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*.amplitude = persist;
        (blk: {
            const tmp = i;
            if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*.lacunarity = lacuna;
        persist *= 2.0;
        lacuna *= 0.5;
    }
    noise.*.octaves = octaves;
    noise.*.octcnt = len;
}
pub fn octaveInitBeta(arg_noise: [*c]OctaveNoise, arg_seed: [*c]u64, arg_octaves: [*c]PerlinNoise, arg_octcnt: c_int, arg_lac: f64, arg_lacMul: f64, arg_persist: f64, arg_persistMul: f64) void {
    var noise = arg_noise;
    _ = &noise;
    var seed = arg_seed;
    _ = &seed;
    var octaves = arg_octaves;
    _ = &octaves;
    var octcnt = arg_octcnt;
    _ = &octcnt;
    var lac = arg_lac;
    _ = &lac;
    var lacMul = arg_lacMul;
    _ = &lacMul;
    var persist = arg_persist;
    _ = &persist;
    var persistMul = arg_persistMul;
    _ = &persistMul;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < octcnt) : (i += 1) {
            perlinInit(&(blk: {
                const tmp = i;
                if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, seed);
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.amplitude = persist;
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.lacunarity = lac;
            persist *= persistMul;
            lac *= lacMul;
        }
    }
    noise.*.octaves = octaves;
    noise.*.octcnt = octcnt;
}
pub fn xOctaveInit(arg_noise: [*c]OctaveNoise, arg_xr: [*c]Xoroshiro, arg_octaves: [*c]PerlinNoise, arg_amplitudes: [*c]const f64, arg_omin: c_int, arg_len: c_int, arg_nmax: c_int) c_int {
    var noise = arg_noise;
    _ = &noise;
    var xr = arg_xr;
    _ = &xr;
    var octaves = arg_octaves;
    _ = &octaves;
    var amplitudes = arg_amplitudes;
    _ = &amplitudes;
    var omin = arg_omin;
    _ = &omin;
    var len = arg_len;
    _ = &len;
    var nmax = arg_nmax;
    _ = &nmax;
    const md5_octave_n = struct {
        const static: [13][2]u64 = [13][2]u64{
            [2]u64{
                12797222860775040626,
                @as(u64, @bitCast(@as(c_long, 8900461776529241512))),
            },
            [2]u64{
                @as(u64, @bitCast(@as(c_long, 1141530288128540355))),
                @as(u64, @bitCast(@as(c_long, 8405022147954297016))),
            },
            [2]u64{
                @as(u64, @bitCast(@as(c_long, 3950544105335881394))),
                @as(u64, @bitCast(@as(c_long, 6623051330073944938))),
            },
            [2]u64{
                @as(u64, @bitCast(@as(c_long, 589938935082149425))),
                @as(u64, @bitCast(@as(c_long, 5662732952352513153))),
            },
            [2]u64{
                @as(u64, @bitCast(@as(c_long, 1078206144088113246))),
                @as(u64, @bitCast(@as(c_long, 5239585857299060288))),
            },
            [2]u64{
                17371061141547152719,
                @as(u64, @bitCast(@as(c_long, 2700503254851170474))),
            },
            [2]u64{
                16509238346663192164,
                @as(u64, @bitCast(@as(c_long, 6887262389667105861))),
            },
            [2]u64{
                @as(u64, @bitCast(@as(c_long, 7888980432583755018))),
                @as(u64, @bitCast(@as(c_long, 3328269827262531447))),
            },
            [2]u64{
                13659652104088827746,
                13867453877334791309,
            },
            [2]u64{
                @as(u64, @bitCast(@as(c_long, 6040343492819601496))),
                13605873274787879742,
            },
            [2]u64{
                13016051061665261435,
                @as(u64, @bitCast(@as(c_long, 162122330481997252))),
            },
            [2]u64{
                16139250376305407496,
                13382012087969406121,
            },
            [2]u64{
                15350246687196007804,
                @as(u64, @bitCast(@as(c_long, 7932617871068508937))),
            },
        };
    };
    _ = &md5_octave_n;
    const lacuna_ini = struct {
        const static: [13]f64 = [13]f64{
            1,
            0.5,
            0.25,
            1.0 / @as(f64, @floatFromInt(@as(c_int, 8))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 16))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 32))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 128))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 256))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 512))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 1024))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 2048))),
            1.0 / @as(f64, @floatFromInt(@as(c_int, 4096))),
        };
    };
    _ = &lacuna_ini;
    const persist_ini = struct {
        const static: [10]f64 = [10]f64{
            0,
            1,
            2.0 / @as(f64, @floatFromInt(@as(c_int, 3))),
            4.0 / @as(f64, @floatFromInt(@as(c_int, 7))),
            8.0 / @as(f64, @floatFromInt(@as(c_int, 15))),
            16.0 / @as(f64, @floatFromInt(@as(c_int, 31))),
            32.0 / @as(f64, @floatFromInt(@as(c_int, 63))),
            64.0 / @as(f64, @floatFromInt(@as(c_int, 127))),
            128.0 / @as(f64, @floatFromInt(@as(c_int, 255))),
            256.0 / @as(f64, @floatFromInt(@as(c_int, 511))),
        };
    };
    _ = &persist_ini;
    var lacuna: f64 = lacuna_ini.static[@as(c_uint, @intCast(-omin))];
    _ = &lacuna;
    var persist: f64 = persist_ini.static[@as(c_uint, @intCast(len))];
    _ = &persist;
    var xlo: u64 = xNextLong(xr);
    _ = &xlo;
    var xhi: u64 = xNextLong(xr);
    _ = &xhi;
    var i: c_int = 0;
    _ = &i;
    var n: c_int = 0;
    _ = &n;
    while ((i < len) and (n != nmax)) : (_ = blk: {
        _ = blk_1: {
            i += 1;
            break :blk_1 blk_2: {
                const ref = &lacuna;
                ref.* *= 2.0;
                break :blk_2 ref.*;
            };
        };
        break :blk blk_1: {
            const ref = &persist;
            ref.* *= 0.5;
            break :blk_1 ref.*;
        };
    }) {
        if ((blk: {
            const tmp = i;
            if (tmp >= 0) break :blk amplitudes + @as(usize, @intCast(tmp)) else break :blk amplitudes - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* == @as(f64, @floatFromInt(@as(c_int, 0)))) continue;
        var pxr: Xoroshiro = undefined;
        _ = &pxr;
        pxr.lo = xlo ^ md5_octave_n.static[@as(c_uint, @intCast((@as(c_int, 12) + omin) + i))][@as(c_uint, @intCast(@as(c_int, 0)))];
        pxr.hi = xhi ^ md5_octave_n.static[@as(c_uint, @intCast((@as(c_int, 12) + omin) + i))][@as(c_uint, @intCast(@as(c_int, 1)))];
        xPerlinInit(&(blk: {
            const tmp = n;
            if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*, &pxr);
        (blk: {
            const tmp = n;
            if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*.amplitude = (blk: {
            const tmp = i;
            if (tmp >= 0) break :blk amplitudes + @as(usize, @intCast(tmp)) else break :blk amplitudes - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* * persist;
        (blk: {
            const tmp = n;
            if (tmp >= 0) break :blk octaves + @as(usize, @intCast(tmp)) else break :blk octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*.lacunarity = lacuna;
        n += 1;
    }
    noise.*.octaves = octaves;
    noise.*.octcnt = n;
    return n;
}
pub fn sampleOctave(arg_noise: [*c]const OctaveNoise, arg_x: f64, arg_y: f64, arg_z: f64) f64 {
    var noise = arg_noise;
    _ = &noise;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var v: f64 = 0;
    _ = &v;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < noise.*.octcnt) : (i += 1) {
            var p: [*c]PerlinNoise = noise.*.octaves + @as(usize, @bitCast(@as(isize, @intCast(i))));
            _ = &p;
            var lf: f64 = p.*.lacunarity;
            _ = &lf;
            var ax: f64 = maintainPrecision(x * lf);
            _ = &ax;
            var ay: f64 = maintainPrecision(y * lf);
            _ = &ay;
            var az: f64 = maintainPrecision(z * lf);
            _ = &az;
            var pv: f64 = samplePerlin(p, ax, ay, az, @as(f64, @floatFromInt(@as(c_int, 0))), @as(f64, @floatFromInt(@as(c_int, 0))));
            _ = &pv;
            v += p.*.amplitude * pv;
        }
    }
    return v;
}
pub fn sampleOctaveAmp(arg_noise: [*c]const OctaveNoise, arg_x: f64, arg_y: f64, arg_z: f64, arg_yamp: f64, arg_ymin: f64, arg_ydefault: c_int) f64 {
    var noise = arg_noise;
    _ = &noise;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var yamp = arg_yamp;
    _ = &yamp;
    var ymin = arg_ymin;
    _ = &ymin;
    var ydefault = arg_ydefault;
    _ = &ydefault;
    var v: f64 = 0;
    _ = &v;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < noise.*.octcnt) : (i += 1) {
            var p: [*c]PerlinNoise = noise.*.octaves + @as(usize, @bitCast(@as(isize, @intCast(i))));
            _ = &p;
            var lf: f64 = p.*.lacunarity;
            _ = &lf;
            var ax: f64 = maintainPrecision(x * lf);
            _ = &ax;
            var ay: f64 = if (ydefault != 0) -p.*.b else maintainPrecision(y * lf);
            _ = &ay;
            var az: f64 = maintainPrecision(z * lf);
            _ = &az;
            var pv: f64 = samplePerlin(p, ax, ay, az, yamp * lf, ymin * lf);
            _ = &pv;
            v += p.*.amplitude * pv;
        }
    }
    return v;
}
pub fn sampleOctaveBeta17Biome(arg_noise: [*c]const OctaveNoise, arg_x: f64, arg_z: f64) f64 {
    var noise = arg_noise;
    _ = &noise;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var v: f64 = 0;
    _ = &v;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < noise.*.octcnt) : (i += 1) {
            var p: [*c]PerlinNoise = noise.*.octaves + @as(usize, @bitCast(@as(isize, @intCast(i))));
            _ = &p;
            var lf: f64 = p.*.lacunarity;
            _ = &lf;
            var ax: f64 = maintainPrecision(x * lf) + p.*.a;
            _ = &ax;
            var az: f64 = maintainPrecision(z * lf) + p.*.b;
            _ = &az;
            var pv: f64 = sampleSimplex2D(p, ax, az);
            _ = &pv;
            v += p.*.amplitude * pv;
        }
    }
    return v;
}
pub fn sampleOctaveBeta17Terrain(arg_noise: [*c]const OctaveNoise, arg_v: [*c]f64, arg_x: f64, arg_z: f64, arg_yLacFlag: c_int, arg_lacmin: f64) void {
    var noise = arg_noise;
    _ = &noise;
    var v = arg_v;
    _ = &v;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var yLacFlag = arg_yLacFlag;
    _ = &yLacFlag;
    var lacmin = arg_lacmin;
    _ = &lacmin;
    v[@as(c_uint, @intCast(@as(c_int, 0)))] = 0.0;
    v[@as(c_uint, @intCast(@as(c_int, 1)))] = 0.0;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < noise.*.octcnt) : (i += 1) {
            var p: [*c]PerlinNoise = noise.*.octaves + @as(usize, @bitCast(@as(isize, @intCast(i))));
            _ = &p;
            var lf: f64 = p.*.lacunarity;
            _ = &lf;
            if ((lacmin != 0) and (lf > lacmin)) continue;
            var ax: f64 = maintainPrecision(x * lf);
            _ = &ax;
            var az: f64 = maintainPrecision(z * lf);
            _ = &az;
            samplePerlinBeta17Terrain(p, v, ax, az, if (yLacFlag != 0) 0.5 else 1.0);
        }
    }
}
pub fn doublePerlinInit(arg_noise: [*c]DoublePerlinNoise, arg_seed: [*c]u64, arg_octavesA: [*c]PerlinNoise, arg_octavesB: [*c]PerlinNoise, arg_omin: c_int, arg_len: c_int) void {
    var noise = arg_noise;
    _ = &noise;
    var seed = arg_seed;
    _ = &seed;
    var octavesA = arg_octavesA;
    _ = &octavesA;
    var octavesB = arg_octavesB;
    _ = &octavesB;
    var omin = arg_omin;
    _ = &omin;
    var len = arg_len;
    _ = &len;
    noise.*.amplitude = ((10.0 / 6.0) * @as(f64, @floatFromInt(len))) / @as(f64, @floatFromInt(len + @as(c_int, 1)));
    octaveInit(&noise.*.octA, seed, octavesA, omin, len);
    octaveInit(&noise.*.octB, seed, octavesB, omin, len);
}
pub fn xDoublePerlinInit(arg_noise: [*c]DoublePerlinNoise, arg_xr: [*c]Xoroshiro, arg_octaves: [*c]PerlinNoise, arg_amplitudes: [*c]const f64, arg_omin: c_int, arg_len: c_int, arg_nmax: c_int) c_int {
    var noise = arg_noise;
    _ = &noise;
    var xr = arg_xr;
    _ = &xr;
    var octaves = arg_octaves;
    _ = &octaves;
    var amplitudes = arg_amplitudes;
    _ = &amplitudes;
    var omin = arg_omin;
    _ = &omin;
    var len = arg_len;
    _ = &len;
    var nmax = arg_nmax;
    _ = &nmax;
    var i: c_int = undefined;
    _ = &i;
    var n: c_int = 0;
    _ = &n;
    var na: c_int = -@as(c_int, 1);
    _ = &na;
    var nb: c_int = -@as(c_int, 1);
    _ = &nb;
    if (nmax > @as(c_int, 0)) {
        na = (nmax + @as(c_int, 1)) >> @intCast(1);
        nb = nmax - na;
    }
    n += xOctaveInit(&noise.*.octA, xr, octaves + @as(usize, @bitCast(@as(isize, @intCast(n)))), amplitudes, omin, len, na);
    n += xOctaveInit(&noise.*.octB, xr, octaves + @as(usize, @bitCast(@as(isize, @intCast(n)))), amplitudes, omin, len, nb);
    {
        i = len - @as(c_int, 1);
        while ((i >= @as(c_int, 0)) and ((blk: {
            const tmp = i;
            if (tmp >= 0) break :blk amplitudes + @as(usize, @intCast(tmp)) else break :blk amplitudes - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* == 0.0)) : (i -= 1) {
            len -= 1;
        }
    }
    {
        i = 0;
        while ((blk: {
            const tmp = i;
            if (tmp >= 0) break :blk amplitudes + @as(usize, @intCast(tmp)) else break :blk amplitudes - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* == 0.0) : (i += 1) {
            len -= 1;
        }
    }
    const amp_ini = struct {
        const static: [10]f64 = [10]f64{
            0,
            5.0 / @as(f64, @floatFromInt(@as(c_int, 6))),
            10.0 / @as(f64, @floatFromInt(@as(c_int, 9))),
            15.0 / @as(f64, @floatFromInt(@as(c_int, 12))),
            20.0 / @as(f64, @floatFromInt(@as(c_int, 15))),
            25.0 / @as(f64, @floatFromInt(@as(c_int, 18))),
            30.0 / @as(f64, @floatFromInt(@as(c_int, 21))),
            35.0 / @as(f64, @floatFromInt(@as(c_int, 24))),
            40.0 / @as(f64, @floatFromInt(@as(c_int, 27))),
            45.0 / @as(f64, @floatFromInt(@as(c_int, 30))),
        };
    };
    _ = &amp_ini;
    noise.*.amplitude = amp_ini.static[@as(c_uint, @intCast(len))];
    return n;
}
pub export fn sampleDoublePerlin(arg_noise: [*c]const DoublePerlinNoise, arg_x: f64, arg_y: f64, arg_z: f64) f64 {
    var noise = arg_noise;
    _ = &noise;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    const f: f64 = 337.0 / 331.0;
    _ = &f;
    var v: f64 = 0;
    _ = &v;
    v += sampleOctave(&noise.*.octA, x, y, z);
    v += sampleOctave(&noise.*.octB, x * f, y * f, z * f);
    return v * noise.*.amplitude;
}
// stderr is defined at top of file as null (error logging disabled in pure Zig builds)
pub const fprintf = libc_shim.fprintf;
pub const printf = libc_shim.printf;
pub fn indexedLerp(arg_idx: u8, arg_a: f64, arg_b: f64, arg_c: f64) f64 {
    var idx = arg_idx;
    _ = &idx;
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var c = arg_c;
    _ = &c;
    while (true) {
        switch (@as(c_int, @bitCast(@as(c_uint, idx))) & @as(c_int, 15)) {
            @as(c_int, 0) => return a + b,
            @as(c_int, 1) => return -a + b,
            @as(c_int, 2) => return a - b,
            @as(c_int, 3) => return -a - b,
            @as(c_int, 4) => return a + c,
            @as(c_int, 5) => return -a + c,
            @as(c_int, 6) => return a - c,
            @as(c_int, 7) => return -a - c,
            @as(c_int, 8) => return b + c,
            @as(c_int, 9) => return -b + c,
            @as(c_int, 10) => return b - c,
            @as(c_int, 11) => return -b - c,
            @as(c_int, 12) => return a + b,
            @as(c_int, 13) => return -b + c,
            @as(c_int, 14) => return -a + b,
            @as(c_int, 15) => return -b - c,
            else => {},
        }
        break;
    }
    __builtin_unreachable();
    return 0;
}
pub fn samplePerlinBeta17Terrain(arg_noise: [*c]const PerlinNoise, arg_v: [*c]f64, arg_d1: f64, arg_d3: f64, arg_yLacAmp: f64) void {
    var noise = arg_noise;
    _ = &noise;
    var v = arg_v;
    _ = &v;
    var d1 = arg_d1;
    _ = &d1;
    var d3 = arg_d3;
    _ = &d3;
    var yLacAmp = arg_yLacAmp;
    _ = &yLacAmp;
    var genFlag: c_int = -@as(c_int, 1);
    _ = &genFlag;
    var l1: f64 = 0;
    _ = &l1;
    var l3: f64 = 0;
    _ = &l3;
    var l5: f64 = 0;
    _ = &l5;
    var l7: f64 = 0;
    _ = &l7;
    d1 += noise.*.a;
    d3 += noise.*.c;
    var idx: [*c]const u8 = @as([*c]const u8, @ptrCast(@alignCast(&noise.*.d)));
    _ = &idx;
    var @"i1": c_int = @as(c_int, @intFromFloat(floor(d1)));
    _ = &@"i1";
    var @"i3": c_int = @as(c_int, @intFromFloat(floor(d3)));
    _ = &@"i3";
    d1 -= @as(f64, @floatFromInt(@"i1"));
    d3 -= @as(f64, @floatFromInt(@"i3"));
    var t1: f64 = ((d1 * d1) * d1) * ((d1 * ((d1 * 6.0) - 15.0)) + 10.0);
    _ = &t1;
    var t3: f64 = ((d3 * d3) * d3) * ((d3 * ((d3 * 6.0) - 15.0)) + 10.0);
    _ = &t3;
    @"i1" &= @as(c_int, 255);
    @"i3" &= @as(c_int, 255);
    var d2: f64 = undefined;
    _ = &d2;
    var @"i2": c_int = undefined;
    _ = &@"i2";
    var yi: c_int = undefined;
    _ = &yi;
    var yic: c_int = 0;
    _ = &yic;
    var gfCopy: c_int = 0;
    _ = &gfCopy;
    {
        yi = 0;
        while (yi <= @as(c_int, 7)) : (yi += 1) {
            d2 = ((@as(f64, @floatFromInt(yi)) * noise.*.lacunarity) * yLacAmp) + noise.*.b;
            @"i2" = @as(c_int, @intFromFloat(floor(d2))) & @as(c_int, 255);
            if ((yi == @as(c_int, 0)) or (@"i2" != genFlag)) {
                yic = yi;
                gfCopy = genFlag;
                genFlag = @"i2";
            }
        }
    }
    genFlag = gfCopy;
    var t2: f64 = undefined;
    _ = &t2;
    {
        yi = yic;
        while (yi <= @as(c_int, 8)) : (yi += 1) {
            d2 = ((@as(f64, @floatFromInt(yi)) * noise.*.lacunarity) * yLacAmp) + noise.*.b;
            @"i2" = @as(c_int, @intFromFloat(floor(d2)));
            d2 -= @as(f64, @floatFromInt(@"i2"));
            t2 = ((d2 * d2) * d2) * ((d2 * ((d2 * 6.0) - 15.0)) + 10.0);
            @"i2" &= @as(c_int, 255);
            if ((yi == @as(c_int, 0)) or (@"i2" != genFlag)) {
                genFlag = @"i2";
                var a1: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    const tmp = @"i1";
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*))) + @"i2";
                _ = &a1;
                var b1: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    const tmp = @"i1" + @as(c_int, 1);
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*))) + @"i2";
                _ = &b1;
                var a2: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    const tmp = a1;
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*))) + @"i3";
                _ = &a2;
                var a3: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    const tmp = a1 + @as(c_int, 1);
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*))) + @"i3";
                _ = &a3;
                var b2: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    const tmp = b1;
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*))) + @"i3";
                _ = &b2;
                var b3: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    const tmp = b1 + @as(c_int, 1);
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*))) + @"i3";
                _ = &b3;
                var m1: f64 = indexedLerp((blk: {
                    const tmp = a2;
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1, d2, d3);
                _ = &m1;
                var l2: f64 = indexedLerp((blk: {
                    const tmp = b2;
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2, d3);
                _ = &l2;
                var m3: f64 = indexedLerp((blk: {
                    const tmp = a3;
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1, d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3);
                _ = &m3;
                var l4: f64 = indexedLerp((blk: {
                    const tmp = b3;
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3);
                _ = &l4;
                var m5: f64 = indexedLerp((blk: {
                    const tmp = a2 + @as(c_int, 1);
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1, d2, d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
                _ = &m5;
                var l6: f64 = indexedLerp((blk: {
                    const tmp = b2 + @as(c_int, 1);
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2, d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
                _ = &l6;
                var m7: f64 = indexedLerp((blk: {
                    const tmp = a3 + @as(c_int, 1);
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1, d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
                _ = &m7;
                var l8: f64 = indexedLerp((blk: {
                    const tmp = b3 + @as(c_int, 1);
                    if (tmp >= 0) break :blk idx + @as(usize, @intCast(tmp)) else break :blk idx - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, d1 - @as(f64, @floatFromInt(@as(c_int, 1))), d2 - @as(f64, @floatFromInt(@as(c_int, 1))), d3 - @as(f64, @floatFromInt(@as(c_int, 1))));
                _ = &l8;
                l1 = lerp(t1, m1, l2);
                l3 = lerp(t1, m3, l4);
                l5 = lerp(t1, m5, l6);
                l7 = lerp(t1, m7, l8);
            }
            if (yi >= @as(c_int, 7)) {
                var n1: f64 = lerp(t2, l1, l3);
                _ = &n1;
                var n5: f64 = lerp(t2, l5, l7);
                _ = &n5;
                (blk: {
                    const tmp = yi - @as(c_int, 7);
                    if (tmp >= 0) break :blk v + @as(usize, @intCast(tmp)) else break :blk v - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).* += lerp(t3, n1, n5) * noise.*.amplitude;
            }
        }
    }
}
pub fn simplexGrad(arg_idx: c_int, arg_x: f64, arg_y: f64, arg_z: f64, arg_d: f64) f64 {
    var idx = arg_idx;
    _ = &idx;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var d = arg_d;
    _ = &d;
    var con: f64 = ((d - (x * x)) - (y * y)) - (z * z);
    _ = &con;
    if (con < @as(f64, @floatFromInt(@as(c_int, 0)))) return 0;
    con *= con;
    return (con * con) * indexedLerp(@as(u8, @bitCast(@as(i8, @truncate(idx)))), x, y, z);
}
pub const MC_B1_7: c_int = 1;
pub const MC_B1_8: c_int = 2;
pub const MC_1_0: c_int = 3;
pub const MC_1_1: c_int = 4;
pub const MC_1_2: c_int = 5;
pub const MC_1_3: c_int = 6;
pub const MC_1_4: c_int = 7;
pub const MC_1_6: c_int = 9;
pub const MC_1_7: c_int = 10;
pub const MC_1_8: c_int = 11;
pub const MC_1_9: c_int = 12;
pub const MC_1_10: c_int = 13;
pub const MC_1_11: c_int = 14;
pub const MC_1_12: c_int = 15;
pub const MC_1_13: c_int = 16;
pub const MC_1_14: c_int = 17;
pub const MC_1_15: c_int = 18;
pub const MC_1_16_1: c_int = 19;
pub const MC_1_16: c_int = 20;
pub const MC_1_17: c_int = 21;
pub const MC_1_18: c_int = 22;
pub const MC_1_19_2: c_int = 23;
pub const MC_1_19_4: c_int = 24;
pub const MC_1_19: c_int = 24;
pub const MC_1_20_6: c_int = 25;
pub const MC_1_20: c_int = 25;
pub const MC_1_21_1: c_int = 26;
pub const MC_1_21_3: c_int = 27;
pub const MC_1_21_WD: c_int = 28;
pub const DIM_NETHER: c_int = -1;
pub const DIM_OVERWORLD: c_int = 0;
pub const DIM_END: c_int = 1;
pub const DIM_UNDEF: c_int = 1000;
pub const none: c_int = -1;
pub const ocean: c_int = 0;
pub const plains: c_int = 1;
pub const desert: c_int = 2;
pub const mountains: c_int = 3;
pub const forest: c_int = 4;
pub const taiga: c_int = 5;
pub const swamp: c_int = 6;
pub const river: c_int = 7;
pub const nether_wastes: c_int = 8;
pub const the_end: c_int = 9;
pub const frozen_ocean: c_int = 10;
pub const frozen_river: c_int = 11;
pub const snowy_tundra: c_int = 12;
pub const mushroom_fields: c_int = 14;
pub const beach: c_int = 16;
pub const desert_hills: c_int = 17;
pub const wooded_hills: c_int = 18;
pub const taiga_hills: c_int = 19;
pub const mountain_edge: c_int = 20;
pub const jungle: c_int = 21;
pub const jungle_hills: c_int = 22;
pub const jungle_edge: c_int = 23;
pub const deep_ocean: c_int = 24;
pub const stone_shore: c_int = 25;
pub const snowy_beach: c_int = 26;
pub const birch_forest: c_int = 27;
pub const dark_forest: c_int = 29;
pub const snowy_taiga: c_int = 30;
pub const wooded_mountains: c_int = 34;
pub const savanna: c_int = 35;
pub const savanna_plateau: c_int = 36;
pub const badlands: c_int = 37;
pub const mesa: c_int = 37;
pub const wooded_badlands_plateau: c_int = 38;
pub const badlands_plateau: c_int = 39;
pub const small_end_islands: c_int = 40;
pub const end_midlands: c_int = 41;
pub const end_highlands: c_int = 42;
pub const end_barrens: c_int = 43;
pub const warm_ocean: c_int = 44;
pub const lukewarm_ocean: c_int = 45;
pub const cold_ocean: c_int = 46;
pub const deep_warm_ocean: c_int = 47;
pub const deep_lukewarm_ocean: c_int = 48;
pub const deep_cold_ocean: c_int = 49;
pub const deep_frozen_ocean: c_int = 50;
pub const seasonal_forest: c_int = 51;
pub const rainforest: c_int = 52;
pub const shrubland: c_int = 53;
pub const sunflower_plains: c_int = 129;
pub const gravelly_mountains: c_int = 131;
pub const flower_forest: c_int = 132;
pub const taiga_mountains: c_int = 133;
pub const ice_spikes: c_int = 140;
pub const dark_forest_hills: c_int = 157;
pub const snowy_taiga_mountains: c_int = 158;
pub const modified_gravelly_mountains: c_int = 162;
pub const shattered_savanna: c_int = 163;
pub const shattered_savanna_plateau: c_int = 164;
pub const eroded_badlands: c_int = 165;
pub const modified_wooded_badlands_plateau: c_int = 166;
pub const modified_badlands_plateau: c_int = 167;
pub const bamboo_jungle: c_int = 168;
pub const bamboo_jungle_hills: c_int = 169;
pub const soul_sand_valley: c_int = 170;
pub const crimson_forest: c_int = 171;
pub const warped_forest: c_int = 172;
pub const basalt_deltas: c_int = 173;
pub const dripstone_caves: c_int = 174;
pub const lush_caves: c_int = 175;
pub const meadow: c_int = 177;
pub const grove: c_int = 178;
pub const snowy_slopes: c_int = 179;
pub const jagged_peaks: c_int = 180;
pub const frozen_peaks: c_int = 181;
pub const stony_peaks: c_int = 182;
pub const old_growth_birch_forest: c_int = 155;
pub const old_growth_pine_taiga: c_int = 32;
pub const old_growth_spruce_taiga: c_int = 160;
pub const snowy_plains: c_int = 12;
pub const sparse_jungle: c_int = 23;
pub const stony_shore: c_int = 25;
pub const windswept_hills: c_int = 3;
pub const windswept_forest: c_int = 34;
pub const windswept_gravelly_hills: c_int = 131;
pub const windswept_savanna: c_int = 163;
pub const wooded_badlands: c_int = 38;
pub const deep_dark: c_int = 183;
pub const mangrove_swamp: c_int = 184;
pub const cherry_grove: c_int = 185;
pub const pale_garden: c_int = 186;
pub fn biomeExists(arg_mc: c_int, arg_id: c_int) c_int {
    var mc = arg_mc;
    _ = &mc;
    var id = arg_id;
    _ = &id;
    if (mc >= MC_1_18) {
        if ((id >= soul_sand_valley) and (id <= basalt_deltas)) return 1;
        if ((id >= small_end_islands) and (id <= end_barrens)) return 1;
        if (id == pale_garden) return @intFromBool(mc >= MC_1_21_WD);
        if (id == cherry_grove) return @intFromBool(mc >= MC_1_20);
        if ((id == deep_dark) or (id == mangrove_swamp)) return @intFromBool(mc >= MC_1_19_2);
        while (true) {
            switch (id) {
                @as(c_int, 0), @as(c_int, 1), @as(c_int, 2), @as(c_int, 3), @as(c_int, 4), @as(c_int, 5), @as(c_int, 6), @as(c_int, 7), @as(c_int, 8), @as(c_int, 9), @as(c_int, 10), @as(c_int, 11), @as(c_int, 12), @as(c_int, 14), @as(c_int, 16), @as(c_int, 21), @as(c_int, 23), @as(c_int, 24), @as(c_int, 25), @as(c_int, 26), @as(c_int, 27), @as(c_int, 29), @as(c_int, 30), @as(c_int, 32), @as(c_int, 34), @as(c_int, 35), @as(c_int, 36), @as(c_int, 37), @as(c_int, 38), @as(c_int, 44), @as(c_int, 45), @as(c_int, 46), @as(c_int, 47), @as(c_int, 48), @as(c_int, 49), @as(c_int, 50), @as(c_int, 129), @as(c_int, 131), @as(c_int, 132), @as(c_int, 140), @as(c_int, 155), @as(c_int, 160), @as(c_int, 163), @as(c_int, 165), @as(c_int, 168), @as(c_int, 174), @as(c_int, 175), @as(c_int, 177), @as(c_int, 178), @as(c_int, 179), @as(c_int, 182), @as(c_int, 180), @as(c_int, 181) => return 1,
                else => return 0,
            }
            break;
        }
    }
    if (mc <= MC_B1_7) {
        while (true) {
            switch (id) {
                @as(c_int, 1), @as(c_int, 2), @as(c_int, 4), @as(c_int, 5), @as(c_int, 6), @as(c_int, 12), @as(c_int, 35), @as(c_int, 51), @as(c_int, 52), @as(c_int, 53), @as(c_int, 0), @as(c_int, 10) => return 1,
                else => return 0,
            }
            break;
        }
    }
    if (mc <= MC_B1_8) {
        while (true) {
            switch (id) {
                @as(c_int, 10), @as(c_int, 11), @as(c_int, 12), @as(c_int, 14), @as(c_int, 15), @as(c_int, 9) => return 0,
                else => {},
            }
            break;
        }
    }
    if (mc <= MC_1_0) {
        while (true) {
            switch (id) {
                @as(c_int, 13), @as(c_int, 16), @as(c_int, 17), @as(c_int, 18), @as(c_int, 19), @as(c_int, 20) => return 0,
                else => {},
            }
            break;
        }
    }
    if ((id >= ocean) and (id <= mountain_edge)) return 1;
    if ((id >= jungle) and (id <= jungle_hills)) return @intFromBool(mc >= MC_1_2);
    if ((id >= jungle_edge) and (id <= badlands_plateau)) return @intFromBool(mc >= MC_1_7);
    if ((id >= small_end_islands) and (id <= end_barrens)) return @intFromBool(mc >= MC_1_9);
    if ((id >= warm_ocean) and (id <= deep_frozen_ocean)) return @intFromBool(mc >= MC_1_13);
    while (true) {
        switch (id) {
            @as(c_int, 127) => return @intFromBool(mc >= MC_1_9),
            @as(c_int, 129), @as(c_int, 130), @as(c_int, 131), @as(c_int, 132), @as(c_int, 133), @as(c_int, 134), @as(c_int, 140), @as(c_int, 149), @as(c_int, 151), @as(c_int, 155), @as(c_int, 156), @as(c_int, 157), @as(c_int, 158), @as(c_int, 160), @as(c_int, 161), @as(c_int, 162), @as(c_int, 163), @as(c_int, 164), @as(c_int, 165), @as(c_int, 166), @as(c_int, 167) => return @intFromBool(mc >= MC_1_7),
            @as(c_int, 168), @as(c_int, 169) => return @intFromBool(mc >= MC_1_14),
            @as(c_int, 170), @as(c_int, 171), @as(c_int, 172), @as(c_int, 173) => return @intFromBool(mc >= MC_1_16_1),
            @as(c_int, 174), @as(c_int, 175) => return @intFromBool(mc >= MC_1_17),
            else => return 0,
        }
        break;
    }
    return 0;
}
pub fn isOverworld(arg_mc: c_int, arg_id: c_int) c_int {
    var mc = arg_mc;
    _ = &mc;
    var id = arg_id;
    _ = &id;
    if (!(biomeExists(mc, id) != 0)) return 0;
    if ((id >= small_end_islands) and (id <= end_barrens)) return 0;
    if ((id >= soul_sand_valley) and (id <= basalt_deltas)) return 0;
    while (true) {
        switch (id) {
            @as(c_int, 8), @as(c_int, 9) => return 0,
            @as(c_int, 10) => return @intFromBool((mc <= MC_1_6) or (mc >= MC_1_13)),
            @as(c_int, 20) => return @intFromBool(mc <= MC_1_6),
            @as(c_int, 47), @as(c_int, 127) => return 0,
            @as(c_int, 155) => return @intFromBool((mc <= MC_1_8) or (mc >= MC_1_11)),
            @as(c_int, 174), @as(c_int, 175) => return @intFromBool(mc >= MC_1_18),
            else => {},
        }
        break;
    }
    return 1;
}
pub fn getCategory(arg_mc: c_int, arg_id: c_int) c_int {
    var mc = arg_mc;
    _ = &mc;
    var id = arg_id;
    _ = &id;
    while (true) {
        switch (id) {
            @as(c_int, 16), @as(c_int, 26) => return beach,
            @as(c_int, 2), @as(c_int, 17), @as(c_int, 130) => return desert,
            @as(c_int, 3), @as(c_int, 20), @as(c_int, 34), @as(c_int, 131), @as(c_int, 162) => return mountains,
            @as(c_int, 4), @as(c_int, 18), @as(c_int, 27), @as(c_int, 28), @as(c_int, 29), @as(c_int, 132), @as(c_int, 155), @as(c_int, 156), @as(c_int, 157) => return forest,
            @as(c_int, 12), @as(c_int, 13), @as(c_int, 140) => return snowy_tundra,
            @as(c_int, 21), @as(c_int, 22), @as(c_int, 23), @as(c_int, 149), @as(c_int, 151), @as(c_int, 168), @as(c_int, 169) => return jungle,
            @as(c_int, 37), @as(c_int, 165), @as(c_int, 166), @as(c_int, 167) => return mesa,
            @as(c_int, 38), @as(c_int, 39) => return if (mc <= MC_1_15) mesa else badlands_plateau,
            @as(c_int, 14), @as(c_int, 15) => return mushroom_fields,
            @as(c_int, 25) => return stone_shore,
            @as(c_int, 0), @as(c_int, 10), @as(c_int, 24), @as(c_int, 44), @as(c_int, 45), @as(c_int, 46), @as(c_int, 47), @as(c_int, 48), @as(c_int, 49), @as(c_int, 50) => return ocean,
            @as(c_int, 1), @as(c_int, 129) => return plains,
            @as(c_int, 7), @as(c_int, 11) => return river,
            @as(c_int, 35), @as(c_int, 36), @as(c_int, 163), @as(c_int, 164) => return savanna,
            @as(c_int, 6), @as(c_int, 134) => return swamp,
            @as(c_int, 5), @as(c_int, 19), @as(c_int, 30), @as(c_int, 31), @as(c_int, 32), @as(c_int, 33), @as(c_int, 133), @as(c_int, 158), @as(c_int, 160), @as(c_int, 161) => return taiga,
            @as(c_int, 8), @as(c_int, 170), @as(c_int, 171), @as(c_int, 172), @as(c_int, 173) => return nether_wastes,
            else => return none,
        }
        break;
    }
    return 0;
}
pub fn isDeepOcean(arg_id: c_int) c_int {
    var id = arg_id;
    _ = &id;
    const deep_bits: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(((((@as(c_ulonglong, 1) << @intCast(deep_ocean)) | (@as(c_ulonglong, 1) << @intCast(deep_warm_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_lukewarm_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_cold_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_frozen_ocean))))));
    _ = &deep_bits;
    return @intFromBool((@as(u32, @bitCast(id)) < @as(u32, @bitCast(@as(c_int, 64)))) and (((@as(c_ulonglong, 1) << @intCast(id)) & @as(c_ulonglong, @bitCast(@as(c_ulonglong, deep_bits)))) != 0));
}
pub fn isOceanic(arg_id: c_int) c_int {
    var id = arg_id;
    _ = &id;
    const ocean_bits: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate((((((((((@as(c_ulonglong, 1) << @intCast(ocean)) | (@as(c_ulonglong, 1) << @intCast(frozen_ocean))) | (@as(c_ulonglong, 1) << @intCast(warm_ocean))) | (@as(c_ulonglong, 1) << @intCast(lukewarm_ocean))) | (@as(c_ulonglong, 1) << @intCast(cold_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_warm_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_lukewarm_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_cold_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_frozen_ocean))))));
    _ = &ocean_bits;
    return @intFromBool((@as(u32, @bitCast(id)) < @as(u32, @bitCast(@as(c_int, 64)))) and (((@as(c_ulonglong, 1) << @intCast(id)) & @as(c_ulonglong, @bitCast(@as(c_ulonglong, ocean_bits)))) != 0));
}
pub const Special: c_int = 5;
pub const L_CONTINENT_4096: c_int = 0;
pub const L_ZOOM_4096: c_int = 1;
pub const L_LAND_4096: c_int = 2;
pub const L_ZOOM_2048: c_int = 3;
pub const L_LAND_2048: c_int = 4;
pub const L_ZOOM_1024: c_int = 5;
pub const L_LAND_1024_A: c_int = 6;
pub const L_LAND_1024_B: c_int = 7;
pub const L_LAND_1024_C: c_int = 8;
pub const L_ISLAND_1024: c_int = 9;
pub const L_SNOW_1024: c_int = 10;
pub const L_LAND_1024_D: c_int = 11;
pub const L_COOL_1024: c_int = 12;
pub const L_HEAT_1024: c_int = 13;
pub const L_SPECIAL_1024: c_int = 14;
pub const L_ZOOM_512: c_int = 15;
pub const L_LAND_512: c_int = 16;
pub const L_ZOOM_256: c_int = 17;
pub const L_LAND_256: c_int = 18;
pub const L_MUSHROOM_256: c_int = 19;
pub const L_DEEP_OCEAN_256: c_int = 20;
pub const L_BIOME_256: c_int = 21;
pub const L_BAMBOO_256: c_int = 22;
pub const L_ZOOM_128: c_int = 23;
pub const L_ZOOM_64: c_int = 24;
pub const L_BIOME_EDGE_64: c_int = 25;
pub const L_NOISE_256: c_int = 26;
pub const L_RIVER_INIT_256: c_int = 26;
pub const L_ZOOM_128_HILLS: c_int = 27;
pub const L_ZOOM_64_HILLS: c_int = 28;
pub const L_HILLS_64: c_int = 29;
pub const L_SUNFLOWER_64: c_int = 30;
pub const L_ZOOM_32: c_int = 31;
pub const L_LAND_32: c_int = 32;
pub const L_ZOOM_16: c_int = 33;
pub const L_SHORE_16: c_int = 34;
pub const L_SWAMP_RIVER_16: c_int = 35;
pub const L_ZOOM_8: c_int = 36;
pub const L_ZOOM_4: c_int = 37;
pub const L_SMOOTH_4: c_int = 38;
pub const L_ZOOM_128_RIVER: c_int = 39;
pub const L_ZOOM_64_RIVER: c_int = 40;
pub const L_ZOOM_32_RIVER: c_int = 41;
pub const L_ZOOM_16_RIVER: c_int = 42;
pub const L_ZOOM_8_RIVER: c_int = 43;
pub const L_ZOOM_4_RIVER: c_int = 44;
pub const L_RIVER_4: c_int = 45;
pub const L_SMOOTH_4_RIVER: c_int = 46;
pub const L_RIVER_MIX_4: c_int = 47;
pub const L_OCEAN_TEMP_256: c_int = 48;
pub const L_ZOOM_128_OCEAN: c_int = 49;
pub const L_ZOOM_64_OCEAN: c_int = 50;
pub const L_ZOOM_32_OCEAN: c_int = 51;
pub const L_ZOOM_16_OCEAN: c_int = 52;
pub const L_ZOOM_8_OCEAN: c_int = 53;
pub const L_ZOOM_4_OCEAN: c_int = 54;
pub const L_OCEAN_MIX_4: c_int = 55;
pub const L_VORONOI_1: c_int = 56;
pub const L_ZOOM_LARGE_A: c_int = 57;
pub const L_ZOOM_LARGE_B: c_int = 58;
pub const L_ZOOM_L_RIVER_A: c_int = 59;
pub const L_ZOOM_L_RIVER_B: c_int = 60;
pub const mapfunc_t = fn ([*c]const struct_Layer, [*c]c_int, c_int, c_int, c_int, c_int) c_int;
pub const Layer = struct_Layer;
pub const struct_Layer = extern struct {
    getMap: ?*const mapfunc_t = @import("std").mem.zeroes(?*const mapfunc_t),
    mc: i8 = @import("std").mem.zeroes(i8),
    zoom: i8 = @import("std").mem.zeroes(i8),
    edge: i8 = @import("std").mem.zeroes(i8),
    scale: c_int = @import("std").mem.zeroes(c_int),
    layerSalt: u64 = @import("std").mem.zeroes(u64),
    startSalt: u64 = @import("std").mem.zeroes(u64),
    startSeed: u64 = @import("std").mem.zeroes(u64),
    noise: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    data: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    p: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
    p2: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
};
pub const struct_LayerStack = extern struct {
    layers: [61]Layer = @import("std").mem.zeroes([61]Layer),
    entry_1: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
    entry_4: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
    entry_16: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
    entry_64: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
    entry_256: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
    oceanRnd: PerlinNoise = @import("std").mem.zeroes(PerlinNoise),
};
pub const LayerStack = struct_LayerStack;
pub fn setLayerSeed(arg_layer: [*c]Layer, arg_worldSeed: u64) void {
    var layer = arg_layer;
    _ = &layer;
    var worldSeed = arg_worldSeed;
    _ = &worldSeed;
    if (layer.*.p2 != @as([*c]Layer, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        setLayerSeed(layer.*.p2, worldSeed);
    }
    if (layer.*.p != @as([*c]Layer, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        setLayerSeed(layer.*.p, worldSeed);
    }
    if (layer.*.noise != @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)))) {
        var s: u64 = undefined;
        _ = &s;
        setSeed(&s, worldSeed);
        perlinInit(@as([*c]PerlinNoise, @ptrCast(@alignCast(layer.*.noise))), &s);
    }
    var ls: u64 = layer.*.layerSalt;
    _ = &ls;
    if (ls == @as(u64, @bitCast(@as(c_long, @as(c_int, 0))))) {
        layer.*.startSalt = 0;
        layer.*.startSeed = 0;
    } else if (@as(c_ulonglong, @bitCast(@as(c_ulonglong, ls))) == ~@as(c_ulonglong, 0)) {
        layer.*.startSalt = getVoronoiSHA(worldSeed);
        layer.*.startSeed = 0;
    } else {
        var st: u64 = worldSeed;
        _ = &st;
        st = mcStepSeed(st, ls);
        st = mcStepSeed(st, ls);
        st = mcStepSeed(st, ls);
        layer.*.startSalt = st;
        layer.*.startSeed = mcStepSeed(st, @as(u64, @bitCast(@as(c_long, @as(c_int, 0)))));
    }
}
pub fn mapContinent(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapZoomFuzzy(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapZoom(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapLand(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapLand16(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapLandB18(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapIsland(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapSnow(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapSnow16(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapCool(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapHeat(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapSpecial(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapMushroom(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapDeepOcean(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], deep_ocean);
    return 0;
}
pub fn mapBiome(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapBamboo(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapNoise(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapBiomeEdge(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapHills(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapRiver(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], river);
    return 0;
}
pub fn mapSmooth(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapSunflower(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapShore(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], beach);
    return 0;
}
pub fn mapSwampRiver(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], swamp);
    return 0;
}
pub fn mapRiverMix(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapOceanTemp(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapOceanMix(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], ocean);
    return 0;
}
pub fn mapVoronoi(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn mapVoronoi114(_: [*c]const Layer, out: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int) c_int {
    @memset(out[0..@as(usize, @intCast(w * h))], plains);
    return 0;
}
pub fn getVoronoiSHA(arg_seed: u64) u64 {
    var seed = arg_seed;
    _ = &seed;
    const K = struct {
        const static: [64]u32 = [64]u32{
            @as(u32, @bitCast(@as(c_int, 1116352408))),
            @as(u32, @bitCast(@as(c_int, 1899447441))),
            3049323471,
            3921009573,
            @as(u32, @bitCast(@as(c_int, 961987163))),
            @as(u32, @bitCast(@as(c_int, 1508970993))),
            2453635748,
            2870763221,
            3624381080,
            @as(u32, @bitCast(@as(c_int, 310598401))),
            @as(u32, @bitCast(@as(c_int, 607225278))),
            @as(u32, @bitCast(@as(c_int, 1426881987))),
            @as(u32, @bitCast(@as(c_int, 1925078388))),
            2162078206,
            2614888103,
            3248222580,
            3835390401,
            4022224774,
            @as(u32, @bitCast(@as(c_int, 264347078))),
            @as(u32, @bitCast(@as(c_int, 604807628))),
            @as(u32, @bitCast(@as(c_int, 770255983))),
            @as(u32, @bitCast(@as(c_int, 1249150122))),
            @as(u32, @bitCast(@as(c_int, 1555081692))),
            @as(u32, @bitCast(@as(c_int, 1996064986))),
            2554220882,
            2821834349,
            2952996808,
            3210313671,
            3336571891,
            3584528711,
            @as(u32, @bitCast(@as(c_int, 113926993))),
            @as(u32, @bitCast(@as(c_int, 338241895))),
            @as(u32, @bitCast(@as(c_int, 666307205))),
            @as(u32, @bitCast(@as(c_int, 773529912))),
            @as(u32, @bitCast(@as(c_int, 1294757372))),
            @as(u32, @bitCast(@as(c_int, 1396182291))),
            @as(u32, @bitCast(@as(c_int, 1695183700))),
            @as(u32, @bitCast(@as(c_int, 1986661051))),
            2177026350,
            2456956037,
            2730485921,
            2820302411,
            3259730800,
            3345764771,
            3516065817,
            3600352804,
            4094571909,
            @as(u32, @bitCast(@as(c_int, 275423344))),
            @as(u32, @bitCast(@as(c_int, 430227734))),
            @as(u32, @bitCast(@as(c_int, 506948616))),
            @as(u32, @bitCast(@as(c_int, 659060556))),
            @as(u32, @bitCast(@as(c_int, 883997877))),
            @as(u32, @bitCast(@as(c_int, 958139571))),
            @as(u32, @bitCast(@as(c_int, 1322822218))),
            @as(u32, @bitCast(@as(c_int, 1537002063))),
            @as(u32, @bitCast(@as(c_int, 1747873779))),
            @as(u32, @bitCast(@as(c_int, 1955562222))),
            @as(u32, @bitCast(@as(c_int, 2024104815))),
            2227730452,
            2361852424,
            2428436474,
            2756734187,
            3204031479,
            3329325298,
        };
    };
    _ = &K;
    const B = struct {
        const static: [8]u32 = [8]u32{
            @as(u32, @bitCast(@as(c_int, 1779033703))),
            3144134277,
            @as(u32, @bitCast(@as(c_int, 1013904242))),
            2773480762,
            @as(u32, @bitCast(@as(c_int, 1359893119))),
            2600822924,
            @as(u32, @bitCast(@as(c_int, 528734635))),
            @as(u32, @bitCast(@as(c_int, 1541459225))),
        };
    };
    _ = &B;
    var m: [64]u32 = undefined;
    _ = &m;
    var a0: u32 = undefined;
    _ = &a0;
    var a1: u32 = undefined;
    _ = &a1;
    var a2: u32 = undefined;
    _ = &a2;
    var a3: u32 = undefined;
    _ = &a3;
    var a4: u32 = undefined;
    _ = &a4;
    var a5: u32 = undefined;
    _ = &a5;
    var a6: u32 = undefined;
    _ = &a6;
    var a7: u32 = undefined;
    _ = &a7;
    var i: u32 = undefined;
    _ = &i;
    var x: u32 = undefined;
    _ = &x;
    var y: u32 = undefined;
    _ = &y;
    m[@as(c_uint, @intCast(@as(c_int, 0)))] = __builtin_bswap32(@as(u32, @bitCast(@as(c_uint, @truncate(seed)))));
    m[@as(c_uint, @intCast(@as(c_int, 1)))] = __builtin_bswap32(@as(u32, @bitCast(@as(c_uint, @truncate(seed >> @intCast(32))))));
    m[@as(c_uint, @intCast(@as(c_int, 2)))] = 2147483648;
    {
        i = 3;
        while (i < @as(u32, @bitCast(@as(c_int, 15)))) : (i +%= 1) {
            m[i] = 0;
        }
    }
    m[@as(c_uint, @intCast(@as(c_int, 15)))] = 64;
    {
        i = 16;
        while (i < @as(u32, @bitCast(@as(c_int, 64)))) : (i +%= 1) {
            m[i] = m[i -% @as(u32, @bitCast(@as(c_int, 7)))] +% m[i -% @as(u32, @bitCast(@as(c_int, 16)))];
            x = m[i -% @as(u32, @bitCast(@as(c_int, 15)))];
            m[i] +%= (rotr32(x, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 7)))))) ^ rotr32(x, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 18))))))) ^ (x >> @intCast(3));
            x = m[i -% @as(u32, @bitCast(@as(c_int, 2)))];
            m[i] +%= (rotr32(x, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 17)))))) ^ rotr32(x, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 19))))))) ^ (x >> @intCast(10));
        }
    }
    a0 = B.static[@as(c_uint, @intCast(@as(c_int, 0)))];
    a1 = B.static[@as(c_uint, @intCast(@as(c_int, 1)))];
    a2 = B.static[@as(c_uint, @intCast(@as(c_int, 2)))];
    a3 = B.static[@as(c_uint, @intCast(@as(c_int, 3)))];
    a4 = B.static[@as(c_uint, @intCast(@as(c_int, 4)))];
    a5 = B.static[@as(c_uint, @intCast(@as(c_int, 5)))];
    a6 = B.static[@as(c_uint, @intCast(@as(c_int, 6)))];
    a7 = B.static[@as(c_uint, @intCast(@as(c_int, 7)))];
    {
        i = 0;
        while (i < @as(u32, @bitCast(@as(c_int, 64)))) : (i +%= 1) {
            x = (a7 +% K.static[i]) +% m[i];
            x +%= (rotr32(a4, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 6)))))) ^ rotr32(a4, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 11))))))) ^ rotr32(a4, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 25))))));
            x +%= (a4 & a5) ^ (~a4 & a6);
            y = (rotr32(a0, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 2)))))) ^ rotr32(a0, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 13))))))) ^ rotr32(a0, @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 22))))));
            y +%= ((a0 & a1) ^ (a0 & a2)) ^ (a1 & a2);
            a7 = a6;
            a6 = a5;
            a5 = a4;
            a4 = a3 +% x;
            a3 = a2;
            a2 = a1;
            a1 = a0;
            a0 = x +% y;
        }
    }
    a0 +%= B.static[@as(c_uint, @intCast(@as(c_int, 0)))];
    a1 +%= B.static[@as(c_uint, @intCast(@as(c_int, 1)))];
    return @as(u64, @bitCast(@as(c_ulong, __builtin_bswap32(a0)))) | (@as(u64, @bitCast(@as(c_ulong, __builtin_bswap32(a1)))) << @intCast(32));
}
pub export fn voronoiAccess3D(arg_sha: u64, arg_x: c_int, arg_y: c_int, arg_z: c_int, arg_x4: [*c]c_int, arg_y4: [*c]c_int, arg_z4: [*c]c_int) void {
    var sha = arg_sha;
    _ = &sha;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var x4 = arg_x4;
    _ = &x4;
    var y4 = arg_y4;
    _ = &y4;
    var z4 = arg_z4;
    _ = &z4;
    x -= @as(c_int, 2);
    y -= @as(c_int, 2);
    z -= @as(c_int, 2);
    var pX: c_int = x >> @intCast(2);
    _ = &pX;
    var pY: c_int = y >> @intCast(2);
    _ = &pY;
    var pZ: c_int = z >> @intCast(2);
    _ = &pZ;
    var dx: c_int = (x & @as(c_int, 3)) * @as(c_int, 10240);
    _ = &dx;
    var dy: c_int = (y & @as(c_int, 3)) * @as(c_int, 10240);
    _ = &dy;
    var dz: c_int = (z & @as(c_int, 3)) * @as(c_int, 10240);
    _ = &dz;
    var ax: c_int = 0;
    _ = &ax;
    var ay: c_int = 0;
    _ = &ay;
    var az: c_int = 0;
    _ = &az;
    var dmin: u64 = @as(u64, @bitCast(@as(c_long, -@as(c_int, 1))));
    _ = &dmin;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < @as(c_int, 8)) : (i += 1) {
            var bx: c_int = @intFromBool((i & @as(c_int, 4)) != @as(c_int, 0));
            _ = &bx;
            var by: c_int = @intFromBool((i & @as(c_int, 2)) != @as(c_int, 0));
            _ = &by;
            var bz: c_int = @intFromBool((i & @as(c_int, 1)) != @as(c_int, 0));
            _ = &bz;
            var cx: c_int = pX + bx;
            _ = &cx;
            var cy: c_int = pY + by;
            _ = &cy;
            var cz: c_int = pZ + bz;
            _ = &cz;
            var rx: c_int = undefined;
            _ = &rx;
            var ry: c_int = undefined;
            _ = &ry;
            var rz: c_int = undefined;
            _ = &rz;
            getVoronoiCell(sha, cx, cy, cz, &rx, &ry, &rz);
            rx += dx - ((@as(c_int, 40) * @as(c_int, 1024)) * bx);
            ry += dy - ((@as(c_int, 40) * @as(c_int, 1024)) * by);
            rz += dz - ((@as(c_int, 40) * @as(c_int, 1024)) * bz);
            var d: u64 = ((@as(u64, @bitCast(@as(c_long, rx))) *% @as(u64, @bitCast(@as(c_long, rx)))) +% (@as(u64, @bitCast(@as(c_long, ry))) *% @as(u64, @bitCast(@as(c_long, ry))))) +% (@as(u64, @bitCast(@as(c_long, rz))) *% @as(u64, @bitCast(@as(c_long, rz))));
            _ = &d;
            if (d < dmin) {
                dmin = d;
                ax = cx;
                ay = cy;
                az = cz;
            }
        }
    }
    if (x4 != null) {
        x4.* = ax;
    }
    if (y4 != null) {
        y4.* = ay;
    }
    if (z4 != null) {
        z4.* = az;
    }
}

pub fn mapVoronoiPlane(_: u64, out: [*c]c_int, src: [*c]c_int, _: c_int, _: c_int, w: c_int, h: c_int, _: c_int, _: c_int, _: c_int, _: c_int, _: c_int) void {
    const n = @as(usize, @intCast(w * h));
    var i: usize = 0;
    while (i < n) : (i += 1) out[i] = src[i];
}
pub inline fn memcpy(__dest: ?*anyopaque, __src: ?*const anyopaque, __n: c_ulong) ?*anyopaque {
    const n: usize = @intCast(__n);
    const dest_bytes = @as([*]u8, @ptrCast(@alignCast(__dest.?)));
    const src_bytes = @as([*]const u8, @ptrCast(@alignCast(__src.?)));
    @memcpy(dest_bytes[0..n], src_bytes[0..n]);
    return __dest;
}
pub inline fn memmove(__dest: ?*anyopaque, __src: ?*const anyopaque, __n: c_ulong) ?*anyopaque {
    const n: usize = @intCast(__n);
    const dest_bytes = @as([*]u8, @ptrCast(@alignCast(__dest.?)));
    const src_bytes = @as([*]const u8, @ptrCast(@alignCast(__src.?)));
    const std = @import("std");
    std.mem.copyBackwards(u8, dest_bytes[0..n], src_bytes[0..n]);
    return __dest;
}
pub inline fn memset(__s: ?*anyopaque, __c: c_int, __n: c_ulong) ?*anyopaque {
    const n: usize = @intCast(__n);
    const dest_bytes = @as([*]u8, @ptrCast(@alignCast(__s.?)));
    @memset(dest_bytes[0..n], @intCast(@as(u32, @bitCast(__c)) & 0xff));
    return __s;
}
// index: removed (unused extern)
pub export const warmBiomes: [6]c_int = [6]c_int{
    desert,
    desert,
    desert,
    savanna,
    savanna,
    plains,
};
pub export const lushBiomes: [6]c_int = [6]c_int{
    forest,
    dark_forest,
    mountains,
    plains,
    birch_forest,
    swamp,
};
pub export const coldBiomes: [4]c_int = [4]c_int{
    forest,
    mountains,
    taiga,
    plains,
};
pub export const snowBiomes: [4]c_int = [4]c_int{
    snowy_tundra,
    snowy_tundra,
    snowy_tundra,
    snowy_taiga,
};
pub export const oldBiomes: [7]c_int = [7]c_int{
    desert,
    forest,
    mountains,
    swamp,
    plains,
    taiga,
    jungle,
};
pub export const oldBiomes11: [6]c_int = [6]c_int{
    desert,
    forest,
    mountains,
    swamp,
    plains,
    taiga,
};
pub fn getVoronoiCell(arg_sha: u64, arg_a: c_int, arg_b: c_int, arg_c: c_int, arg_x: [*c]c_int, arg_y: [*c]c_int, arg_z: [*c]c_int) void {
    var sha = arg_sha;
    _ = &sha;
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var c = arg_c;
    _ = &c;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var s: u64 = sha;
    _ = &s;
    s = mcStepSeed(s, @as(u64, @bitCast(@as(c_long, a))));
    s = mcStepSeed(s, @as(u64, @bitCast(@as(c_long, b))));
    s = mcStepSeed(s, @as(u64, @bitCast(@as(c_long, c))));
    s = mcStepSeed(s, @as(u64, @bitCast(@as(c_long, a))));
    s = mcStepSeed(s, @as(u64, @bitCast(@as(c_long, b))));
    s = mcStepSeed(s, @as(u64, @bitCast(@as(c_long, c))));
    x.* = @as(c_int, @bitCast(@as(c_uint, @truncate((((s >> @intCast(24)) & @as(u64, @bitCast(@as(c_long, @as(c_int, 1023))))) -% @as(u64, @bitCast(@as(c_long, @as(c_int, 512))))) *% @as(u64, @bitCast(@as(c_long, @as(c_int, 36))))))));
    s = mcStepSeed(s, sha);
    y.* = @as(c_int, @bitCast(@as(c_uint, @truncate((((s >> @intCast(24)) & @as(u64, @bitCast(@as(c_long, @as(c_int, 1023))))) -% @as(u64, @bitCast(@as(c_long, @as(c_int, 512))))) *% @as(u64, @bitCast(@as(c_long, @as(c_int, 36))))))));
    s = mcStepSeed(s, sha);
    z.* = @as(c_int, @bitCast(@as(c_uint, @truncate((((s >> @intCast(24)) & @as(u64, @bitCast(@as(c_long, @as(c_int, 1023))))) -% @as(u64, @bitCast(@as(c_long, @as(c_int, 512))))) *% @as(u64, @bitCast(@as(c_long, @as(c_int, 36))))))));
}
pub const struct_Range = extern struct {
    scale: c_int = @import("std").mem.zeroes(c_int),
    x: c_int = @import("std").mem.zeroes(c_int),
    z: c_int = @import("std").mem.zeroes(c_int),
    sx: c_int = @import("std").mem.zeroes(c_int),
    sz: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    sy: c_int = @import("std").mem.zeroes(c_int),
};
pub const Range = struct_Range;
pub const struct_NetherNoise = extern struct {
    temperature: DoublePerlinNoise = @import("std").mem.zeroes(DoublePerlinNoise),
    humidity: DoublePerlinNoise = @import("std").mem.zeroes(DoublePerlinNoise),
    oct: [8]PerlinNoise = @import("std").mem.zeroes([8]PerlinNoise),
};
pub const NetherNoise = struct_NetherNoise;
pub const struct_EndNoise = extern struct {
    perlin: PerlinNoise = @import("std").mem.zeroes(PerlinNoise),
    mc: c_int = @import("std").mem.zeroes(c_int),
};
pub const EndNoise = struct_EndNoise;
pub const struct_SurfaceNoise = extern struct {
    xzScale: f64 = @import("std").mem.zeroes(f64),
    yScale: f64 = @import("std").mem.zeroes(f64),
    xzFactor: f64 = @import("std").mem.zeroes(f64),
    yFactor: f64 = @import("std").mem.zeroes(f64),
    octmin: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octmax: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octmain: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octsurf: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octdepth: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    oct: [60]PerlinNoise = @import("std").mem.zeroes([60]PerlinNoise),
};
pub const SurfaceNoise = struct_SurfaceNoise;
pub const struct_SurfaceNoiseBeta = extern struct {
    octmin: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octmax: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octmain: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octcontA: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    octcontB: OctaveNoise = @import("std").mem.zeroes(OctaveNoise),
    oct: [66]PerlinNoise = @import("std").mem.zeroes([66]PerlinNoise),
};
pub const SurfaceNoiseBeta = struct_SurfaceNoiseBeta;
pub const struct_SeaLevelColumnNoiseBeta = extern struct {
    contASample: f64 = @import("std").mem.zeroes(f64),
    contBSample: f64 = @import("std").mem.zeroes(f64),
    minSample: [2]f64 = @import("std").mem.zeroes([2]f64),
    maxSample: [2]f64 = @import("std").mem.zeroes([2]f64),
    mainSample: [2]f64 = @import("std").mem.zeroes([2]f64),
};
pub const SeaLevelColumnNoiseBeta = struct_SeaLevelColumnNoiseBeta;
pub const Spline = struct_Spline;
pub const struct_Spline = extern struct {
    len: c_int = @import("std").mem.zeroes(c_int),
    typ: c_int = @import("std").mem.zeroes(c_int),
    loc: [12]f32 = @import("std").mem.zeroes([12]f32),
    der: [12]f32 = @import("std").mem.zeroes([12]f32),
    val: [12][*c]Spline = @import("std").mem.zeroes([12][*c]Spline),
};
pub const struct_FixSpline = extern struct {
    len: c_int = @import("std").mem.zeroes(c_int),
    val: f32 = @import("std").mem.zeroes(f32),
};
pub const FixSpline = struct_FixSpline;
pub const struct_SplineStack = extern struct {
    stack: [42]Spline = @import("std").mem.zeroes([42]Spline),
    fstack: [151]FixSpline = @import("std").mem.zeroes([151]FixSpline),
    len: c_int = @import("std").mem.zeroes(c_int),
    flen: c_int = @import("std").mem.zeroes(c_int),
};
pub const SplineStack = struct_SplineStack;
pub const NP_TEMPERATURE: c_int = 0;
pub const NP_HUMIDITY: c_int = 1;
pub const NP_CONTINENTALNESS: c_int = 2;
pub const NP_EROSION: c_int = 3;
pub const NP_SHIFT: c_int = 4;
pub const NP_DEPTH: c_int = 4;
pub const NP_WEIRDNESS: c_int = 5;
pub const NP_MAX: c_int = 6;
pub const struct_BiomeNoise = extern struct {
    climate: [6]DoublePerlinNoise = @import("std").mem.zeroes([6]DoublePerlinNoise),
    oct: [46]PerlinNoise = @import("std").mem.zeroes([46]PerlinNoise),
    sp: [*c]Spline = @import("std").mem.zeroes([*c]Spline),
    ss: SplineStack = @import("std").mem.zeroes(SplineStack),
    nptype: c_int = @import("std").mem.zeroes(c_int),
    mc: c_int = @import("std").mem.zeroes(c_int),
};
pub const BiomeNoise = struct_BiomeNoise;
pub const struct_BiomeNoiseBeta = extern struct {
    climate: [3]OctaveNoise = @import("std").mem.zeroes([3]OctaveNoise),
    oct: [10]PerlinNoise = @import("std").mem.zeroes([10]PerlinNoise),
    nptype: c_int = @import("std").mem.zeroes(c_int),
    mc: c_int = @import("std").mem.zeroes(c_int),
};
pub const BiomeNoiseBeta = struct_BiomeNoiseBeta;
pub const struct_BiomeTree = extern struct {
    steps: [*c]const u32 = @import("std").mem.zeroes([*c]const u32),
    param: [*c]const i32 = @import("std").mem.zeroes([*c]const i32),
    nodes: [*c]const u64 = @import("std").mem.zeroes([*c]const u64),
    order: u32 = @import("std").mem.zeroes(u32),
    len: u32 = @import("std").mem.zeroes(u32),
};
pub const BiomeTree = struct_BiomeTree;
pub fn initSurfaceNoise(arg_sn: [*c]SurfaceNoise, arg_dim: c_int, arg_seed: u64) void {
    var sn = arg_sn;
    _ = &sn;
    var dim = arg_dim;
    _ = &dim;
    var seed = arg_seed;
    _ = &seed;
    var s: u64 = undefined;
    _ = &s;
    setSeed(&s, seed);
    octaveInit(&sn.*.octmin, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&sn.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 0))))), -@as(c_int, 15), @as(c_int, 16));
    octaveInit(&sn.*.octmax, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&sn.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 16))))), -@as(c_int, 15), @as(c_int, 16));
    octaveInit(&sn.*.octmain, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&sn.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 32))))), -@as(c_int, 7), @as(c_int, 8));
    if (dim == DIM_END) {
        sn.*.xzScale = 2.0;
        sn.*.yScale = 1.0;
        sn.*.xzFactor = 80;
        sn.*.yFactor = 160;
    } else {
        octaveInit(&sn.*.octsurf, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&sn.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 40))))), -@as(c_int, 3), @as(c_int, 4));
        skipNextN(&s, @as(u64, @bitCast(@as(c_long, @as(c_int, 262) * @as(c_int, 10)))));
        octaveInit(&sn.*.octdepth, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&sn.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 44))))), -@as(c_int, 15), @as(c_int, 16));
        sn.*.xzScale = 0.9999999814507745;
        sn.*.yScale = 0.9999999814507745;
        sn.*.xzFactor = 80;
        sn.*.yFactor = 160;
    }
}
pub fn initSurfaceNoiseBeta(arg_snb: [*c]SurfaceNoiseBeta, arg_seed: u64) void {
    var snb = arg_snb;
    _ = &snb;
    var seed = arg_seed;
    _ = &seed;
    var s: u64 = undefined;
    _ = &s;
    setSeed(&s, seed);
    octaveInitBeta(&snb.*.octmin, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&snb.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 0))))), @as(c_int, 16), 684.412, 0.5, 1.0, 2.0);
    octaveInitBeta(&snb.*.octmax, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&snb.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 16))))), @as(c_int, 16), 684.412, 0.5, 1.0, 2.0);
    octaveInitBeta(&snb.*.octmain, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&snb.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 32))))), @as(c_int, 8), 684.412 / 80.0, 0.5, 1.0, 2.0);
    skipNextN(&s, @as(u64, @bitCast(@as(c_long, @as(c_int, 262) * @as(c_int, 8)))));
    octaveInitBeta(&snb.*.octcontA, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&snb.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 40))))), @as(c_int, 10), 1.121, 0.5, 1.0, 2.0);
    octaveInitBeta(&snb.*.octcontB, &s, @as([*c]PerlinNoise, @ptrCast(@alignCast(&snb.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 50))))), @as(c_int, 16), 200.0, 0.5, 1.0, 2.0);
}
pub fn sampleSurfaceNoise(arg_sn: [*c]const SurfaceNoise, arg_x: c_int, arg_y: c_int, arg_z: c_int) f64 {
    var sn = arg_sn;
    _ = &sn;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var xzScale: f64 = 684.412 * sn.*.xzScale;
    _ = &xzScale;
    var yScale: f64 = 684.412 * sn.*.yScale;
    _ = &yScale;
    var xzStep: f64 = xzScale / sn.*.xzFactor;
    _ = &xzStep;
    var yStep: f64 = yScale / sn.*.yFactor;
    _ = &yStep;
    var minNoise: f64 = 0;
    _ = &minNoise;
    var maxNoise: f64 = 0;
    _ = &maxNoise;
    var mainNoise: f64 = 0;
    _ = &mainNoise;
    var persist: f64 = 1.0;
    _ = &persist;
    var contrib: f64 = 1.0;
    _ = &contrib;
    var dx: f64 = undefined;
    _ = &dx;
    var dy: f64 = undefined;
    _ = &dy;
    var dz: f64 = undefined;
    _ = &dz;
    var sy: f64 = undefined;
    _ = &sy;
    var ty: f64 = undefined;
    _ = &ty;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < @as(c_int, 16)) : (i += 1) {
            dx = maintainPrecision((@as(f64, @floatFromInt(x)) * xzScale) * persist);
            dy = maintainPrecision((@as(f64, @floatFromInt(y)) * yScale) * persist);
            dz = maintainPrecision((@as(f64, @floatFromInt(z)) * xzScale) * persist);
            sy = yScale * persist;
            ty = @as(f64, @floatFromInt(y)) * sy;
            minNoise += samplePerlin(&(blk: {
                const tmp = i;
                if (tmp >= 0) break :blk sn.*.octmin.octaves + @as(usize, @intCast(tmp)) else break :blk sn.*.octmin.octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, dx, dy, dz, sy, ty) * contrib;
            maxNoise += samplePerlin(&(blk: {
                const tmp = i;
                if (tmp >= 0) break :blk sn.*.octmax.octaves + @as(usize, @intCast(tmp)) else break :blk sn.*.octmax.octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, dx, dy, dz, sy, ty) * contrib;
            if (i < @as(c_int, 8)) {
                dx = maintainPrecision((@as(f64, @floatFromInt(x)) * xzStep) * persist);
                dy = maintainPrecision((@as(f64, @floatFromInt(y)) * yStep) * persist);
                dz = maintainPrecision((@as(f64, @floatFromInt(z)) * xzStep) * persist);
                sy = yStep * persist;
                ty = @as(f64, @floatFromInt(y)) * sy;
                mainNoise += samplePerlin(&(blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk sn.*.octmain.octaves + @as(usize, @intCast(tmp)) else break :blk sn.*.octmain.octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*, dx, dy, dz, sy, ty) * contrib;
            }
            persist *= 0.5;
            contrib *= 2.0;
        }
    }
    return clampedLerp(0.5 + (0.05 * mainNoise), minNoise / 512.0, maxNoise / 512.0);
}
pub fn sampleSurfaceNoiseBetween(arg_sn: [*c]const SurfaceNoise, arg_x: c_int, arg_y: c_int, arg_z: c_int, arg_noiseMin: f64, arg_noiseMax: f64) f64 {
    var sn = arg_sn;
    _ = &sn;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var noiseMin = arg_noiseMin;
    _ = &noiseMin;
    var noiseMax = arg_noiseMax;
    _ = &noiseMax;
    var persist: f64 = undefined;
    _ = &persist;
    var amp: f64 = undefined;
    _ = &amp;
    var dx: f64 = undefined;
    _ = &dx;
    var dy: f64 = undefined;
    _ = &dy;
    var dz: f64 = undefined;
    _ = &dz;
    var sy: f64 = undefined;
    _ = &sy;
    var i: c_int = undefined;
    _ = &i;
    var xzScale: f64 = 684.412 * sn.*.xzScale;
    _ = &xzScale;
    var yScale: f64 = 684.412 * sn.*.yScale;
    _ = &yScale;
    var vmin: f64 = 0;
    _ = &vmin;
    var vmax: f64 = 0;
    _ = &vmax;
    persist = 1.0 / 32768.0;
    amp = 64.0;
    {
        i = 15;
        while (i >= @as(c_int, 0)) : (i -= 1) {
            dx = (@as(f64, @floatFromInt(x)) * xzScale) * persist;
            dz = (@as(f64, @floatFromInt(z)) * xzScale) * persist;
            sy = yScale * persist;
            dy = @as(f64, @floatFromInt(y)) * sy;
            vmin += samplePerlin(&(blk: {
                const tmp = i;
                if (tmp >= 0) break :blk sn.*.octmin.octaves + @as(usize, @intCast(tmp)) else break :blk sn.*.octmin.octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, dx, dy, dz, sy, dy) * amp;
            vmax += samplePerlin(&(blk: {
                const tmp = i;
                if (tmp >= 0) break :blk sn.*.octmax.octaves + @as(usize, @intCast(tmp)) else break :blk sn.*.octmax.octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, dx, dy, dz, sy, dy) * amp;
            if (((vmin - amp) > noiseMax) and ((vmax - amp) > noiseMax)) return noiseMax;
            if (((vmin + amp) < noiseMin) and ((vmax + amp) < noiseMin)) return noiseMin;
            amp *= 0.5;
            persist *= 2.0;
        }
    }
    var xzStep: f64 = xzScale / sn.*.xzFactor;
    _ = &xzStep;
    var yStep: f64 = yScale / sn.*.yFactor;
    _ = &yStep;
    var vmain: f64 = 0.5;
    _ = &vmain;
    persist = 1.0 / 128.0;
    amp = 0.05 * 128.0;
    {
        i = 7;
        while (i >= @as(c_int, 0)) : (i -= 1) {
            dx = (@as(f64, @floatFromInt(x)) * xzStep) * persist;
            dz = (@as(f64, @floatFromInt(z)) * xzStep) * persist;
            sy = yStep * persist;
            dy = @as(f64, @floatFromInt(y)) * sy;
            vmain += samplePerlin(&(blk: {
                const tmp = i;
                if (tmp >= 0) break :blk sn.*.octmain.octaves + @as(usize, @intCast(tmp)) else break :blk sn.*.octmain.octaves - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, dx, dy, dz, sy, dy) * amp;
            if ((vmain - amp) > @as(f64, @floatFromInt(@as(c_int, 1)))) return vmax;
            if ((vmain + amp) < @as(f64, @floatFromInt(@as(c_int, 0)))) return vmin;
            amp *= 0.5;
            persist *= 2.0;
        }
    }
    return clampedLerp(vmain, vmin, vmax);
}
pub fn setNetherSeed(arg_nn: [*c]NetherNoise, arg_seed: u64) void {
    var nn = arg_nn;
    _ = &nn;
    var seed = arg_seed;
    _ = &seed;
    var s: u64 = undefined;
    _ = &s;
    setSeed(&s, seed);
    doublePerlinInit(&nn.*.temperature, &s, &nn.*.oct[@as(c_uint, @intCast(@as(c_int, 0)))], &nn.*.oct[@as(c_uint, @intCast(@as(c_int, 2)))], -@as(c_int, 7), @as(c_int, 2));
    setSeed(&s, seed +% @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))));
    doublePerlinInit(&nn.*.humidity, &s, &nn.*.oct[@as(c_uint, @intCast(@as(c_int, 4)))], &nn.*.oct[@as(c_uint, @intCast(@as(c_int, 6)))], -@as(c_int, 7), @as(c_int, 2));
}
pub fn getNetherBiome(arg_nn: [*c]const NetherNoise, arg_x: c_int, arg_y: c_int, arg_z: c_int, arg_ndel: [*c]f32) c_int {
    var nn = arg_nn;
    _ = &nn;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var ndel = arg_ndel;
    _ = &ndel;
    const npoints: [5][4]f32 = [5][4]f32{
        [4]f32{
            0,
            0,
            0,
            @as(f32, @floatFromInt(nether_wastes)),
        },
        [4]f32{
            0,
            @as(f32, @floatCast(-0.5)),
            0,
            @as(f32, @floatFromInt(soul_sand_valley)),
        },
        [4]f32{
            @as(f32, @floatCast(0.4)),
            0,
            0,
            @as(f32, @floatFromInt(crimson_forest)),
        },
        [4]f32{
            0,
            @as(f32, @floatCast(0.5)),
            @as(f32, @floatCast(0.375 * 0.375)),
            @as(f32, @floatFromInt(warped_forest)),
        },
        [4]f32{
            @as(f32, @floatCast(-0.5)),
            0,
            @as(f32, @floatCast(0.175 * 0.175)),
            @as(f32, @floatFromInt(basalt_deltas)),
        },
    };
    _ = &npoints;
    y = 0;
    var temp: f32 = @as(f32, @floatCast(sampleDoublePerlin(&nn.*.temperature, @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(y)), @as(f64, @floatFromInt(z)))));
    _ = &temp;
    var humidity: f32 = @as(f32, @floatCast(sampleDoublePerlin(&nn.*.humidity, @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(y)), @as(f64, @floatFromInt(z)))));
    _ = &humidity;
    var i: c_int = undefined;
    _ = &i;
    var id: c_int = 0;
    _ = &id;
    var dmin: f32 = 340282346638528860000000000000000000000.0;
    _ = &dmin;
    var dmin2: f32 = 340282346638528860000000000000000000000.0;
    _ = &dmin2;
    {
        i = 0;
        while (i < @as(c_int, 5)) : (i += 1) {
            var dx: f32 = npoints[@as(c_uint, @intCast(i))][@as(c_uint, @intCast(@as(c_int, 0)))] - temp;
            _ = &dx;
            var dy: f32 = npoints[@as(c_uint, @intCast(i))][@as(c_uint, @intCast(@as(c_int, 1)))] - humidity;
            _ = &dy;
            var dsq: f32 = ((dx * dx) + (dy * dy)) + npoints[@as(c_uint, @intCast(i))][@as(c_uint, @intCast(@as(c_int, 2)))];
            _ = &dsq;
            if (dsq < dmin) {
                dmin2 = dmin;
                dmin = dsq;
                id = i;
            } else if (dsq < dmin2) {
                dmin2 = dsq;
            }
        }
    }
    if (ndel != null) {
        ndel.* = sqrtf(dmin2) - sqrtf(dmin);
    }
    id = @as(c_int, @intFromFloat(npoints[@as(c_uint, @intCast(id))][@as(c_uint, @intCast(@as(c_int, 3)))]));
    return id;
}
pub fn mapNether3D(arg_nn: [*c]const NetherNoise, arg_out: [*c]c_int, arg_r: Range, arg_confidence: f32) c_int {
    var nn = arg_nn;
    _ = &nn;
    var out = arg_out;
    _ = &out;
    var r = arg_r;
    _ = &r;
    var confidence = arg_confidence;
    _ = &confidence;
    var i: i64 = undefined;
    _ = &i;
    var j: i64 = undefined;
    _ = &j;
    var k: i64 = undefined;
    _ = &k;
    if (r.sy <= @as(c_int, 0)) {
        r.sy = 1;
    }
    if (r.scale <= @as(c_int, 3)) {
        _ = printf("mapNether3D() invalid scale for this function\n");
        return 1;
    }
    var scale: c_int = @divTrunc(r.scale, @as(c_int, 4));
    _ = &scale;
    _ = memset(@as(?*anyopaque, @ptrCast(out)), @as(c_int, 0), ((@sizeOf(c_int) *% @as(c_ulong, @bitCast(@as(c_long, r.sx)))) *% @as(c_ulong, @bitCast(@as(c_long, r.sy)))) *% @as(c_ulong, @bitCast(@as(c_long, r.sz))));
    var invgrad: f32 = @as(f32, @floatCast((1.0 / ((@as(f64, @floatCast(confidence)) * 0.05) * @as(f64, @floatFromInt(@as(c_int, 2))))) / @as(f64, @floatFromInt(scale))));
    _ = &invgrad;
    {
        k = 0;
        while (k < @as(i64, @bitCast(@as(c_long, r.sy)))) : (k += 1) {
            var yout: [*c]c_int = &(blk: {
                const tmp = (k * @as(i64, @bitCast(@as(c_long, r.sx)))) * @as(i64, @bitCast(@as(c_long, r.sz)));
                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &yout;
            {
                j = 0;
                while (j < @as(i64, @bitCast(@as(c_long, r.sz)))) : (j += 1) {
                    {
                        i = 0;
                        while (i < @as(i64, @bitCast(@as(c_long, r.sx)))) : (i += 1) {
                            if ((blk: {
                                const tmp = (j * @as(i64, @bitCast(@as(c_long, r.sx)))) + i;
                                if (tmp >= 0) break :blk yout + @as(usize, @intCast(tmp)) else break :blk yout - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* != 0) continue;
                            var noisedelta: f32 = undefined;
                            _ = &noisedelta;
                            var xi: c_int = @as(c_int, @bitCast(@as(c_int, @truncate((@as(i64, @bitCast(@as(c_long, r.x))) + i) * @as(i64, @bitCast(@as(c_long, scale)))))));
                            _ = &xi;
                            var yk: c_int = @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(@as(c_long, r.y))) + k))));
                            _ = &yk;
                            var zj: c_int = @as(c_int, @bitCast(@as(c_int, @truncate((@as(i64, @bitCast(@as(c_long, r.z))) + j) * @as(i64, @bitCast(@as(c_long, scale)))))));
                            _ = &zj;
                            var v: c_int = getNetherBiome(nn, xi, yk, zj, &noisedelta);
                            _ = &v;
                            (blk: {
                                const tmp = (j * @as(i64, @bitCast(@as(c_long, r.sx)))) + i;
                                if (tmp >= 0) break :blk yout + @as(usize, @intCast(tmp)) else break :blk yout - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = v;
                            var cellrad: f32 = noisedelta * invgrad;
                            _ = &cellrad;
                            fillRad3D(out, @as(c_int, @bitCast(@as(c_int, @truncate(i)))), @as(c_int, @bitCast(@as(c_int, @truncate(j)))), @as(c_int, @bitCast(@as(c_int, @truncate(k)))), r.sx, r.sy, r.sz, v, cellrad);
                        }
                    }
                }
            }
        }
    }
    return 0;
}
pub fn genNetherScaled(arg_nn: [*c]const NetherNoise, arg_out: [*c]c_int, arg_r: Range, arg_mc: c_int, arg_sha: u64) c_int {
    var nn = arg_nn;
    _ = &nn;
    var out = arg_out;
    _ = &out;
    var r = arg_r;
    _ = &r;
    var mc = arg_mc;
    _ = &mc;
    var sha = arg_sha;
    _ = &sha;
    if (r.scale <= @as(c_int, 0)) {
        r.scale = 4;
    }
    if (r.sy == @as(c_int, 0)) {
        r.sy = 1;
    }
    var siz: u64 = (@as(u64, @bitCast(@as(c_long, r.sx))) *% @as(u64, @bitCast(@as(c_long, r.sy)))) *% @as(u64, @bitCast(@as(c_long, r.sz)));
    _ = &siz;
    if (mc <= MC_1_15) {
        var i: u64 = undefined;
        _ = &i;
        {
            i = 0;
            while (i < siz) : (i +%= 1) {
                out[i] = nether_wastes;
            }
        }
        return 0;
    }
    if (r.scale == @as(c_int, 1)) {
        var s: Range = getVoronoiSrcRange(r);
        _ = &s;
        var src: [*c]c_int = undefined;
        _ = &src;
        if (siz > @as(u64, @bitCast(@as(c_long, @as(c_int, 1))))) {
            src = out + siz;
            var err: c_int = mapNether3D(nn, src, s, @as(f32, @floatCast(1.0)));
            _ = &err;
            if (err != 0) return err;
        } else {
            src = null;
        }
        var i: c_int = undefined;
        _ = &i;
        var j: c_int = undefined;
        _ = &j;
        var k: c_int = undefined;
        _ = &k;
        var p: [*c]c_int = out;
        _ = &p;
        {
            k = 0;
            while (k < r.sy) : (k += 1) {
                {
                    j = 0;
                    while (j < r.sz) : (j += 1) {
                        {
                            i = 0;
                            while (i < r.sx) : (i += 1) {
                                var x4: c_int = undefined;
                                _ = &x4;
                                var z4: c_int = undefined;
                                _ = &z4;
                                var y4: c_int = undefined;
                                _ = &y4;
                                voronoiAccess3D(sha, r.x + i, r.y + k, r.z + j, &x4, &y4, &z4);
                                if (src != null) {
                                    x4 -= s.x;
                                    y4 -= s.y;
                                    z4 -= s.z;
                                    p.* = (blk: {
                                        const tmp = (((@as(i64, @bitCast(@as(c_long, y4))) * @as(i64, @bitCast(@as(c_long, s.sx)))) * @as(i64, @bitCast(@as(c_long, s.sz)))) + (@as(i64, @bitCast(@as(c_long, z4))) * @as(i64, @bitCast(@as(c_long, s.sx))))) + @as(i64, @bitCast(@as(c_long, x4)));
                                        if (tmp >= 0) break :blk src + @as(usize, @intCast(tmp)) else break :blk src - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).*;
                                } else {
                                    p.* = getNetherBiome(nn, x4, y4, z4, null);
                                }
                                p += 1;
                            }
                        }
                    }
                }
            }
        }
        return 0;
    } else {
        return mapNether3D(nn, out, r, @as(f32, @floatCast(1.0)));
    }
    return 0;
}
pub fn setEndSeed(arg_en: [*c]EndNoise, arg_mc: c_int, arg_seed: u64) void {
    var en = arg_en;
    _ = &en;
    var mc = arg_mc;
    _ = &mc;
    var seed = arg_seed;
    _ = &seed;
    var s: u64 = undefined;
    _ = &s;
    setSeed(&s, seed);
    skipNextN(&s, @as(u64, @bitCast(@as(c_long, @as(c_int, 17292)))));
    perlinInit(&en.*.perlin, &s);
    en.*.mc = mc;
}
pub fn mapEndBiome(arg_en: [*c]const EndNoise, arg_out: [*c]c_int, arg_x: c_int, arg_z: c_int, arg_w: c_int, arg_h: c_int) c_int {
    var en = arg_en;
    _ = &en;
    var out = arg_out;
    _ = &out;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var w = arg_w;
    _ = &w;
    var h = arg_h;
    _ = &h;
    var i: i64 = undefined;
    _ = &i;
    var j: i64 = undefined;
    _ = &j;
    var hw: i64 = @as(i64, @bitCast(@as(c_long, w + @as(c_int, 26))));
    _ = &hw;
    var hh: i64 = @as(i64, @bitCast(@as(c_long, h + @as(c_int, 26))));
    _ = &hh;
    var hmap: [*c]u16 = @as([*c]u16, @ptrCast(@alignCast(malloc((@sizeOf(u16) *% @as(c_ulong, @bitCast(hw))) *% @as(c_ulong, @bitCast(hh))))));
    _ = &hmap;
    {
        j = 0;
        while (j < hh) : (j += 1) {
            {
                i = 0;
                while (i < hw) : (i += 1) {
                    var rx: i64 = (@as(i64, @bitCast(@as(c_long, x))) + i) - @as(i64, @bitCast(@as(c_long, @as(c_int, 12))));
                    _ = &rx;
                    var rz: i64 = (@as(i64, @bitCast(@as(c_long, z))) + j) - @as(i64, @bitCast(@as(c_long, @as(c_int, 12))));
                    _ = &rz;
                    var rsq: u64 = @as(u64, @bitCast((rx * rx) + (rz * rz)));
                    _ = &rsq;
                    var v: u16 = 0;
                    _ = &v;
                    if ((rsq > @as(u64, @bitCast(@as(c_long, @as(c_int, 4096))))) and (sampleSimplex2D(&en.*.perlin, @as(f64, @floatFromInt(rx)), @as(f64, @floatFromInt(rz))) < @as(f64, @floatCast(-0.8999999761581421)))) {
                        v = @as(u16, @bitCast(@as(c_ushort, @truncate((@as(c_uint, @intFromFloat((fabsf(@as(f32, @floatFromInt(rx))) * 3439.0) + (fabsf(@as(f32, @floatFromInt(rz))) * 147.0))) % @as(c_uint, @bitCast(@as(c_int, 13)))) +% @as(c_uint, @bitCast(@as(c_int, 9)))))));
                        v *%= @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, @bitCast(@as(c_uint, v)))))));
                    }
                    (blk: {
                        const tmp = (j * hw) + i;
                        if (tmp >= 0) break :blk hmap + @as(usize, @intCast(tmp)) else break :blk hmap - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = v;
                }
            }
        }
    }
    {
        j = 0;
        while (j < @as(i64, @bitCast(@as(c_long, h)))) : (j += 1) {
            {
                i = 0;
                while (i < @as(i64, @bitCast(@as(c_long, w)))) : (i += 1) {
                    var hx: i64 = i + @as(i64, @bitCast(@as(c_long, x)));
                    _ = &hx;
                    var hz: i64 = j + @as(i64, @bitCast(@as(c_long, z)));
                    _ = &hz;
                    var rsq: u64 = @as(u64, @bitCast((hx * hx) + (hz * hz)));
                    _ = &rsq;
                    if (rsq <= @as(u64, @bitCast(@as(c_long, 4096)))) {
                        (blk: {
                            const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                            if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = the_end;
                    } else {
                        hx = (@as(i64, @bitCast(@as(c_long, @as(c_int, 2)))) * hx) + @as(i64, @bitCast(@as(c_long, @as(c_int, 1))));
                        hz = (@as(i64, @bitCast(@as(c_long, @as(c_int, 2)))) * hz) + @as(i64, @bitCast(@as(c_long, @as(c_int, 1))));
                        if (en.*.mc > MC_1_13) {
                            rsq = @as(u64, @bitCast((hx * hx) + (hz * hz)));
                            if (@as(c_int, @bitCast(@as(c_uint, @truncate(rsq)))) < @as(c_int, 0)) {
                                (blk: {
                                    const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                                    if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                }).* = end_barrens;
                                continue;
                            }
                        }
                        var p_elev: [*c]u16 = &(blk: {
                            const tmp = ((@divTrunc(hz, @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))) - @as(i64, @bitCast(@as(c_long, z)))) * hw) + (@divTrunc(hx, @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))) - @as(i64, @bitCast(@as(c_long, x))));
                            if (tmp >= 0) break :blk hmap + @as(usize, @intCast(tmp)) else break :blk hmap - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*;
                        _ = &p_elev;
                        (blk: {
                            const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                            if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = getEndBiome(@as(c_int, @bitCast(@as(c_int, @truncate(hx)))), @as(c_int, @bitCast(@as(c_int, @truncate(hz)))), p_elev, @as(c_int, @bitCast(@as(c_int, @truncate(hw)))));
                    }
                }
            }
        }
    }
    free(@as(?*anyopaque, @ptrCast(hmap)));
    return 0;
}
pub fn mapEnd(arg_en: [*c]const EndNoise, arg_out: [*c]c_int, arg_x: c_int, arg_z: c_int, arg_w: c_int, arg_h: c_int) c_int {
    var en = arg_en;
    _ = &en;
    var out = arg_out;
    _ = &out;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var w = arg_w;
    _ = &w;
    var h = arg_h;
    _ = &h;
    var cx: c_int = x >> @intCast(2);
    _ = &cx;
    var cz: c_int = z >> @intCast(2);
    _ = &cz;
    var cw: i64 = @as(i64, @bitCast(@as(c_long, (((x + w) >> @intCast(2)) + @as(c_int, 1)) - cx)));
    _ = &cw;
    var ch: i64 = @as(i64, @bitCast(@as(c_long, (((z + h) >> @intCast(2)) + @as(c_int, 1)) - cz)));
    _ = &ch;
    var buf: [*c]c_int = @as([*c]c_int, @ptrCast(@alignCast(malloc((@sizeOf(c_int) *% @as(c_ulong, @bitCast(cw))) *% @as(c_ulong, @bitCast(ch))))));
    _ = &buf;
    _ = mapEndBiome(en, buf, cx, cz, @as(c_int, @bitCast(@as(c_int, @truncate(cw)))), @as(c_int, @bitCast(@as(c_int, @truncate(ch)))));
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    {
        j = 0;
        while (j < h) : (j += 1) {
            var cj: c_int = ((z + j) >> @intCast(2)) - cz;
            _ = &cj;
            {
                i = 0;
                while (i < w) : (i += 1) {
                    var ci: c_int = ((x + i) >> @intCast(2)) - cx;
                    _ = &ci;
                    var v: c_int = (blk: {
                        const tmp = (@as(i64, @bitCast(@as(c_long, cj))) * cw) + @as(i64, @bitCast(@as(c_long, ci)));
                        if (tmp >= 0) break :blk buf + @as(usize, @intCast(tmp)) else break :blk buf - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*;
                    _ = &v;
                    (blk: {
                        const tmp = (j * w) + i;
                        if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = v;
                }
            }
        }
    }
    free(@as(?*anyopaque, @ptrCast(buf)));
    return 0;
}
pub fn mapEndSurfaceHeight(arg_y: [*c]f32, arg_en: [*c]const EndNoise, arg_sn: [*c]const SurfaceNoise, arg_x: c_int, arg_z: c_int, arg_w: c_int, arg_h: c_int, arg_scale: c_int, arg_ymin: c_int) c_int {
    var y = arg_y;
    _ = &y;
    var en = arg_en;
    _ = &en;
    var sn = arg_sn;
    _ = &sn;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var w = arg_w;
    _ = &w;
    var h = arg_h;
    _ = &h;
    var scale = arg_scale;
    _ = &scale;
    var ymin = arg_ymin;
    _ = &ymin;
    if ((((scale != @as(c_int, 1)) and (scale != @as(c_int, 2))) and (scale != @as(c_int, 4))) and (scale != @as(c_int, 8))) return 1;
    var y0_1: c_int = ymin >> @intCast(2);
    _ = &y0_1;
    if (y0_1 < @as(c_int, 2)) {
        y0_1 = 2;
    }
    if (y0_1 > @as(c_int, 17)) {
        y0_1 = 17;
    }
    var y1_2: c_int = 18;
    _ = &y1_2;
    var yn_3: c_int = (y1_2 - y0_1) + @as(c_int, 1);
    _ = &yn_3;
    var cellmid: f64 = if (scale > @as(c_int, 1)) @as(f64, @floatFromInt(scale)) / 16.0 else @as(f64, @floatFromInt(@as(c_int, 0)));
    _ = &cellmid;
    var cellsiz: c_int = @divTrunc(@as(c_int, 8), scale);
    _ = &cellsiz;
    var cx: c_int = floordiv(x, cellsiz);
    _ = &cx;
    var cz: c_int = floordiv(z, cellsiz);
    _ = &cz;
    var cw: c_int = (floordiv((x + w) - @as(c_int, 1), cellsiz) - cx) + @as(c_int, 2);
    _ = &cw;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var buf: [*c]f64 = @as([*c]f64, @ptrCast(@alignCast(malloc(((@sizeOf(f64) *% @as(c_ulong, @bitCast(@as(c_long, yn_3)))) *% @as(c_ulong, @bitCast(@as(c_long, cw)))) *% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 2))))))));
    _ = &buf;
    var ncol: [2][*c]f64 = undefined;
    _ = &ncol;
    ncol[@as(c_uint, @intCast(@as(c_int, 0)))] = buf;
    ncol[@as(c_uint, @intCast(@as(c_int, 1)))] = buf + @as(usize, @bitCast(@as(isize, @intCast(yn_3 * cw))));
    {
        i = 0;
        while (i < cw) : (i += 1) {
            sampleNoiseColumnEnd(ncol[@as(c_uint, @intCast(@as(c_int, 1)))] + @as(usize, @bitCast(@as(isize, @intCast(i * yn_3)))), sn, en, cx + i, cz + @as(c_int, 0), y0_1, y1_2);
        }
    }
    {
        j = 0;
        while (j < h) : (j += 1) {
            var cj: c_int = floordiv(z + j, cellsiz);
            _ = &cj;
            var dj: c_int = (z + j) - (cj * cellsiz);
            _ = &dj;
            if ((j == @as(c_int, 0)) or (dj == @as(c_int, 0))) {
                var tmp: [*c]f64 = ncol[@as(c_uint, @intCast(@as(c_int, 0)))];
                _ = &tmp;
                ncol[@as(c_uint, @intCast(@as(c_int, 0)))] = ncol[@as(c_uint, @intCast(@as(c_int, 1)))];
                ncol[@as(c_uint, @intCast(@as(c_int, 1)))] = tmp;
                {
                    i = 0;
                    while (i < cw) : (i += 1) {
                        sampleNoiseColumnEnd(ncol[@as(c_uint, @intCast(@as(c_int, 1)))] + @as(usize, @bitCast(@as(isize, @intCast(i * yn_3)))), sn, en, cx + i, cj + @as(c_int, 1), y0_1, y1_2);
                    }
                }
            }
            {
                i = 0;
                while (i < w) : (i += 1) {
                    var ci: c_int = floordiv(x + i, cellsiz);
                    _ = &ci;
                    var di: c_int = (x + i) - (ci * cellsiz);
                    _ = &di;
                    var dx: f64 = (@as(f64, @floatFromInt(di)) / @as(f64, @floatFromInt(cellsiz))) + cellmid;
                    _ = &dx;
                    var dz: f64 = (@as(f64, @floatFromInt(dj)) / @as(f64, @floatFromInt(cellsiz))) + cellmid;
                    _ = &dz;
                    var ncol0: [*c]f64 = ncol[@as(c_uint, @intCast(@as(c_int, 0)))] + @as(usize, @bitCast(@as(isize, @intCast((ci - cx) * yn_3))));
                    _ = &ncol0;
                    var ncol1: [*c]f64 = ncol[@as(c_uint, @intCast(@as(c_int, 1)))] + @as(usize, @bitCast(@as(isize, @intCast((ci - cx) * yn_3))));
                    _ = &ncol1;
                    (blk: {
                        const tmp = (j * w) + i;
                        if (tmp >= 0) break :blk y + @as(usize, @intCast(tmp)) else break :blk y - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = @as(f32, @floatFromInt(getSurfaceHeight(ncol0, ncol1, ncol0 + @as(usize, @bitCast(@as(isize, @intCast(yn_3)))), ncol1 + @as(usize, @bitCast(@as(isize, @intCast(yn_3)))), y0_1, y1_2, @as(c_int, 4), dx, dz)));
                }
            }
        }
    }
    free(@as(?*anyopaque, @ptrCast(buf)));
    return 0;
}
pub fn genEndScaled(arg_en: [*c]const EndNoise, arg_out: [*c]c_int, arg_r: Range, arg_mc: c_int, arg_sha: u64) c_int {
    var en = arg_en;
    _ = &en;
    var out = arg_out;
    _ = &out;
    var r = arg_r;
    _ = &r;
    var mc = arg_mc;
    _ = &mc;
    var sha = arg_sha;
    _ = &sha;
    if (mc < MC_1_0) return 1;
    if (r.sy == @as(c_int, 0)) {
        r.sy = 1;
    }
    if (mc <= MC_1_8) {
        var i: u64 = undefined;
        _ = &i;
        var siz: u64 = (@as(u64, @bitCast(@as(c_long, r.sx))) *% @as(u64, @bitCast(@as(c_long, r.sy)))) *% @as(u64, @bitCast(@as(c_long, r.sz)));
        _ = &siz;
        {
            i = 0;
            while (i < siz) : (i +%= 1) {
                out[i] = the_end;
            }
        }
        return 0;
    }
    var err: c_int = undefined;
    _ = &err;
    var iy: c_int = undefined;
    _ = &iy;
    if (r.scale == @as(c_int, 1)) {
        var s: Range = getVoronoiSrcRange(r);
        _ = &s;
        err = mapEnd(en, out, s.x, s.z, s.sx, s.sz);
        if (err != 0) return err;
        if (mc <= MC_1_14) {
            var lvoronoi: Layer = undefined;
            _ = &lvoronoi;
            _ = memset(@as(?*anyopaque, @ptrCast(&lvoronoi)), @as(c_int, 0), @sizeOf(Layer));
            lvoronoi.startSalt = getLayerSalt(@as(u64, @bitCast(@as(c_long, @as(c_int, 10)))));
            err = mapVoronoi114(&lvoronoi, out, r.x, r.z, r.sx, r.sz);
            if (err != 0) return err;
        } else {
            var src: [*c]c_int = out + @as(usize, @bitCast(@as(isize, @intCast((@as(i64, @bitCast(@as(c_long, r.sx))) * @as(i64, @bitCast(@as(c_long, r.sy)))) * @as(i64, @bitCast(@as(c_long, r.sz)))))));
            _ = &src;
            _ = memmove(@as(?*anyopaque, @ptrCast(src)), @as(?*const anyopaque, @ptrCast(out)), (@sizeOf(c_int) *% @as(c_ulong, @bitCast(@as(c_long, s.sx)))) *% @as(c_ulong, @bitCast(@as(c_long, s.sz))));
            {
                iy = 0;
                while (iy < r.sy) : (iy += 1) {
                    mapVoronoiPlane(sha, out + @as(usize, @bitCast(@as(isize, @intCast((r.sx * r.sz) * iy)))), src, r.x, r.z, r.sx, r.sz, r.y + iy, s.x, s.z, s.sx, s.sz);
                }
            }
            return 0;
        }
    } else if (r.scale == @as(c_int, 4)) {
        err = mapEnd(en, out, r.x, r.z, r.sx, r.sz);
        if (err != 0) return err;
    } else if (r.scale == @as(c_int, 16)) {
        err = mapEndBiome(en, out, r.x, r.z, r.sx, r.sz);
        if (err != 0) return err;
    } else {
        var d: f32 = @as(f32, @floatCast(@as(f64, @floatFromInt(r.scale)) / 8.0));
        _ = &d;
        var i: c_int = undefined;
        _ = &i;
        var j: c_int = undefined;
        _ = &j;
        {
            j = 0;
            while (j < r.sz) : (j += 1) {
                {
                    i = 0;
                    while (i < r.sx) : (i += 1) {
                        var hx: i64 = @as(i64, @intFromFloat(@as(f32, @floatFromInt(i + r.x)) * d));
                        _ = &hx;
                        var hz: i64 = @as(i64, @intFromFloat(@as(f32, @floatFromInt(j + r.z)) * d));
                        _ = &hz;
                        var rsq: u64 = @as(u64, @bitCast((hx * hx) + (hz * hz)));
                        _ = &rsq;
                        if (rsq <= @as(u64, @bitCast(@as(c_long, 16384)))) {
                            (blk: {
                                const tmp = (j * r.sx) + i;
                                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = the_end;
                            continue;
                        } else if ((mc > MC_1_13) and (@as(c_int, @bitCast(@as(c_uint, @truncate(rsq)))) < @as(c_int, 0))) {
                            (blk: {
                                const tmp = (j * r.sx) + i;
                                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = end_barrens;
                            continue;
                        }
                        var h: f32 = getEndHeightNoise(en, @as(c_int, @bitCast(@as(c_int, @truncate(hx)))), @as(c_int, @bitCast(@as(c_int, @truncate(hz)))), @as(c_int, 4));
                        _ = &h;
                        if (h > @as(f32, @floatFromInt(@as(c_int, 40)))) {
                            (blk: {
                                const tmp = (j * r.sx) + i;
                                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = end_highlands;
                        } else if (h >= @as(f32, @floatFromInt(@as(c_int, 0)))) {
                            (blk: {
                                const tmp = (j * r.sx) + i;
                                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = end_midlands;
                        } else if (h >= @as(f32, @floatFromInt(-@as(c_int, 20)))) {
                            (blk: {
                                const tmp = (j * r.sx) + i;
                                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = end_barrens;
                        } else {
                            (blk: {
                                const tmp = (j * r.sx) + i;
                                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = small_end_islands;
                        }
                    }
                }
            }
        }
    }
    {
        iy = 1;
        while (iy < r.sy) : (iy += 1) {
            var i: i64 = undefined;
            _ = &i;
            var siz: i64 = @as(i64, @bitCast(@as(c_long, r.sx))) * @as(i64, @bitCast(@as(c_long, r.sz)));
            _ = &siz;
            {
                i = 0;
                while (i < siz) : (i += 1) {
                    (blk: {
                        const tmp = (@as(i64, @bitCast(@as(c_long, iy))) * siz) + i;
                        if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = (blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*;
                }
            }
        }
    }
    return 0;
}
pub const SAMPLE_NO_SHIFT: c_int = 1;
pub const SAMPLE_NO_DEPTH: c_int = 2;
pub const SAMPLE_NO_BIOME: c_int = 4;
pub fn initBiomeNoise(arg_bn: [*c]BiomeNoise, arg_mc: c_int) void {
    var bn = arg_bn;
    _ = &bn;
    var mc = arg_mc;
    _ = &mc;
    var ss: [*c]SplineStack = &bn.*.ss;
    _ = &ss;
    _ = memset(@as(?*anyopaque, @ptrCast(ss)), @as(c_int, 0), @sizeOf(SplineStack));
    var sp: [*c]Spline = &ss.*.stack[@as(c_uint, @intCast(blk: {
            const ref = &ss.*.len;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))];
    _ = &sp;
    sp.*.typ = SP_CONTINENTALNESS;
    var sp1: [*c]Spline = createLandSpline(ss, -0.15000000596046448, 0.0, 0.0, 0.10000000149011612, 0.0, -0.029999999329447746, @as(c_int, 0));
    _ = &sp1;
    var sp2: [*c]Spline = createLandSpline(ss, -0.10000000149011612, 0.029999999329447746, 0.10000000149011612, 0.10000000149011612, 0.009999999776482582, -0.029999999329447746, @as(c_int, 0));
    _ = &sp2;
    var sp3: [*c]Spline = createLandSpline(ss, -0.10000000149011612, 0.029999999329447746, 0.10000000149011612, 0.699999988079071, 0.009999999776482582, -0.029999999329447746, @as(c_int, 1));
    _ = &sp3;
    var sp4: [*c]Spline = createLandSpline(ss, -0.05000000074505806, 0.029999999329447746, 0.10000000149011612, 1.0, 0.009999999776482582, 0.009999999776482582, @as(c_int, 1));
    _ = &sp4;
    addSplineVal(sp, -1.100000023841858, createFixSpline(ss, 0.04399999976158142), 0.0);
    addSplineVal(sp, -1.0199999809265137, createFixSpline(ss, -0.22220000624656677), 0.0);
    addSplineVal(sp, -0.5099999904632568, createFixSpline(ss, -0.22220000624656677), 0.0);
    addSplineVal(sp, -0.4399999976158142, createFixSpline(ss, -0.11999999731779099), 0.0);
    addSplineVal(sp, -0.18000000715255737, createFixSpline(ss, -0.11999999731779099), 0.0);
    addSplineVal(sp, -0.1599999964237213, sp1, 0.0);
    addSplineVal(sp, -0.15000000596046448, sp1, 0.0);
    addSplineVal(sp, -0.10000000149011612, sp2, 0.0);
    addSplineVal(sp, 0.25, sp3, 0.0);
    addSplineVal(sp, 1.0, sp4, 0.0);
    bn.*.sp = sp;
    bn.*.mc = mc;
}
pub fn setBiomeSeed(arg_bn: [*c]BiomeNoise, arg_seed: u64, arg_large: c_int) void {
    var bn = arg_bn;
    _ = &bn;
    var seed = arg_seed;
    _ = &seed;
    var large = arg_large;
    _ = &large;
    var pxr: Xoroshiro = undefined;
    _ = &pxr;
    xSetSeed(&pxr, seed);
    var xlo: u64 = xNextLong(&pxr);
    _ = &xlo;
    var xhi: u64 = xNextLong(&pxr);
    _ = &xhi;
    var n: c_int = 0;
    _ = &n;
    var i: c_int = 0;
    _ = &i;
    while (i < NP_MAX) : (i += 1) {
        n += init_climate_seed(&bn.*.climate[@as(c_uint, @intCast(i))], @as([*c]PerlinNoise, @ptrCast(@alignCast(&bn.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(n)))), xlo, xhi, large, i, -@as(c_int, 1));
    }
    if (@as(usize, @bitCast(@as(c_long, n))) > (@sizeOf([46]PerlinNoise) / @sizeOf(PerlinNoise))) {
        _ = printf("setBiomeSeed(): BiomeNoise is malformed, buffer too small\n");
        exit(@as(c_int, 1));
    }
    bn.*.nptype = -@as(c_int, 1);
}
pub fn setBetaBiomeSeed(arg_bnb: [*c]BiomeNoiseBeta, arg_seed: u64) void {
    var bnb = arg_bnb;
    _ = &bnb;
    var seed = arg_seed;
    _ = &seed;
    var seedScratch: u64 = undefined;
    _ = &seedScratch;
    setSeed(&seedScratch, seed *% @as(u64, @bitCast(@as(c_long, @as(c_int, 9871)))));
    octaveInitBeta(@as([*c]OctaveNoise, @ptrCast(@alignCast(&bnb.*.climate))), &seedScratch, @as([*c]PerlinNoise, @ptrCast(@alignCast(&bnb.*.oct))), @as(c_int, 4), 0.025 / 1.5, 0.25, 0.55, 2.0);
    setSeed(&seedScratch, seed *% @as(u64, @bitCast(@as(c_long, @as(c_int, 39811)))));
    octaveInitBeta(@as([*c]OctaveNoise, @ptrCast(@alignCast(&bnb.*.climate))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1))))), &seedScratch, @as([*c]PerlinNoise, @ptrCast(@alignCast(&bnb.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 4))))), @as(c_int, 4), 0.05 / 1.5, 1.0 / @as(f64, @floatFromInt(@as(c_int, 3))), 0.55, 2.0);
    setSeed(&seedScratch, seed *% @as(u64, @bitCast(@as(c_long, 543321))));
    octaveInitBeta(@as([*c]OctaveNoise, @ptrCast(@alignCast(&bnb.*.climate))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2))))), &seedScratch, @as([*c]PerlinNoise, @ptrCast(@alignCast(&bnb.*.oct))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 8))))), @as(c_int, 2), 0.25 / 1.5, 10.0 / @as(f64, @floatFromInt(@as(c_int, 17))), 0.55, 2.0);
    bnb.*.nptype = -@as(c_int, 1);
}
pub fn sampleBiomeNoise(arg_bn: [*c]const BiomeNoise, arg_np: [*c]i64, arg_x: c_int, arg_y: c_int, arg_z: c_int, arg_dat: [*c]u64, arg_sample_flags: u32) c_int {
    var bn = arg_bn;
    _ = &bn;
    var np = arg_np;
    _ = &np;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var dat = arg_dat;
    _ = &dat;
    var sample_flags = arg_sample_flags;
    _ = &sample_flags;
    if (bn.*.nptype >= @as(c_int, 0)) {
        if (np != null) {
            _ = memset(@as(?*anyopaque, @ptrCast(np)), @as(c_int, 0), @as(c_ulong, @bitCast(@as(c_long, NP_MAX))) *% @sizeOf(i64));
        }
        var id: i64 = @as(i64, @intFromFloat(10000.0 * sampleClimatePara(bn, np, @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(z)))));
        _ = &id;
        return @as(c_int, @bitCast(@as(c_int, @truncate(id))));
    }
    var t: f32 = 0;
    _ = &t;
    var h: f32 = 0;
    _ = &h;
    var c: f32 = 0;
    _ = &c;
    var e: f32 = 0;
    _ = &e;
    var d: f32 = 0;
    _ = &d;
    var w: f32 = 0;
    _ = &w;
    var px: f64 = @as(f64, @floatFromInt(x));
    _ = &px;
    var pz: f64 = @as(f64, @floatFromInt(z));
    _ = &pz;
    if (!((sample_flags & @as(u32, @bitCast(SAMPLE_NO_SHIFT))) != 0)) {
        px += sampleDoublePerlin(&bn.*.climate[@as(c_uint, @intCast(NP_SHIFT))], @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(@as(c_int, 0))), @as(f64, @floatFromInt(z))) * 4.0;
        pz += sampleDoublePerlin(&bn.*.climate[@as(c_uint, @intCast(NP_SHIFT))], @as(f64, @floatFromInt(z)), @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(@as(c_int, 0)))) * 4.0;
    }
    c = @as(f32, @floatCast(sampleDoublePerlin(&bn.*.climate[@as(c_uint, @intCast(NP_CONTINENTALNESS))], px, @as(f64, @floatFromInt(@as(c_int, 0))), pz)));
    e = @as(f32, @floatCast(sampleDoublePerlin(&bn.*.climate[@as(c_uint, @intCast(NP_EROSION))], px, @as(f64, @floatFromInt(@as(c_int, 0))), pz)));
    w = @as(f32, @floatCast(sampleDoublePerlin(&bn.*.climate[@as(c_uint, @intCast(NP_WEIRDNESS))], px, @as(f64, @floatFromInt(@as(c_int, 0))), pz)));
    if (!((sample_flags & @as(u32, @bitCast(SAMPLE_NO_DEPTH))) != 0)) {
        var np_param: [4]f32 = [4]f32{
            c,
            e,
            -3.0 * (fabsf(fabsf(w) - 0.6666666865348816) - 0.3333333432674408),
            w,
        };
        _ = &np_param;
        var off: f64 = @as(f64, @floatCast(getSpline(bn.*.sp, @as([*c]f32, @ptrCast(@alignCast(&np_param)))) + 0.014999999664723873));
        _ = &off;
        d = @as(f32, @floatCast(((1.0 - (@as(f64, @floatFromInt(y * @as(c_int, 4))) / 128.0)) - (83.0 / 160.0)) + off));
    }
    t = @as(f32, @floatCast(sampleDoublePerlin(&bn.*.climate[@as(c_uint, @intCast(NP_TEMPERATURE))], px, @as(f64, @floatFromInt(@as(c_int, 0))), pz)));
    h = @as(f32, @floatCast(sampleDoublePerlin(&bn.*.climate[@as(c_uint, @intCast(NP_HUMIDITY))], px, @as(f64, @floatFromInt(@as(c_int, 0))), pz)));
    var l_np: [6]i64 = undefined;
    _ = &l_np;
    var p_np: [*c]i64 = if (np != null) np else @as([*c]i64, @ptrCast(@alignCast(&l_np)));
    _ = &p_np;
    p_np[@as(c_uint, @intCast(@as(c_int, 0)))] = @as(i64, @intFromFloat(10000.0 * t));
    p_np[@as(c_uint, @intCast(@as(c_int, 1)))] = @as(i64, @intFromFloat(10000.0 * h));
    p_np[@as(c_uint, @intCast(@as(c_int, 2)))] = @as(i64, @intFromFloat(10000.0 * c));
    p_np[@as(c_uint, @intCast(@as(c_int, 3)))] = @as(i64, @intFromFloat(10000.0 * e));
    p_np[@as(c_uint, @intCast(@as(c_int, 4)))] = @as(i64, @intFromFloat(10000.0 * d));
    p_np[@as(c_uint, @intCast(@as(c_int, 5)))] = @as(i64, @intFromFloat(10000.0 * w));
    var id: c_int = none;
    _ = &id;
    if (!((sample_flags & @as(u32, @bitCast(SAMPLE_NO_BIOME))) != 0)) {
        id = climateToBiome(bn.*.mc, @as([*c]const u64, @ptrCast(@alignCast(p_np))), dat);
    }
    return id;
}
pub fn sampleBiomeNoiseBeta(arg_bnb: [*c]const BiomeNoiseBeta, arg_np: [*c]i64, arg_nv: [*c]f64, arg_x: c_int, arg_z: c_int) c_int {
    var bnb = arg_bnb;
    _ = &bnb;
    var np = arg_np;
    _ = &np;
    var nv = arg_nv;
    _ = &nv;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    if ((bnb.*.nptype >= @as(c_int, 0)) and (np != null)) {
        _ = memset(@as(?*anyopaque, @ptrCast(np)), @as(c_int, 0), @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 2)))) *% @sizeOf(i64));
    }
    var t: f64 = undefined;
    _ = &t;
    var h: f64 = undefined;
    _ = &h;
    var f: f64 = undefined;
    _ = &f;
    f = (sampleOctaveBeta17Biome(&bnb.*.climate[@as(c_uint, @intCast(@as(c_int, 2)))], @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(z))) * 1.1) + 0.5;
    t = (((sampleOctaveBeta17Biome(&bnb.*.climate[@as(c_uint, @intCast(@as(c_int, 0)))], @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(z))) * 0.15) + 0.7) * 0.99) + (f * 0.01);
    t = @as(f64, @floatFromInt(@as(c_int, 1))) - ((@as(f64, @floatFromInt(@as(c_int, 1))) - t) * (@as(f64, @floatFromInt(@as(c_int, 1))) - t));
    t = if (t < @as(f64, @floatFromInt(@as(c_int, 0)))) @as(f64, @floatFromInt(@as(c_int, 0))) else t;
    t = if (t > @as(f64, @floatFromInt(@as(c_int, 1)))) @as(f64, @floatFromInt(@as(c_int, 1))) else t;
    if (bnb.*.nptype == NP_TEMPERATURE) return @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @intFromFloat(@as(f64, @floatCast(10000.0)) * t))))));
    h = (((sampleOctaveBeta17Biome(&bnb.*.climate[@as(c_uint, @intCast(@as(c_int, 1)))], @as(f64, @floatFromInt(x)), @as(f64, @floatFromInt(z))) * 0.15) + 0.5) * 0.998) + (f * 0.002);
    h = if (h < @as(f64, @floatFromInt(@as(c_int, 0)))) @as(f64, @floatFromInt(@as(c_int, 0))) else h;
    h = if (h > @as(f64, @floatFromInt(@as(c_int, 1)))) @as(f64, @floatFromInt(@as(c_int, 1))) else h;
    if (bnb.*.nptype == NP_HUMIDITY) return @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @intFromFloat((@as(f64, @floatCast(10000.0)) * h) * t))))));
    if (nv != null) {
        nv[@as(c_uint, @intCast(@as(c_int, 0)))] = t;
        nv[@as(c_uint, @intCast(@as(c_int, 1)))] = h;
    }
    return getOldBetaBiome(@as(f32, @floatCast(t)), @as(f32, @floatCast(h)));
}
pub fn approxSurfaceBeta(arg_bnb: [*c]const BiomeNoiseBeta, arg_snb: [*c]const SurfaceNoiseBeta, arg_x: c_int, arg_z: c_int) f64 {
    var bnb = arg_bnb;
    _ = &bnb;
    var snb = arg_snb;
    _ = &snb;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var climate: [2]f64 = undefined;
    _ = &climate;
    _ = sampleBiomeNoiseBeta(bnb, null, @as([*c]f64, @ptrCast(@alignCast(&climate))), x, z);
    var cols: [2]f64 = undefined;
    _ = &cols;
    var colNoise: SeaLevelColumnNoiseBeta = undefined;
    _ = &colNoise;
    genColumnNoise(snb, &colNoise, @as(f64, @floatFromInt(x)) * 0.25, @as(f64, @floatFromInt(z)) * 0.25, @as(f64, @floatFromInt(@as(c_int, 0))));
    processColumnNoise(@as([*c]f64, @ptrCast(@alignCast(&cols))), &colNoise, @as([*c]f64, @ptrCast(@alignCast(&climate))));
    return @as(f64, @floatFromInt(@as(c_int, 63))) + (((cols[@as(c_uint, @intCast(@as(c_int, 0)))] * 0.125) + (cols[@as(c_uint, @intCast(@as(c_int, 1)))] * 0.875)) * 0.5);
}
pub fn getOldBetaBiome(arg_t: f32, arg_h: f32) c_int {
    var t = arg_t;
    _ = &t;
    var h = arg_h;
    _ = &h;
    const biome_table_beta_1_7 = struct {
        const static: [4096]u8 = [4096]u8{
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            1,
            1,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            1,
            1,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            6,
            6,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            0,
            0,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            9,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            7,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            7,
            8,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            8,
            8,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            8,
            8,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            8,
            8,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            8,
            8,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            2,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            8,
            8,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            5,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            3,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            4,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            8,
            8,
        };
    };
    _ = &biome_table_beta_1_7;
    const bmap = struct {
        const static: [10]c_int = [10]c_int{
            plains,
            desert,
            forest,
            taiga,
            swamp,
            snowy_tundra,
            savanna,
            seasonal_forest,
            rainforest,
            shrubland,
        };
    };
    _ = &bmap;
    var idx: c_int = @as(c_int, @intFromFloat(t * @as(f32, @floatFromInt(@as(c_int, 63))))) + (@as(c_int, @intFromFloat(h * @as(f32, @floatFromInt(@as(c_int, 63))))) * @as(c_int, 64));
    _ = &idx;
    return bmap.static[biome_table_beta_1_7.static[@as(c_uint, @intCast(idx))]];
}
pub export fn climateToBiome(arg_mc: c_int, np: [*c]const u64, arg_dat: [*c]u64) c_int {
    var mc = arg_mc;
    _ = &mc;
    _ = &np;
    var dat = arg_dat;
    _ = &dat;
    const btree18 = struct {
        const static: BiomeTree = BiomeTree{
            .steps = @as([*c]const u32, @ptrCast(@alignCast(&btree18_steps))),
            .param = &btree18_param[@as(c_uint, @intCast(@as(c_int, 0)))][@as(c_uint, @intCast(@as(c_int, 0)))],
            .nodes = @as([*c]const u64, @ptrCast(@alignCast(&btree18_nodes))),
            .order = @as(u32, @bitCast(btree18_order)),
            .len = @as(u32, @bitCast(@as(c_uint, @truncate(@sizeOf([8421]u64) / @sizeOf(u64))))),
        };
    };
    _ = &btree18;
    const btree192 = struct {
        const static: BiomeTree = BiomeTree{
            .steps = @as([*c]const u32, @ptrCast(@alignCast(&btree192_steps))),
            .param = &btree192_param[@as(c_uint, @intCast(@as(c_int, 0)))][@as(c_uint, @intCast(@as(c_int, 0)))],
            .nodes = @as([*c]const u64, @ptrCast(@alignCast(&btree192_nodes))),
            .order = @as(u32, @bitCast(btree192_order)),
            .len = @as(u32, @bitCast(@as(c_uint, @truncate(@sizeOf([8438]u64) / @sizeOf(u64))))),
        };
    };
    _ = &btree192;
    const btree19 = struct {
        const static: BiomeTree = BiomeTree{
            .steps = @as([*c]const u32, @ptrCast(@alignCast(&btree19_steps))),
            .param = &btree19_param[@as(c_uint, @intCast(@as(c_int, 0)))][@as(c_uint, @intCast(@as(c_int, 0)))],
            .nodes = @as([*c]const u64, @ptrCast(@alignCast(&btree19_nodes))),
            .order = @as(u32, @bitCast(btree19_order)),
            .len = @as(u32, @bitCast(@as(c_uint, @truncate(@sizeOf([9112]u64) / @sizeOf(u64))))),
        };
    };
    _ = &btree19;
    const btree20 = struct {
        const static: BiomeTree = BiomeTree{
            .steps = @as([*c]const u32, @ptrCast(@alignCast(&btree20_steps))),
            .param = &btree20_param[@as(c_uint, @intCast(@as(c_int, 0)))][@as(c_uint, @intCast(@as(c_int, 0)))],
            .nodes = @as([*c]const u64, @ptrCast(@alignCast(&btree20_nodes))),
            .order = @as(u32, @bitCast(btree20_order)),
            .len = @as(u32, @bitCast(@as(c_uint, @truncate(@sizeOf([9112]u64) / @sizeOf(u64))))),
        };
    };
    _ = &btree20;
    const btree21wd = struct {
        const static: BiomeTree = BiomeTree{
            .steps = @as([*c]const u32, @ptrCast(@alignCast(&btree21wd_steps))),
            .param = &btree21wd_param[@as(c_uint, @intCast(@as(c_int, 0)))][@as(c_uint, @intCast(@as(c_int, 0)))],
            .nodes = @as([*c]const u64, @ptrCast(@alignCast(&btree21wd_nodes))),
            .order = @as(u32, @bitCast(btree21wd_order)),
            .len = @as(u32, @bitCast(@as(c_uint, @truncate(@sizeOf([9112]u64) / @sizeOf(u64))))),
        };
    };
    _ = &btree21wd;
    var bt: [*c]const BiomeTree = undefined;
    _ = &bt;
    var idx: c_int = undefined;
    _ = &idx;
    if (mc >= MC_1_21_WD) {
        bt = &btree21wd.static;
    } else if (mc >= MC_1_20_6) {
        bt = &btree20.static;
    } else if (mc >= MC_1_19_4) {
        bt = &btree19.static;
    } else if (mc >= MC_1_19_2) {
        bt = &btree192.static;
    } else {
        bt = &btree18.static;
    }
    if (dat != null) {
        var alt: c_int = @as(c_int, @bitCast(@as(c_uint, @truncate(dat.*))));
        _ = &alt;
        var ds: u64 = biome_tree.getNpDist(np, bt.*.param, bt.*.nodes, alt);
        _ = &ds;
        idx = biome_tree.getResultingNode(np, bt.*.steps, bt.*.param, bt.*.nodes, bt.*.len, bt.*.order, @as(c_int, 0), alt, ds, @as(c_int, 0));
        dat.* = @as(u64, @bitCast(@as(c_long, idx)));
    } else {
        idx = biome_tree.getResultingNode(np, bt.*.steps, bt.*.param, bt.*.nodes, bt.*.len, bt.*.order, @as(c_int, 0), @as(c_int, 0), @as(u64, @bitCast(@as(c_long, -@as(c_int, 1)))), @as(c_int, 0));
    }
    return @as(c_int, @bitCast(@as(c_uint, @truncate(((blk: {
        const tmp = idx;
        if (tmp >= 0) break :blk bt.*.nodes + @as(usize, @intCast(tmp)) else break :blk bt.*.nodes - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* >> @intCast(48)) & @as(u64, @bitCast(@as(c_long, @as(c_int, 255))))))));
}
pub fn sampleClimatePara(arg_bn: [*c]const BiomeNoise, arg_np: [*c]i64, arg_x: f64, arg_z: f64) f64 {
    var bn = arg_bn;
    _ = &bn;
    var np = arg_np;
    _ = &np;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    if (bn.*.nptype == NP_DEPTH) {
        var c: f32 = undefined;
        _ = &c;
        var e: f32 = undefined;
        _ = &e;
        var w: f32 = undefined;
        _ = &w;
        c = @as(f32, @floatCast(sampleDoublePerlin(@as([*c]const DoublePerlinNoise, @ptrCast(@alignCast(&bn.*.climate))) + @as(usize, @bitCast(@as(isize, @intCast(NP_CONTINENTALNESS)))), x, @as(f64, @floatFromInt(@as(c_int, 0))), z)));
        e = @as(f32, @floatCast(sampleDoublePerlin(@as([*c]const DoublePerlinNoise, @ptrCast(@alignCast(&bn.*.climate))) + @as(usize, @bitCast(@as(isize, @intCast(NP_EROSION)))), x, @as(f64, @floatFromInt(@as(c_int, 0))), z)));
        w = @as(f32, @floatCast(sampleDoublePerlin(@as([*c]const DoublePerlinNoise, @ptrCast(@alignCast(&bn.*.climate))) + @as(usize, @bitCast(@as(isize, @intCast(NP_WEIRDNESS)))), x, @as(f64, @floatFromInt(@as(c_int, 0))), z)));
        var np_param: [4]f32 = [4]f32{
            c,
            e,
            -3.0 * (fabsf(fabsf(w) - 0.6666666865348816) - 0.3333333432674408),
            w,
        };
        _ = &np_param;
        var off: f64 = @as(f64, @floatCast(getSpline(bn.*.sp, @as([*c]f32, @ptrCast(@alignCast(&np_param)))) + 0.014999999664723873));
        _ = &off;
        var y: c_int = 0;
        _ = &y;
        var d: f32 = @as(f32, @floatCast(((1.0 - (@as(f64, @floatFromInt(y * @as(c_int, 4))) / 128.0)) - (83.0 / 160.0)) + off));
        _ = &d;
        if (np != null) {
            np[@as(c_uint, @intCast(@as(c_int, 2)))] = @as(i64, @intFromFloat(10000.0 * c));
            np[@as(c_uint, @intCast(@as(c_int, 3)))] = @as(i64, @intFromFloat(10000.0 * e));
            np[@as(c_uint, @intCast(@as(c_int, 4)))] = @as(i64, @intFromFloat(10000.0 * d));
            np[@as(c_uint, @intCast(@as(c_int, 5)))] = @as(i64, @intFromFloat(10000.0 * w));
        }
        return @as(f64, @floatCast(d));
    }
    var p: f64 = sampleDoublePerlin(@as([*c]const DoublePerlinNoise, @ptrCast(@alignCast(&bn.*.climate))) + @as(usize, @bitCast(@as(isize, @intCast(bn.*.nptype)))), x, @as(f64, @floatFromInt(@as(c_int, 0))), z);
    _ = &p;
    if (np != null) {
        (blk: {
            const tmp = bn.*.nptype;
            if (tmp >= 0) break :blk np + @as(usize, @intCast(tmp)) else break :blk np - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* = @as(i64, @intFromFloat(@as(f64, @floatCast(10000.0)) * p));
    }
    return p;
}
pub fn genBiomeNoiseScaled(arg_bn: [*c]const BiomeNoise, arg_out: [*c]c_int, arg_r: Range, arg_sha: u64) c_int {
    var bn = arg_bn;
    _ = &bn;
    var out = arg_out;
    _ = &out;
    var r = arg_r;
    _ = &r;
    var sha = arg_sha;
    _ = &sha;
    if (r.sy == @as(c_int, 0)) {
        r.sy = 1;
    }
    var siz: u64 = (@as(u64, @bitCast(@as(c_long, r.sx))) *% @as(u64, @bitCast(@as(c_long, r.sy)))) *% @as(u64, @bitCast(@as(c_long, r.sz)));
    _ = &siz;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var k: c_int = undefined;
    _ = &k;
    if (r.scale == @as(c_int, 1)) {
        var s: Range = getVoronoiSrcRange(r);
        _ = &s;
        var src: [*c]c_int = undefined;
        _ = &src;
        if (siz > @as(u64, @bitCast(@as(c_long, @as(c_int, 1))))) {
            src = out + siz;
            genBiomeNoise3D(bn, src, s, @as(c_int, 0));
        } else {
            src = null;
        }
        var p: [*c]c_int = out;
        _ = &p;
        {
            k = 0;
            while (k < r.sy) : (k += 1) {
                {
                    j = 0;
                    while (j < r.sz) : (j += 1) {
                        {
                            i = 0;
                            while (i < r.sx) : (i += 1) {
                                var x4: c_int = undefined;
                                _ = &x4;
                                var z4: c_int = undefined;
                                _ = &z4;
                                var y4: c_int = undefined;
                                _ = &y4;
                                voronoiAccess3D(sha, r.x + i, r.y + k, r.z + j, &x4, &y4, &z4);
                                if (src != null) {
                                    x4 -= s.x;
                                    y4 -= s.y;
                                    z4 -= s.z;
                                    p.* = (blk: {
                                        const tmp = (((@as(i64, @bitCast(@as(c_long, y4))) * @as(i64, @bitCast(@as(c_long, s.sx)))) * @as(i64, @bitCast(@as(c_long, s.sz)))) + (@as(i64, @bitCast(@as(c_long, z4))) * @as(i64, @bitCast(@as(c_long, s.sx))))) + @as(i64, @bitCast(@as(c_long, x4)));
                                        if (tmp >= 0) break :blk src + @as(usize, @intCast(tmp)) else break :blk src - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).*;
                                } else {
                                    p.* = sampleBiomeNoise(bn, null, x4, y4, z4, null, @as(u32, @bitCast(@as(c_int, 0))));
                                }
                                p += 1;
                            }
                        }
                    }
                }
            }
        }
    } else {
        genBiomeNoise3D(bn, out, r, @intFromBool(r.scale > @as(c_int, 4)));
    }
    return 0;
}
pub fn genBiomeNoiseBetaScaled(arg_bnb: [*c]const BiomeNoiseBeta, arg_snb: [*c]const SurfaceNoiseBeta, arg_out: [*c]c_int, arg_r: Range) c_int {
    var bnb = arg_bnb;
    _ = &bnb;
    var snb = arg_snb;
    _ = &snb;
    var out = arg_out;
    _ = &out;
    var r = arg_r;
    _ = &r;
    if (!(snb != null) or (r.scale >= @as(c_int, 4))) {
        var i: c_int = undefined;
        _ = &i;
        var j: c_int = undefined;
        _ = &j;
        var mid: c_int = r.scale >> @intCast(1);
        _ = &mid;
        {
            j = 0;
            while (j < r.sz) : (j += 1) {
                var z: c_int = ((r.z + j) * r.scale) + mid;
                _ = &z;
                {
                    i = 0;
                    while (i < r.sx) : (i += 1) {
                        var climate: [2]f64 = undefined;
                        _ = &climate;
                        var x: c_int = ((r.x + i) * r.scale) + mid;
                        _ = &x;
                        var id: c_int = sampleBiomeNoiseBeta(bnb, null, @as([*c]f64, @ptrCast(@alignCast(&climate))), x, z);
                        _ = &id;
                        if (snb != null) {
                            var cols: [2]f64 = undefined;
                            _ = &cols;
                            var colNoise: SeaLevelColumnNoiseBeta = undefined;
                            _ = &colNoise;
                            genColumnNoise(snb, &colNoise, @as(f64, @floatFromInt(x)) * 0.25, @as(f64, @floatFromInt(z)) * 0.25, 4.0 / @as(f64, @floatFromInt(r.scale)));
                            processColumnNoise(@as([*c]f64, @ptrCast(@alignCast(&cols))), &colNoise, @as([*c]f64, @ptrCast(@alignCast(&climate))));
                            if (((cols[@as(c_uint, @intCast(@as(c_int, 0)))] * 0.125) + (cols[@as(c_uint, @intCast(@as(c_int, 1)))] * 0.875)) <= @as(f64, @floatFromInt(@as(c_int, 0)))) {
                                id = if (climate[@as(c_uint, @intCast(@as(c_int, 0)))] < 0.5) frozen_ocean else ocean;
                            }
                        }
                        (blk: {
                            const tmp = (@as(i64, @bitCast(@as(c_long, j))) * @as(i64, @bitCast(@as(c_long, r.sx)))) + @as(i64, @bitCast(@as(c_long, i)));
                            if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = id;
                    }
                }
            }
        }
        return 0;
    }
    var cellwidth: c_int = r.scale >> @intCast(1);
    _ = &cellwidth;
    var cx1: c_int = r.x >> @intCast(@as(c_int, 2) >> @intCast(cellwidth));
    _ = &cx1;
    var cz1: c_int = r.z >> @intCast(@as(c_int, 2) >> @intCast(cellwidth));
    _ = &cz1;
    var cx2: c_int = (cx1 + (r.sx >> @intCast(@as(c_int, 2) >> @intCast(cellwidth)))) + @as(c_int, 1);
    _ = &cx2;
    var cz2: c_int = (cz1 + (r.sz >> @intCast(@as(c_int, 2) >> @intCast(cellwidth)))) + @as(c_int, 1);
    _ = &cz2;
    var steps: c_int = @as(c_int, 4) >> @intCast(cellwidth);
    _ = &steps;
    var minDim: c_int = undefined;
    _ = &minDim;
    var maxDim: c_int = undefined;
    _ = &maxDim;
    if ((cx2 - cx1) > (cz2 - cz1)) {
        maxDim = cx2 - cx1;
        minDim = cz2 - cz1;
    } else {
        maxDim = cz2 - cz1;
        minDim = cx2 - cx1;
    }
    var bufLen: c_int = (minDim * @as(c_int, 2)) + @as(c_int, 1);
    _ = &bufLen;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var x: c_int = undefined;
    _ = &x;
    var z: c_int = undefined;
    _ = &z;
    var cx: c_int = undefined;
    _ = &cx;
    var cz: c_int = undefined;
    _ = &cz;
    var xStart: c_int = cx1;
    _ = &xStart;
    var zStart: c_int = cz1;
    _ = &zStart;
    var idx: c_int = 0;
    _ = &idx;
    var buf: [*c]SeaLevelColumnNoiseBeta = @as([*c]SeaLevelColumnNoiseBeta, @ptrCast(@alignCast(out + @as(usize, @bitCast(@as(isize, @intCast(@as(i64, @bitCast(@as(c_long, r.sx))) * @as(i64, @bitCast(@as(c_long, r.sz))))))))));
    _ = &buf;
    var colNoise: [*c]SeaLevelColumnNoiseBeta = undefined;
    _ = &colNoise;
    var cols: [8]f64 = undefined;
    _ = &cols;
    var climate: [2]f64 = undefined;
    _ = &climate;
    const off = struct {
        const static: [5]c_int = [5]c_int{
            1,
            4,
            7,
            10,
            13,
        };
    };
    _ = &off;
    var stripe: c_int = undefined;
    _ = &stripe;
    {
        stripe = 0;
        while (stripe < ((maxDim + minDim) - @as(c_int, 1))) : (stripe += 1) {
            cx = xStart;
            cz = zStart;
            while ((cx < cx2) and (cz >= cz1)) {
                var csx: c_int = (cx * @as(c_int, 4)) & ~@as(c_int, 15);
                _ = &csx;
                var csz: c_int = (cz * @as(c_int, 4)) & ~@as(c_int, 15);
                _ = &csz;
                var ci: c_int = cx & @as(c_int, 3);
                _ = &ci;
                var cj: c_int = cz & @as(c_int, 3);
                _ = &cj;
                colNoise = &(blk: {
                    const tmp = idx;
                    if (tmp >= 0) break :blk buf + @as(usize, @intCast(tmp)) else break :blk buf - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
                if (stripe == @as(c_int, 0)) {
                    genColumnNoise(snb, colNoise, @as(f64, @floatFromInt(cx)), @as(f64, @floatFromInt(cz)), @as(f64, @floatFromInt(@as(c_int, 0))));
                }
                _ = sampleBiomeNoiseBeta(bnb, null, @as([*c]f64, @ptrCast(@alignCast(&climate))), csx + off.static[@as(c_uint, @intCast(ci))], csz + off.static[@as(c_uint, @intCast(cj))]);
                processColumnNoise(&cols[@as(c_uint, @intCast(@as(c_int, 0)))], colNoise, @as([*c]f64, @ptrCast(@alignCast(&climate))));
                colNoise = &(blk: {
                    const tmp = @import("std").zig.c_translation.signedRemainder((idx + minDim) + @as(c_int, 1), bufLen);
                    if (tmp >= 0) break :blk buf + @as(usize, @intCast(tmp)) else break :blk buf - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
                if (cz == cz1) {
                    genColumnNoise(snb, colNoise, @as(f64, @floatFromInt(cx + @as(c_int, 1))), @as(f64, @floatFromInt(cz)), @as(f64, @floatFromInt(@as(c_int, 0))));
                }
                _ = sampleBiomeNoiseBeta(bnb, null, @as([*c]f64, @ptrCast(@alignCast(&climate))), csx + off.static[@as(c_uint, @intCast(ci + @as(c_int, 1)))], csz + off.static[@as(c_uint, @intCast(cj))]);
                processColumnNoise(&cols[@as(c_uint, @intCast(@as(c_int, 2)))], colNoise, @as([*c]f64, @ptrCast(@alignCast(&climate))));
                colNoise = &(blk: {
                    const tmp = @import("std").zig.c_translation.signedRemainder(idx + minDim, bufLen);
                    if (tmp >= 0) break :blk buf + @as(usize, @intCast(tmp)) else break :blk buf - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
                if (cx == cx1) {
                    genColumnNoise(snb, colNoise, @as(f64, @floatFromInt(cx)), @as(f64, @floatFromInt(cz + @as(c_int, 1))), @as(f64, @floatFromInt(@as(c_int, 0))));
                }
                _ = sampleBiomeNoiseBeta(bnb, null, @as([*c]f64, @ptrCast(@alignCast(&climate))), csx + off.static[@as(c_uint, @intCast(ci))], csz + off.static[@as(c_uint, @intCast(cj + @as(c_int, 1)))]);
                processColumnNoise(&cols[@as(c_uint, @intCast(@as(c_int, 4)))], colNoise, @as([*c]f64, @ptrCast(@alignCast(&climate))));
                colNoise = &(blk: {
                    const tmp = idx;
                    if (tmp >= 0) break :blk buf + @as(usize, @intCast(tmp)) else break :blk buf - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
                genColumnNoise(snb, colNoise, @as(f64, @floatFromInt(cx + @as(c_int, 1))), @as(f64, @floatFromInt(cz + @as(c_int, 1))), @as(f64, @floatFromInt(@as(c_int, 0))));
                _ = sampleBiomeNoiseBeta(bnb, null, @as([*c]f64, @ptrCast(@alignCast(&climate))), csx + off.static[@as(c_uint, @intCast(ci + @as(c_int, 1)))], csz + off.static[@as(c_uint, @intCast(cj + @as(c_int, 1)))]);
                processColumnNoise(&cols[@as(c_uint, @intCast(@as(c_int, 6)))], colNoise, @as([*c]f64, @ptrCast(@alignCast(&climate))));
                {
                    j = 0;
                    while (j < steps) : (j += 1) {
                        z = (cz * steps) + j;
                        if ((z < r.z) or (z >= (r.z + r.sz))) continue;
                        {
                            i = 0;
                            while (i < steps) : (i += 1) {
                                x = (cx * steps) + i;
                                if ((x < r.x) or (x >= (r.x + r.sx))) continue;
                                var mid: c_int = r.scale >> @intCast(1);
                                _ = &mid;
                                var bx: c_int = (x * r.scale) + mid;
                                _ = &bx;
                                var bz: c_int = (z * r.scale) + mid;
                                _ = &bz;
                                var id: c_int = sampleBiomeNoiseBeta(bnb, null, @as([*c]f64, @ptrCast(@alignCast(&climate))), bx, bz);
                                _ = &id;
                                var dx: f64 = @as(f64, @floatFromInt(bx & @as(c_int, 3))) * 0.25;
                                _ = &dx;
                                var dz: f64 = @as(f64, @floatFromInt(bz & @as(c_int, 3))) * 0.25;
                                _ = &dz;
                                if (lerp4(@as([*c]f64, @ptrCast(@alignCast(&cols))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 0))))), @as([*c]f64, @ptrCast(@alignCast(&cols))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2))))), @as([*c]f64, @ptrCast(@alignCast(&cols))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 4))))), @as([*c]f64, @ptrCast(@alignCast(&cols))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 6))))), 7.0 / @as(f64, @floatFromInt(@as(c_int, 8))), dx, dz) <= @as(f64, @floatFromInt(@as(c_int, 0)))) {
                                    id = if (climate[@as(c_uint, @intCast(@as(c_int, 0)))] < 0.5) frozen_ocean else ocean;
                                }
                                (blk: {
                                    const tmp = (@as(i64, @bitCast(@as(c_long, z - r.z))) * @as(i64, @bitCast(@as(c_long, r.sx)))) + @as(i64, @bitCast(@as(c_long, x - r.x)));
                                    if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                }).* = id;
                            }
                        }
                    }
                }
                cx += 1;
                cz -= 1;
                idx = @import("std").zig.c_translation.signedRemainder(idx + @as(c_int, 1), bufLen);
            }
            if (zStart < (cz2 - @as(c_int, 1))) {
                zStart += 1;
            } else {
                xStart += 1;
            }
            if ((stripe + @as(c_int, 1)) < minDim) {
                idx = @import("std").zig.c_translation.signedRemainder(((idx + minDim) - stripe) - @as(c_int, 1), bufLen);
            } else if ((stripe + @as(c_int, 1)) > maxDim) {
                idx = @import("std").zig.c_translation.signedRemainder(((idx + stripe) - maxDim) + @as(c_int, 2), bufLen);
            } else if (xStart > cx1) {
                idx = @import("std").zig.c_translation.signedRemainder(idx + @as(c_int, 1), bufLen);
            }
        }
    }
    return 0;
}
pub fn getBiomeDepthAndScale(arg_id: c_int, arg_depth: [*c]f64, arg_scale: [*c]f64, arg_grass: [*c]c_int) c_int {
    var id = arg_id;
    _ = &id;
    var depth = arg_depth;
    _ = &depth;
    var scale = arg_scale;
    _ = &scale;
    var grass = arg_grass;
    _ = &grass;
    const dh: c_int = 62;
    _ = &dh;
    var s: f64 = 0;
    _ = &s;
    var d: f64 = 0;
    _ = &d;
    var g: f64 = 0;
    _ = &g;
    while (true) {
        switch (id) {
            @as(c_int, 0) => {
                s = 0.1;
                d = -1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 1) => {
                s = 0.05;
                d = 0.125;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 2) => {
                s = 0.05;
                d = 0.125;
                g = 0;
                break;
            },
            @as(c_int, 3) => {
                s = 0.5;
                d = 1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 4) => {
                s = 0.2;
                d = 0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 5) => {
                s = 0.2;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 6) => {
                s = 0.1;
                d = -0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 7) => {
                s = 0.0;
                d = -0.5;
                g = 60;
                break;
            },
            @as(c_int, 10) => {
                s = 0.1;
                d = -1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 11) => {
                s = 0.0;
                d = -0.5;
                g = 60;
                break;
            },
            @as(c_int, 12) => {
                s = 0.05;
                d = 0.125;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 13) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 14) => {
                s = 0.3;
                d = 0.2;
                g = 0;
                break;
            },
            @as(c_int, 15) => {
                s = 0.025;
                d = 0.0;
                g = 0;
                break;
            },
            @as(c_int, 16) => {
                s = 0.025;
                d = 0.0;
                g = 64;
                break;
            },
            @as(c_int, 17) => {
                s = 0.3;
                d = 0.45;
                g = 0;
                break;
            },
            @as(c_int, 18) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 19) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 20) => {
                s = 0.3;
                d = 0.8;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 21) => {
                s = 0.2;
                d = 0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 22) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 23) => {
                s = 0.2;
                d = 0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 24) => {
                s = 0.1;
                d = -1.8;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 25) => {
                s = 0.8;
                d = 0.1;
                g = 64;
                break;
            },
            @as(c_int, 26) => {
                s = 0.025;
                d = 0.0;
                g = 64;
                break;
            },
            @as(c_int, 27) => {
                s = 0.2;
                d = 0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 28) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 29) => {
                s = 0.2;
                d = 0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 30) => {
                s = 0.2;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 31) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 32) => {
                s = 0.2;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 33) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 34) => {
                s = 0.5;
                d = 1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 35) => {
                s = 0.05;
                d = 0.125;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 36) => {
                s = 0.025;
                d = 1.5;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 37) => {
                s = 0.2;
                d = 0.1;
                g = 0;
                break;
            },
            @as(c_int, 38) => {
                s = 0.025;
                d = 1.5;
                g = 0;
                break;
            },
            @as(c_int, 39) => {
                s = 0.025;
                d = 1.5;
                g = 0;
                break;
            },
            @as(c_int, 44) => {
                s = 0.1;
                d = -1.0;
                g = 0;
                break;
            },
            @as(c_int, 45) => {
                s = 0.1;
                d = -1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 46) => {
                s = 0.1;
                d = -1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 47) => {
                s = 0.1;
                d = -1.8;
                g = 0;
                break;
            },
            @as(c_int, 48) => {
                s = 0.1;
                d = -1.8;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 49) => {
                s = 0.1;
                d = -1.8;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 50) => {
                s = 0.1;
                d = -1.8;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 129) => {
                s = 0.05;
                d = 0.125;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 130) => {
                s = 0.25;
                d = 0.225;
                g = 0;
                break;
            },
            @as(c_int, 131) => {
                s = 0.5;
                d = 1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 132) => {
                s = 0.4;
                d = 0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 133) => {
                s = 0.4;
                d = 0.3;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 134) => {
                s = 0.3;
                d = -0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 140) => {
                s = 0.45;
                d = 0.425;
                g = 0;
                break;
            },
            @as(c_int, 149) => {
                s = 0.4;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 151) => {
                s = 0.4;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 155) => {
                s = 0.4;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 156) => {
                s = 0.5;
                d = 0.55;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 157) => {
                s = 0.4;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 158) => {
                s = 0.4;
                d = 0.3;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 160) => {
                s = 0.2;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 161) => {
                s = 0.2;
                d = 0.2;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 162) => {
                s = 0.5;
                d = 1.0;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 163) => {
                s = 1.225;
                d = 0.3625;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 164) => {
                s = 1.212;
                d = 1.05;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 165) => {
                s = 0.2;
                d = 0.1;
                g = 0;
                break;
            },
            @as(c_int, 166) => {
                s = 0.3;
                d = 0.45;
                g = 0;
                break;
            },
            @as(c_int, 167) => {
                s = 0.3;
                d = 0.45;
                g = 0;
                break;
            },
            @as(c_int, 168) => {
                s = 0.2;
                d = 0.1;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            @as(c_int, 169) => {
                s = 0.3;
                d = 0.45;
                g = @as(f64, @floatFromInt(dh));
                break;
            },
            else => return 0,
        }
        break;
    }
    if (scale != null) {
        scale.* = s;
    }
    if (depth != null) {
        depth.* = d;
    }
    if (grass != null) {
        grass.* = @as(c_int, @intFromFloat(g));
    }
    return 1;
}
pub fn getVoronoiSrcRange(arg_r: Range) Range {
    var r = arg_r;
    _ = &r;
    if (r.scale != @as(c_int, 1)) {
        _ = printf("getVoronoiSrcRange() expects input range with scale 1:1\n");
        exit(@as(c_int, 1));
    }
    var s: Range = undefined;
    _ = &s;
    var x: c_int = r.x - @as(c_int, 2);
    _ = &x;
    var z: c_int = r.z - @as(c_int, 2);
    _ = &z;
    s.scale = 4;
    s.x = x >> @intCast(2);
    s.z = z >> @intCast(2);
    s.sx = (((x + r.sx) >> @intCast(2)) - s.x) + @as(c_int, 2);
    s.sz = (((z + r.sz) >> @intCast(2)) - s.z) + @as(c_int, 2);
    if (r.sy < @as(c_int, 1)) {
        s.y = blk: {
            const tmp = @as(c_int, 0);
            s.sy = tmp;
            break :blk tmp;
        };
    } else {
        var ty: c_int = r.y - @as(c_int, 2);
        _ = &ty;
        s.y = ty >> @intCast(2);
        s.sy = (((ty + r.sy) >> @intCast(2)) - s.y) + @as(c_int, 2);
    }
    return s;
}
// Btree lookup tables — extracted to btree_data.zig for maintainability.
pub const btree_data = @import("btree_data.zig");
pub const btree18_order = btree_data.btree18_order;
pub const btree18_steps = btree_data.btree18_steps;
pub const btree18_param = btree_data.btree18_param;
pub const btree18_nodes = btree_data.btree18_nodes;
pub const btree192_order = btree_data.btree192_order;
pub const btree192_steps = btree_data.btree192_steps;
pub const btree192_param = btree_data.btree192_param;
pub const btree192_nodes = btree_data.btree192_nodes;
pub const btree19_order = btree_data.btree19_order;
pub const btree19_steps = btree_data.btree19_steps;
pub const btree19_param = btree_data.btree19_param;
pub const btree19_nodes = btree_data.btree19_nodes;
pub const btree20_order = btree_data.btree20_order;
pub const btree20_steps = btree_data.btree20_steps;
pub const btree20_param = btree_data.btree20_param;
pub const btree20_nodes = btree_data.btree20_nodes;
pub const btree21wd_order = btree_data.btree21wd_order;
pub const btree21wd_steps = btree_data.btree21wd_steps;
pub const btree21wd_param = btree_data.btree21wd_param;
pub const btree21wd_nodes = btree_data.btree21wd_nodes;
pub fn fillRad3D(arg_out: [*c]c_int, arg_x: c_int, arg_y: c_int, arg_z: c_int, arg_sx: c_int, arg_sy: c_int, arg_sz: c_int, arg_id: c_int, arg_rad: f32) void {
    var out = arg_out;
    _ = &out;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var sx = arg_sx;
    _ = &sx;
    var sy = arg_sy;
    _ = &sy;
    var sz = arg_sz;
    _ = &sz;
    var id = arg_id;
    _ = &id;
    var rad = arg_rad;
    _ = &rad;
    var r: c_int = undefined;
    _ = &r;
    var rsq: c_int = undefined;
    _ = &rsq;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var k: c_int = undefined;
    _ = &k;
    r = @as(c_int, @intFromFloat(rad));
    if (r <= @as(c_int, 0)) return;
    rsq = @as(c_int, @intFromFloat(floor(@as(f64, @floatCast(rad * rad)))));
    {
        k = -r;
        while (k <= r) : (k += 1) {
            var ak: c_int = y + k;
            _ = &ak;
            if ((ak < @as(c_int, 0)) or (ak >= sy)) continue;
            var ksq: c_int = k * k;
            _ = &ksq;
            var yout: [*c]c_int = &(blk: {
                const tmp = (@as(i64, @bitCast(@as(c_long, ak))) * @as(i64, @bitCast(@as(c_long, sx)))) * @as(i64, @bitCast(@as(c_long, sz)));
                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &yout;
            {
                j = -r;
                while (j <= r) : (j += 1) {
                    var aj: c_int = z + j;
                    _ = &aj;
                    if ((aj < @as(c_int, 0)) or (aj >= sz)) continue;
                    var jksq: c_int = (j * j) + ksq;
                    _ = &jksq;
                    {
                        i = -r;
                        while (i <= r) : (i += 1) {
                            var ai: c_int = x + i;
                            _ = &ai;
                            if ((ai < @as(c_int, 0)) or (ai >= sx)) continue;
                            var ijksq: c_int = (i * i) + jksq;
                            _ = &ijksq;
                            if (ijksq > rsq) continue;
                            (blk: {
                                const tmp = (@as(i64, @bitCast(@as(c_long, aj))) * @as(i64, @bitCast(@as(c_long, sx)))) + @as(i64, @bitCast(@as(c_long, ai)));
                                if (tmp >= 0) break :blk yout + @as(usize, @intCast(tmp)) else break :blk yout - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = id;
                        }
                    }
                }
            }
        }
    }
}
pub fn getEndBiome(arg_hx: c_int, arg_hz: c_int, arg_hmap: [*c]const u16, arg_hw: c_int) c_int {
    var hx = arg_hx;
    _ = &hx;
    var hz = arg_hz;
    _ = &hz;
    var hmap = arg_hmap;
    _ = &hmap;
    var hw = arg_hw;
    _ = &hw;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    const ds: [26]u16 = [26]u16{
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 625))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 529))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 441))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 361))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 289))))),
        225,
        169,
        121,
        81,
        49,
        25,
        9,
        1,
        1,
        9,
        25,
        49,
        81,
        121,
        169,
        225,
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 289))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 361))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 441))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 529))))),
        @as(u16, @bitCast(@as(c_short, @truncate(@as(c_int, 625))))),
    };
    _ = &ds;
    var p_dsi: [*c]const u16 = @as([*c]const u16, @ptrCast(@alignCast(&ds))) + @as(usize, @intFromBool(hx < @as(c_int, 0)));
    _ = &p_dsi;
    var p_dsj: [*c]const u16 = @as([*c]const u16, @ptrCast(@alignCast(&ds))) + @as(usize, @intFromBool(hz < @as(c_int, 0)));
    _ = &p_dsj;
    var p_elev: [*c]const u16 = hmap;
    _ = &p_elev;
    var h: u32 = undefined;
    _ = &h;
    if ((abs(hx) <= @as(c_int, 15)) and (abs(hz) <= @as(c_int, 15))) {
        h = @as(u32, @bitCast(@as(c_int, 64) * ((hx * hx) + (hz * hz))));
    } else {
        h = @as(u32, @bitCast(@as(c_int, 14401)));
    }
    {
        j = 0;
        while (j < @as(c_int, 25)) : (j += 1) {
            var dsj: u16 = (blk: {
                const tmp = j;
                if (tmp >= 0) break :blk p_dsj + @as(usize, @intCast(tmp)) else break :blk p_dsj - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &dsj;
            var e: u16 = undefined;
            _ = &e;
            var u: u32 = undefined;
            _ = &u;
            {
                i = 0;
                {
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                }
                {
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                }
                {
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                }
                {
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                }
                {
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                    if (__builtin_expect(@as(c_long, @bitCast(@as(c_ulong, blk: {
                        const tmp = (blk_1: {
                            const tmp_2 = i;
                            if (tmp_2 >= 0) break :blk_1 p_elev + @as(usize, @intCast(tmp_2)) else break :blk_1 p_elev - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                        }).*;
                        e = tmp;
                        break :blk tmp;
                    }))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                        if ((blk: {
                            const tmp = (@as(u32, @bitCast(@as(c_uint, (blk_1: {
                                const tmp_2 = i;
                                if (tmp_2 >= 0) break :blk_1 p_dsi + @as(usize, @intCast(tmp_2)) else break :blk_1 p_dsi - ~@as(usize, @bitCast(@as(isize, @intCast(tmp_2)) +% -1));
                            }).*))) +% @as(u32, @bitCast(@as(c_uint, dsj)))) *% @as(u32, @bitCast(@as(c_uint, e)));
                            u = tmp;
                            break :blk tmp;
                        }) < h) {
                            h = u;
                        }
                    }
                    i += 1;
                }
            }
            p_elev += @as(usize, @bitCast(@as(isize, @intCast(hw))));
        }
    }
    if (h < @as(u32, @bitCast(@as(c_int, 3600)))) return end_highlands else if (h <= @as(u32, @bitCast(@as(c_int, 10000)))) return end_midlands else if (h <= @as(u32, @bitCast(@as(c_int, 14400)))) return end_barrens;
    return small_end_islands;
}
pub fn getEndHeightNoise(arg_en: [*c]const EndNoise, arg_x: c_int, arg_z: c_int, arg_range: c_int) f32 {
    var en = arg_en;
    _ = &en;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var range = arg_range;
    _ = &range;
    var hx: c_int = @divTrunc(x, @as(c_int, 2));
    _ = &hx;
    var hz: c_int = @divTrunc(z, @as(c_int, 2));
    _ = &hz;
    var oddx: c_int = @import("std").zig.c_translation.signedRemainder(x, @as(c_int, 2));
    _ = &oddx;
    var oddz: c_int = @import("std").zig.c_translation.signedRemainder(z, @as(c_int, 2));
    _ = &oddz;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var h: i64 = @as(i64, @bitCast(@as(c_long, @as(c_int, 64)))) * ((@as(i64, @bitCast(@as(c_long, x))) * @as(i64, @bitCast(@as(c_long, x)))) + (@as(i64, @bitCast(@as(c_long, z))) * @as(i64, @bitCast(@as(c_long, z)))));
    _ = &h;
    if (range == @as(c_int, 0)) {
        range = 12;
    }
    {
        j = -range;
        while (j <= range) : (j += 1) {
            {
                i = -range;
                while (i <= range) : (i += 1) {
                    var rx: i64 = @as(i64, @bitCast(@as(c_long, hx + i)));
                    _ = &rx;
                    var rz: i64 = @as(i64, @bitCast(@as(c_long, hz + j)));
                    _ = &rz;
                    var rsq: u64 = @as(u64, @bitCast((rx * rx) + (rz * rz)));
                    _ = &rsq;
                    var v: u16 = 0;
                    _ = &v;
                    if ((rsq > @as(u64, @bitCast(@as(c_long, @as(c_int, 4096))))) and (sampleSimplex2D(&en.*.perlin, @as(f64, @floatFromInt(rx)), @as(f64, @floatFromInt(rz))) < @as(f64, @floatCast(-0.8999999761581421)))) {
                        v = @as(u16, @bitCast(@as(c_ushort, @truncate((@as(c_uint, @intFromFloat((fabsf(@as(f32, @floatFromInt(rx))) * 3439.0) + (fabsf(@as(f32, @floatFromInt(rz))) * 147.0))) % @as(c_uint, @bitCast(@as(c_int, 13)))) +% @as(c_uint, @bitCast(@as(c_int, 9)))))));
                        rx = @as(i64, @bitCast(@as(c_long, oddx - (i * @as(c_int, 2)))));
                        rz = @as(i64, @bitCast(@as(c_long, oddz - (j * @as(c_int, 2)))));
                        rsq = @as(u64, @bitCast((rx * rx) + (rz * rz)));
                        var noise: i64 = @as(i64, @bitCast((rsq *% @as(u64, @bitCast(@as(c_ulong, v)))) *% @as(u64, @bitCast(@as(c_ulong, v)))));
                        _ = &noise;
                        if (noise < h) {
                            h = noise;
                        }
                    }
                }
            }
        }
    }
    var ret: f32 = @as(f32, @floatFromInt(@as(c_int, 100))) - sqrtf(@as(f32, @floatFromInt(h)));
    _ = &ret;
    if (ret < @as(f32, @floatFromInt(-@as(c_int, 100)))) {
        ret = @as(f32, @floatFromInt(-@as(c_int, 100)));
    }
    if (ret > @as(f32, @floatFromInt(@as(c_int, 80)))) {
        ret = 80;
    }
    return ret;
}
pub fn sampleNoiseColumnEnd(arg_column: [*c]f64, arg_sn: [*c]const SurfaceNoise, arg_en: [*c]const EndNoise, arg_x: c_int, arg_z: c_int, arg_colymin: c_int, arg_colymax: c_int) void {
    var column = arg_column;
    _ = &column;
    var sn = arg_sn;
    _ = &sn;
    var en = arg_en;
    _ = &en;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var colymin = arg_colymin;
    _ = &colymin;
    var colymax = arg_colymax;
    _ = &colymax;
    const upper_drop = struct {
        const static: [33]f64 = [33]f64{
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            63.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            62.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            61.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            60.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            59.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            58.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            57.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            56.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            55.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            54.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            53.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            52.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            51.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            50.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            49.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            48.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            47.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
            46.0 / @as(f64, @floatFromInt(@as(c_int, 64))),
        };
    };
    _ = &upper_drop;
    const lower_drop = struct {
        const static: [33]f64 = [33]f64{
            0.0,
            0.0,
            1.0 / @as(f64, @floatFromInt(@as(c_int, 7))),
            2.0 / @as(f64, @floatFromInt(@as(c_int, 7))),
            3.0 / @as(f64, @floatFromInt(@as(c_int, 7))),
            4.0 / @as(f64, @floatFromInt(@as(c_int, 7))),
            5.0 / @as(f64, @floatFromInt(@as(c_int, 7))),
            6.0 / @as(f64, @floatFromInt(@as(c_int, 7))),
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
            1.0,
        };
    };
    _ = &lower_drop;
    var y: c_int = undefined;
    _ = &y;
    if (en.*.mc > MC_1_13) {
        var rsq: u64 = (@as(u64, @bitCast(@as(c_long, x))) *% @as(u64, @bitCast(@as(c_long, x)))) +% (@as(u64, @bitCast(@as(c_long, z))) *% @as(u64, @bitCast(@as(c_long, z))));
        _ = &rsq;
        if (@as(c_int, @bitCast(@as(c_uint, @truncate(rsq)))) < @as(c_int, 0)) {
            {
                y = colymin;
                while (y <= colymax) : (y += 1) {
                    (blk: {
                        const tmp = y - colymin;
                        if (tmp >= 0) break :blk column + @as(usize, @intCast(tmp)) else break :blk column - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = nan("");
                }
            }
            return;
        }
    }
    var depth: f64 = @as(f64, @floatCast(getEndHeightNoise(en, x, z, @as(c_int, 0)) - 8.0));
    _ = &depth;
    {
        y = colymin;
        while (y <= colymax) : (y += 1) {
            if (lower_drop.static[@as(c_uint, @intCast(y))] == 0.0) {
                (blk: {
                    const tmp = y - colymin;
                    if (tmp >= 0) break :blk column + @as(usize, @intCast(tmp)) else break :blk column - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).* = @as(f64, @floatFromInt(-@as(c_int, 30)));
                continue;
            }
            var noise: f64 = sampleSurfaceNoiseBetween(sn, x, y, z, @as(f64, @floatFromInt(-@as(c_int, 128))), @as(f64, @floatFromInt(@as(c_int, 128))));
            _ = &noise;
            var clamped: f64 = noise + depth;
            _ = &clamped;
            clamped = lerp(upper_drop.static[@as(c_uint, @intCast(y))], @as(f64, @floatFromInt(-@as(c_int, 3000))), clamped);
            clamped = lerp(lower_drop.static[@as(c_uint, @intCast(y))], @as(f64, @floatFromInt(-@as(c_int, 30))), clamped);
            (blk: {
                const tmp = y - colymin;
                if (tmp >= 0) break :blk column + @as(usize, @intCast(tmp)) else break :blk column - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = clamped;
        }
    }
}
pub fn getSurfaceHeight(ncol00: [*c]const f64, ncol01: [*c]const f64, ncol10: [*c]const f64, ncol11: [*c]const f64, arg_colymin: c_int, arg_colymax: c_int, arg_blockspercell: c_int, arg_dx: f64, arg_dz: f64) c_int {
    _ = &ncol00;
    _ = &ncol01;
    _ = &ncol10;
    _ = &ncol11;
    var colymin = arg_colymin;
    _ = &colymin;
    var colymax = arg_colymax;
    _ = &colymax;
    var blockspercell = arg_blockspercell;
    _ = &blockspercell;
    var dx = arg_dx;
    _ = &dx;
    var dz = arg_dz;
    _ = &dz;
    var y: c_int = undefined;
    _ = &y;
    var celly: c_int = undefined;
    _ = &celly;
    {
        celly = colymax - @as(c_int, 1);
        while (celly >= colymin) : (celly -= 1) {
            var idx: c_int = celly - colymin;
            _ = &idx;
            var v000: f64 = (blk: {
                const tmp = idx;
                if (tmp >= 0) break :blk ncol00 + @as(usize, @intCast(tmp)) else break :blk ncol00 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v000;
            var v001: f64 = (blk: {
                const tmp = idx;
                if (tmp >= 0) break :blk ncol01 + @as(usize, @intCast(tmp)) else break :blk ncol01 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v001;
            var v100: f64 = (blk: {
                const tmp = idx;
                if (tmp >= 0) break :blk ncol10 + @as(usize, @intCast(tmp)) else break :blk ncol10 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v100;
            var v101: f64 = (blk: {
                const tmp = idx;
                if (tmp >= 0) break :blk ncol11 + @as(usize, @intCast(tmp)) else break :blk ncol11 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v101;
            var v010: f64 = (blk: {
                const tmp = idx + @as(c_int, 1);
                if (tmp >= 0) break :blk ncol00 + @as(usize, @intCast(tmp)) else break :blk ncol00 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v010;
            var v011: f64 = (blk: {
                const tmp = idx + @as(c_int, 1);
                if (tmp >= 0) break :blk ncol01 + @as(usize, @intCast(tmp)) else break :blk ncol01 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v011;
            var v110: f64 = (blk: {
                const tmp = idx + @as(c_int, 1);
                if (tmp >= 0) break :blk ncol10 + @as(usize, @intCast(tmp)) else break :blk ncol10 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v110;
            var v111: f64 = (blk: {
                const tmp = idx + @as(c_int, 1);
                if (tmp >= 0) break :blk ncol11 + @as(usize, @intCast(tmp)) else break :blk ncol11 - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &v111;
            {
                y = blockspercell - @as(c_int, 1);
                while (y >= @as(c_int, 0)) : (y -= 1) {
                    var dy: f64 = @as(f64, @floatFromInt(y)) / @as(f64, @floatFromInt(blockspercell));
                    _ = &dy;
                    var noise: f64 = lerp3(dy, dx, dz, v000, v010, v100, v110, v001, v011, v101, v111);
                    _ = &noise;
                    if (noise > @as(f64, @floatFromInt(@as(c_int, 0)))) return (celly * blockspercell) + y;
                }
            }
        }
    }
    return 0;
}
pub fn init_climate_seed(arg_dpn: [*c]DoublePerlinNoise, arg_oct: [*c]PerlinNoise, arg_xlo: u64, arg_xhi: u64, arg_large: c_int, arg_nptype: c_int, arg_nmax: c_int) c_int {
    var dpn = arg_dpn;
    _ = &dpn;
    var oct = arg_oct;
    _ = &oct;
    var xlo = arg_xlo;
    _ = &xlo;
    var xhi = arg_xhi;
    _ = &xhi;
    var large = arg_large;
    _ = &large;
    var nptype = arg_nptype;
    _ = &nptype;
    var nmax = arg_nmax;
    _ = &nmax;
    var pxr: Xoroshiro = undefined;
    _ = &pxr;
    var n: c_int = 0;
    _ = &n;
    while (true) {
        switch (nptype) {
            @as(c_int, 4) => {
                {
                    const amp = struct {
                        const static: [4]f64 = [4]f64{
                            1,
                            1,
                            1,
                            0,
                        };
                    };
                    _ = &amp;
                    pxr.lo = xlo ^ @as(u64, @bitCast(@as(c_long, 577895406318539652)));
                    pxr.hi = xhi ^ @as(u64, @bitCast(@as(c_long, 4557074653038767061)));
                    n += xDoublePerlinInit(dpn, &pxr, oct, @as([*c]const f64, @ptrCast(@alignCast(&amp.static))), -@as(c_int, 3), @as(c_int, 4), nmax);
                }
                break;
            },
            @as(c_int, 0) => {
                {
                    const amp = struct {
                        const static: [6]f64 = [6]f64{
                            1.5,
                            0,
                            1,
                            0,
                            0,
                            0,
                        };
                    };
                    _ = &amp;
                    pxr.lo = xlo ^ (if (large != 0) @as(c_ulong, 10685635038780148187) else @as(c_ulong, @bitCast(@as(c_long, 6664882324328353151))));
                    pxr.hi = xhi ^ (if (large != 0) @as(c_ulong, @bitCast(@as(c_long, 5761303799458311062))) else @as(c_ulong, 17859146487254174088));
                    n += xDoublePerlinInit(dpn, &pxr, oct, @as([*c]const f64, @ptrCast(@alignCast(&amp.static))), if (large != 0) -@as(c_int, 12) else -@as(c_int, 10), @as(c_int, 6), nmax);
                }
                break;
            },
            @as(c_int, 1) => {
                {
                    const amp = struct {
                        const static: [6]f64 = [6]f64{
                            1,
                            1,
                            0,
                            0,
                            0,
                            0,
                        };
                    };
                    _ = &amp;
                    pxr.lo = xlo ^ (if (large != 0) @as(c_ulong, @bitCast(@as(c_long, 8194488175179944705))) else @as(c_ulong, 9348150263868561038));
                    pxr.hi = xhi ^ (if (large != 0) @as(c_ulong, 13502879989887892011) else @as(c_ulong, 17422373889327170509));
                    n += xDoublePerlinInit(dpn, &pxr, oct, @as([*c]const f64, @ptrCast(@alignCast(&amp.static))), if (large != 0) -@as(c_int, 10) else -@as(c_int, 8), @as(c_int, 6), nmax);
                }
                break;
            },
            @as(c_int, 2) => {
                {
                    const amp = struct {
                        const static: [9]f64 = [9]f64{
                            1,
                            1,
                            2,
                            2,
                            2,
                            1,
                            1,
                            1,
                            1,
                        };
                    };
                    _ = &amp;
                    pxr.lo = xlo ^ (if (large != 0) @as(c_ulong, 11114692157640599772) else @as(c_ulong, 9477944837549565538));
                    pxr.hi = xhi ^ (if (large != 0) @as(c_ulong, 17162581654990867885) else @as(c_ulong, 12656866088844454061));
                    n += xDoublePerlinInit(dpn, &pxr, oct, @as([*c]const f64, @ptrCast(@alignCast(&amp.static))), if (large != 0) -@as(c_int, 11) else -@as(c_int, 9), @as(c_int, 9), nmax);
                }
                break;
            },
            @as(c_int, 3) => {
                {
                    const amp = struct {
                        const static: [5]f64 = [5]f64{
                            1,
                            1,
                            0,
                            1,
                            1,
                        };
                    };
                    _ = &amp;
                    pxr.lo = xlo ^ (if (large != 0) @as(c_ulong, 10130929960551098705) else @as(c_ulong, 14998273076172386264));
                    pxr.hi = xhi ^ (if (large != 0) @as(c_ulong, 16922189808605746015) else @as(c_ulong, @bitCast(@as(c_long, 5157273775208757888))));
                    n += xDoublePerlinInit(dpn, &pxr, oct, @as([*c]const f64, @ptrCast(@alignCast(&amp.static))), if (large != 0) -@as(c_int, 11) else -@as(c_int, 9), @as(c_int, 5), nmax);
                }
                break;
            },
            @as(c_int, 5) => {
                {
                    const amp = struct {
                        const static: [6]f64 = [6]f64{
                            1,
                            2,
                            1,
                            0,
                            0,
                            0,
                        };
                    };
                    _ = &amp;
                    pxr.lo = xlo ^ @as(c_ulong, 17278323085305457460);
                    pxr.hi = xhi ^ @as(u64, @bitCast(@as(c_long, 2012804684704589034)));
                    n += xDoublePerlinInit(dpn, &pxr, oct, @as([*c]const f64, @ptrCast(@alignCast(&amp.static))), -@as(c_int, 7), @as(c_int, 6), nmax);
                }
                break;
            },
            else => {
                _ = printf("unsupported climate parameter %d\n", nptype);
                exit(@as(c_int, 1));
            },
        }
        break;
    }
    return n;
}
pub const SP_CONTINENTALNESS: c_int = 0;
pub const SP_EROSION: c_int = 1;
pub const SP_RIDGES: c_int = 2;
pub const SP_WEIRDNESS: c_int = 3;
pub fn addSplineVal(arg_rsp: [*c]Spline, arg_loc: f32, arg_val: [*c]Spline, arg_der: f32) void {
    var rsp = arg_rsp;
    _ = &rsp;
    var loc = arg_loc;
    _ = &loc;
    var val = arg_val;
    _ = &val;
    var der = arg_der;
    _ = &der;
    rsp.*.loc[@as(c_uint, @intCast(rsp.*.len))] = loc;
    rsp.*.val[@as(c_uint, @intCast(rsp.*.len))] = val;
    rsp.*.der[@as(c_uint, @intCast(rsp.*.len))] = der;
    rsp.*.len += 1;
}
pub fn createFixSpline(arg_ss: [*c]SplineStack, arg_val: f32) [*c]Spline {
    var ss = arg_ss;
    _ = &ss;
    var val = arg_val;
    _ = &val;
    var sp: [*c]FixSpline = &ss.*.fstack[@as(c_uint, @intCast(blk: {
            const ref = &ss.*.flen;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))];
    _ = &sp;
    sp.*.len = 1;
    sp.*.val = val;
    return @as([*c]Spline, @ptrCast(@alignCast(sp)));
}
pub fn getOffsetValue(arg_weirdness: f32, arg_continentalness: f32) f32 {
    var weirdness = arg_weirdness;
    _ = &weirdness;
    var continentalness = arg_continentalness;
    _ = &continentalness;
    var f0: f32 = 1.0 - ((1.0 - continentalness) * 0.5);
    _ = &f0;
    var f1: f32 = 0.5 * (1.0 - continentalness);
    _ = &f1;
    var f2: f32 = (weirdness + 1.1699999570846558) * 0.4608294665813446;
    _ = &f2;
    var off: f32 = (f2 * f0) - f1;
    _ = &off;
    if (weirdness < -0.699999988079071) return if (off > -0.22220000624656677) off else -0.22220000624656677 else return if (off > @as(f32, @floatFromInt(@as(c_int, 0)))) off else @as(f32, @floatFromInt(@as(c_int, 0)));
    return 0;
}
pub fn createSpline_38219(arg_ss: [*c]SplineStack, arg_f: f32, arg_bl: c_int) [*c]Spline {
    var ss = arg_ss;
    _ = &ss;
    var f = arg_f;
    _ = &f;
    var bl = arg_bl;
    _ = &bl;
    var sp: [*c]Spline = &ss.*.stack[@as(c_uint, @intCast(blk: {
            const ref = &ss.*.len;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))];
    _ = &sp;
    sp.*.typ = SP_RIDGES;
    var i: f32 = getOffsetValue(-1.0, f);
    _ = &i;
    var k: f32 = getOffsetValue(1.0, f);
    _ = &k;
    var l: f32 = 1.0 - ((1.0 - f) * 0.5);
    _ = &l;
    var u: f32 = 0.5 * (1.0 - f);
    _ = &u;
    l = (u / (0.4608294665813446 * l)) - 1.1699999570846558;
    if ((-0.6499999761581421 < l) and (l < 1.0)) {
        var p: f32 = undefined;
        _ = &p;
        var q: f32 = undefined;
        _ = &q;
        var r: f32 = undefined;
        _ = &r;
        var s: f32 = undefined;
        _ = &s;
        u = getOffsetValue(-0.6499999761581421, f);
        p = getOffsetValue(-0.75, f);
        q = (p - i) * 4.0;
        r = getOffsetValue(l, f);
        s = (k - r) / (1.0 - l);
        addSplineVal(sp, -1.0, createFixSpline(ss, i), q);
        addSplineVal(sp, -0.75, createFixSpline(ss, p), @as(f32, @floatFromInt(@as(c_int, 0))));
        addSplineVal(sp, -0.6499999761581421, createFixSpline(ss, u), @as(f32, @floatFromInt(@as(c_int, 0))));
        addSplineVal(sp, l - 0.009999999776482582, createFixSpline(ss, r), @as(f32, @floatFromInt(@as(c_int, 0))));
        addSplineVal(sp, l, createFixSpline(ss, r), s);
        addSplineVal(sp, 1.0, createFixSpline(ss, k), s);
    } else {
        u = (k - i) * 0.5;
        if (bl != 0) {
            addSplineVal(sp, -1.0, createFixSpline(ss, @as(f32, @floatCast(if (@as(f64, @floatCast(i)) > 0.2) @as(f64, @floatCast(i)) else 0.2))), @as(f32, @floatFromInt(@as(c_int, 0))));
            addSplineVal(sp, 0.0, createFixSpline(ss, @as(f32, @floatCast(lerp(@as(f64, @floatCast(0.5)), @as(f64, @floatCast(i)), @as(f64, @floatCast(k)))))), u);
        } else {
            addSplineVal(sp, -1.0, createFixSpline(ss, i), u);
        }
        addSplineVal(sp, 1.0, createFixSpline(ss, k), u);
    }
    return sp;
}
pub fn createFlatOffsetSpline(arg_ss: [*c]SplineStack, arg_f: f32, arg_g: f32, arg_h: f32, arg_i: f32, arg_j: f32, arg_k: f32) [*c]Spline {
    var ss = arg_ss;
    _ = &ss;
    var f = arg_f;
    _ = &f;
    var g = arg_g;
    _ = &g;
    var h = arg_h;
    _ = &h;
    var i = arg_i;
    _ = &i;
    var j = arg_j;
    _ = &j;
    var k = arg_k;
    _ = &k;
    var sp: [*c]Spline = &ss.*.stack[@as(c_uint, @intCast(blk: {
            const ref = &ss.*.len;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))];
    _ = &sp;
    sp.*.typ = SP_RIDGES;
    var l: f32 = 0.5 * (g - f);
    _ = &l;
    if (l < k) {
        l = k;
    }
    var m: f32 = 5.0 * (h - g);
    _ = &m;
    addSplineVal(sp, -1.0, createFixSpline(ss, f), l);
    addSplineVal(sp, -0.4000000059604645, createFixSpline(ss, g), if (l < m) l else m);
    addSplineVal(sp, 0.0, createFixSpline(ss, h), m);
    addSplineVal(sp, 0.4000000059604645, createFixSpline(ss, i), 2.0 * (i - h));
    addSplineVal(sp, 1.0, createFixSpline(ss, j), 0.699999988079071 * (j - i));
    return sp;
}
pub fn createLandSpline(arg_ss: [*c]SplineStack, arg_f: f32, arg_g: f32, arg_h: f32, arg_i: f32, arg_j: f32, arg_k: f32, arg_bl: c_int) [*c]Spline {
    var ss = arg_ss;
    _ = &ss;
    var f = arg_f;
    _ = &f;
    var g = arg_g;
    _ = &g;
    var h = arg_h;
    _ = &h;
    var i = arg_i;
    _ = &i;
    var j = arg_j;
    _ = &j;
    var k = arg_k;
    _ = &k;
    var bl = arg_bl;
    _ = &bl;
    var sp1: [*c]Spline = createSpline_38219(ss, @as(f32, @floatCast(lerp(@as(f64, @floatCast(i)), @as(f64, @floatCast(0.6000000238418579)), @as(f64, @floatCast(1.5))))), bl);
    _ = &sp1;
    var sp2: [*c]Spline = createSpline_38219(ss, @as(f32, @floatCast(lerp(@as(f64, @floatCast(i)), @as(f64, @floatCast(0.6000000238418579)), @as(f64, @floatCast(1.0))))), bl);
    _ = &sp2;
    var sp3: [*c]Spline = createSpline_38219(ss, i, bl);
    _ = &sp3;
    const ih: f32 = 0.5 * i;
    _ = &ih;
    var sp4: [*c]Spline = createFlatOffsetSpline(ss, f - 0.15000000596046448, ih, ih, ih, i * 0.6000000238418579, 0.5);
    _ = &sp4;
    var sp5: [*c]Spline = createFlatOffsetSpline(ss, f, j * i, g * i, ih, i * 0.6000000238418579, 0.5);
    _ = &sp5;
    var sp6: [*c]Spline = createFlatOffsetSpline(ss, f, j, j, g, h, 0.5);
    _ = &sp6;
    var sp7: [*c]Spline = createFlatOffsetSpline(ss, f, j, j, g, h, 0.5);
    _ = &sp7;
    var sp8: [*c]Spline = &ss.*.stack[@as(c_uint, @intCast(blk: {
            const ref = &ss.*.len;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))];
    _ = &sp8;
    sp8.*.typ = SP_RIDGES;
    addSplineVal(sp8, -1.0, createFixSpline(ss, f), 0.0);
    addSplineVal(sp8, -0.4000000059604645, sp6, 0.0);
    addSplineVal(sp8, 0.0, createFixSpline(ss, h + 0.07000000029802322), 0.0);
    var sp9: [*c]Spline = createFlatOffsetSpline(ss, -0.019999999552965164, k, k, g, h, 0.0);
    _ = &sp9;
    var sp: [*c]Spline = &ss.*.stack[@as(c_uint, @intCast(blk: {
            const ref = &ss.*.len;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))];
    _ = &sp;
    sp.*.typ = SP_EROSION;
    addSplineVal(sp, -0.8500000238418579, sp1, 0.0);
    addSplineVal(sp, -0.699999988079071, sp2, 0.0);
    addSplineVal(sp, -0.4000000059604645, sp3, 0.0);
    addSplineVal(sp, -0.3499999940395355, sp4, 0.0);
    addSplineVal(sp, -0.10000000149011612, sp5, 0.0);
    addSplineVal(sp, 0.20000000298023224, sp6, 0.0);
    if (bl != 0) {
        addSplineVal(sp, 0.4000000059604645, sp7, 0.0);
        addSplineVal(sp, 0.44999998807907104, sp8, 0.0);
        addSplineVal(sp, 0.550000011920929, sp8, 0.0);
        addSplineVal(sp, 0.5799999833106995, sp7, 0.0);
    }
    addSplineVal(sp, 0.699999988079071, sp9, 0.0);
    return sp;
}
pub export fn getSpline(arg_sp: [*c]const Spline, arg_vals: [*c]const f32) f32 {
    var sp = arg_sp;
    _ = &sp;
    var vals = arg_vals;
    _ = &vals;
    if ((!(sp != null) or (sp.*.len <= @as(c_int, 0))) or (sp.*.len >= @as(c_int, 12))) {
        _ = printf("getSpline(): bad parameters\n");
        exit(@as(c_int, 1));
    }
    if (sp.*.len == @as(c_int, 1)) return @as([*c]FixSpline, @ptrCast(@volatileCast(@constCast(sp)))).*.val;
    var f: f32 = (blk: {
        const tmp = sp.*.typ;
        if (tmp >= 0) break :blk vals + @as(usize, @intCast(tmp)) else break :blk vals - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &f;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i < sp.*.len) : (i += 1) if (sp.*.loc[@as(c_uint, @intCast(i))] >= f) break;
    }
    if ((i == @as(c_int, 0)) or (i == sp.*.len)) {
        if (i != 0) {
            i -= 1;
        }
        var v: f32 = getSpline(sp.*.val[@as(c_uint, @intCast(i))], vals);
        _ = &v;
        return v + (sp.*.der[@as(c_uint, @intCast(i))] * (f - sp.*.loc[@as(c_uint, @intCast(i))]));
    }
    var sp1: [*c]const Spline = sp.*.val[@as(c_uint, @intCast(i - @as(c_int, 1)))];
    _ = &sp1;
    var sp2: [*c]const Spline = sp.*.val[@as(c_uint, @intCast(i))];
    _ = &sp2;
    var g: f32 = sp.*.loc[@as(c_uint, @intCast(i - @as(c_int, 1)))];
    _ = &g;
    var h: f32 = sp.*.loc[@as(c_uint, @intCast(i))];
    _ = &h;
    var k: f32 = (f - g) / (h - g);
    _ = &k;
    var l: f32 = sp.*.der[@as(c_uint, @intCast(i - @as(c_int, 1)))];
    _ = &l;
    var m: f32 = sp.*.der[@as(c_uint, @intCast(i))];
    _ = &m;
    var n: f32 = getSpline(sp1, vals);
    _ = &n;
    var o: f32 = getSpline(sp2, vals);
    _ = &o;
    var p: f32 = (l * (h - g)) - (o - n);
    _ = &p;
    var q: f32 = (-m * (h - g)) + (o - n);
    _ = &q;
    var r: f32 = @as(f32, @floatCast(lerp(@as(f64, @floatCast(k)), @as(f64, @floatCast(n)), @as(f64, @floatCast(o))) + (@as(f64, @floatCast(k * (1.0 - k))) * lerp(@as(f64, @floatCast(k)), @as(f64, @floatCast(p)), @as(f64, @floatCast(q))))));
    _ = &r;
    return r;
}
pub fn get_np_dist(np: [*c]const u64, arg_bt: [*c]const BiomeTree, arg_idx: c_int) u64 {
    _ = &np;
    var bt = arg_bt;
    _ = &bt;
    var idx = arg_idx;
    _ = &idx;
    var ds: u64 = 0;
    _ = &ds;
    var node: u64 = (blk: {
        const tmp = idx;
        if (tmp >= 0) break :blk bt.*.nodes + @as(usize, @intCast(tmp)) else break :blk bt.*.nodes - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &node;
    var a: u64 = undefined;
    _ = &a;
    var b: u64 = undefined;
    _ = &b;
    var d: u64 = undefined;
    _ = &d;
    var i: u32 = undefined;
    _ = &i;
    {
        i = 0;
        while (i < @as(u32, @bitCast(@as(c_int, 6)))) : (i +%= 1) {
            idx = @as(c_int, @bitCast(@as(c_uint, @truncate((node >> @intCast(@as(u32, @bitCast(@as(c_int, 8))) *% i)) & @as(u64, @bitCast(@as(c_long, @as(c_int, 255))))))));
            a = np[i] -% @as(u64, @bitCast(@as(c_long, (blk: {
                const tmp = (@as(c_int, 2) * idx) + @as(c_int, 1);
                if (tmp >= 0) break :blk bt.*.param + @as(usize, @intCast(tmp)) else break :blk bt.*.param - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*)));
            b = @as(u64, @bitCast(@as(c_long, (blk: {
                const tmp = (@as(c_int, 2) * idx) + @as(c_int, 0);
                if (tmp >= 0) break :blk bt.*.param + @as(usize, @intCast(tmp)) else break :blk bt.*.param - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*))) -% np[i];
            d = if (@as(i64, @bitCast(a)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) a else if (@as(i64, @bitCast(b)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) b else @as(u64, @bitCast(@as(c_long, @as(c_int, 0))));
            d = d *% d;
            ds +%= d;
        }
    }
    return ds;
}
pub fn get_resulting_node(np: [*c]const u64, arg_bt: [*c]const BiomeTree, arg_idx: c_int, arg_alt: c_int, arg_ds: u64, arg_depth: c_int) c_int {
    _ = &np;
    var bt = arg_bt;
    _ = &bt;
    var idx = arg_idx;
    _ = &idx;
    var alt = arg_alt;
    _ = &alt;
    var ds = arg_ds;
    _ = &ds;
    var depth = arg_depth;
    _ = &depth;
    if ((blk: {
        const tmp = depth;
        if (tmp >= 0) break :blk bt.*.steps + @as(usize, @intCast(tmp)) else break :blk bt.*.steps - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* == @as(u32, @bitCast(@as(c_int, 0)))) return idx;
    var step: u32 = undefined;
    _ = &step;
    while (true) {
        step = (blk: {
            const tmp = depth;
            if (tmp >= 0) break :blk bt.*.steps + @as(usize, @intCast(tmp)) else break :blk bt.*.steps - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
        depth += 1;
        if (!((@as(u32, @bitCast(idx)) +% step) >= bt.*.len)) break;
    }
    var node: u64 = (blk: {
        const tmp = idx;
        if (tmp >= 0) break :blk bt.*.nodes + @as(usize, @intCast(tmp)) else break :blk bt.*.nodes - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &node;
    var inner: u16 = @as(u16, @bitCast(@as(c_ushort, @truncate(node >> @intCast(48)))));
    _ = &inner;
    var leaf: c_int = alt;
    _ = &leaf;
    var i: u32 = undefined;
    _ = &i;
    var n: u32 = undefined;
    _ = &n;
    {
        _ = blk: {
            i = 0;
            break :blk blk_1: {
                const tmp = bt.*.order;
                n = tmp;
                break :blk_1 tmp;
            };
        };
        while (i < n) : (i +%= 1) {
            var ds_inner: u64 = get_np_dist(np, bt, @as(c_int, @bitCast(@as(c_uint, inner))));
            _ = &ds_inner;
            if (ds_inner < ds) {
                var leaf2: c_int = get_resulting_node(np, bt, @as(c_int, @bitCast(@as(c_uint, inner))), leaf, ds, depth);
                _ = &leaf2;
                var ds_leaf2: u64 = undefined;
                _ = &ds_leaf2;
                if (@as(c_int, @bitCast(@as(c_uint, inner))) == leaf2) {
                    ds_leaf2 = ds_inner;
                } else {
                    ds_leaf2 = get_np_dist(np, bt, leaf2);
                }
                if (ds_leaf2 < ds) {
                    ds = ds_leaf2;
                    leaf = leaf2;
                }
            }
            inner +%= @as(u16, @bitCast(@as(c_ushort, @truncate(step))));
            if (@as(u32, @bitCast(@as(c_uint, inner))) >= bt.*.len) break;
        }
    }
    return leaf;
}
pub fn genBiomeNoise3D(arg_bn: [*c]const BiomeNoise, arg_out: [*c]c_int, arg_r: Range, arg_opt: c_int) void {
    var bn = arg_bn;
    _ = &bn;
    var out = arg_out;
    _ = &out;
    var r = arg_r;
    _ = &r;
    var opt = arg_opt;
    _ = &opt;
    var dat: u64 = 0;
    _ = &dat;
    var p_dat: [*c]u64 = if (opt != 0) &dat else null;
    _ = &p_dat;
    var flags: u32 = @as(u32, @bitCast(if (opt != 0) SAMPLE_NO_SHIFT else @as(c_int, 0)));
    _ = &flags;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var k: c_int = undefined;
    _ = &k;
    var p: [*c]c_int = out;
    _ = &p;
    var scale: c_int = if (r.scale > @as(c_int, 4)) @divTrunc(r.scale, @as(c_int, 4)) else @as(c_int, 1);
    _ = &scale;
    var mid: c_int = @divTrunc(scale, @as(c_int, 2));
    _ = &mid;
    {
        k = 0;
        while (k < r.sy) : (k += 1) {
            var yk: c_int = r.y + k;
            _ = &yk;
            {
                j = 0;
                while (j < r.sz) : (j += 1) {
                    var zj: c_int = ((r.z + j) * scale) + mid;
                    _ = &zj;
                    {
                        i = 0;
                        while (i < r.sx) : (i += 1) {
                            var xi: c_int = ((r.x + i) * scale) + mid;
                            _ = &xi;
                            p.* = sampleBiomeNoise(bn, null, xi, yk, zj, p_dat, flags);
                            p += 1;
                        }
                    }
                }
            }
        }
    }
}
pub fn genColumnNoise(arg_snb: [*c]const SurfaceNoiseBeta, arg_dest: [*c]SeaLevelColumnNoiseBeta, arg_cx: f64, arg_cz: f64, arg_lacmin: f64) void {
    var snb = arg_snb;
    _ = &snb;
    var dest = arg_dest;
    _ = &dest;
    var cx = arg_cx;
    _ = &cx;
    var cz = arg_cz;
    _ = &cz;
    var lacmin = arg_lacmin;
    _ = &lacmin;
    dest.*.contASample = sampleOctaveAmp(&snb.*.octcontA, cx, @as(f64, @floatFromInt(@as(c_int, 0))), cz, @as(f64, @floatFromInt(@as(c_int, 0))), @as(f64, @floatFromInt(@as(c_int, 0))), @as(c_int, 1));
    dest.*.contBSample = sampleOctaveAmp(&snb.*.octcontB, cx, @as(f64, @floatFromInt(@as(c_int, 0))), cz, @as(f64, @floatFromInt(@as(c_int, 0))), @as(f64, @floatFromInt(@as(c_int, 0))), @as(c_int, 1));
    sampleOctaveBeta17Terrain(&snb.*.octmin, @as([*c]f64, @ptrCast(@alignCast(&dest.*.minSample))), cx, cz, @as(c_int, 0), lacmin);
    sampleOctaveBeta17Terrain(&snb.*.octmax, @as([*c]f64, @ptrCast(@alignCast(&dest.*.maxSample))), cx, cz, @as(c_int, 0), lacmin);
    sampleOctaveBeta17Terrain(&snb.*.octmain, @as([*c]f64, @ptrCast(@alignCast(&dest.*.mainSample))), cx, cz, @as(c_int, 1), lacmin);
}
pub fn processColumnNoise(arg_out: [*c]f64, arg_src: [*c]const SeaLevelColumnNoiseBeta, climate: [*c]const f64) void {
    var out = arg_out;
    _ = &out;
    var src = arg_src;
    _ = &src;
    _ = &climate;
    var humi: f64 = @as(f64, @floatFromInt(@as(c_int, 1))) - (climate[@as(c_uint, @intCast(@as(c_int, 0)))] * climate[@as(c_uint, @intCast(@as(c_int, 1)))]);
    _ = &humi;
    humi *= humi;
    humi *= humi;
    humi = @as(f64, @floatFromInt(@as(c_int, 1))) - humi;
    var contA: f64 = ((src.*.contASample + @as(f64, @floatFromInt(@as(c_int, 256)))) / @as(f64, @floatFromInt(@as(c_int, 512)))) * humi;
    _ = &contA;
    contA = if (contA > @as(f64, @floatFromInt(@as(c_int, 1)))) 1.0 else contA;
    var contB: f64 = src.*.contBSample / @as(f64, @floatFromInt(@as(c_int, 8000)));
    _ = &contB;
    if (contB < @as(f64, @floatFromInt(@as(c_int, 0)))) {
        contB = -contB * 0.3;
    }
    contB = (contB * @as(f64, @floatFromInt(@as(c_int, 3)))) - @as(f64, @floatFromInt(@as(c_int, 2)));
    if (contB < @as(f64, @floatFromInt(@as(c_int, 0)))) {
        contB /= @as(f64, @floatFromInt(@as(c_int, 2)));
        contB = if (contB < @as(f64, @floatFromInt(-@as(c_int, 1)))) (-1.0 / 1.4) / @as(f64, @floatFromInt(@as(c_int, 2))) else (contB / 1.4) / @as(f64, @floatFromInt(@as(c_int, 2)));
        contA = 0;
    } else {
        contB = if (contB > @as(f64, @floatFromInt(@as(c_int, 1)))) 1.0 / @as(f64, @floatFromInt(@as(c_int, 8))) else contB / @as(f64, @floatFromInt(@as(c_int, 8)));
    }
    contA = if (contA < @as(f64, @floatFromInt(@as(c_int, 0)))) 0.5 else contA + 0.5;
    contB = (contB * 17.0) / @as(f64, @floatFromInt(@as(c_int, 16)));
    contB = (17.0 / @as(f64, @floatFromInt(@as(c_int, 2)))) + (contB * @as(f64, @floatFromInt(@as(c_int, 4))));
    var low: [*c]const f64 = @as([*c]const f64, @ptrCast(@alignCast(&src.*.minSample)));
    _ = &low;
    var high: [*c]const f64 = @as([*c]const f64, @ptrCast(@alignCast(&src.*.maxSample)));
    _ = &high;
    var selector: [*c]const f64 = @as([*c]const f64, @ptrCast(@alignCast(&src.*.mainSample)));
    _ = &selector;
    var i: c_int = undefined;
    _ = &i;
    {
        i = 0;
        while (i <= @as(c_int, 1)) : (i += 1) {
            var chooseLHS: f64 = undefined;
            _ = &chooseLHS;
            var procCont: f64 = ((@as(f64, @floatFromInt(i + @as(c_int, 7))) - contB) * @as(f64, @floatFromInt(@as(c_int, 12)))) / contA;
            _ = &procCont;
            procCont = if (procCont < @as(f64, @floatFromInt(@as(c_int, 0)))) procCont * @as(f64, @floatFromInt(@as(c_int, 4))) else procCont;
            var lSample: f64 = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk low + @as(usize, @intCast(tmp)) else break :blk low - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* / @as(f64, @floatFromInt(@as(c_int, 512)));
            _ = &lSample;
            var hSample: f64 = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk high + @as(usize, @intCast(tmp)) else break :blk high - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* / @as(f64, @floatFromInt(@as(c_int, 512)));
            _ = &hSample;
            var sSample: f64 = (((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk selector + @as(usize, @intCast(tmp)) else break :blk selector - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* / @as(f64, @floatFromInt(@as(c_int, 10)))) + @as(f64, @floatFromInt(@as(c_int, 1)))) / @as(f64, @floatFromInt(@as(c_int, 2)));
            _ = &sSample;
            chooseLHS = if (sSample < 0.0) lSample else if (sSample > @as(f64, @floatFromInt(@as(c_int, 1)))) hSample else lSample + ((hSample - lSample) * sSample);
            chooseLHS -= procCont;
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = chooseLHS;
        }
    }
}
pub fn lerp4(a: [*c]const f64, b: [*c]const f64, c: [*c]const f64, d: [*c]const f64, arg_dy: f64, arg_dx: f64, arg_dz: f64) f64 {
    _ = &a;
    _ = &b;
    _ = &c;
    _ = &d;
    var dy = arg_dy;
    _ = &dy;
    var dx = arg_dx;
    _ = &dx;
    var dz = arg_dz;
    _ = &dz;
    var b00: f64 = a[@as(c_uint, @intCast(@as(c_int, 0)))] + ((a[@as(c_uint, @intCast(@as(c_int, 1)))] - a[@as(c_uint, @intCast(@as(c_int, 0)))]) * dy);
    _ = &b00;
    var b01: f64 = b[@as(c_uint, @intCast(@as(c_int, 0)))] + ((b[@as(c_uint, @intCast(@as(c_int, 1)))] - b[@as(c_uint, @intCast(@as(c_int, 0)))]) * dy);
    _ = &b01;
    var b10: f64 = c[@as(c_uint, @intCast(@as(c_int, 0)))] + ((c[@as(c_uint, @intCast(@as(c_int, 1)))] - c[@as(c_uint, @intCast(@as(c_int, 0)))]) * dy);
    _ = &b10;
    var b11: f64 = d[@as(c_uint, @intCast(@as(c_int, 0)))] + ((d[@as(c_uint, @intCast(@as(c_int, 1)))] - d[@as(c_uint, @intCast(@as(c_int, 0)))]) * dy);
    _ = &b11;
    var b0: f64 = b00 + ((b10 - b00) * dz);
    _ = &b0;
    var b1: f64 = b01 + ((b11 - b01) * dz);
    _ = &b1;
    return b0 + ((b1 - b0) * dx);
}
pub const LARGE_BIOMES: c_int = 1;
pub const NO_BETA_OCEAN: c_int = 2;
pub const FORCE_OCEAN_VARIANTS: c_int = 4;
const struct_unnamed_17 = extern struct {
    ls: LayerStack = @import("std").mem.zeroes(LayerStack),
    xlayer: [5]Layer = @import("std").mem.zeroes([5]Layer),
    entry: [*c]Layer = @import("std").mem.zeroes([*c]Layer),
};
const struct_unnamed_18 = extern struct {
    bn: BiomeNoise = @import("std").mem.zeroes(BiomeNoise),
};
const struct_unnamed_19 = extern struct {
    bnb: BiomeNoiseBeta = @import("std").mem.zeroes(BiomeNoiseBeta),
};
const union_unnamed_16 = extern union {
    unnamed_0: struct_unnamed_17,
    unnamed_1: struct_unnamed_18,
    unnamed_2: struct_unnamed_19,
};
pub const struct_Generator = extern struct {
    mc: c_int = @import("std").mem.zeroes(c_int),
    dim: c_int = @import("std").mem.zeroes(c_int),
    flags: u32 = @import("std").mem.zeroes(u32),
    seed: u64 = @import("std").mem.zeroes(u64),
    sha: u64 = @import("std").mem.zeroes(u64),
    unnamed_0: union_unnamed_16 = @import("std").mem.zeroes(union_unnamed_16),
    nn: NetherNoise = @import("std").mem.zeroes(NetherNoise),
    en: EndNoise = @import("std").mem.zeroes(EndNoise),
};
pub const Generator = struct_Generator;
pub export fn setupGenerator(arg_g: [*c]Generator, arg_mc: c_int, arg_flags: u32) void {
    var g = arg_g;
    _ = &g;
    var mc = arg_mc;
    _ = &mc;
    var flags = arg_flags;
    _ = &flags;
    g.*.mc = mc;
    g.*.dim = DIM_UNDEF;
    g.*.flags = flags;
    g.*.seed = 0;
    g.*.sha = 0;
    if ((mc >= MC_B1_8) and (mc <= MC_1_17)) {
        setupLayerStack(&g.*.unnamed_0.unnamed_0.ls, mc, @as(c_int, @bitCast(flags & @as(u32, @bitCast(LARGE_BIOMES)))));
        g.*.unnamed_0.unnamed_0.entry = null;
        if (((flags & @as(u32, @bitCast(FORCE_OCEAN_VARIANTS))) != 0) and (mc >= MC_1_13)) {
            g.*.unnamed_0.unnamed_0.ls.entry_16 = setupLayer(@as([*c]Layer, @ptrCast(@alignCast(&g.*.unnamed_0.unnamed_0.xlayer))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2))))), &mapOceanMixMod, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 0)))), g.*.unnamed_0.unnamed_0.ls.entry_16, &g.*.unnamed_0.unnamed_0.ls.layers[@as(c_uint, @intCast(L_ZOOM_16_OCEAN))]);
            g.*.unnamed_0.unnamed_0.ls.entry_64 = setupLayer(@as([*c]Layer, @ptrCast(@alignCast(&g.*.unnamed_0.unnamed_0.xlayer))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 3))))), &mapOceanMixMod, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 0)))), g.*.unnamed_0.unnamed_0.ls.entry_64, &g.*.unnamed_0.unnamed_0.ls.layers[@as(c_uint, @intCast(L_ZOOM_64_OCEAN))]);
            g.*.unnamed_0.unnamed_0.ls.entry_256 = setupLayer(@as([*c]Layer, @ptrCast(@alignCast(&g.*.unnamed_0.unnamed_0.xlayer))) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 4))))), &mapOceanMixMod, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 0)))), g.*.unnamed_0.unnamed_0.ls.entry_256, &g.*.unnamed_0.unnamed_0.ls.layers[@as(c_uint, @intCast(L_OCEAN_TEMP_256))]);
        }
    } else if (mc >= MC_1_18) {
        initBiomeNoise(&g.*.unnamed_0.unnamed_1.bn, mc);
    } else {
        g.*.unnamed_0.unnamed_2.bnb.mc = mc;
    }
}
pub export fn applySeed(arg_g: [*c]Generator, arg_dim: c_int, arg_seed: u64) void {
    var g = arg_g;
    _ = &g;
    var dim = arg_dim;
    _ = &dim;
    var seed = arg_seed;
    _ = &seed;
    g.*.dim = dim;
    g.*.seed = seed;
    g.*.sha = 0;
    if (dim == DIM_OVERWORLD) {
        if (g.*.mc <= MC_B1_7) {
            setBetaBiomeSeed(&g.*.unnamed_0.unnamed_2.bnb, seed);
        } else if (g.*.mc <= MC_1_17) {
            setLayerSeed(if (g.*.unnamed_0.unnamed_0.entry != null) g.*.unnamed_0.unnamed_0.entry else g.*.unnamed_0.unnamed_0.ls.entry_1, seed);
        } else {
            setBiomeSeed(&g.*.unnamed_0.unnamed_1.bn, seed, @as(c_int, @bitCast(g.*.flags & @as(u32, @bitCast(LARGE_BIOMES)))));
        }
    } else if ((dim == DIM_NETHER) and (g.*.mc >= MC_1_16_1)) {
        setNetherSeed(&g.*.nn, seed);
    } else if ((dim == DIM_END) and (g.*.mc >= MC_1_9)) {
        setEndSeed(&g.*.en, g.*.mc, seed);
    }
    if (g.*.mc >= MC_1_15) {
        if (((g.*.mc <= MC_1_17) and (dim == DIM_OVERWORLD)) and !(g.*.unnamed_0.unnamed_0.entry != null)) {
            g.*.sha = g.*.unnamed_0.unnamed_0.ls.entry_1.*.startSalt;
        } else {
            g.*.sha = getVoronoiSHA(seed);
        }
    }
}
pub fn getMinCacheSize(arg_g: [*c]const Generator, arg_scale: c_int, arg_sx: c_int, arg_sy: c_int, arg_sz: c_int) usize {
    var g = arg_g;
    _ = &g;
    var scale = arg_scale;
    _ = &scale;
    var sx = arg_sx;
    _ = &sx;
    var sy = arg_sy;
    _ = &sy;
    var sz = arg_sz;
    _ = &sz;
    if (sy == @as(c_int, 0)) {
        sy = 1;
    }
    var len: usize = (@as(usize, @bitCast(@as(c_long, sx))) *% @as(usize, @bitCast(@as(c_long, sz)))) *% @as(usize, @bitCast(@as(c_long, sy)));
    _ = &len;
    if (((g.*.mc <= MC_B1_7) and (scale <= @as(c_int, 4))) and !((g.*.flags & @as(u32, @bitCast(NO_BETA_OCEAN))) != 0)) {
        var cellwidth: c_int = scale >> @intCast(1);
        _ = &cellwidth;
        var smin: c_int = if (sx < sz) sx else sz;
        _ = &smin;
        var slen: c_int = (((smin >> @intCast(@as(c_int, 2) >> @intCast(cellwidth))) + @as(c_int, 1)) * @as(c_int, 2)) + @as(c_int, 1);
        _ = &slen;
        len +%= @as(usize, @bitCast(@as(c_ulong, @bitCast(@as(c_long, slen))) *% @sizeOf(SeaLevelColumnNoiseBeta)));
    } else if (((g.*.mc >= MC_B1_8) and (g.*.mc <= MC_1_17)) and (g.*.dim == DIM_OVERWORLD)) {
        var entry: [*c]const Layer = getLayerForScale(g, scale);
        _ = &entry;
        if (!(entry != null)) {
            _ = printf("getMinCacheSize(): failed to determine scaled entry\n");
            return 0;
        }
        var len2d: usize = getMinLayerCacheSize(entry, sx, sz);
        _ = &len2d;
        len +%= len2d -% @as(usize, @bitCast(@as(c_long, sx * sz)));
    } else if (((g.*.mc >= MC_1_18) or (g.*.dim != DIM_OVERWORLD)) and (scale <= @as(c_int, 1))) {
        sx = ((sx + @as(c_int, 3)) >> @intCast(2)) + @as(c_int, 2);
        sy = ((sy + @as(c_int, 3)) >> @intCast(2)) + @as(c_int, 2);
        sz = ((sz + @as(c_int, 3)) >> @intCast(2)) + @as(c_int, 2);
        len +%= @as(usize, @bitCast(@as(c_long, (sx * sy) * sz)));
    }
    return len;
}
pub export fn allocCache(arg_g: [*c]const Generator, arg_r: Range) [*c]c_int {
    var g = arg_g;
    _ = &g;
    var r = arg_r;
    _ = &r;
    var len: usize = getMinCacheSize(g, r.scale, r.sx, r.sy, r.sz);
    _ = &len;
    if (len == @as(usize, @bitCast(@as(c_long, @as(c_int, 0))))) return null;
    return @as([*c]c_int, @ptrCast(@alignCast(calloc(len, @sizeOf(c_int)))));
}
pub export fn genBiomes(arg_g: [*c]const Generator, arg_cache: [*c]c_int, arg_r: Range) c_int {
    var g = arg_g;
    _ = &g;
    var cache = arg_cache;
    _ = &cache;
    var r = arg_r;
    _ = &r;
    var err: c_int = 1;
    _ = &err;
    var i: i64 = undefined;
    _ = &i;
    var k: i64 = undefined;
    _ = &k;
    if (g.*.dim == DIM_OVERWORLD) {
        if ((g.*.mc >= MC_B1_8) and (g.*.mc <= MC_1_17)) {
            var entry: [*c]const Layer = getLayerForScale(g, r.scale);
            _ = &entry;
            if (!(entry != null)) return -@as(c_int, 1);
            err = genArea(entry, cache, r.x, r.z, r.sx, r.sz);
            if (err != 0) return err;
            {
                k = 1;
                while (k < @as(i64, @bitCast(@as(c_long, r.sy)))) : (k += 1) {
                    {
                        i = 0;
                        while (i < @as(i64, @bitCast(@as(c_long, r.sx * r.sz)))) : (i += 1) {
                            (blk: {
                                const tmp = ((k * @as(i64, @bitCast(@as(c_long, r.sx)))) * @as(i64, @bitCast(@as(c_long, r.sz)))) + i;
                                if (tmp >= 0) break :blk cache + @as(usize, @intCast(tmp)) else break :blk cache - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = (blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk cache + @as(usize, @intCast(tmp)) else break :blk cache - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*;
                        }
                    }
                }
            }
            return 0;
        } else if (g.*.mc >= MC_1_18) {
            return genBiomeNoiseScaled(&g.*.unnamed_0.unnamed_1.bn, cache, r, g.*.sha);
        } else {
            if ((g.*.flags & @as(u32, @bitCast(NO_BETA_OCEAN))) != 0) {
                err = genBiomeNoiseBetaScaled(&g.*.unnamed_0.unnamed_2.bnb, null, cache, r);
            } else {
                var snb: SurfaceNoiseBeta = undefined;
                _ = &snb;
                initSurfaceNoiseBeta(&snb, g.*.seed);
                err = genBiomeNoiseBetaScaled(&g.*.unnamed_0.unnamed_2.bnb, &snb, cache, r);
            }
            if (err != 0) return err;
            {
                k = 1;
                while (k < @as(i64, @bitCast(@as(c_long, r.sy)))) : (k += 1) {
                    {
                        i = 0;
                        while (i < @as(i64, @bitCast(@as(c_long, r.sx * r.sz)))) : (i += 1) {
                            (blk: {
                                const tmp = ((k * @as(i64, @bitCast(@as(c_long, r.sx)))) * @as(i64, @bitCast(@as(c_long, r.sz)))) + i;
                                if (tmp >= 0) break :blk cache + @as(usize, @intCast(tmp)) else break :blk cache - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = (blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk cache + @as(usize, @intCast(tmp)) else break :blk cache - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*;
                        }
                    }
                }
            }
            return 0;
        }
    } else if (g.*.dim == DIM_NETHER) {
        return genNetherScaled(&g.*.nn, cache, r, g.*.mc, g.*.sha);
    } else if (g.*.dim == DIM_END) {
        return genEndScaled(&g.*.en, cache, r, g.*.mc, g.*.sha);
    }
    return err;
}
pub export fn getBiomeAt(arg_g: [*c]const Generator, arg_scale: c_int, arg_x: c_int, arg_y: c_int, arg_z: c_int) c_int {
    var g = arg_g;
    _ = &g;
    var scale = arg_scale;
    _ = &scale;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var r: Range = Range{
        .scale = scale,
        .x = x,
        .z = z,
        .sx = @as(c_int, 1),
        .sz = @as(c_int, 1),
        .y = y,
        .sy = @as(c_int, 1),
    };
    _ = &r;
    var ids: [*c]c_int = allocCache(g, r);
    _ = &ids;
    var id: c_int = genBiomes(g, ids, r);
    _ = &id;
    if (id == @as(c_int, 0)) {
        id = ids[@as(c_uint, @intCast(@as(c_int, 0)))];
    } else {
        id = none;
    }
    free(@as(?*anyopaque, @ptrCast(ids)));
    return id;
}
pub fn getLayerForScale(arg_g: [*c]const Generator, arg_scale: c_int) [*c]const Layer {
    var g = arg_g;
    _ = &g;
    var scale = arg_scale;
    _ = &scale;
    if (g.*.mc > MC_1_17) return null;
    while (true) {
        switch (scale) {
            @as(c_int, 0) => return g.*.unnamed_0.unnamed_0.entry,
            @as(c_int, 1) => return g.*.unnamed_0.unnamed_0.ls.entry_1,
            @as(c_int, 4) => return g.*.unnamed_0.unnamed_0.ls.entry_4,
            @as(c_int, 16) => return g.*.unnamed_0.unnamed_0.ls.entry_16,
            @as(c_int, 64) => return g.*.unnamed_0.unnamed_0.ls.entry_64,
            @as(c_int, 256) => return g.*.unnamed_0.unnamed_0.ls.entry_256,
            else => return null,
        }
        break;
    }
    return null;
}
pub fn setupLayerStack(arg_g: [*c]LayerStack, arg_mc: c_int, arg_largeBiomes: c_int) void {
    var g = arg_g;
    _ = &g;
    var mc = arg_mc;
    _ = &mc;
    var largeBiomes = arg_largeBiomes;
    _ = &largeBiomes;
    if (mc < MC_1_3) {
        largeBiomes = 0;
    }
    _ = memset(@as(?*anyopaque, @ptrCast(g)), @as(c_int, 0), @sizeOf(LayerStack));
    var p: [*c]Layer = undefined;
    _ = &p;
    var l: [*c]Layer = @as([*c]Layer, @ptrCast(@alignCast(&g.*.layers)));
    _ = &l;
    var map_land: ?*const mapfunc_t = null;
    _ = &map_land;
    if (mc == MC_B1_8) {
        map_land = &mapLandB18;
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_CONTINENT_4096)))), &mapContinent, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), null, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4096)))), &mapZoomFuzzy, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_4096)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_2048)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_2048)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_1024)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_1024_A)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_512)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2003)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_512)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_256)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2004)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_256)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_BIOME_256)))), &mapBiome, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 200)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_NOISE_256)))), &mapNoise, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 100)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_256)))), null);
    } else if (mc <= MC_1_6) {
        map_land = &mapLand16;
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_CONTINENT_4096)))), &mapContinent, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), null, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_2048)))), &mapZoomFuzzy, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_2048)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_1024)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_1024_A)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SNOW_1024)))), &mapSnow16, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_512)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_512)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_256)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2003)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_256)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 4)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_MUSHROOM_256)))), &mapMushroom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 5)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_BIOME_256)))), &mapBiome, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 200)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_NOISE_256)))), &mapNoise, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 100)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_MUSHROOM_256)))), null);
    } else {
        map_land = &mapLand;
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_CONTINENT_4096)))), &mapContinent, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), null, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_2048)))), &mapZoomFuzzy, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_2048)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_1024)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_1024_A)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_1024_B)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 50)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_1024_C)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 70)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ISLAND_1024)))), &mapIsland, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SNOW_1024)))), &mapSnow, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_1024_D)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_COOL_1024)))), &mapCool, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_HEAT_1024)))), &mapHeat, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SPECIAL_1024)))), &mapSpecial, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_512)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_256)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2003)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_256)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 4)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_MUSHROOM_256)))), &mapMushroom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 5)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_DEEP_OCEAN_256)))), &mapDeepOcean, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 4)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_BIOME_256)))), &mapBiome, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 200)))), p, null);
        if (mc >= MC_1_14) {
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_BAMBOO_256)))), &mapBamboo, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        }
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_BIOME_EDGE_64)))), &mapBiomeEdge, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_RIVER_INIT_256)))), &mapNoise, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 100)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_DEEP_OCEAN_256)))), null);
    }
    if (mc <= MC_1_0) {} else if (mc <= MC_1_12) {
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128_HILLS)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 0)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_HILLS)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 0)))), p, null);
    } else {
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128_HILLS)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_HILLS)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
    }
    if (mc <= MC_1_0) {
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_32)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64)))), null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_32)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SHORE_16)))), &mapShore, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_8)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1003)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4)))), &mapSmooth, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_NOISE_256)))), null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_32_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1003)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_8_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1004)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1005)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_RIVER_4)))), &mapRiver, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4_RIVER)))), &mapSmooth, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
    } else if (mc <= MC_1_6) {
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_HILLS_64)))), &mapHills, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_HILLS)))));
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_32)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_32)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SHORE_16)))), &mapShore, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SWAMP_RIVER_16)))), &mapSwampRiver, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_8)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1003)))), p, null);
        if (largeBiomes != 0) {
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_LARGE_A)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1004)))), p, null);
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_LARGE_B)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1005)))), p, null);
        }
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4)))), &mapSmooth, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_NOISE_256)))), null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_32_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1003)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_8_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1004)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1005)))), p, null);
        if (largeBiomes != 0) {
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_L_RIVER_A)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1006)))), p, null);
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_L_RIVER_B)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1007)))), p, null);
        }
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_RIVER_4)))), &mapRiver, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4_RIVER)))), &mapSmooth, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
    } else {
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_HILLS_64)))), &mapHills, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_BIOME_EDGE_64)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_HILLS)))));
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SUNFLOWER_64)))), &mapSunflower, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_32)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_LAND_32)))), map_land, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 3)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SHORE_16)))), &mapShore, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_8)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1003)))), p, null);
        if (largeBiomes != 0) {
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_LARGE_A)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1004)))), p, null);
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_LARGE_B)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1005)))), p, null);
        }
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4)))), &mapSmooth, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_RIVER_INIT_256)))), null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_32_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_8_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4_RIVER)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1003)))), p, null);
        if ((largeBiomes != 0) and (mc == MC_1_7)) {
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_L_RIVER_A)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1004)))), p, null);
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_L_RIVER_B)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1005)))), p, null);
        }
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_RIVER_4)))), &mapRiver, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4_RIVER)))), &mapSmooth, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 1000)))), p, null);
    }
    p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_RIVER_MIX_4)))), &mapRiverMix, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 100)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_SMOOTH_4_RIVER)))));
    if (mc <= MC_1_12) {
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_VORONOI_1)))), &mapVoronoi114, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 4))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 10)))), p, null);
    } else {
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_OCEAN_TEMP_256)))), &mapOceanTemp, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2)))), null, null);
        p.*.noise = @as(?*anyopaque, @ptrCast(&g.*.oceanRnd));
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_128_OCEAN)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2001)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64_OCEAN)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2002)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_32_OCEAN)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2003)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16_OCEAN)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2004)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_8_OCEAN)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2005)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4_OCEAN)))), &mapZoom, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 2006)))), p, null);
        p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_OCEAN_MIX_4)))), &mapOceanMix, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 17))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 100)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_RIVER_MIX_4)))), l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4_OCEAN)))));
        if (mc <= MC_1_14) {
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_VORONOI_1)))), &mapVoronoi114, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 4))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_long, @as(c_int, 10)))), p, null);
        } else {
            p = setupLayer(l + @as(usize, @bitCast(@as(isize, @intCast(L_VORONOI_1)))), &mapVoronoi, mc, @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 4))))), @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 3))))), @as(u64, @bitCast(@as(c_ulong, @truncate(~@as(c_ulonglong, 0))))), p, null);
        }
    }
    g.*.entry_1 = p;
    g.*.entry_4 = l + @as(usize, @bitCast(@as(isize, @intCast(if (mc <= MC_1_12) L_RIVER_MIX_4 else L_OCEAN_MIX_4))));
    if (largeBiomes != 0) {
        g.*.entry_16 = l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_4))));
        g.*.entry_64 = l + @as(usize, @bitCast(@as(isize, @intCast(if (mc <= MC_1_6) L_SWAMP_RIVER_16 else L_SHORE_16))));
        g.*.entry_256 = l + @as(usize, @bitCast(@as(isize, @intCast(if (mc <= MC_1_6) L_HILLS_64 else L_SUNFLOWER_64))));
    } else if (mc >= MC_1_1) {
        g.*.entry_16 = l + @as(usize, @bitCast(@as(isize, @intCast(if (mc <= MC_1_6) L_SWAMP_RIVER_16 else L_SHORE_16))));
        g.*.entry_64 = l + @as(usize, @bitCast(@as(isize, @intCast(if (mc <= MC_1_6) L_HILLS_64 else L_SUNFLOWER_64))));
        g.*.entry_256 = l + @as(usize, @bitCast(@as(isize, @intCast(if (mc <= MC_1_14) L_BIOME_256 else L_BAMBOO_256))));
    } else {
        g.*.entry_16 = l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_16))));
        g.*.entry_64 = l + @as(usize, @bitCast(@as(isize, @intCast(L_ZOOM_64))));
        g.*.entry_256 = l + @as(usize, @bitCast(@as(isize, @intCast(L_BIOME_256))));
    }
    setupScale(g.*.entry_1, @as(c_int, 1));
}
pub fn getMinLayerCacheSize(arg_layer: [*c]const Layer, arg_sizeX: c_int, arg_sizeZ: c_int) usize {
    var layer = arg_layer;
    _ = &layer;
    var sizeX = arg_sizeX;
    _ = &sizeX;
    var sizeZ = arg_sizeZ;
    _ = &sizeZ;
    var maxX: c_int = sizeX;
    _ = &maxX;
    var maxZ: c_int = sizeZ;
    _ = &maxZ;
    var bufsiz: usize = 0;
    _ = &bufsiz;
    getMaxArea(layer, sizeX, sizeZ, &maxX, &maxZ, &bufsiz);
    return bufsiz +% (@as(usize, @bitCast(@as(c_long, maxX))) *% @as(usize, @bitCast(@as(c_long, maxZ))));
}
pub fn setupLayer(arg_l: [*c]Layer, arg_map: ?*const mapfunc_t, arg_mc: c_int, arg_zoom: i8, arg_edge: i8, arg_saltbase: u64, arg_p: [*c]Layer, arg_p2: [*c]Layer) [*c]Layer {
    var l = arg_l;
    _ = &l;
    var map = arg_map;
    _ = &map;
    var mc = arg_mc;
    _ = &mc;
    var zoom = arg_zoom;
    _ = &zoom;
    var edge = arg_edge;
    _ = &edge;
    var saltbase = arg_saltbase;
    _ = &saltbase;
    var p = arg_p;
    _ = &p;
    var p2 = arg_p2;
    _ = &p2;
    l.*.getMap = map;
    l.*.mc = @as(i8, @bitCast(@as(i8, @truncate(mc))));
    l.*.zoom = zoom;
    l.*.edge = edge;
    l.*.scale = 0;
    if ((saltbase == @as(u64, @bitCast(@as(c_long, @as(c_int, 0))))) or (@as(c_ulonglong, @bitCast(@as(c_ulonglong, saltbase))) == ~@as(c_ulonglong, 0))) {
        l.*.layerSalt = saltbase;
    } else {
        l.*.layerSalt = getLayerSalt(saltbase);
    }
    l.*.startSalt = 0;
    l.*.startSeed = 0;
    l.*.noise = @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)));
    l.*.data = @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)));
    l.*.p = p;
    l.*.p2 = p2;
    return l;
}
pub fn genArea(arg_layer: [*c]const Layer, arg_out: [*c]c_int, arg_areaX: c_int, arg_areaZ: c_int, arg_areaWidth: c_int, arg_areaHeight: c_int) c_int {
    var layer = arg_layer;
    _ = &layer;
    var out = arg_out;
    _ = &out;
    var areaX = arg_areaX;
    _ = &areaX;
    var areaZ = arg_areaZ;
    _ = &areaZ;
    var areaWidth = arg_areaWidth;
    _ = &areaWidth;
    var areaHeight = arg_areaHeight;
    _ = &areaHeight;
    _ = memset(@as(?*anyopaque, @ptrCast(out)), @as(c_int, 0), (@sizeOf(c_int) *% @as(c_ulong, @bitCast(@as(c_long, areaWidth)))) *% @as(c_ulong, @bitCast(@as(c_long, areaHeight))));
    return layer.*.getMap.?(layer, out, areaX, areaZ, areaWidth, areaHeight);
}
pub export fn mapApproxHeight(arg_y: [*c]f32, arg_ids: [*c]c_int, arg_g: [*c]const Generator, arg_sn: [*c]const SurfaceNoise, arg_x: c_int, arg_z: c_int, arg_w: c_int, arg_h: c_int) c_int {
    var y = arg_y;
    _ = &y;
    var ids = arg_ids;
    _ = &ids;
    var g = arg_g;
    _ = &g;
    var sn = arg_sn;
    _ = &sn;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var w = arg_w;
    _ = &w;
    var h = arg_h;
    _ = &h;
    if (g.*.dim == DIM_NETHER) return 127;
    if (g.*.dim == DIM_END) {
        if (g.*.mc <= MC_1_8) return 1;
        return mapEndSurfaceHeight(y, &g.*.en, sn, x, z, w, h, @as(c_int, 4), @as(c_int, 0));
    }
    if (g.*.mc >= MC_1_18) {
        if ((g.*.unnamed_0.unnamed_1.bn.nptype != -@as(c_int, 1)) and (g.*.unnamed_0.unnamed_1.bn.nptype != NP_DEPTH)) return 1;
        var i: i64 = undefined;
        _ = &i;
        var j: i64 = undefined;
        _ = &j;
        {
            j = 0;
            while (j < @as(i64, @bitCast(@as(c_long, h)))) : (j += 1) {
                {
                    i = 0;
                    while (i < @as(i64, @bitCast(@as(c_long, w)))) : (i += 1) {
                        var flags: c_int = 0;
                        _ = &flags;
                        var np: [6]i64 = undefined;
                        _ = &np;
                        var id: c_int = sampleBiomeNoise(&g.*.unnamed_0.unnamed_1.bn, @as([*c]i64, @ptrCast(@alignCast(&np))), @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(@as(c_long, x))) + i)))), @as(c_int, 0), @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(@as(c_long, z))) + j)))), null, @as(u32, @bitCast(flags)));
                        _ = &id;
                        if (ids != null) {
                            (blk: {
                                const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                                if (tmp >= 0) break :blk ids + @as(usize, @intCast(tmp)) else break :blk ids - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* = id;
                        }
                        (blk: {
                            const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                            if (tmp >= 0) break :blk y + @as(usize, @intCast(tmp)) else break :blk y - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = @as(f32, @floatCast(@as(f64, @floatFromInt(np[@as(c_uint, @intCast(NP_DEPTH))])) / 76.0));
                    }
                }
            }
        }
        return 0;
    } else if (g.*.mc <= MC_B1_7) {
        var snb: SurfaceNoiseBeta = undefined;
        _ = &snb;
        initSurfaceNoiseBeta(&snb, g.*.seed);
        var i: i64 = undefined;
        _ = &i;
        var j: i64 = undefined;
        _ = &j;
        {
            j = 0;
            while (j < @as(i64, @bitCast(@as(c_long, h)))) : (j += 1) {
                {
                    i = 0;
                    while (i < @as(i64, @bitCast(@as(c_long, w)))) : (i += 1) {
                        var samplex: c_int = @as(c_int, @bitCast(@as(c_int, @truncate(((@as(i64, @bitCast(@as(c_long, x))) + i) * @as(i64, @bitCast(@as(c_long, @as(c_int, 4))))) + @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))))));
                        _ = &samplex;
                        var samplez: c_int = @as(c_int, @bitCast(@as(c_int, @truncate(((@as(i64, @bitCast(@as(c_long, z))) + j) * @as(i64, @bitCast(@as(c_long, @as(c_int, 4))))) + @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))))));
                        _ = &samplez;
                        (blk: {
                            const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                            if (tmp >= 0) break :blk y + @as(usize, @intCast(tmp)) else break :blk y - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = @as(f32, @floatCast(approxSurfaceBeta(&g.*.unnamed_0.unnamed_2.bnb, &snb, samplex, samplez)));
                    }
                }
            }
        }
        return 0;
    }
    const biome_kernel: [25]f32 = [25]f32{
        @as(f32, @floatCast(3.302044127)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(4.545454545)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(3.302044127)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(6.194967155)),
        @as(f32, @floatCast(8.333333333)),
        @as(f32, @floatCast(6.194967155)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(4.545454545)),
        @as(f32, @floatCast(8.333333333)),
        @as(f32, @floatCast(50.0)),
        @as(f32, @floatCast(8.333333333)),
        @as(f32, @floatCast(4.545454545)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(6.194967155)),
        @as(f32, @floatCast(8.333333333)),
        @as(f32, @floatCast(6.194967155)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(3.302044127)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(4.545454545)),
        @as(f32, @floatCast(4.104975761)),
        @as(f32, @floatCast(3.302044127)),
    };
    _ = &biome_kernel;
    var depth: [*c]f64 = @as([*c]f64, @ptrCast(@alignCast(malloc(((@sizeOf(f64) *% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 2))))) *% @as(c_ulong, @bitCast(@as(c_long, w)))) *% @as(c_ulong, @bitCast(@as(c_long, h)))))));
    _ = &depth;
    var scale: [*c]f64 = depth + @as(usize, @bitCast(@as(isize, @intCast(w * h))));
    _ = &scale;
    var i: i64 = undefined;
    _ = &i;
    var j: i64 = undefined;
    _ = &j;
    var ii: c_int = undefined;
    _ = &ii;
    var jj: c_int = undefined;
    _ = &jj;
    var r: Range = Range{
        .scale = @as(c_int, 4),
        .x = x - @as(c_int, 2),
        .z = z - @as(c_int, 2),
        .sx = w + @as(c_int, 5),
        .sz = h + @as(c_int, 5),
        .y = @as(c_int, 0),
        .sy = @as(c_int, 1),
    };
    _ = &r;
    var cache: [*c]c_int = allocCache(g, r);
    _ = &cache;
    _ = genBiomes(g, cache, r);
    {
        j = 0;
        while (j < @as(i64, @bitCast(@as(c_long, h)))) : (j += 1) {
            {
                i = 0;
                while (i < @as(i64, @bitCast(@as(c_long, w)))) : (i += 1) {
                    var d0: f64 = undefined;
                    _ = &d0;
                    var s0: f64 = undefined;
                    _ = &s0;
                    var wt: f64 = 0;
                    _ = &wt;
                    var ws: f64 = 0;
                    _ = &ws;
                    var wd: f64 = 0;
                    _ = &wd;
                    var id0: c_int = (blk: {
                        const tmp = ((j + @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))) * @as(i64, @bitCast(@as(c_long, r.sx)))) + (i + @as(i64, @bitCast(@as(c_long, @as(c_int, 2)))));
                        if (tmp >= 0) break :blk cache + @as(usize, @intCast(tmp)) else break :blk cache - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*;
                    _ = &id0;
                    _ = getBiomeDepthAndScale(id0, &d0, &s0, null);
                    {
                        jj = 0;
                        while (jj < @as(c_int, 5)) : (jj += 1) {
                            {
                                ii = 0;
                                while (ii < @as(c_int, 5)) : (ii += 1) {
                                    var d: f64 = undefined;
                                    _ = &d;
                                    var s: f64 = undefined;
                                    _ = &s;
                                    var id: c_int = (blk: {
                                        const tmp = ((j + @as(i64, @bitCast(@as(c_long, jj)))) * @as(i64, @bitCast(@as(c_long, r.sx)))) + (i + @as(i64, @bitCast(@as(c_long, ii))));
                                        if (tmp >= 0) break :blk cache + @as(usize, @intCast(tmp)) else break :blk cache - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).*;
                                    _ = &id;
                                    _ = getBiomeDepthAndScale(id, &d, &s, null);
                                    var weight: f32 = @as(f32, @floatCast(@as(f64, @floatCast(biome_kernel[@as(c_uint, @intCast((jj * @as(c_int, 5)) + ii))])) / (d + @as(f64, @floatFromInt(@as(c_int, 2))))));
                                    _ = &weight;
                                    if (d > d0) {
                                        weight *= @as(f32, @floatCast(0.5));
                                    }
                                    ws += s * @as(f64, @floatCast(weight));
                                    wd += d * @as(f64, @floatCast(weight));
                                    wt += @as(f64, @floatCast(weight));
                                }
                            }
                        }
                    }
                    ws /= wt;
                    wd /= wt;
                    ws = (ws * 0.9) + 0.1;
                    wd = ((wd * 4.0) - @as(f64, @floatFromInt(@as(c_int, 1)))) / @as(f64, @floatFromInt(@as(c_int, 8)));
                    ws = @as(f64, @floatFromInt(@as(c_int, 96))) / ws;
                    wd = (wd * 17.0) / @as(f64, @floatFromInt(@as(c_int, 64)));
                    (blk: {
                        const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                        if (tmp >= 0) break :blk depth + @as(usize, @intCast(tmp)) else break :blk depth - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = wd;
                    (blk: {
                        const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                        if (tmp >= 0) break :blk scale + @as(usize, @intCast(tmp)) else break :blk scale - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = ws;
                    if (ids != null) {
                        (blk: {
                            const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                            if (tmp >= 0) break :blk ids + @as(usize, @intCast(tmp)) else break :blk ids - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = id0;
                    }
                }
            }
        }
    }
    free(@as(?*anyopaque, @ptrCast(cache)));
    {
        j = 0;
        while (j < @as(i64, @bitCast(@as(c_long, h)))) : (j += 1) {
            {
                i = 0;
                while (i < @as(i64, @bitCast(@as(c_long, w)))) : (i += 1) {
                    var px: c_int = @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(@as(c_long, x))) + i))));
                    _ = &px;
                    var pz: c_int = @as(c_int, @bitCast(@as(c_int, @truncate(@as(i64, @bitCast(@as(c_long, z))) + j))));
                    _ = &pz;
                    var off: f64 = sampleOctaveAmp(&sn.*.octdepth, @as(f64, @floatFromInt(px * @as(c_int, 200))), @as(f64, @floatFromInt(@as(c_int, 10))), @as(f64, @floatFromInt(pz * @as(c_int, 200))), @as(f64, @floatFromInt(@as(c_int, 1))), @as(f64, @floatFromInt(@as(c_int, 0))), @as(c_int, 1));
                    _ = &off;
                    off *= 65535.0 / @as(f64, @floatFromInt(@as(c_int, 8000)));
                    if (off < @as(f64, @floatFromInt(@as(c_int, 0)))) {
                        off = -0.3 * off;
                    }
                    off = (off * @as(f64, @floatFromInt(@as(c_int, 3)))) - @as(f64, @floatFromInt(@as(c_int, 2)));
                    if (off > @as(f64, @floatFromInt(@as(c_int, 1)))) {
                        off = 1;
                    }
                    off *= 17.0 / @as(f64, @floatFromInt(@as(c_int, 64)));
                    if (off < @as(f64, @floatFromInt(@as(c_int, 0)))) {
                        off *= 1.0 / @as(f64, @floatFromInt(@as(c_int, 28)));
                    } else {
                        off *= 1.0 / @as(f64, @floatFromInt(@as(c_int, 40)));
                    }
                    var vmin: f64 = 0;
                    _ = &vmin;
                    var vmax: f64 = 0;
                    _ = &vmax;
                    var ytest: c_int = 8;
                    _ = &ytest;
                    var ymin: c_int = 0;
                    _ = &ymin;
                    var ymax: c_int = 32;
                    _ = &ymax;
                    while (true) {
                        var v: [2]f64 = undefined;
                        _ = &v;
                        var k: c_int = undefined;
                        _ = &k;
                        {
                            k = 0;
                            while (k < @as(c_int, 2)) : (k += 1) {
                                var py: c_int = ytest + k;
                                _ = &py;
                                var n0: f64 = sampleSurfaceNoise(sn, px, py, pz);
                                _ = &n0;
                                var fall: f64 = ((@as(f64, @floatFromInt(@as(c_int, 1))) - (@as(f64, @floatFromInt(@as(c_int, 2) * py)) / 32.0)) + off) - 0.46875;
                                _ = &fall;
                                fall = (blk: {
                                    const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                                    if (tmp >= 0) break :blk scale + @as(usize, @intCast(tmp)) else break :blk scale - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                }).* * (fall + (blk: {
                                    const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                                    if (tmp >= 0) break :blk depth + @as(usize, @intCast(tmp)) else break :blk depth - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                }).*);
                                n0 += if (fall > @as(f64, @floatFromInt(@as(c_int, 0)))) @as(f64, @floatFromInt(@as(c_int, 4))) * fall else fall;
                                v[@as(c_uint, @intCast(k))] = n0;
                                if ((n0 >= @as(f64, @floatFromInt(@as(c_int, 0)))) and (py > ymin)) {
                                    ymin = py;
                                    vmin = n0;
                                }
                                if ((n0 < @as(f64, @floatFromInt(@as(c_int, 0)))) and (py < ymax)) {
                                    ymax = py;
                                    vmax = n0;
                                }
                            }
                        }
                        var dy: f64 = v[@as(c_uint, @intCast(@as(c_int, 0)))] / (v[@as(c_uint, @intCast(@as(c_int, 0)))] - v[@as(c_uint, @intCast(@as(c_int, 1)))]);
                        _ = &dy;
                        dy = if (dy <= @as(f64, @floatFromInt(@as(c_int, 0)))) floor(dy) else ceil(dy);
                        ytest += @as(c_int, @intFromFloat(dy));
                        if (ytest <= ymin) {
                            ytest = ymin + @as(c_int, 1);
                        }
                        if (ytest >= ymax) {
                            ytest = ymax - @as(c_int, 1);
                        }
                        if (!((ymax - ymin) > @as(c_int, 1))) break;
                    }
                    (blk: {
                        const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                        if (tmp >= 0) break :blk y + @as(usize, @intCast(tmp)) else break :blk y - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = @as(f32, @floatCast(@as(f64, @floatFromInt(@as(c_int, 8))) * ((vmin / (vmin - vmax)) + @as(f64, @floatFromInt(ymin)))));
                }
            }
        }
    }
    free(@as(?*anyopaque, @ptrCast(depth)));
    return 0;
}
pub fn mapOceanMixMod(arg_l: [*c]const Layer, arg_out: [*c]c_int, arg_x: c_int, arg_z: c_int, arg_w: c_int, arg_h: c_int) c_int {
    var l = arg_l;
    _ = &l;
    var out = arg_out;
    _ = &out;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var w = arg_w;
    _ = &w;
    var h = arg_h;
    _ = &h;
    var otyp: [*c]c_int = undefined;
    _ = &otyp;
    var i: i64 = undefined;
    _ = &i;
    var j: i64 = undefined;
    _ = &j;
    _ = l.*.p2.*.getMap.?(l.*.p2, out, x, z, w, h);
    otyp = @as([*c]c_int, @ptrCast(@alignCast(malloc(@as(c_ulong, @bitCast(@as(c_long, w * h))) *% @sizeOf(c_int)))));
    _ = memcpy(@as(?*anyopaque, @ptrCast(otyp)), @as(?*const anyopaque, @ptrCast(out)), @as(c_ulong, @bitCast(@as(c_long, w * h))) *% @sizeOf(c_int));
    _ = l.*.p.*.getMap.?(l.*.p, out, x, z, w, h);
    {
        j = 0;
        while (j < @as(i64, @bitCast(@as(c_long, h)))) : (j += 1) {
            {
                i = 0;
                while (i < @as(i64, @bitCast(@as(c_long, w)))) : (i += 1) {
                    var landID: c_int = undefined;
                    _ = &landID;
                    var oceanID: c_int = undefined;
                    _ = &oceanID;
                    landID = (blk: {
                        const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                        if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*;
                    if (!(isOceanic(landID) != 0)) continue;
                    oceanID = (blk: {
                        const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                        if (tmp >= 0) break :blk otyp + @as(usize, @intCast(tmp)) else break :blk otyp - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*;
                    if (landID == deep_ocean) {
                        while (true) {
                            switch (oceanID) {
                                @as(c_int, 45) => {
                                    oceanID = deep_lukewarm_ocean;
                                    break;
                                },
                                @as(c_int, 0) => {
                                    oceanID = deep_ocean;
                                    break;
                                },
                                @as(c_int, 46) => {
                                    oceanID = deep_cold_ocean;
                                    break;
                                },
                                @as(c_int, 10) => {
                                    oceanID = deep_frozen_ocean;
                                    break;
                                },
                                else => {},
                            }
                            break;
                        }
                    }
                    (blk: {
                        const tmp = (j * @as(i64, @bitCast(@as(c_long, w)))) + i;
                        if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).* = oceanID;
                }
            }
        }
    }
    free(@as(?*anyopaque, @ptrCast(otyp)));
    return 0;
}
pub fn setupScale(arg_l: [*c]Layer, arg_scale: c_int) void {
    var l = arg_l;
    _ = &l;
    var scale = arg_scale;
    _ = &scale;
    l.*.scale = scale;
    if (l.*.p != null) {
        setupScale(l.*.p, scale * @as(c_int, @bitCast(@as(c_int, l.*.zoom))));
    }
    if (l.*.p2 != null) {
        setupScale(l.*.p2, scale * @as(c_int, @bitCast(@as(c_int, l.*.zoom))));
    }
}
pub fn getMaxArea(arg_layer: [*c]const Layer, arg_areaX: c_int, arg_areaZ: c_int, arg_maxX: [*c]c_int, arg_maxZ: [*c]c_int, arg_siz: [*c]usize) void {
    var layer = arg_layer;
    _ = &layer;
    var areaX = arg_areaX;
    _ = &areaX;
    var areaZ = arg_areaZ;
    _ = &areaZ;
    var maxX = arg_maxX;
    _ = &maxX;
    var maxZ = arg_maxZ;
    _ = &maxZ;
    var siz = arg_siz;
    _ = &siz;
    if (layer == @as([*c]const Layer, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) return;
    areaX += @as(c_int, @bitCast(@as(c_int, layer.*.edge)));
    areaZ += @as(c_int, @bitCast(@as(c_int, layer.*.edge)));
    if ((layer.*.p2 != null) or (@as(c_int, @bitCast(@as(c_int, layer.*.zoom))) != @as(c_int, 1))) {
        siz.* +%= @as(usize, @bitCast(@as(c_long, areaX * areaZ)));
    }
    if (areaX > maxX.*) {
        maxX.* = areaX;
    }
    if (areaZ > maxZ.*) {
        maxZ.* = areaZ;
    }
    if (@as(c_int, @bitCast(@as(c_int, layer.*.zoom))) == @as(c_int, 2)) {
        areaX >>= @intCast(@as(c_int, 1));
        areaZ >>= @intCast(@as(c_int, 1));
    } else if (@as(c_int, @bitCast(@as(c_int, layer.*.zoom))) == @as(c_int, 4)) {
        areaX >>= @intCast(@as(c_int, 2));
        areaZ >>= @intCast(@as(c_int, 2));
    }
    getMaxArea(layer.*.p, areaX, areaZ, maxX, maxZ, siz);
    if (layer.*.p2 != null) {
        getMaxArea(layer.*.p2, areaX, areaZ, maxX, maxZ, siz);
    }
}
pub const Feature: c_int = 0;
pub const Desert_Pyramid: c_int = 1;
pub const Jungle_Temple: c_int = 2;
pub const Jungle_Pyramid: c_int = 2;
pub const Swamp_Hut: c_int = 3;
pub const Igloo: c_int = 4;
pub const Village: c_int = 5;
pub const Ocean_Ruin: c_int = 6;
pub const Shipwreck: c_int = 7;
pub const Monument: c_int = 8;
pub const Mansion: c_int = 9;
pub const Outpost: c_int = 10;
pub const Ruined_Portal: c_int = 11;
pub const Ruined_Portal_N: c_int = 12;
pub const Ancient_City: c_int = 13;
pub const Treasure: c_int = 14;
pub const Mineshaft: c_int = 15;
pub const Desert_Well: c_int = 16;
pub const Geode: c_int = 17;
pub const Fortress: c_int = 18;
pub const Bastion: c_int = 19;
pub const End_City: c_int = 20;
pub const End_Gateway: c_int = 21;
pub const End_Island: c_int = 22;
pub const Trail_Ruins: c_int = 23;
pub const Trial_Chambers: c_int = 24;
pub const struct_StructureConfig = extern struct {
    salt: i32 = @import("std").mem.zeroes(i32),
    regionSize: i8 = @import("std").mem.zeroes(i8),
    chunkRange: i8 = @import("std").mem.zeroes(i8),
    structType: u8 = @import("std").mem.zeroes(u8),
    dim: i8 = @import("std").mem.zeroes(i8),
    rarity: f32 = @import("std").mem.zeroes(f32),
};
pub const StructureConfig = struct_StructureConfig;
pub const struct_Pos = extern struct {
    x: c_int = @import("std").mem.zeroes(c_int),
    z: c_int = @import("std").mem.zeroes(c_int),
};
pub const Pos = struct_Pos;
pub const struct_Pos3 = extern struct {
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    z: c_int = @import("std").mem.zeroes(c_int),
};
pub const Pos3 = struct_Pos3;
pub const struct_StructureVariant = extern struct {
    flags: u8,
    size: u8,
    start: u8,
    biome: c_short,
    rotation: u8,
    mirror: u8,
    x: i16,
    y: i16,
    z: i16,
    sx: i16,
    sy: i16,
    sz: i16,
};
pub const StructureVariant = struct_StructureVariant;
pub export fn getStructureConfig(arg_structureType: c_int, arg_mc: c_int, arg_sconf: [*c]StructureConfig) c_int {
    var structureType = arg_structureType;
    _ = &structureType;
    var mc = arg_mc;
    _ = &mc;
    var sconf = arg_sconf;
    _ = &sconf;
    const s_feature = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Feature)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_feature;
    const s_igloo_112 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Igloo)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_igloo_112;
    const s_swamp_hut_112 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Swamp_Hut)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_swamp_hut_112;
    const s_desert_pyramid_112 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Desert_Pyramid)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_desert_pyramid_112;
    const s_jungle_temple_112 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Jungle_Pyramid)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_jungle_temple_112;
    const s_ocean_ruin_115 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357621),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 16))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 8))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ocean_Ruin)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ocean_ruin_115;
    const s_shipwreck_115 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 165745295),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 16))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 8))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Shipwreck)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_shipwreck_115;
    const s_desert_pyramid = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Desert_Pyramid)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_desert_pyramid;
    const s_igloo = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357618),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Igloo)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_igloo;
    const s_jungle_temple = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357619),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Jungle_Pyramid)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_jungle_temple;
    const s_swamp_hut = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357620),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Swamp_Hut)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_swamp_hut;
    const s_outpost = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 165745296),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Outpost)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_outpost;
    const s_village_117 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387312),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Village)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_village_117;
    const s_village = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387312),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 34))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 26))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Village)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_village;
    const s_ocean_ruin = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357621),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 20))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 12))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ocean_Ruin)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ocean_ruin;
    const s_shipwreck = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 165745295),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 20))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Shipwreck)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_shipwreck;
    const s_monument = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387313),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 27))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Monument)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_monument;
    const s_mansion = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387319),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 80))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 60))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Mansion)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_mansion;
    const s_ruined_portal = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 34222645),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 40))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 25))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ruined_Portal)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ruined_portal;
    const s_ruined_portal_n = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 34222645),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 40))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 25))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ruined_Portal)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ruined_portal_n;
    const s_ruined_portal_n_117 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 34222645),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 25))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 15))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ruined_Portal_N)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ruined_portal_n_117;
    const s_ancient_city = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 20083232),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 16))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ancient_City)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ancient_city;
    const s_trail_ruins = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 83469867),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 34))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 26))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Trail_Ruins)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_trail_ruins;
    const s_trial_chambers = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 94251327),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 34))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 22))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Trial_Chambers)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_trial_chambers;
    const s_treasure = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387320),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Treasure)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_treasure;
    const s_mineshaft = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 0),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Mineshaft)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_mineshaft;
    const s_desert_well_115 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 30010),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Desert_Well)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 1000))),
        };
    };
    _ = &s_desert_well_115;
    const s_desert_well_117 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 40013),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Desert_Well)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 1000))),
        };
    };
    _ = &s_desert_well_117;
    const s_desert_well = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 40002),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Desert_Well)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 1000))),
        };
    };
    _ = &s_desert_well;
    const s_geode_117 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 20000),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Geode)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 24))),
        };
    };
    _ = &s_geode_117;
    const s_geode = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 20002),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Geode)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 24))),
        };
    };
    _ = &s_geode;
    const s_fortress_115 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 0),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 16))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 8))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Fortress)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_fortress_115;
    const s_fortress = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 30084232),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 27))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 23))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Fortress)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_fortress;
    const s_bastion = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 30084232),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 27))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 23))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Bastion)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_bastion;
    const s_end_city = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387313),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 20))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 9))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_City)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_end_city;
    const s_end_gateway_115 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 30000),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_Gateway)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 700))),
        };
    };
    _ = &s_end_gateway_115;
    const s_end_gateway_116 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 40013),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_Gateway)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 700))),
        };
    };
    _ = &s_end_gateway_116;
    const s_end_gateway_117 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 40013),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_Gateway)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 700))),
        };
    };
    _ = &s_end_gateway_117;
    const s_end_gateway = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 40000),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_Gateway)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 700))),
        };
    };
    _ = &s_end_gateway;
    const s_end_island_116 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 0),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_Island)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 14))),
        };
    };
    _ = &s_end_island_116;
    const s_end_island = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 0),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_Island)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = 1.0 / @as(f32, @floatFromInt(@as(c_int, 14))),
        };
    };
    _ = &s_end_island;
    while (true) {
        switch (structureType) {
            @as(c_int, 0) => {
                sconf.* = s_feature.static;
                return @intFromBool(mc <= MC_1_12);
            },
            @as(c_int, 1) => {
                sconf.* = if (mc <= MC_1_12) s_desert_pyramid_112.static else s_desert_pyramid.static;
                return @intFromBool(mc >= MC_1_3);
            },
            @as(c_int, 2) => {
                sconf.* = if (mc <= MC_1_12) s_jungle_temple_112.static else s_jungle_temple.static;
                return @intFromBool(mc >= MC_1_3);
            },
            @as(c_int, 3) => {
                sconf.* = if (mc <= MC_1_12) s_swamp_hut_112.static else s_swamp_hut.static;
                return @intFromBool(mc >= MC_1_4);
            },
            @as(c_int, 4) => {
                sconf.* = if (mc <= MC_1_12) s_igloo_112.static else s_igloo.static;
                return @intFromBool(mc >= MC_1_9);
            },
            @as(c_int, 5) => {
                sconf.* = if (mc <= MC_1_17) s_village_117.static else s_village.static;
                return @intFromBool(mc >= MC_B1_8);
            },
            @as(c_int, 6) => {
                sconf.* = if (mc <= MC_1_15) s_ocean_ruin_115.static else s_ocean_ruin.static;
                return @intFromBool(mc >= MC_1_13);
            },
            @as(c_int, 7) => {
                sconf.* = if (mc <= MC_1_15) s_shipwreck_115.static else s_shipwreck.static;
                return @intFromBool(mc >= MC_1_13);
            },
            @as(c_int, 11) => {
                sconf.* = s_ruined_portal.static;
                return @intFromBool(mc >= MC_1_16_1);
            },
            @as(c_int, 12) => {
                sconf.* = if (mc <= MC_1_17) s_ruined_portal_n_117.static else s_ruined_portal_n.static;
                return @intFromBool(mc >= MC_1_16_1);
            },
            @as(c_int, 8) => {
                sconf.* = s_monument.static;
                return @intFromBool(mc >= MC_1_8);
            },
            @as(c_int, 20) => {
                sconf.* = s_end_city.static;
                return @intFromBool(mc >= MC_1_9);
            },
            @as(c_int, 9) => {
                sconf.* = s_mansion.static;
                return @intFromBool(mc >= MC_1_11);
            },
            @as(c_int, 10) => {
                sconf.* = s_outpost.static;
                return @intFromBool(mc >= MC_1_14);
            },
            @as(c_int, 13) => {
                sconf.* = s_ancient_city.static;
                return @intFromBool(mc >= MC_1_19_2);
            },
            @as(c_int, 14) => {
                sconf.* = s_treasure.static;
                return @intFromBool(mc >= MC_1_13);
            },
            @as(c_int, 15) => {
                sconf.* = s_mineshaft.static;
                return @intFromBool(mc >= MC_B1_8);
            },
            @as(c_int, 18) => {
                sconf.* = if (mc <= MC_1_15) s_fortress_115.static else s_fortress.static;
                return @intFromBool(mc >= MC_1_0);
            },
            @as(c_int, 19) => {
                sconf.* = s_bastion.static;
                return @intFromBool(mc >= MC_1_16_1);
            },
            @as(c_int, 21) => {
                if (mc <= MC_1_15) {
                    sconf.* = s_end_gateway_115.static;
                } else if (mc <= MC_1_16) {
                    sconf.* = s_end_gateway_116.static;
                } else if (mc <= MC_1_17) {
                    sconf.* = s_end_gateway_117.static;
                } else {
                    sconf.* = s_end_gateway.static;
                }
                return @intFromBool(mc >= MC_1_13);
            },
            @as(c_int, 22) => {
                if (mc <= MC_1_16) {
                    sconf.* = s_end_island_116.static;
                } else {
                    sconf.* = s_end_island.static;
                }
                return @intFromBool(mc >= MC_1_13);
            },
            @as(c_int, 16) => {
                if (mc <= MC_1_15) {
                    sconf.* = s_desert_well_115.static;
                } else if (mc <= MC_1_17) {
                    sconf.* = s_desert_well_117.static;
                } else {
                    sconf.* = s_desert_well.static;
                }
                return @intFromBool(mc >= MC_1_13);
            },
            @as(c_int, 17) => {
                sconf.* = if (mc <= MC_1_17) s_geode_117.static else s_geode.static;
                return @intFromBool(mc >= MC_1_17);
            },
            @as(c_int, 23) => {
                sconf.* = s_trail_ruins.static;
                return @intFromBool(mc >= MC_1_20);
            },
            @as(c_int, 24) => {
                sconf.* = s_trial_chambers.static;
                return @intFromBool(mc >= MC_1_21_1);
            },
            else => {
                _ = memset(@as(?*anyopaque, @ptrCast(sconf)), @as(c_int, 0), @sizeOf(StructureConfig));
                return 0;
            },
        }
        break;
    }
    return 0;
}
pub export fn getStructurePos(arg_structureType: c_int, arg_mc: c_int, arg_seed: u64, arg_regX: c_int, arg_regZ: c_int, arg_pos: [*c]Pos) c_int {
    var structureType = arg_structureType;
    _ = &structureType;
    var mc = arg_mc;
    _ = &mc;
    var seed = arg_seed;
    _ = &seed;
    var regX = arg_regX;
    _ = &regX;
    var regZ = arg_regZ;
    _ = &regZ;
    var pos = arg_pos;
    _ = &pos;
    var sconf: StructureConfig = undefined;
    _ = &sconf;
    if (!(getStructureConfig(structureType, mc, &sconf) != 0)) {
        return 0;
    }
    while (true) {
        switch (structureType) {
            @as(c_int, 0), @as(c_int, 1), @as(c_int, 2), @as(c_int, 3), @as(c_int, 4), @as(c_int, 5), @as(c_int, 6), @as(c_int, 7), @as(c_int, 11), @as(c_int, 12), @as(c_int, 13), @as(c_int, 23), @as(c_int, 24) => {
                pos.* = getFeaturePos(sconf, seed, regX, regZ);
                return 1;
            },
            @as(c_int, 8), @as(c_int, 9) => {
                pos.* = getLargeStructurePos(sconf, seed, regX, regZ);
                return 1;
            },
            @as(c_int, 20) => {
                pos.* = getLargeStructurePos(sconf, seed, regX, regZ);
                return @intFromBool(@as(c_longlong, @bitCast(@as(c_longlong, (@as(i64, @bitCast(@as(c_long, pos.*.x))) * @as(i64, @bitCast(@as(c_long, pos.*.x)))) + (@as(i64, @bitCast(@as(c_long, pos.*.z))) * @as(i64, @bitCast(@as(c_long, pos.*.z))))))) >= (@as(c_longlong, @bitCast(@as(c_longlong, @as(c_int, 1008)))) * @as(c_longlong, 1008)));
            },
            @as(c_int, 10) => {
                pos.* = getFeaturePos(sconf, seed, regX, regZ);
                setAttemptSeed(&seed, pos.*.x >> @intCast(4), pos.*.z >> @intCast(4));
                return @intFromBool(nextInt(&seed, @as(c_int, 5)) == @as(c_int, 0));
            },
            @as(c_int, 14) => {
                pos.*.x = (regX * @as(c_int, 16)) + @as(c_int, 9);
                pos.*.z = (regZ * @as(c_int, 16)) + @as(c_int, 9);
                seed = @as(u64, @bitCast(@as(c_ulong, @truncate((((@as(c_ulonglong, @bitCast(@as(c_longlong, regX))) *% @as(c_ulonglong, 341873128712)) +% (@as(c_ulonglong, @bitCast(@as(c_longlong, regZ))) *% @as(c_ulonglong, 132897987541))) +% @as(c_ulonglong, @bitCast(@as(c_ulonglong, seed)))) +% @as(c_ulonglong, @bitCast(@as(c_longlong, sconf.salt)))))));
                setSeed(&seed, seed);
                return @intFromBool(@as(f64, @floatCast(nextFloat(&seed))) < 0.01);
            },
            @as(c_int, 15) => return getMineshafts(mc, seed, regX, regZ, regX, regZ, pos, @as(c_int, 1)),
            @as(c_int, 18) => {
                if (mc >= MC_1_18) {
                    pos.* = getFeaturePos(sconf, seed, regX, regZ);
                    return 1;
                } else if (mc >= MC_1_16_1) {
                    getRegPos(pos, &seed, regX, regZ, sconf);
                    return @intFromBool(nextInt(&seed, @as(c_int, 5)) < @as(c_int, 2));
                } else {
                    setAttemptSeed(&seed, regX * @as(c_int, 16), regZ * @as(c_int, 16));
                    var valid: c_int = @intFromBool(nextInt(&seed, @as(c_int, 3)) == @as(c_int, 0));
                    _ = &valid;
                    pos.*.x = (((regX * @as(c_int, 16)) + nextInt(&seed, @as(c_int, 8))) + @as(c_int, 4)) * @as(c_int, 16);
                    pos.*.z = (((regZ * @as(c_int, 16)) + nextInt(&seed, @as(c_int, 8))) + @as(c_int, 4)) * @as(c_int, 16);
                    return valid;
                }
                if (mc >= MC_1_18) {
                    pos.* = getFeaturePos(sconf, seed, regX, regZ);
                    seed = chunkGenerateRnd(seed, pos.*.x >> @intCast(4), pos.*.z >> @intCast(4));
                    return @intFromBool(nextInt(&seed, @as(c_int, 5)) >= @as(c_int, 2));
                } else {
                    getRegPos(pos, &seed, regX, regZ, sconf);
                    return @intFromBool(nextInt(&seed, @as(c_int, 5)) >= @as(c_int, 2));
                }
                pos.*.x = regX * @as(c_int, 16);
                pos.*.z = regZ * @as(c_int, 16);
                seed = getPopulationSeed(mc, seed, pos.*.x, pos.*.z);
                if (mc >= MC_1_18) {
                    var xr: Xoroshiro = undefined;
                    _ = &xr;
                    xSetSeed(&xr, seed +% @as(u64, @bitCast(@as(c_long, sconf.salt))));
                    if (xNextFloat(&xr) >= sconf.rarity) return 0;
                    pos.*.x += xNextIntJ(&xr, @as(u32, @bitCast(@as(c_int, 16))));
                    pos.*.z += xNextIntJ(&xr, @as(u32, @bitCast(@as(c_int, 16))));
                } else {
                    setSeed(&seed, seed +% @as(u64, @bitCast(@as(c_long, sconf.salt))));
                    if (@as(f64, @floatCast(sconf.rarity)) < 1.0) {
                        if (nextFloat(&seed) >= sconf.rarity) return 0;
                    } else {
                        if (nextInt(&seed, @as(c_int, @intFromFloat(sconf.rarity))) != @as(c_int, 0)) return 0;
                    }
                    pos.*.x += nextInt(&seed, @as(c_int, 16));
                    pos.*.z += nextInt(&seed, @as(c_int, 16));
                }
                return 1;
            },
            @as(c_int, 19) => {
                if (mc >= MC_1_18) {
                    pos.* = getFeaturePos(sconf, seed, regX, regZ);
                    seed = chunkGenerateRnd(seed, pos.*.x >> @intCast(4), pos.*.z >> @intCast(4));
                    return @intFromBool(nextInt(&seed, @as(c_int, 5)) >= @as(c_int, 2));
                } else {
                    getRegPos(pos, &seed, regX, regZ, sconf);
                    return @intFromBool(nextInt(&seed, @as(c_int, 5)) >= @as(c_int, 2));
                }
                pos.*.x = regX * @as(c_int, 16);
                pos.*.z = regZ * @as(c_int, 16);
                seed = getPopulationSeed(mc, seed, pos.*.x, pos.*.z);
                if (mc >= MC_1_18) {
                    var xr: Xoroshiro = undefined;
                    _ = &xr;
                    xSetSeed(&xr, seed +% @as(u64, @bitCast(@as(c_long, sconf.salt))));
                    if (xNextFloat(&xr) >= sconf.rarity) return 0;
                    pos.*.x += xNextIntJ(&xr, @as(u32, @bitCast(@as(c_int, 16))));
                    pos.*.z += xNextIntJ(&xr, @as(u32, @bitCast(@as(c_int, 16))));
                } else {
                    setSeed(&seed, seed +% @as(u64, @bitCast(@as(c_long, sconf.salt))));
                    if (@as(f64, @floatCast(sconf.rarity)) < 1.0) {
                        if (nextFloat(&seed) >= sconf.rarity) return 0;
                    } else {
                        if (nextInt(&seed, @as(c_int, @intFromFloat(sconf.rarity))) != @as(c_int, 0)) return 0;
                    }
                    pos.*.x += nextInt(&seed, @as(c_int, 16));
                    pos.*.z += nextInt(&seed, @as(c_int, 16));
                }
                return 1;
            },
            @as(c_int, 21), @as(c_int, 22), @as(c_int, 16), @as(c_int, 17) => {
                pos.*.x = regX * @as(c_int, 16);
                pos.*.z = regZ * @as(c_int, 16);
                seed = getPopulationSeed(mc, seed, pos.*.x, pos.*.z);
                if (mc >= MC_1_18) {
                    var xr: Xoroshiro = undefined;
                    _ = &xr;
                    xSetSeed(&xr, seed +% @as(u64, @bitCast(@as(c_long, sconf.salt))));
                    if (xNextFloat(&xr) >= sconf.rarity) return 0;
                    pos.*.x += xNextIntJ(&xr, @as(u32, @bitCast(@as(c_int, 16))));
                    pos.*.z += xNextIntJ(&xr, @as(u32, @bitCast(@as(c_int, 16))));
                } else {
                    setSeed(&seed, seed +% @as(u64, @bitCast(@as(c_long, sconf.salt))));
                    if (@as(f64, @floatCast(sconf.rarity)) < 1.0) {
                        if (nextFloat(&seed) >= sconf.rarity) return 0;
                    } else {
                        if (nextInt(&seed, @as(c_int, @intFromFloat(sconf.rarity))) != @as(c_int, 0)) return 0;
                    }
                    pos.*.x += nextInt(&seed, @as(c_int, 16));
                    pos.*.z += nextInt(&seed, @as(c_int, 16));
                }
                return 1;
            },
            else => {
                // _ = fprintf(stderr, "ERR getStructurePos: unsupported structure type %d\n", structureType);
                exit(-@as(c_int, 1));
            },
        }
        break;
    }
    return 0;
}
pub fn getFeaturePos(arg_config: StructureConfig, arg_seed: u64, arg_regX: c_int, arg_regZ: c_int) Pos {
    var config = arg_config;
    _ = &config;
    var seed = arg_seed;
    _ = &seed;
    var regX = arg_regX;
    _ = &regX;
    var regZ = arg_regZ;
    _ = &regZ;
    var pos: Pos = getFeatureChunkInRegion(config, seed, regX, regZ);
    _ = &pos;
    pos.x = @as(c_int, @bitCast(@as(c_uint, @truncate(((@as(u64, @bitCast(@as(c_long, regX))) *% @as(u64, @bitCast(@as(c_long, config.regionSize)))) +% @as(u64, @bitCast(@as(c_long, pos.x)))) << @intCast(4)))));
    pos.z = @as(c_int, @bitCast(@as(c_uint, @truncate(((@as(u64, @bitCast(@as(c_long, regZ))) *% @as(u64, @bitCast(@as(c_long, config.regionSize)))) +% @as(u64, @bitCast(@as(c_long, pos.z)))) << @intCast(4)))));
    return pos;
}
pub fn getFeatureChunkInRegion(arg_config: StructureConfig, arg_seed: u64, arg_regX: c_int, arg_regZ: c_int) Pos {
    var config = arg_config;
    _ = &config;
    var seed = arg_seed;
    _ = &seed;
    var regX = arg_regX;
    _ = &regX;
    var regZ = arg_regZ;
    _ = &regZ;
    var pos: Pos = undefined;
    _ = &pos;
    const K: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 25214903917)))));
    _ = &K;
    const M: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate((@as(c_ulonglong, 1) << @intCast(48)) -% @as(c_ulonglong, @bitCast(@as(c_longlong, @as(c_int, 1))))))));
    _ = &M;
    const b: u64 = 11;
    _ = &b;
    seed = @as(u64, @bitCast(@as(c_ulong, @truncate(((@as(c_ulonglong, @bitCast(@as(c_ulonglong, seed))) +% (@as(c_ulonglong, @bitCast(@as(c_longlong, regX))) *% @as(c_ulonglong, 341873128712))) +% (@as(c_ulonglong, @bitCast(@as(c_longlong, regZ))) *% @as(c_ulonglong, 132897987541))) +% @as(c_ulonglong, @bitCast(@as(c_longlong, config.salt)))))));
    seed = seed ^ K;
    seed = ((seed *% K) +% b) & M;
    var r: u64 = @as(u64, @bitCast(@as(c_long, config.chunkRange)));
    _ = &r;
    if ((r & (r -% @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))))) != 0) {
        pos.x = @as(c_int, @bitCast(@as(c_uint, @truncate(@as(u64, @bitCast(@as(c_long, @as(c_int, @bitCast(@as(c_uint, @truncate(seed >> @intCast(17)))))))) % r))));
        seed = ((seed *% K) +% b) & M;
        pos.z = @as(c_int, @bitCast(@as(c_uint, @truncate(@as(u64, @bitCast(@as(c_long, @as(c_int, @bitCast(@as(c_uint, @truncate(seed >> @intCast(17)))))))) % r))));
    } else {
        pos.x = @as(c_int, @bitCast(@as(c_uint, @truncate((r *% (seed >> @intCast(17))) >> @intCast(31)))));
        seed = ((seed *% K) +% b) & M;
        pos.z = @as(c_int, @bitCast(@as(c_uint, @truncate((r *% (seed >> @intCast(17))) >> @intCast(31)))));
    }
    return pos;
}
pub fn getLargeStructurePos(arg_config: StructureConfig, arg_seed: u64, arg_regX: c_int, arg_regZ: c_int) Pos {
    var config = arg_config;
    _ = &config;
    var seed = arg_seed;
    _ = &seed;
    var regX = arg_regX;
    _ = &regX;
    var regZ = arg_regZ;
    _ = &regZ;
    var pos: Pos = getLargeStructureChunkInRegion(config, seed, regX, regZ);
    _ = &pos;
    pos.x = @as(c_int, @bitCast(@as(c_uint, @truncate(((@as(u64, @bitCast(@as(c_long, regX))) *% @as(u64, @bitCast(@as(c_long, config.regionSize)))) +% @as(u64, @bitCast(@as(c_long, pos.x)))) << @intCast(4)))));
    pos.z = @as(c_int, @bitCast(@as(c_uint, @truncate(((@as(u64, @bitCast(@as(c_long, regZ))) *% @as(u64, @bitCast(@as(c_long, config.regionSize)))) +% @as(u64, @bitCast(@as(c_long, pos.z)))) << @intCast(4)))));
    return pos;
}
pub fn getLargeStructureChunkInRegion(arg_config: StructureConfig, arg_seed: u64, arg_regX: c_int, arg_regZ: c_int) Pos {
    var config = arg_config;
    _ = &config;
    var seed = arg_seed;
    _ = &seed;
    var regX = arg_regX;
    _ = &regX;
    var regZ = arg_regZ;
    _ = &regZ;
    var pos: Pos = undefined;
    _ = &pos;
    const K: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 25214903917)))));
    _ = &K;
    const M: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate((@as(c_ulonglong, 1) << @intCast(48)) -% @as(c_ulonglong, @bitCast(@as(c_longlong, @as(c_int, 1))))))));
    _ = &M;
    const b: u64 = 11;
    _ = &b;
    seed = @as(u64, @bitCast(@as(c_ulong, @truncate(((@as(c_ulonglong, @bitCast(@as(c_ulonglong, seed))) +% (@as(c_ulonglong, @bitCast(@as(c_longlong, regX))) *% @as(c_ulonglong, 341873128712))) +% (@as(c_ulonglong, @bitCast(@as(c_longlong, regZ))) *% @as(c_ulonglong, 132897987541))) +% @as(c_ulonglong, @bitCast(@as(c_longlong, config.salt)))))));
    seed = seed ^ K;
    seed = ((seed *% K) +% b) & M;
    pos.x = @import("std").zig.c_translation.signedRemainder(@as(c_int, @bitCast(@as(c_uint, @truncate(seed >> @intCast(17))))), @as(c_int, @bitCast(@as(c_int, config.chunkRange))));
    seed = ((seed *% K) +% b) & M;
    pos.x += @import("std").zig.c_translation.signedRemainder(@as(c_int, @bitCast(@as(c_uint, @truncate(seed >> @intCast(17))))), @as(c_int, @bitCast(@as(c_int, config.chunkRange))));
    seed = ((seed *% K) +% b) & M;
    pos.z = @import("std").zig.c_translation.signedRemainder(@as(c_int, @bitCast(@as(c_uint, @truncate(seed >> @intCast(17))))), @as(c_int, @bitCast(@as(c_int, config.chunkRange))));
    seed = ((seed *% K) +% b) & M;
    pos.z += @import("std").zig.c_translation.signedRemainder(@as(c_int, @bitCast(@as(c_uint, @truncate(seed >> @intCast(17))))), @as(c_int, @bitCast(@as(c_int, config.chunkRange))));
    pos.x >>= @intCast(@as(c_int, 1));
    pos.z >>= @intCast(@as(c_int, 1));
    return pos;
}
pub fn getMineshafts(arg_mc: c_int, arg_seed: u64, arg_cx0: c_int, arg_cz0: c_int, arg_cx1: c_int, arg_cz1: c_int, arg_out: [*c]Pos, arg_nout: c_int) c_int {
    var mc = arg_mc;
    _ = &mc;
    var seed = arg_seed;
    _ = &seed;
    var cx0 = arg_cx0;
    _ = &cx0;
    var cz0 = arg_cz0;
    _ = &cz0;
    var cx1 = arg_cx1;
    _ = &cx1;
    var cz1 = arg_cz1;
    _ = &cz1;
    var out = arg_out;
    _ = &out;
    var nout = arg_nout;
    _ = &nout;
    var s: u64 = undefined;
    _ = &s;
    setSeed(&s, seed);
    var a: u64 = nextLong(&s);
    _ = &a;
    var b: u64 = nextLong(&s);
    _ = &b;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var n: c_int = 0;
    _ = &n;
    {
        i = cx0;
        while (i <= cx1) : (i += 1) {
            var aix: u64 = (@as(u64, @bitCast(@as(c_long, i))) *% a) ^ seed;
            _ = &aix;
            {
                j = cz0;
                while (j <= cz1) : (j += 1) {
                    setSeed(&s, aix ^ (@as(u64, @bitCast(@as(c_long, j))) *% b));
                    if (mc >= MC_1_13) {
                        if (__builtin_expect(@as(c_long, @intFromBool(nextDouble(&s) < 0.004)), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                            if ((out != null) and (n < nout)) {
                                (blk: {
                                    const tmp = n;
                                    if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                }).*.x = i * @as(c_int, 16);
                                (blk: {
                                    const tmp = n;
                                    if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                }).*.z = j * @as(c_int, 16);
                            }
                            n += 1;
                        }
                    } else {
                        skipNextN(&s, @as(u64, @bitCast(@as(c_long, @as(c_int, 1)))));
                        if (__builtin_expect(@as(c_long, @intFromBool(nextDouble(&s) < 0.004)), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
                            var d: c_int = i;
                            _ = &d;
                            if (-i > d) {
                                d = -i;
                            }
                            if (j > d) {
                                d = j;
                            }
                            if (-j > d) {
                                d = -j;
                            }
                            if ((d >= @as(c_int, 80)) or (nextInt(&s, @as(c_int, 80)) < d)) {
                                if ((out != null) and (n < nout)) {
                                    (blk: {
                                        const tmp = n;
                                        if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).*.x = i * @as(c_int, 16);
                                    (blk: {
                                        const tmp = n;
                                        if (tmp >= 0) break :blk out + @as(usize, @intCast(tmp)) else break :blk out - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).*.z = j * @as(c_int, 16);
                                }
                                n += 1;
                            }
                        }
                    }
                }
            }
        }
    }
    return n;
}

pub fn estimateSpawn(arg_g: [*c]const Generator, arg_rng: [*c]u64) Pos {
    var g = arg_g;
    _ = &g;
    var rng = arg_rng;
    _ = &rng;
    var spawn: Pos = Pos{
        .x = @as(c_int, 0),
        .z = @as(c_int, 0),
    };
    _ = &spawn;
    if (g.*.mc <= MC_B1_7) {
        return spawn;
    } else if (g.*.mc <= MC_1_17) {
        var found: c_int = undefined;
        _ = &found;
        var spawn_biomes: u64 = g_spawn_biomes_17;
        _ = &spawn_biomes;
        if (g.*.mc <= MC_1_0) {
            spawn_biomes = @as(u64, @bitCast(@as(c_ulong, @truncate(((@as(c_ulonglong, 1) << @intCast(forest)) | (@as(c_ulonglong, 1) << @intCast(swamp))) | (@as(c_ulonglong, 1) << @intCast(taiga))))));
        }
        var s: u64 = undefined;
        _ = &s;
        setSeed(&s, g.*.seed);
        spawn = locateBiome(g, @as(c_int, 0), @as(c_int, 63), @as(c_int, 0), @as(c_int, 256), spawn_biomes, @as(u64, @bitCast(@as(c_long, @as(c_int, 0)))), &s, &found);
        if (!(found != 0)) {
            spawn.x = blk: {
                const tmp = @as(c_int, 8);
                spawn.z = tmp;
                break :blk tmp;
            };
        }
        if (rng != null) {
            rng.* = s;
        }
    } else {
        spawn = findFittestPos(g);
    }
    return spawn;
}
pub export fn getSpawn(arg_g: [*c]const Generator) Pos {
    var g = arg_g;
    _ = &g;
    var rng: u64 = undefined;
    _ = &rng;
    var spawn: Pos = estimateSpawn(g, &rng);
    _ = &spawn;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var k: c_int = undefined;
    _ = &k;
    var u: c_int = undefined;
    _ = &u;
    var v: c_int = undefined;
    _ = &v;
    var cx0: c_int = undefined;
    _ = &cx0;
    var cz0: c_int = undefined;
    _ = &cz0;
    var ii: u32 = undefined;
    _ = &ii;
    var jj: u32 = undefined;
    _ = &jj;
    if (g.*.mc <= MC_B1_7) return spawn;
    var sn: SurfaceNoise = undefined;
    _ = &sn;
    initSurfaceNoise(&sn, DIM_OVERWORLD, g.*.seed);
    if (g.*.mc <= MC_1_12) {
        {
            i = 0;
            while (i < @as(c_int, 1000)) : (i += 1) {
                var y: f32 = undefined;
                _ = &y;
                var id: c_int = undefined;
                _ = &id;
                var grass: c_int = 0;
                _ = &grass;
                _ = mapApproxHeight(&y, &id, g, &sn, spawn.x >> @intCast(2), spawn.z >> @intCast(2), @as(c_int, 1), @as(c_int, 1));
                _ = getBiomeDepthAndScale(id, null, null, &grass);
                if ((grass > @as(c_int, 0)) and (y >= @as(f32, @floatFromInt(grass)))) break;
                spawn.x += nextInt(&rng, @as(c_int, 64)) - nextInt(&rng, @as(c_int, 64));
                spawn.z += nextInt(&rng, @as(c_int, 64)) - nextInt(&rng, @as(c_int, 64));
            }
        }
    } else if (g.*.mc <= MC_1_17) {
        j = blk: {
            const tmp = blk_1: {
                const tmp_2 = @as(c_int, 0);
                u = tmp_2;
                break :blk_1 tmp_2;
            };
            k = tmp;
            break :blk tmp;
        };
        v = -@as(c_int, 1);
        {
            i = 0;
            while (i < @as(c_int, 1024)) : (i += 1) {
                if ((((j > -@as(c_int, 16)) and (j <= @as(c_int, 16))) and (k > -@as(c_int, 16))) and (k <= @as(c_int, 16))) {
                    var y: [16]f32 = undefined;
                    _ = &y;
                    var ids: [16]c_int = undefined;
                    _ = &ids;
                    cx0 = (spawn.x & ~@as(c_int, 15)) + (j * @as(c_int, 16));
                    cz0 = (spawn.z & ~@as(c_int, 15)) + (k * @as(c_int, 16));
                    _ = mapApproxHeight(@as([*c]f32, @ptrCast(@alignCast(&y))), @as([*c]c_int, @ptrCast(@alignCast(&ids))), g, &sn, cx0 >> @intCast(2), cz0 >> @intCast(2), @as(c_int, 4), @as(c_int, 4));
                    {
                        ii = 0;
                        while (ii < @as(u32, @bitCast(@as(c_int, 4)))) : (ii +%= 1) {
                            {
                                jj = 0;
                                while (jj < @as(u32, @bitCast(@as(c_int, 4)))) : (jj +%= 1) {
                                    var grass: c_int = 0;
                                    _ = &grass;
                                    _ = getBiomeDepthAndScale(ids[(jj *% @as(u32, @bitCast(@as(c_int, 4)))) +% ii], null, null, &grass);
                                    if ((grass <= @as(c_int, 0)) or (y[(jj *% @as(u32, @bitCast(@as(c_int, 4)))) +% ii] < @as(f32, @floatFromInt(grass)))) continue;
                                    spawn.x = @as(c_int, @bitCast(@as(u32, @bitCast(cx0)) +% (ii *% @as(u32, @bitCast(@as(c_int, 4))))));
                                    spawn.z = @as(c_int, @bitCast(@as(u32, @bitCast(cz0)) +% (jj *% @as(u32, @bitCast(@as(c_int, 4))))));
                                    return spawn;
                                }
                            }
                        }
                    }
                }
                if (((j == k) or ((j < @as(c_int, 0)) and (j == -k))) or ((j > @as(c_int, 0)) and (j == (@as(c_int, 1) - k)))) {
                    var tmp: c_int = u;
                    _ = &tmp;
                    u = -v;
                    v = tmp;
                }
                j += u;
                k += v;
            }
        }
        spawn.x = (spawn.x & ~@as(c_int, 15)) + @as(c_int, 8);
        spawn.z = (spawn.z & ~@as(c_int, 15)) + @as(c_int, 8);
    } else {
        j = blk: {
            const tmp = blk_1: {
                const tmp_2 = @as(c_int, 0);
                u = tmp_2;
                break :blk_1 tmp_2;
            };
            k = tmp;
            break :blk tmp;
        };
        v = -@as(c_int, 1);
        {
            i = 0;
            while (i < @as(c_int, 121)) : (i += 1) {
                if ((((j >= -@as(c_int, 5)) and (j <= @as(c_int, 5))) and (k >= -@as(c_int, 5))) and (k <= @as(c_int, 5))) {
                    cx0 = (spawn.x & ~@as(c_int, 15)) + (j * @as(c_int, 16));
                    cz0 = (spawn.z & ~@as(c_int, 15)) + (k * @as(c_int, 16));
                    {
                        ii = 0;
                        while (ii < @as(u32, @bitCast(@as(c_int, 4)))) : (ii +%= 1) {
                            {
                                jj = 0;
                                while (jj < @as(u32, @bitCast(@as(c_int, 4)))) : (jj +%= 1) {
                                    var y: f32 = undefined;
                                    _ = &y;
                                    var id: c_int = undefined;
                                    _ = &id;
                                    var x: c_int = @as(c_int, @bitCast(@as(u32, @bitCast(cx0)) +% (ii *% @as(u32, @bitCast(@as(c_int, 4))))));
                                    _ = &x;
                                    var z: c_int = @as(c_int, @bitCast(@as(u32, @bitCast(cz0)) +% (jj *% @as(u32, @bitCast(@as(c_int, 4))))));
                                    _ = &z;
                                    _ = mapApproxHeight(&y, &id, g, &sn, x >> @intCast(2), z >> @intCast(2), @as(c_int, 1), @as(c_int, 1));
                                    if ((((y > @as(f32, @floatFromInt(@as(c_int, 63)))) or (id == frozen_ocean)) or (id == deep_frozen_ocean)) or (id == frozen_river)) {
                                        spawn.x = x;
                                        spawn.z = z;
                                        return spawn;
                                    }
                                }
                            }
                        }
                    }
                }
                if (((j == k) or ((j < @as(c_int, 0)) and (j == -k))) or ((j > @as(c_int, 0)) and (j == (@as(c_int, 1) - k)))) {
                    var tmp: c_int = u;
                    _ = &tmp;
                    u = -v;
                    v = tmp;
                }
                j += u;
                k += v;
            }
        }
        spawn.x = (spawn.x & ~@as(c_int, 15)) + @as(c_int, 8);
        spawn.z = (spawn.z & ~@as(c_int, 15)) + @as(c_int, 8);
    }
    return spawn;
}
pub fn locateBiome(arg_g: [*c]const Generator, arg_x: c_int, arg_y: c_int, arg_z: c_int, arg_radius: c_int, arg_validB: u64, arg_validM: u64, arg_rng: [*c]u64, arg_passes: [*c]c_int) Pos {
    var g = arg_g;
    _ = &g;
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var z = arg_z;
    _ = &z;
    var radius = arg_radius;
    _ = &radius;
    var validB = arg_validB;
    _ = &validB;
    var validM = arg_validM;
    _ = &validM;
    var rng = arg_rng;
    _ = &rng;
    var passes = arg_passes;
    _ = &passes;
    var out: Pos = Pos{
        .x = x,
        .z = z,
    };
    _ = &out;
    var i: c_int = undefined;
    _ = &i;
    var j: c_int = undefined;
    _ = &j;
    var found: c_int = undefined;
    _ = &found;
    found = 0;
    if (g.*.mc >= MC_1_18) {
        x >>= @intCast(@as(c_int, 2));
        z >>= @intCast(@as(c_int, 2));
        radius >>= @intCast(@as(c_int, 2));
        var dat: u64 = 0;
        _ = &dat;
        {
            j = -radius;
            while (j <= radius) : (j += 1) {
                {
                    i = -radius;
                    while (i <= radius) : (i += 1) {
                        var id: c_int = sampleBiomeNoise(&g.*.unnamed_0.unnamed_1.bn, null, x + i, y, z + j, &dat, @as(u32, @bitCast(@as(c_int, 0))));
                        _ = &id;
                        if (!(id_matches(id, validB, validM) != 0)) continue;
                        if ((found == @as(c_int, 0)) or (nextInt(rng, found + @as(c_int, 1)) == @as(c_int, 0))) {
                            out.x = (x + i) * @as(c_int, 4);
                            out.z = (z + j) * @as(c_int, 4);
                        }
                        found += 1;
                    }
                }
            }
        }
    } else {
        var x1: c_int = (x - radius) >> @intCast(2);
        _ = &x1;
        var z1: c_int = (z - radius) >> @intCast(2);
        _ = &z1;
        var x2: c_int = (x + radius) >> @intCast(2);
        _ = &x2;
        var z2: c_int = (z + radius) >> @intCast(2);
        _ = &z2;
        var width: c_int = (x2 - x1) + @as(c_int, 1);
        _ = &width;
        var height: c_int = (z2 - z1) + @as(c_int, 1);
        _ = &height;
        var r: Range = Range{
            .scale = @as(c_int, 4),
            .x = x1,
            .z = z1,
            .sx = width,
            .sz = height,
            .y = y,
            .sy = @as(c_int, 1),
        };
        _ = &r;
        var ids: [*c]c_int = allocCache(g, r);
        _ = &ids;
        _ = genBiomes(g, ids, r);
        if (g.*.mc >= MC_1_13) {
            {
                _ = blk: {
                    i = 0;
                    break :blk blk_1: {
                        const tmp = @as(c_int, 2);
                        j = tmp;
                        break :blk_1 tmp;
                    };
                };
                while (i < (width * height)) : (i += 1) {
                    if (!(id_matches((blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk ids + @as(usize, @intCast(tmp)) else break :blk ids - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*, validB, validM) != 0)) continue;
                    if ((found == @as(c_int, 0)) or (nextInt(rng, blk: {
                        const ref = &j;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }) == @as(c_int, 0))) {
                        out.x = (x1 + @import("std").zig.c_translation.signedRemainder(i, width)) * @as(c_int, 4);
                        out.z = (z1 + @divTrunc(i, width)) * @as(c_int, 4);
                        found = 1;
                    }
                }
            }
            found = j - @as(c_int, 2);
        } else {
            {
                i = 0;
                while (i < (width * height)) : (i += 1) {
                    if (!(id_matches((blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk ids + @as(usize, @intCast(tmp)) else break :blk ids - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*, validB, validM) != 0)) continue;
                    if ((found == @as(c_int, 0)) or (nextInt(rng, found + @as(c_int, 1)) == @as(c_int, 0))) {
                        out.x = (x1 + @import("std").zig.c_translation.signedRemainder(i, width)) * @as(c_int, 4);
                        out.z = (z1 + @divTrunc(i, width)) * @as(c_int, 4);
                        found += 1;
                    }
                }
            }
        }
        free(@as(?*anyopaque, @ptrCast(ids)));
    }
    if (passes != @as([*c]c_int, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        passes.* = found;
    }
    return out;
}

pub export fn isViableStructurePos(arg_structureType: c_int, arg_g: [*c]Generator, arg_x: c_int, arg_z: c_int, arg_flags: u32) c_int {
    const structureType = arg_structureType;
    const g = arg_g;
    const x = arg_x;
    const z = arg_z;
    const flags = arg_flags;

    if (g == null) return 0;

    const chunkX = x >> 4;
    const chunkZ = z >> 4;

    if (g.*.dim != DIM_OVERWORLD) return 0;
    if (g.*.mc < MC_1_18) return 0;

    switch (structureType) {
        Trail_Ruins => {
            if (g.*.mc <= MC_1_19) return 0;
            const id = getBiomeAt(g, 0, chunkX * 4 + 2, 319 >> 2, chunkZ * 4 + 2);
            return @intFromBool(id >= 0 and isViableFeatureBiome(g.*.mc, structureType, id) != 0);
        },
        Ocean_Ruin, Shipwreck, Treasure, Igloo, Desert_Pyramid, Jungle_Pyramid, Swamp_Hut => {
            const id = getBiomeAt(g, 0, chunkX * 4 + 2, 319 >> 2, chunkZ * 4 + 2);
            return @intFromBool(id >= 0 and isViableFeatureBiome(g.*.mc, structureType, id) != 0);
        },
        Village => {
            const vv = [_]c_int{ plains, desert, savanna, taiga, snowy_tundra };
            for (vv) |vbiome| {
                if (flags != 0 and flags != @as(u32, @bitCast(vbiome))) continue;
                var sv: StructureVariant = undefined;
                _ = getVariant(&sv, Village, g.*.mc, g.*.seed, x, z, vbiome);
                const sampleX = @divTrunc((chunkX * 32 + 2 * @as(c_int, sv.x) + @as(c_int, sv.sx) - 1), 2) >> 2;
                const sampleZ = @divTrunc((chunkZ * 32 + 2 * @as(c_int, sv.z) + @as(c_int, sv.sz) - 1), 2) >> 2;
                const id = getBiomeAt(g, 0, sampleX, 319 >> 2, sampleZ);
                if (id == vbiome or (id == meadow and vbiome == plains)) return vbiome;
            }
            return 0;
        },
        Outpost => {
            if (g.*.mc <= MC_1_13) return 0;
            var rng = g.*.seed;
            setAttemptSeed(&rng, chunkX, chunkZ);
            if (nextInt(&rng, 5) != 0) return 0;

            var vilconf: StructureConfig = undefined;
            if (getStructureConfig(Village, g.*.mc, &vilconf) == 0) return 0;
            const cx0 = chunkX - 10;
            const cx1 = chunkX + 10;
            const cz0 = chunkZ - 10;
            const cz1 = chunkZ + 10;
            const rx0 = floordiv(cx0, vilconf.regionSize);
            const rx1 = floordiv(cx1, vilconf.regionSize);
            const rz0 = floordiv(cz0, vilconf.regionSize);
            const rz1 = floordiv(cz1, vilconf.regionSize);
            var rz: c_int = rz0;
            while (rz <= rz1) : (rz += 1) {
                var rx: c_int = rx0;
                while (rx <= rx1) : (rx += 1) {
                    const p = getFeaturePos(vilconf, g.*.seed, rx, rz);
                    const cx = p.x >> 4;
                    const cz = p.z >> 4;
                    if (cx >= cx0 and cx <= cx1 and cz >= cz0 and cz <= cz1) return 0;
                }
            }

            rng = chunkGenerateRnd(g.*.seed, chunkX, chunkZ);
            var sampleX: c_int = undefined;
            var sampleZ: c_int = undefined;
            switch (nextInt(&rng, 4)) {
                0 => {
                    sampleX = 15;
                    sampleZ = 15;
                },
                1 => {
                    sampleX = -15;
                    sampleZ = 15;
                },
                2 => {
                    sampleX = -15;
                    sampleZ = -15;
                },
                else => {
                    sampleX = 15;
                    sampleZ = -15;
                },
            }
            sampleX = @divTrunc((chunkX * 32 + sampleX), 2) >> 2;
            sampleZ = @divTrunc((chunkZ * 32 + sampleZ), 2) >> 2;
            const id = getBiomeAt(g, 0, sampleX, 319 >> 2, sampleZ);
            return @intFromBool(id >= 0 and isViableFeatureBiome(g.*.mc, structureType, id) != 0);
        },
        Monument => {
            const sampleX = chunkX * 16 + 8;
            const sampleZ = chunkZ * 16 + 8;
            const id = getBiomeAt(g, 4, sampleX >> 2, 36 >> 2, sampleZ >> 2);
            if (isDeepOcean(id) == 0) return 0;
            return areBiomesViable(g, sampleX, 63, sampleZ, 29, g_monument_biomes1, 0, 0);
        },
        Mansion => {
            const sampleX = chunkX * 16 + 7;
            const sampleZ = chunkZ * 16 + 7;
            const id = getBiomeAt(g, 4, sampleX >> 2, 319 >> 2, sampleZ >> 2);
            return @intFromBool(id >= 0 and isViableFeatureBiome(g.*.mc, structureType, id) != 0);
        },
        Ruined_Portal, Ruined_Portal_N => return @intFromBool(g.*.mc > MC_1_15),
        Geode => return @intFromBool(g.*.mc > MC_1_16),
        Ancient_City, Trial_Chambers => {
            if (structureType == Ancient_City and g.*.mc <= MC_1_18) return 0;
            if (structureType == Trial_Chambers and g.*.mc <= MC_1_20) return 0;
            var sv: StructureVariant = undefined;
            _ = getVariant(&sv, structureType, g.*.mc, g.*.seed, x, z, -1);
            const sampleX = @divTrunc((chunkX * 32 + 2 * @as(c_int, sv.x) + @as(c_int, sv.sx) - 1), 2) >> 2;
            const sampleZ = @divTrunc((chunkZ * 32 + 2 * @as(c_int, sv.z) + @as(c_int, sv.sz) - 1), 2) >> 2;
            const sampleY = @as(c_int, sv.y) >> 2;
            const id = getBiomeAt(g, 4, sampleX, sampleY, sampleZ);
            return @intFromBool(id >= 0 and isViableFeatureBiome(g.*.mc, structureType, id) != 0);
        },
        Mineshaft => return 1,
        else => return 0,
    }
}
pub fn isViableFeatureBiome(arg_mc: c_int, arg_structureType: c_int, arg_biomeID: c_int) c_int {
    var mc = arg_mc;
    _ = &mc;
    var structureType = arg_structureType;
    _ = &structureType;
    var biomeID = arg_biomeID;
    _ = &biomeID;
    while (true) {
        switch (structureType) {
            @as(c_int, 1) => return @intFromBool((biomeID == desert) or (biomeID == desert_hills)),
            @as(c_int, 2) => return @intFromBool((((biomeID == jungle) or (biomeID == jungle_hills)) or (biomeID == bamboo_jungle)) or (biomeID == bamboo_jungle_hills)),
            @as(c_int, 3) => return @intFromBool(biomeID == swamp),
            @as(c_int, 4) => {
                if (mc <= MC_1_8) return 0;
                return @intFromBool(((biomeID == snowy_tundra) or (biomeID == snowy_taiga)) or (biomeID == snowy_slopes));
            },
            @as(c_int, 6) => {
                if (mc <= MC_1_12) return 0;
                return isOceanic(biomeID);
            },
            @as(c_int, 7) => {
                if (mc <= MC_1_12) return 0;
                return @intFromBool(((isOceanic(biomeID) != 0) or (biomeID == beach)) or (biomeID == snowy_beach));
            },
            @as(c_int, 11), @as(c_int, 12) => return @intFromBool(mc >= MC_1_16_1),
            @as(c_int, 13) => {
                if (mc <= MC_1_18) return 0;
                return @intFromBool(biomeID == deep_dark);
            },
            @as(c_int, 23) => {
                if (mc <= MC_1_19) return 0 else {
                    while (true) {
                        switch (biomeID) {
                            @as(c_int, 5), @as(c_int, 30), @as(c_int, 32), @as(c_int, 160), @as(c_int, 155), @as(c_int, 21) => return 1,
                            else => return 0,
                        }
                        break;
                    }
                }
                if (mc <= MC_1_20) return 0;
                return @intFromBool((biomeID != deep_dark) and (isOverworld(mc, biomeID) != 0));
            },
            @as(c_int, 24) => {
                if (mc <= MC_1_20) return 0;
                return @intFromBool((biomeID != deep_dark) and (isOverworld(mc, biomeID) != 0));
            },
            @as(c_int, 14) => {
                if (mc <= MC_1_12) return 0;
                return @intFromBool((biomeID == beach) or (biomeID == snowy_beach));
            },
            @as(c_int, 15) => return isOverworld(mc, biomeID),
            @as(c_int, 16) => return @intFromBool(biomeID == desert),
            @as(c_int, 8) => {
                if (mc <= MC_1_7) return 0;
                return isDeepOcean(biomeID);
            },
            @as(c_int, 10) => {
                if (mc <= MC_1_13) return 0;
                if (mc >= MC_1_18) {
                    while (true) {
                        switch (biomeID) {
                            @as(c_int, 2), @as(c_int, 1), @as(c_int, 35), @as(c_int, 12), @as(c_int, 5), @as(c_int, 177), @as(c_int, 181), @as(c_int, 180), @as(c_int, 182), @as(c_int, 179), @as(c_int, 178), @as(c_int, 185) => return 1,
                            else => return 0,
                        }
                        break;
                    }
                }
                if (((biomeID == plains) or (biomeID == desert)) or (biomeID == savanna)) return 1;
                if ((mc >= MC_1_10) and (biomeID == taiga)) return 1;
                if ((mc >= MC_1_14) and (biomeID == snowy_tundra)) return 1;
                if ((mc >= MC_1_18) and (biomeID == meadow)) return 1;
                return 0;
            },
            @as(c_int, 5) => {
                if (((biomeID == plains) or (biomeID == desert)) or (biomeID == savanna)) return 1;
                if ((mc >= MC_1_10) and (biomeID == taiga)) return 1;
                if ((mc >= MC_1_14) and (biomeID == snowy_tundra)) return 1;
                if ((mc >= MC_1_18) and (biomeID == meadow)) return 1;
                return 0;
            },
            @as(c_int, 9) => {
                if (mc <= MC_1_10) return 0;
                return @intFromBool((biomeID == dark_forest) or (biomeID == dark_forest_hills));
            },
            @as(c_int, 18) => return @intFromBool(((((biomeID == nether_wastes) or (biomeID == soul_sand_valley)) or (biomeID == warped_forest)) or (biomeID == crimson_forest)) or (biomeID == basalt_deltas)),
            @as(c_int, 19) => {
                if (mc <= MC_1_15) return 0;
                return @intFromBool((((biomeID == nether_wastes) or (biomeID == soul_sand_valley)) or (biomeID == warped_forest)) or (biomeID == crimson_forest));
            },
            @as(c_int, 20) => {
                if (mc <= MC_1_8) return 0;
                return @intFromBool((biomeID == end_midlands) or (biomeID == end_highlands));
            },
            @as(c_int, 21) => {
                if (mc <= MC_1_12) return 0;
                return @intFromBool(biomeID == end_highlands);
            },
            else => {
                // _ = fprintf(stderr, "isViableFeatureBiome: not implemented for structure type %d.\n", structureType);
                exit(@as(c_int, 1));
            },
        }
        break;
    }
    return 0;
}
pub export fn isViableStructureTerrain(arg_structType: c_int, arg_g: [*c]Generator, arg_x: c_int, arg_z: c_int) c_int {
    var structType = arg_structType;
    _ = &structType;
    var g = arg_g;
    _ = &g;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var sx: c_int = undefined;
    _ = &sx;
    var sz: c_int = undefined;
    _ = &sz;
    if (g.*.mc <= MC_1_17) return 1;
    if ((structType == Desert_Pyramid) or (structType == Jungle_Temple)) {
        sx = if (structType == Desert_Pyramid) @as(c_int, 21) else @as(c_int, 12);
        sz = if (structType == Desert_Pyramid) @as(c_int, 21) else @as(c_int, 15);
    } else if (structType == Mansion) {
        var cx: c_int = x >> @intCast(4);
        _ = &cx;
        var cz: c_int = z >> @intCast(4);
        _ = &cz;
        var rng: u64 = chunkGenerateRnd(g.*.seed, cx, cz);
        _ = &rng;
        var rot: c_int = nextInt(&rng, @as(c_int, 4));
        _ = &rot;
        sx = 5;
        sz = 5;
        if (rot == @as(c_int, 0)) {
            sx = -@as(c_int, 5);
        }
        if (rot == @as(c_int, 1)) {
            sx = -@as(c_int, 5);
            sz = -@as(c_int, 5);
        }
        if (rot == @as(c_int, 2)) {
            sz = -@as(c_int, 5);
        }
        x = (cx * @as(c_int, 16)) + @as(c_int, 7);
        z = (cz * @as(c_int, 16)) + @as(c_int, 7);
    } else {
        return 1;
    }
    var corners: [4][2]f64 = [4][2]f64{
        [2]f64{
            @as(f64, @floatFromInt(x + @as(c_int, 0))) / 4.0,
            @as(f64, @floatFromInt(z + @as(c_int, 0))) / 4.0,
        },
        [2]f64{
            @as(f64, @floatFromInt(x + sx)) / 4.0,
            @as(f64, @floatFromInt(z + sz)) / 4.0,
        },
        [2]f64{
            @as(f64, @floatFromInt(x + @as(c_int, 0))) / 4.0,
            @as(f64, @floatFromInt(z + sz)) / 4.0,
        },
        [2]f64{
            @as(f64, @floatFromInt(x + sx)) / 4.0,
            @as(f64, @floatFromInt(z + @as(c_int, 0))) / 4.0,
        },
    };
    _ = &corners;
    var nptype: c_int = g.*.unnamed_0.unnamed_1.bn.nptype;
    _ = &nptype;
    var i: c_int = undefined;
    _ = &i;
    var ret: c_int = 1;
    _ = &ret;
    g.*.unnamed_0.unnamed_1.bn.nptype = NP_DEPTH;
    {
        i = 0;
        while (i < @as(c_int, 4)) : (i += 1) {
            var depth: f64 = sampleClimatePara(&g.*.unnamed_0.unnamed_1.bn, null, corners[@as(c_uint, @intCast(i))][@as(c_uint, @intCast(@as(c_int, 0)))], corners[@as(c_uint, @intCast(i))][@as(c_uint, @intCast(@as(c_int, 1)))]);
            _ = &depth;
            if (depth < 0.48) {
                ret = 0;
                break;
            }
        }
    }
    g.*.unnamed_0.unnamed_1.bn.nptype = nptype;
    return ret;
}
pub fn chunkGenerateRnd(arg_worldSeed: u64, arg_chunkX: c_int, arg_chunkZ: c_int) u64 {
    var worldSeed = arg_worldSeed;
    _ = &worldSeed;
    var chunkX = arg_chunkX;
    _ = &chunkX;
    var chunkZ = arg_chunkZ;
    _ = &chunkZ;
    var rnd: u64 = undefined;
    _ = &rnd;
    setSeed(&rnd, worldSeed);
    rnd = ((nextLong(&rnd) *% @as(u64, @bitCast(@as(c_long, chunkX)))) ^ (nextLong(&rnd) *% @as(u64, @bitCast(@as(c_long, chunkZ))))) ^ worldSeed;
    setSeed(&rnd, rnd);
    return rnd;
}

pub fn getVariant(arg_r: ?*StructureVariant, arg_structType: c_int, arg_mc: c_int, arg_seed: u64, arg_x: c_int, arg_z: c_int, arg_biomeID: c_int) c_int {
    const r = arg_r orelse return 0;
    const structType = arg_structType;
    const mc = arg_mc;
    var x = arg_x;
    var z = arg_z;
    const biomeID = arg_biomeID;

    const abandoned_bit: u8 = 1 << 0;
    const giant_bit: u8 = 1 << 1;
    const underground_bit: u8 = 1 << 2;
    const airpocket_bit: u8 = 1 << 3;
    const basement_bit: u8 = 1 << 4;
    const cracked_bit: u8 = 1 << 5;

    var t: c_int = undefined;
    var sx: i16 = 0;
    var sy: i16 = 0;
    var sz: i16 = 0;
    var rng: u64 = chunkGenerateRnd(arg_seed, x >> 4, z >> 4);

    r.* = .{
        .flags = 0,
        .size = 0,
        .start = @bitCast(@as(i8, -1)),
        .biome = -1,
        .rotation = 0,
        .mirror = 0,
        .x = 0,
        .y = 320,
        .z = 0,
        .sx = 0,
        .sy = 0,
        .sz = 0,
    };

    switch (structType) {
        Village => {
            if (mc <= MC_1_9) return 0;
            if (isViableFeatureBiome(mc, Village, biomeID) == 0) return 0;
            if (mc <= MC_1_13) {
                skipNextN(&rng, if (mc == MC_1_13) 10 else 11);
                if (nextInt(&rng, 50) == 0) r.*.flags |= abandoned_bit;
                return 1;
            }
            r.*.biome = @as(c_short, @intCast(biomeID));
            r.*.rotation = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 4)))));
            switch (biomeID) {
                meadow => {
                    r.*.biome = @as(c_short, @intCast(plains));
                    t = nextInt(&rng, 204);
                    if (t < 50) {
                        r.*.start = 0;
                        sx = 9;
                        sy = 4;
                        sz = 9;
                    } else if (t < 100) {
                        r.*.start = 1;
                        sx = 10;
                        sy = 7;
                        sz = 10;
                    } else if (t < 150) {
                        r.*.start = 2;
                        sx = 8;
                        sy = 5;
                        sz = 15;
                    } else if (t < 200) {
                        r.*.start = 3;
                        sx = 11;
                        sy = 9;
                        sz = 11;
                    } else if (t < 201) {
                        r.*.start = 0;
                        sx = 9;
                        sy = 4;
                        sz = 9;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 202) {
                        r.*.start = 1;
                        sx = 10;
                        sy = 7;
                        sz = 10;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 203) {
                        r.*.start = 2;
                        sx = 8;
                        sy = 5;
                        sz = 15;
                        r.*.flags |= abandoned_bit;
                    } else {
                        r.*.start = 3;
                        sx = 11;
                        sy = 9;
                        sz = 11;
                        r.*.flags |= abandoned_bit;
                    }
                },
                plains => {
                    t = nextInt(&rng, 204);
                    if (t < 50) {
                        r.*.start = 0;
                        sx = 9;
                        sy = 4;
                        sz = 9;
                    } else if (t < 100) {
                        r.*.start = 1;
                        sx = 10;
                        sy = 7;
                        sz = 10;
                    } else if (t < 150) {
                        r.*.start = 2;
                        sx = 8;
                        sy = 5;
                        sz = 15;
                    } else if (t < 200) {
                        r.*.start = 3;
                        sx = 11;
                        sy = 9;
                        sz = 11;
                    } else if (t < 201) {
                        r.*.start = 0;
                        sx = 9;
                        sy = 4;
                        sz = 9;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 202) {
                        r.*.start = 1;
                        sx = 10;
                        sy = 7;
                        sz = 10;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 203) {
                        r.*.start = 2;
                        sx = 8;
                        sy = 5;
                        sz = 15;
                        r.*.flags |= abandoned_bit;
                    } else {
                        r.*.start = 3;
                        sx = 11;
                        sy = 9;
                        sz = 11;
                        r.*.flags |= abandoned_bit;
                    }
                },
                desert => {
                    t = nextInt(&rng, 250);
                    if (t < 98) {
                        r.*.start = 1;
                        sx = 17;
                        sy = 6;
                        sz = 9;
                    } else if (t < 196) {
                        r.*.start = 2;
                        sx = 12;
                        sy = 6;
                        sz = 12;
                    } else if (t < 245) {
                        r.*.start = 3;
                        sx = 15;
                        sy = 6;
                        sz = 15;
                    } else if (t < 247) {
                        r.*.start = 1;
                        sx = 17;
                        sy = 6;
                        sz = 9;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 249) {
                        r.*.start = 2;
                        sx = 12;
                        sy = 6;
                        sz = 12;
                        r.*.flags |= abandoned_bit;
                    } else {
                        r.*.start = 3;
                        sx = 15;
                        sy = 6;
                        sz = 15;
                        r.*.flags |= abandoned_bit;
                    }
                },
                savanna => {
                    t = nextInt(&rng, 459);
                    if (t < 100) {
                        r.*.start = 1;
                        sx = 14;
                        sy = 5;
                        sz = 12;
                    } else if (t < 150) {
                        r.*.start = 2;
                        sx = 11;
                        sy = 6;
                        sz = 11;
                    } else if (t < 300) {
                        r.*.start = 3;
                        sx = 9;
                        sy = 6;
                        sz = 11;
                    } else if (t < 450) {
                        r.*.start = 4;
                        sx = 9;
                        sy = 6;
                        sz = 9;
                    } else if (t < 452) {
                        r.*.start = 1;
                        sx = 14;
                        sy = 5;
                        sz = 12;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 453) {
                        r.*.start = 2;
                        sx = 11;
                        sy = 6;
                        sz = 11;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 456) {
                        r.*.start = 3;
                        sx = 9;
                        sy = 6;
                        sz = 11;
                        r.*.flags |= abandoned_bit;
                    } else {
                        r.*.start = 4;
                        sx = 9;
                        sy = 6;
                        sz = 9;
                        r.*.flags |= abandoned_bit;
                    }
                },
                taiga => {
                    t = nextInt(&rng, 100);
                    if (t < 49) {
                        r.*.start = 1;
                        sx = 22;
                        sy = 3;
                        sz = 18;
                    } else if (t < 98) {
                        r.*.start = 2;
                        sx = 9;
                        sy = 7;
                        sz = 9;
                    } else if (t < 99) {
                        r.*.start = 1;
                        sx = 22;
                        sy = 3;
                        sz = 18;
                        r.*.flags |= abandoned_bit;
                    } else {
                        r.*.start = 2;
                        sx = 9;
                        sy = 7;
                        sz = 9;
                        r.*.flags |= abandoned_bit;
                    }
                },
                snowy_tundra => {
                    t = nextInt(&rng, 306);
                    if (t < 100) {
                        r.*.start = 1;
                        sx = 12;
                        sy = 8;
                        sz = 8;
                    } else if (t < 150) {
                        r.*.start = 2;
                        sx = 11;
                        sy = 5;
                        sz = 9;
                    } else if (t < 300) {
                        r.*.start = 3;
                        sx = 7;
                        sy = 7;
                        sz = 7;
                    } else if (t < 302) {
                        r.*.start = 1;
                        sx = 12;
                        sy = 8;
                        sz = 8;
                        r.*.flags |= abandoned_bit;
                    } else if (t < 303) {
                        r.*.start = 2;
                        sx = 11;
                        sy = 5;
                        sz = 9;
                        r.*.flags |= abandoned_bit;
                    } else {
                        r.*.start = 3;
                        sx = 7;
                        sy = 7;
                        sz = 7;
                        r.*.flags |= abandoned_bit;
                    }
                },
                else => return 0,
            }
            r.*.sy = sy;
            if (mc >= MC_1_18) {
                switch (r.*.rotation) {
                    0 => {
                        r.*.x = 0;
                        r.*.z = 0;
                        r.*.sx = sx;
                        r.*.sz = sz;
                    },
                    1 => {
                        r.*.x = @as(i16, @intCast(1 - @as(c_int, sz)));
                        r.*.z = 0;
                        r.*.sx = sz;
                        r.*.sz = sx;
                    },
                    2 => {
                        r.*.x = @as(i16, @intCast(1 - @as(c_int, sx)));
                        r.*.z = @as(i16, @intCast(1 - @as(c_int, sz)));
                        r.*.sx = sx;
                        r.*.sz = sz;
                    },
                    else => {
                        r.*.x = 0;
                        r.*.z = @as(i16, @intCast(1 - @as(c_int, sx)));
                        r.*.sx = sz;
                        r.*.sz = sx;
                    },
                }
            } else {
                const xneg: c_int = @intFromBool(x < 0);
                const zneg: c_int = @intFromBool(z < 0);
                switch (r.*.rotation) {
                    0 => {
                        r.*.x = 0;
                        r.*.z = 0;
                        r.*.sx = sx;
                        r.*.sz = sz;
                    },
                    1 => {
                        r.*.x = @as(i16, @intCast(xneg - @as(c_int, sz)));
                        r.*.z = 0;
                        r.*.sx = sz;
                        r.*.sz = sx;
                    },
                    2 => {
                        r.*.x = @as(i16, @intCast(xneg - @as(c_int, sx)));
                        r.*.z = @as(i16, @intCast(zneg - @as(c_int, sz)));
                        r.*.sx = sx;
                        r.*.sz = sz;
                    },
                    else => {
                        r.*.x = 0;
                        r.*.z = @as(i16, @intCast(zneg - @as(c_int, sx)));
                        r.*.sx = sz;
                        r.*.sz = sx;
                    },
                }
            }
            return 1;
        },
        Ancient_City => {
            r.*.rotation = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 4)))));
            r.*.start = @as(u8, @bitCast(@as(i8, @truncate(1 + nextInt(&rng, 3)))));
            sx = 18;
            sy = 31;
            sz = 41;
            const xpos: c_int = @intFromBool(x > 0);
            const zpos: c_int = @intFromBool(z > 0);
            const xneg: c_int = @intFromBool(x < 0);
            const zneg: c_int = @intFromBool(z < 0);
            switch (r.*.rotation) {
                0 => {
                    x = -xpos;
                    z = -zpos;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                1 => {
                    x = xneg - sz;
                    z = -zpos;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
                2 => {
                    x = xneg - sx;
                    z = zneg - sz;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                else => {
                    x = -xpos;
                    z = zneg - sx;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
            }
            sx = 13;
            sz = 20;
            switch (r.*.rotation) {
                0 => {
                    r.*.x = @as(i16, @intCast(x - @as(c_int, sx)));
                    r.*.z = @as(i16, @intCast(z - @as(c_int, sz)));
                },
                1 => {
                    r.*.x = @as(i16, @intCast(x + @as(c_int, sz)));
                    r.*.z = @as(i16, @intCast(z - @as(c_int, sx)));
                },
                2 => {
                    r.*.x = @as(i16, @intCast(x + @as(c_int, sx)));
                    r.*.z = @as(i16, @intCast(z + @as(c_int, sz)));
                },
                else => {
                    r.*.x = @as(i16, @intCast(x - @as(c_int, sz)));
                    r.*.z = @as(i16, @intCast(z + @as(c_int, sx)));
                },
            }
            r.*.y = -27;
            r.*.sy = sy;
            return 1;
        },
        Trial_Chambers => {
            r.*.y = @as(i16, @intCast(nextInt(&rng, 21) - 40));
            r.*.rotation = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 4)))));
            r.*.start = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 2)))));
            r.*.sx = 19;
            r.*.sy = 20;
            r.*.sz = 19;
            switch (r.*.rotation) {
                1 => {
                    r.*.x = @as(i16, @intCast(1 - @as(c_int, r.*.sz)));
                    r.*.z = 0;
                },
                2 => {
                    r.*.x = @as(i16, @intCast(1 - @as(c_int, r.*.sx)));
                    r.*.z = @as(i16, @intCast(1 - @as(c_int, r.*.sz)));
                },
                3 => {
                    r.*.x = 0;
                    r.*.z = @as(i16, @intCast(1 - @as(c_int, r.*.sx)));
                },
                else => {},
            }
            return 1;
        },
        Monument => {
            r.*.x = -29;
            r.*.z = -29;
            r.*.sx = 58;
            r.*.sz = 58;
            return 1;
        },
        Igloo => {
            if (mc <= MC_1_12) setSeed(&rng, getPopulationSeed(mc, arg_seed, (x >> 4) - 1, (z >> 4) - 1));
            r.*.rotation = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 4)))));
            if (nextDouble(&rng) < 0.5) r.*.flags |= basement_bit;
            r.*.size = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 8) + 4))));
            sx = 7;
            sy = 5;
            sz = 8;
            r.*.sy = sy;
            switch (r.*.rotation) {
                0 => {
                    r.*.rotation = 0;
                    r.*.mirror = 0;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                1 => {
                    r.*.rotation = 1;
                    r.*.mirror = 0;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
                2 => {
                    r.*.rotation = 0;
                    r.*.mirror = 1;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                else => {
                    r.*.rotation = 1;
                    r.*.mirror = 1;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
            }
            return 1;
        },
        Desert_Pyramid => {
            sx = 21;
            sy = 15;
            sz = 21;
            r.*.sy = sy;
            if (mc <= MC_1_19) {
                r.*.sx = sx;
                r.*.sz = sz;
                return 1;
            }
            switch (nextInt(&rng, 4)) {
                0 => {
                    r.*.rotation = 0;
                    r.*.mirror = 0;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                1 => {
                    r.*.rotation = 1;
                    r.*.mirror = 0;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
                2 => {
                    r.*.rotation = 0;
                    r.*.mirror = 1;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                else => {
                    r.*.rotation = 1;
                    r.*.mirror = 1;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
            }
            return 1;
        },
        Jungle_Temple => {
            sx = 12;
            sy = 10;
            sz = 15;
            r.*.sy = sy;
            if (mc <= MC_1_19) {
                r.*.sx = sx;
                r.*.sz = sz;
                return 1;
            }
            switch (nextInt(&rng, 4)) {
                0 => {
                    r.*.rotation = 0;
                    r.*.mirror = 0;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                1 => {
                    r.*.rotation = 1;
                    r.*.mirror = 0;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
                2 => {
                    r.*.rotation = 0;
                    r.*.mirror = 1;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                else => {
                    r.*.rotation = 1;
                    r.*.mirror = 1;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
            }
            return 1;
        },
        Swamp_Hut => {
            sx = 7;
            sy = 7;
            sz = 9;
            r.*.sy = sy;
            if (mc <= MC_1_19) {
                r.*.sx = sx;
                r.*.sz = sz;
                return 1;
            }
            switch (nextInt(&rng, 4)) {
                0 => {
                    r.*.rotation = 0;
                    r.*.mirror = 0;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                1 => {
                    r.*.rotation = 1;
                    r.*.mirror = 0;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
                2 => {
                    r.*.rotation = 0;
                    r.*.mirror = 1;
                    r.*.sx = sx;
                    r.*.sz = sz;
                },
                else => {
                    r.*.rotation = 1;
                    r.*.mirror = 1;
                    r.*.sx = sz;
                    r.*.sz = sx;
                },
            }
            return 1;
        },
        Ruined_Portal, Ruined_Portal_N => {
            const cat = getCategory(mc, biomeID);
            switch (cat) {
                desert, jungle, swamp, ocean, nether_wastes => r.*.biome = @as(c_short, @intCast(cat)),
                else => {},
            }
            if (r.*.biome == -1) {
                switch (biomeID) {
                    mangrove_swamp => r.*.biome = @as(c_short, @intCast(swamp)),
                    mountains, mountain_edge, wooded_mountains, gravelly_mountains, modified_gravelly_mountains, savanna_plateau, shattered_savanna, shattered_savanna_plateau, badlands, eroded_badlands, wooded_badlands_plateau, modified_badlands_plateau, modified_wooded_badlands_plateau, snowy_taiga_mountains, taiga_mountains, stony_shore, meadow, frozen_peaks, jagged_peaks, stony_peaks, snowy_slopes => r.*.biome = @as(c_short, @intCast(mountains)),
                    else => {},
                }
            }
            if (r.*.biome == -1) r.*.biome = @as(c_short, @intCast(plains));
            if (r.*.biome == plains or r.*.biome == mountains) {
                if (nextFloat(&rng) < 0.5) {
                    r.*.flags |= underground_bit;
                    r.*.flags |= airpocket_bit;
                } else if (nextFloat(&rng) < 0.5) {
                    r.*.flags |= airpocket_bit;
                }
            } else if (r.*.biome == jungle) {
                if (nextFloat(&rng) < 0.5) r.*.flags |= airpocket_bit;
            }
            if (nextFloat(&rng) < 0.05) {
                r.*.flags |= giant_bit;
                r.*.start = @as(u8, @bitCast(@as(i8, @truncate(1 + nextInt(&rng, 3)))));
            } else {
                r.*.start = @as(u8, @bitCast(@as(i8, @truncate(1 + nextInt(&rng, 10)))));
            }
            r.*.rotation = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 4)))));
            r.*.mirror = @as(u8, @intCast(@intFromBool(nextFloat(&rng) < 0.5)));
            return 1;
        },
        Geode => {
            var sc: StructureConfig = undefined;
            _ = getStructureConfig(Geode, mc, &sc);
            if (mc >= MC_1_18) {
                var xr: Xoroshiro = undefined;
                xSetSeed(&xr, getPopulationSeed(mc, arg_seed, x & ~@as(c_int, 15), z & ~@as(c_int, 15)) +% @as(u64, @bitCast(@as(c_long, sc.salt))));
                if (xNextFloat(&xr) >= sc.rarity) return 0;
                r.*.x = @as(i16, @intCast(xNextIntJ(&xr, 16)));
                r.*.z = @as(i16, @intCast(xNextIntJ(&xr, 16)));
                r.*.x = @as(i16, @intCast(@as(c_int, r.*.x) - (x & 15)));
                r.*.z = @as(i16, @intCast(@as(c_int, r.*.z) - (z & 15)));
                r.*.y = @as(i16, @intCast(xNextIntJ(&xr, 89) - 58));
                r.*.size = @as(u8, @bitCast(@as(i8, @truncate(xNextIntJ(&xr, 2) + 3))));
                xSkipN(&xr, 2);
                if (xNextFloat(&xr) < 0.95) r.*.flags |= cracked_bit;
                r.*.x += 5;
                r.*.y += 5;
                r.*.z += 5;
                return 1;
            } else {
                setSeed(&rng, getPopulationSeed(mc, arg_seed, x & ~@as(c_int, 15), z & ~@as(c_int, 15)) +% @as(u64, @bitCast(@as(c_long, sc.salt))));
                if (nextFloat(&rng) >= sc.rarity) return 0;
                r.*.x = @as(i16, @intCast(nextInt(&rng, 16)));
                r.*.z = @as(i16, @intCast(nextInt(&rng, 16)));
                r.*.x = @as(i16, @intCast(@as(c_int, r.*.x) - (x & 15)));
                r.*.z = @as(i16, @intCast(@as(c_int, r.*.z) - (z & 15)));
                r.*.y = @as(i16, @intCast(nextInt(&rng, 41) + 6));
                r.*.size = @as(u8, @bitCast(@as(i8, @truncate(nextInt(&rng, 2) + 3))));
                skipNextN(&rng, 2);
                if (nextFloat(&rng) < 0.95) r.*.flags |= cracked_bit;
                r.*.x += 5;
                r.*.y += 5;
                r.*.z += 5;
                return 1;
            }
        },
        else => return 0,
    }
}





pub fn setAttemptSeed(arg_s: [*c]u64, arg_cx: c_int, arg_cz: c_int) void {
    var s = arg_s;
    _ = &s;
    var cx = arg_cx;
    _ = &cx;
    var cz = arg_cz;
    _ = &cz;
    s.* ^= @as(u64, @bitCast(@as(c_long, cx >> @intCast(4)))) ^ (@as(u64, @bitCast(@as(c_long, cz >> @intCast(4)))) << @intCast(4));
    setSeed(s, s.*);
    _ = next(s, @as(c_int, 31));
}
pub fn getPopulationSeed(arg_mc: c_int, arg_ws: u64, arg_x: c_int, arg_z: c_int) u64 {
    var mc = arg_mc;
    _ = &mc;
    var ws = arg_ws;
    _ = &ws;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var xr: Xoroshiro = undefined;
    _ = &xr;
    var s: u64 = undefined;
    _ = &s;
    var a: u64 = undefined;
    _ = &a;
    var b: u64 = undefined;
    _ = &b;
    if (mc >= MC_1_18) {
        xSetSeed(&xr, ws);
        a = xNextLongJ(&xr);
        b = xNextLongJ(&xr);
    } else {
        setSeed(&s, ws);
        a = nextLong(&s);
        b = nextLong(&s);
    }
    if (mc >= MC_1_13) {
        a |= @as(u64, @bitCast(@as(c_long, @as(c_int, 1))));
        b |= @as(u64, @bitCast(@as(c_long, @as(c_int, 1))));
    } else {
        a = @as(u64, @bitCast((@divTrunc(@as(i64, @bitCast(a)), @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))) * @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))) + @as(i64, @bitCast(@as(c_long, @as(c_int, 1))))));
        b = @as(u64, @bitCast((@divTrunc(@as(i64, @bitCast(b)), @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))) * @as(i64, @bitCast(@as(c_long, @as(c_int, 2))))) + @as(i64, @bitCast(@as(c_long, @as(c_int, 1))))));
    }
    return ((@as(u64, @bitCast(@as(c_long, x))) *% a) +% (@as(u64, @bitCast(@as(c_long, z))) *% b)) ^ ws;
}
pub fn getRegPos(arg_p: [*c]Pos, arg_s: [*c]u64, arg_rx: c_int, arg_rz: c_int, arg_sc: StructureConfig) void {
    var p = arg_p;
    _ = &p;
    var s = arg_s;
    _ = &s;
    var rx = arg_rx;
    _ = &rx;
    var rz = arg_rz;
    _ = &rz;
    var sc = arg_sc;
    _ = &sc;
    setSeed(s, @as(u64, @bitCast(@as(c_ulong, @truncate((((@as(c_ulonglong, @bitCast(@as(c_longlong, rx))) *% @as(c_ulonglong, 341873128712)) +% (@as(c_ulonglong, @bitCast(@as(c_longlong, rz))) *% @as(c_ulonglong, 132897987541))) +% @as(c_ulonglong, @bitCast(@as(c_ulonglong, s.*)))) +% @as(c_ulonglong, @bitCast(@as(c_longlong, sc.salt))))))));
    p.*.x = @as(c_int, @bitCast(@as(c_uint, @truncate(((@as(u64, @bitCast(@as(c_long, rx))) *% @as(u64, @bitCast(@as(c_long, sc.regionSize)))) +% @as(u64, @bitCast(@as(c_long, nextInt(s, @as(c_int, @bitCast(@as(c_int, sc.chunkRange)))))))) << @intCast(4)))));
    p.*.z = @as(c_int, @bitCast(@as(c_uint, @truncate(((@as(u64, @bitCast(@as(c_long, rz))) *% @as(u64, @bitCast(@as(c_long, sc.regionSize)))) +% @as(u64, @bitCast(@as(c_long, nextInt(s, @as(c_int, @bitCast(@as(c_int, sc.chunkRange)))))))) << @intCast(4)))));
}
pub fn id_matches(arg_id: c_int, arg_b: u64, arg_m: u64) c_int {
    var id = arg_id;
    _ = &id;
    var b = arg_b;
    _ = &b;
    var m = arg_m;
    _ = &m;
    return if (id < @as(c_int, 128)) @intFromBool(!!((@as(c_ulonglong, @bitCast(@as(c_ulonglong, b))) & (@as(c_ulonglong, 1) << @intCast(id))) != 0)) else @intFromBool(!!((@as(c_ulonglong, @bitCast(@as(c_ulonglong, m))) & (@as(c_ulonglong, 1) << @intCast(id - @as(c_int, 128)))) != 0));
}
pub fn areBiomesViable(arg_g: [*c]const Generator, arg_x: c_int, arg_y: c_int, arg_z: c_int, arg_rad: c_int, arg_validB: u64, arg_validM: u64, arg_approx: c_int) c_int {
    const g = arg_g;
    const x = arg_x;
    var y = arg_y;
    const z = arg_z;
    const rad = arg_rad;
    const validB = arg_validB;
    const validM = arg_validM;
    const approx = arg_approx;

    const x1 = (x - rad) >> 2;
    const x2 = (x + rad) >> 2;
    const sx = x2 - x1 + 1;
    const z1 = (z - rad) >> 2;
    const z2 = (z + rad) >> 2;
    const sz = z2 - z1 + 1;

    y = (y - rad) >> 2;

    const corners = [_]Pos{
        .{ .x = x1, .z = z1 },
        .{ .x = x2, .z = z2 },
        .{ .x = x1, .z = z2 },
        .{ .x = x2, .z = z1 },
    };
    for (corners) |p| {
        const id = getBiomeAt(g, 4, p.x, y, p.z);
        if (id < 0 or id_matches(id, validB, validM) == 0) return 0;
    }
    if (approx >= 1) return 1;

    if (g.*.mc >= MC_1_18) {
        var i: c_int = 0;
        while (i < sx) : (i += 1) {
            var dat: u64 = 0;
            var j: c_int = 0;
            while (j < sz) : (j += 1) {
                const id = sampleBiomeNoise(@constCast(&g.*.unnamed_0.unnamed_1.bn), null, x1 + i, y, z1 + j, &dat, 0);
                if (id < 0 or id_matches(id, validB, validM) == 0) return 0;
            }
        }
        return 1;
    }

    const r = Range{
        .scale = 4,
        .x = x1,
        .z = z1,
        .sx = sx,
        .sz = sz,
        .y = y,
        .sy = 1,
    };
    const ids = allocCache(g, r);
    defer free(@as(?*anyopaque, @ptrCast(ids)));
    if (genBiomes(g, ids, r) != 0) return 0;

    var i: c_int = 0;
    while (i < sx * sz) : (i += 1) {
        const id = ids[@as(c_uint, @intCast(i))];
        if (id < 0 or id_matches(id, validB, validM) == 0) return 0;
    }
    return 1;
}
pub fn calcFitness(arg_g: [*c]const Generator, arg_x: c_int, arg_z: c_int) u64 {
    var g = arg_g;
    _ = &g;
    var x = arg_x;
    _ = &x;
    var z = arg_z;
    _ = &z;
    var np: [6]i64 = undefined;
    _ = &np;
    var flags: u32 = @as(u32, @bitCast(SAMPLE_NO_DEPTH | SAMPLE_NO_BIOME));
    _ = &flags;
    _ = sampleBiomeNoise(&g.*.unnamed_0.unnamed_1.bn, @as([*c]i64, @ptrCast(@alignCast(&np))), x >> @intCast(2), @as(c_int, 0), z >> @intCast(2), null, flags);
    const spawn_np: [7][2]i64 = [7][2]i64{
        [2]i64{
            @as(i64, @bitCast(@as(c_long, -@as(c_int, 10000)))),
            @as(i64, @bitCast(@as(c_long, @as(c_int, 10000)))),
        },
        [2]i64{
            @as(i64, @bitCast(@as(c_long, -@as(c_int, 10000)))),
            @as(i64, @bitCast(@as(c_long, @as(c_int, 10000)))),
        },
        [2]i64{
            @as(i64, @bitCast(@as(c_long, -@as(c_int, 1100)))),
            @as(i64, @bitCast(@as(c_long, @as(c_int, 10000)))),
        },
        [2]i64{
            @as(i64, @bitCast(@as(c_long, -@as(c_int, 10000)))),
            @as(i64, @bitCast(@as(c_long, @as(c_int, 10000)))),
        },
        [2]i64{
            0,
            0,
        },
        [2]i64{
            @as(i64, @bitCast(@as(c_long, -@as(c_int, 10000)))),
            @as(i64, @bitCast(@as(c_long, -@as(c_int, 1600)))),
        },
        [2]i64{
            @as(i64, @bitCast(@as(c_long, @as(c_int, 1600)))),
            @as(i64, @bitCast(@as(c_long, @as(c_int, 10000)))),
        },
    };
    _ = &spawn_np;
    var ds: u64 = 0;
    _ = &ds;
    var ds1: u64 = 0;
    _ = &ds1;
    var ds2: u64 = 0;
    _ = &ds2;
    var a: u64 = undefined;
    _ = &a;
    var b: u64 = undefined;
    _ = &b;
    var q: u64 = undefined;
    _ = &q;
    var i: u64 = undefined;
    _ = &i;
    {
        i = 0;
        while (i < @as(u64, @bitCast(@as(c_long, @as(c_int, 5))))) : (i +%= 1) {
            a = @as(u64, @bitCast(np[i])) -% @as(u64, @bitCast(spawn_np[i][@as(c_uint, @intCast(@as(c_int, 1)))]));
            b = @as(u64, @bitCast(-np[i])) +% @as(u64, @bitCast(spawn_np[i][@as(c_uint, @intCast(@as(c_int, 0)))]));
            q = if (@as(i64, @bitCast(a)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) a else if (@as(i64, @bitCast(b)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) b else @as(u64, @bitCast(@as(c_long, @as(c_int, 0))));
            ds +%= q *% q;
        }
    }
    a = @as(u64, @bitCast(np[@as(c_uint, @intCast(@as(c_int, 5)))])) -% @as(u64, @bitCast(spawn_np[@as(c_uint, @intCast(@as(c_int, 5)))][@as(c_uint, @intCast(@as(c_int, 1)))]));
    b = @as(u64, @bitCast(-np[@as(c_uint, @intCast(@as(c_int, 5)))])) +% @as(u64, @bitCast(spawn_np[@as(c_uint, @intCast(@as(c_int, 5)))][@as(c_uint, @intCast(@as(c_int, 0)))]));
    q = if (@as(i64, @bitCast(a)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) a else if (@as(i64, @bitCast(b)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) b else @as(u64, @bitCast(@as(c_long, @as(c_int, 0))));
    ds1 = ds +% (q *% q);
    a = @as(u64, @bitCast(np[@as(c_uint, @intCast(@as(c_int, 5)))])) -% @as(u64, @bitCast(spawn_np[@as(c_uint, @intCast(@as(c_int, 6)))][@as(c_uint, @intCast(@as(c_int, 1)))]));
    b = @as(u64, @bitCast(-np[@as(c_uint, @intCast(@as(c_int, 5)))])) +% @as(u64, @bitCast(spawn_np[@as(c_uint, @intCast(@as(c_int, 6)))][@as(c_uint, @intCast(@as(c_int, 0)))]));
    q = if (@as(i64, @bitCast(a)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) a else if (@as(i64, @bitCast(b)) > @as(i64, @bitCast(@as(c_long, @as(c_int, 0))))) b else @as(u64, @bitCast(@as(c_long, @as(c_int, 0))));
    ds2 = ds +% (q *% q);
    ds = if (ds1 <= ds2) ds1 else ds2;
    a = @as(u64, @bitCast(@as(i64, @bitCast(@as(c_long, x))) * @as(i64, @bitCast(@as(c_long, x)))));
    b = @as(u64, @bitCast(@as(i64, @bitCast(@as(c_long, z))) * @as(i64, @bitCast(@as(c_long, z)))));
    if (g.*.mc <= MC_1_21_1) {
        var s: f64 = @as(f64, @floatFromInt(a +% b)) / @as(f64, @floatFromInt(@as(c_int, 2500) * @as(c_int, 2500)));
        _ = &s;
        q = @as(u64, @intFromFloat((s * s) * 100000000.0)) +% ds;
    } else {
        q = @as(u64, @bitCast(@as(c_ulong, @truncate(((@as(c_ulonglong, @bitCast(@as(c_ulonglong, ds))) *% @as(c_ulonglong, @bitCast(@as(c_longlong, 2048) * @as(c_longlong, 2048)))) +% @as(c_ulonglong, @bitCast(@as(c_ulonglong, a)))) +% @as(c_ulonglong, @bitCast(@as(c_ulonglong, b)))))));
    }
    return q;
}
pub fn findFittest(arg_g: [*c]const Generator, arg_pos: [*c]Pos, arg_fitness: [*c]u64, arg_maxrad: f64, arg_step: f64) void {
    var g = arg_g;
    _ = &g;
    var pos = arg_pos;
    _ = &pos;
    var fitness = arg_fitness;
    _ = &fitness;
    var maxrad = arg_maxrad;
    _ = &maxrad;
    var step = arg_step;
    _ = &step;
    var rad: f64 = undefined;
    _ = &rad;
    var ang: f64 = undefined;
    _ = &ang;
    var p: Pos = pos.*;
    _ = &p;
    {
        rad = step;
        while (rad <= maxrad) : (rad += step) {
            {
                ang = 0;
                while (ang <= (3.141592653589793 * @as(f64, @floatFromInt(@as(c_int, 2))))) : (ang += step / rad) {
                    var x: c_int = p.x + @as(c_int, @intFromFloat(sin(ang) * rad));
                    _ = &x;
                    var z: c_int = p.z + @as(c_int, @intFromFloat(cos(ang) * rad));
                    _ = &z;
                    var fit: u64 = calcFitness(g, x, z);
                    _ = &fit;
                    if (fit < fitness.*) {
                        pos.*.x = x;
                        pos.*.z = z;
                        fitness.* = fit;
                    }
                }
            }
        }
    }
}
pub fn findFittestPos(arg_g: [*c]const Generator) Pos {
    var g = arg_g;
    _ = &g;
    var spawn: Pos = Pos{
        .x = @as(c_int, 0),
        .z = @as(c_int, 0),
    };
    _ = &spawn;
    var fitness: u64 = calcFitness(g, @as(c_int, 0), @as(c_int, 0));
    _ = &fitness;
    findFittest(g, &spawn, &fitness, 2048.0, 512.0);
    findFittest(g, &spawn, &fitness, 512.0, 32.0);
    spawn.x = (spawn.x & ~@as(c_int, 15)) + @as(c_int, 8);
    spawn.z = (spawn.z & ~@as(c_int, 15)) + @as(c_int, 8);
    return spawn;
}
pub const g_spawn_biomes_17: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(((((((@as(c_ulonglong, 1) << @intCast(forest)) | (@as(c_ulonglong, 1) << @intCast(plains))) | (@as(c_ulonglong, 1) << @intCast(taiga))) | (@as(c_ulonglong, 1) << @intCast(taiga_hills))) | (@as(c_ulonglong, 1) << @intCast(wooded_hills))) | (@as(c_ulonglong, 1) << @intCast(jungle))) | (@as(c_ulonglong, 1) << @intCast(jungle_hills))))));
pub const g_monument_biomes1: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate((((((((((((@as(c_ulonglong, 1) << @intCast(ocean)) | (@as(c_ulonglong, 1) << @intCast(deep_ocean))) | (@as(c_ulonglong, 1) << @intCast(river))) | (@as(c_ulonglong, 1) << @intCast(frozen_river))) | (@as(c_ulonglong, 1) << @intCast(frozen_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_frozen_ocean))) | (@as(c_ulonglong, 1) << @intCast(cold_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_cold_ocean))) | (@as(c_ulonglong, 1) << @intCast(lukewarm_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_lukewarm_ocean))) | (@as(c_ulonglong, 1) << @intCast(warm_ocean))) | (@as(c_ulonglong, 1) << @intCast(deep_warm_ocean))))));
const struct_unnamed_27 = extern struct {
    offset: Pos3 = @import("std").mem.zeroes(Pos3),
    size: Pos3 = @import("std").mem.zeroes(Pos3),
    skip: c_int = @import("std").mem.zeroes(c_int),
    repeatable: c_int = @import("std").mem.zeroes(c_int),
    weight: c_int = @import("std").mem.zeroes(c_int),
    max: c_int = @import("std").mem.zeroes(c_int),
    name: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
};
pub const fortress_info: [15]struct_unnamed_27 = [15]struct_unnamed_27{
    struct_unnamed_27{
        .offset = Pos3{
            .x = @as(c_int, 0),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 18),
            .y = @as(c_int, 9),
            .z = @as(c_int, 18),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 0),
        .max = @as(c_int, 0),
        .name = "NeStart",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 1),
            .y = -@as(c_int, 3),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 4),
            .y = @as(c_int, 9),
            .z = @as(c_int, 18),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 1),
        .weight = @as(c_int, 30),
        .max = @as(c_int, 0),
        .name = "NeBS",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 8),
            .y = -@as(c_int, 3),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 18),
            .y = @as(c_int, 9),
            .z = @as(c_int, 18),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 10),
        .max = @as(c_int, 4),
        .name = "NeBCr",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 2),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 6),
            .y = @as(c_int, 8),
            .z = @as(c_int, 6),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 10),
        .max = @as(c_int, 4),
        .name = "NeRC",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 2),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 6),
            .y = @as(c_int, 10),
            .z = @as(c_int, 6),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 10),
        .max = @as(c_int, 3),
        .name = "NeSR",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 2),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 6),
            .y = @as(c_int, 7),
            .z = @as(c_int, 8),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 5),
        .max = @as(c_int, 2),
        .name = "NeMT",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 5),
            .y = -@as(c_int, 3),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 12),
            .y = @as(c_int, 13),
            .z = @as(c_int, 12),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 5),
        .max = @as(c_int, 1),
        .name = "NeCE",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 1),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 4),
            .y = @as(c_int, 6),
            .z = @as(c_int, 4),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 1),
        .weight = @as(c_int, 25),
        .max = @as(c_int, 0),
        .name = "NeSC",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 1),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 4),
            .y = @as(c_int, 6),
            .z = @as(c_int, 4),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 15),
        .max = @as(c_int, 5),
        .name = "NeSCSC",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 1),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 4),
            .y = @as(c_int, 6),
            .z = @as(c_int, 4),
        },
        .skip = @as(c_int, 1),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 5),
        .max = @as(c_int, 10),
        .name = "NeSCRT",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 1),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 4),
            .y = @as(c_int, 6),
            .z = @as(c_int, 4),
        },
        .skip = @as(c_int, 1),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 5),
        .max = @as(c_int, 10),
        .name = "NeSCLT",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 1),
            .y = -@as(c_int, 7),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 4),
            .y = @as(c_int, 13),
            .z = @as(c_int, 9),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 1),
        .weight = @as(c_int, 10),
        .max = @as(c_int, 3),
        .name = "NeCCS",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 3),
            .y = @as(c_int, 0),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 8),
            .y = @as(c_int, 6),
            .z = @as(c_int, 8),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 7),
        .max = @as(c_int, 2),
        .name = "NeCTB",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 5),
            .y = -@as(c_int, 3),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 12),
            .y = @as(c_int, 13),
            .z = @as(c_int, 12),
        },
        .skip = @as(c_int, 0),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 5),
        .max = @as(c_int, 2),
        .name = "NeCSR",
    },
    struct_unnamed_27{
        .offset = Pos3{
            .x = -@as(c_int, 1),
            .y = -@as(c_int, 3),
            .z = @as(c_int, 0),
        },
        .size = Pos3{
            .x = @as(c_int, 4),
            .y = @as(c_int, 9),
            .z = @as(c_int, 7),
        },
        .skip = @as(c_int, 1),
        .repeatable = @as(c_int, 0),
        .weight = @as(c_int, 0),
        .max = @as(c_int, 0),
        .name = "NeBEF",
    },
};



pub const g_biome_para_range_18: [51][13]c_int = [51][13]c_int{
    [13]c_int{
        ocean,
        -@as(c_int, 1500),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 4550),
        -@as(c_int, 1900),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        plains,
        -@as(c_int, 4500),
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        1000,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        desert,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        windswept_hills,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        1000,
        -@as(c_int, 1899),
        2147483647,
        4500,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        forest,
        -@as(c_int, 4500),
        5500,
        -@as(c_int, 1000),
        3000,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        taiga,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1500),
        1000,
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        swamp,
        -@as(c_int, 4500),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1100),
        2147483647,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        river,
        -@as(c_int, 4500),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        500,
    },
    [13]c_int{
        frozen_ocean,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 4501),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 4550),
        -@as(c_int, 1900),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        frozen_river,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 4501),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        500,
    },
    [13]c_int{
        snowy_plains,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 4500),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        1000,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        mushroom_fields,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 10500),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        beach,
        -@as(c_int, 4500),
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1900),
        -@as(c_int, 1100),
        -@as(c_int, 2225),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2666,
    },
    [13]c_int{
        jungle,
        2000,
        5500,
        1000,
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        sparse_jungle,
        2000,
        5500,
        1000,
        3000,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        2147483647,
    },
    [13]c_int{
        deep_ocean,
        -@as(c_int, 1500),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 10500),
        -@as(c_int, 4551),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        stony_shore,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1900),
        -@as(c_int, 1100),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 2225),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        snowy_beach,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 4500),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1900),
        -@as(c_int, 1100),
        -@as(c_int, 2225),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2666,
    },
    [13]c_int{
        birch_forest,
        -@as(c_int, 1500),
        2000,
        1000,
        3000,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        dark_forest,
        -@as(c_int, 1500),
        2000,
        3000,
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        snowy_taiga,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 4500),
        -@as(c_int, 1000),
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        old_growth_pine_taiga,
        -@as(c_int, 4500),
        -@as(c_int, 1500),
        3000,
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        2147483647,
    },
    [13]c_int{
        windswept_forest,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        1000,
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        4500,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        savanna,
        2000,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        savanna_plateau,
        2000,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1100),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        badlands,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        1000,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        wooded_badlands,
        5500,
        2147483647,
        1000,
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        warm_ocean,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 10500),
        -@as(c_int, 1900),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        lukewarm_ocean,
        2001,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 4550),
        -@as(c_int, 1900),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        cold_ocean,
        -@as(c_int, 4500),
        -@as(c_int, 1501),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 4550),
        -@as(c_int, 1900),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        deep_lukewarm_ocean,
        2001,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 10500),
        -@as(c_int, 4551),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        deep_cold_ocean,
        -@as(c_int, 4500),
        -@as(c_int, 1501),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 10500),
        -@as(c_int, 4551),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        deep_frozen_ocean,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 4501),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 10500),
        -@as(c_int, 4551),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        sunflower_plains,
        -@as(c_int, 1500),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3500),
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        2147483647,
    },
    [13]c_int{
        windswept_gravelly_hills,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1500),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1899),
        2147483647,
        4500,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        flower_forest,
        -@as(c_int, 1500),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3500),
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 500),
    },
    [13]c_int{
        ice_spikes,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 4500),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3500),
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        2147483647,
    },
    [13]c_int{
        old_growth_birch_forest,
        -@as(c_int, 1500),
        2000,
        1000,
        3000,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        2147483647,
    },
    [13]c_int{
        old_growth_spruce_taiga,
        -@as(c_int, 4500),
        -@as(c_int, 1500),
        3000,
        2147483647,
        -@as(c_int, 1900),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 500),
    },
    [13]c_int{
        windswept_savanna,
        -@as(c_int, 1500),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        3000,
        -@as(c_int, 1899),
        300,
        4500,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        501,
        2147483647,
    },
    [13]c_int{
        eroded_badlands,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        bamboo_jungle,
        2000,
        5500,
        3000,
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        2147483647,
    },
    [13]c_int{
        dripstone_caves,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        6999,
        3001,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        1000,
        9500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        lush_caves,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        2001,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        1000,
        9500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        meadow,
        -@as(c_int, 4500),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        3000,
        300,
        2147483647,
        -@as(c_int, 7799),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        grove,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 1000),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        snowy_slopes,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        jagged_peaks,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 9333),
        -@as(c_int, 4001),
    },
    [13]c_int{
        frozen_peaks,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        4000,
        9333,
    },
    [13]c_int{
        stony_peaks,
        2000,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 9333),
        9333,
    },
    [13]c_int{
        -@as(c_int, 1),
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    },
};
pub const g_biome_para_range_19_diff: [7][13]c_int = [7][13]c_int{
    [13]c_int{
        eroded_badlands,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 500),
        2147483647,
    },
    [13]c_int{
        grove,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 1000),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10499,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        snowy_slopes,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10499,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        jagged_peaks,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10499,
        -@as(c_int, 9333),
        -@as(c_int, 4001),
    },
    [13]c_int{
        deep_dark,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        1818,
        10500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        mangrove_swamp,
        2000,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1100),
        2147483647,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        -@as(c_int, 1),
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    },
};
pub const g_biome_para_range_20_diff: [8][13]c_int = [8][13]c_int{
    [13]c_int{
        swamp,
        -@as(c_int, 4500),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1100),
        2147483647,
        5500,
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        grove,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 1000),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        snowy_slopes,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
    },
    [13]c_int{
        jagged_peaks,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10500,
        -@as(c_int, 9333),
        -@as(c_int, 4000),
    },
    [13]c_int{
        frozen_peaks,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10500,
        4000,
        9333,
    },
    [13]c_int{
        stony_peaks,
        2000,
        5500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        -@as(c_int, 1899),
        2147483647,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 3750),
        -@as(c_int, 2147483647) - @as(c_int, 1),
        10500,
        -@as(c_int, 9333),
        9333,
    },
    [13]c_int{
        cherry_grove,
        -@as(c_int, 4500),
        2000,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        -@as(c_int, 1000),
        300,
        2147483647,
        -@as(c_int, 7799),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        2666,
        2147483647,
    },
    [13]c_int{
        -@as(c_int, 1),
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    },
};
pub const g_biome_para_range_21wd_diff: [2][13]c_int = [2][13]c_int{
    [13]c_int{
        pale_garden,
        -@as(c_int, 1500),
        2000,
        3000,
        2147483647,
        300,
        2147483647,
        -@as(c_int, 7799),
        500,
        -@as(c_int, 2147483647) - @as(c_int, 1),
        2147483647,
        2666,
        2147483647,
    },
    [13]c_int{
        -@as(c_int, 1),
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    },
};
pub fn struct2str(arg_stype: c_int) [*c]const u8 {
    var stype = arg_stype;
    _ = &stype;
    while (true) {
        switch (stype) {
            @as(c_int, 1) => return "desert_pyramid",
            @as(c_int, 2) => return "jungle_pyramid",
            @as(c_int, 3) => return "swamp_hut",
            @as(c_int, 4) => return "igloo",
            @as(c_int, 5) => return "village",
            @as(c_int, 6) => return "ocean_ruin",
            @as(c_int, 7) => return "shipwreck",
            @as(c_int, 8) => return "monument",
            @as(c_int, 9) => return "mansion",
            @as(c_int, 10) => return "pillager_outpost",
            @as(c_int, 14) => return "buried_treasure",
            @as(c_int, 15) => return "mineshaft",
            @as(c_int, 16) => return "desert_well",
            @as(c_int, 11) => return "ruined_portal",
            @as(c_int, 12) => return "ruined_portal_nether",
            @as(c_int, 17) => return "amethyst_geode",
            @as(c_int, 13) => return "ancient_city",
            @as(c_int, 23) => return "trail_ruins",
            @as(c_int, 24) => return "trial_chambers",
            @as(c_int, 18) => return "fortress",
            @as(c_int, 19) => return "bastion_remnant",
            @as(c_int, 20) => return "end_city",
            @as(c_int, 21) => return "end_gateway",
            else => {},
        }
        break;
    }
    return null;
}
pub const low20QuadIdeal: [4]u64 = [4]u64{
    @as(u64, @bitCast(@as(c_long, @as(c_int, 278296)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 816410)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 1004042)))),
    0,
};
pub const low20QuadClassic: [5]u64 = [5]u64{
    @as(u64, @bitCast(@as(c_long, @as(c_int, 278296)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 498186)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 816410)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 1004042)))),
    0,
};
pub const low20QuadHutNormal: [11]u64 = [11]u64{
    @as(u64, @bitCast(@as(c_long, @as(c_int, 278296)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 413976)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 480792)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 498186)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 562968)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 603930)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 678408)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 744984)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 816410)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 1004042)))),
    0,
};
pub const low20QuadHutBarely: [29]u64 = [29]u64{
    @as(u64, @bitCast(@as(c_long, @as(c_int, 75565)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 96520)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 223161)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 278296)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 296905)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 296910)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 330407)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 411573)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 413976)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 480792)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 498186)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 562968)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 603930)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 616428)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 670986)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 678168)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 678173)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 678408)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 744984)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 812873)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 814490)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 816410)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 880904)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 881018)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 927545)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 956696)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 975300)))),
    @as(u64, @bitCast(@as(c_long, @as(c_int, 1004042)))),
    0,
};



pub const MersenneTwister = extern struct {
    array: [624]u32 = @import("std").mem.zeroes([624]u32),
    index: uint_fast16_t = @import("std").mem.zeroes(uint_fast16_t),
};
pub inline fn _mTwist(mt: [*c]MersenneTwister) void {
    _ = &mt;
    const mag01 = struct {
        const static: [2]u32 = [2]u32{
            0,
            2567483615,
        };
    };
    _ = &mag01;
    var i: uint_fast16_t = undefined;
    _ = &i;
    {
        i = 0;
        while (i < @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 624) - @as(c_int, 397))))) : (i +%= 1) {
            var y: u32 = (mt.*.array[i] & @as(c_uint, 2147483648)) | (mt.*.array[i +% @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 1))))] & @as(c_uint, 2147483647));
            _ = &y;
            mt.*.array[i] = (mt.*.array[i +% @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 397))))] ^ (y >> @intCast(1))) ^ mag01.static[y & @as(u32, @bitCast(@as(c_int, 1)))];
        }
    }
    while (i < @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 624) - @as(c_int, 1))))) : (i +%= 1) {
        var y: u32 = (mt.*.array[i] & @as(c_uint, 2147483648)) | (mt.*.array[i +% @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 1))))] & @as(c_uint, 2147483647));
        _ = &y;
        mt.*.array[i] = (mt.*.array[i -% @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 624) - @as(c_int, 397))))] ^ (y >> @intCast(1))) ^ mag01.static[y & @as(u32, @bitCast(@as(c_int, 1)))];
    }
    var y: u32 = (mt.*.array[@as(c_uint, @intCast(@as(c_int, 624) - @as(c_int, 1)))] & @as(c_uint, 2147483648)) | (mt.*.array[@as(c_uint, @intCast(@as(c_int, 0)))] & @as(c_uint, 2147483647));
    _ = &y;
    mt.*.array[@as(c_uint, @intCast(@as(c_int, 624) - @as(c_int, 1)))] = (mt.*.array[@as(c_uint, @intCast(@as(c_int, 397) - @as(c_int, 1)))] ^ (y >> @intCast(1))) ^ mag01.static[y & @as(u32, @bitCast(@as(c_int, 1)))];
    mt.*.index = 0;
}
pub inline fn mSetSeed(mt: [*c]MersenneTwister, seed: u64, n: c_int) void {
    _ = &mt;
    _ = &seed;
    _ = &n;
    if (__builtin_expect(@as(c_long, @intFromBool(!!(n > @as(c_int, 0)))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 1))))) != 0) {
        {
            var i: usize = 0;
            _ = &i;
            while (i < @as(usize, @bitCast(@as(c_long, @as(c_int, 624))))) : (i +%= 1) {
                mt.*.array[i] = 0;
            }
        }
        const end: usize = if (@as(usize, @bitCast(@as(c_long, @as(c_int, 624) - @as(c_int, 1)))) < @as(usize, @bitCast(@as(c_long, n + @as(c_int, 396))))) @as(usize, @bitCast(@as(c_long, @as(c_int, 624) - @as(c_int, 1)))) else @as(usize, @bitCast(@as(c_long, n + @as(c_int, 396))));
        _ = &end;
        mt.*.array[@as(c_uint, @intCast(@as(c_int, 0)))] = @as(u32, @bitCast(@as(c_uint, @truncate(seed & @as(u64, @bitCast(@as(c_ulong, @as(c_uint, 4294967295))))))));
        {
            var i: usize = 1;
            _ = &i;
            while (i <= end) : (i +%= 1) {
                var prev: u32 = mt.*.array[i -% @as(usize, @bitCast(@as(c_long, @as(c_int, 1))))];
                _ = &prev;
                mt.*.array[i] = @as(u32, @bitCast(@as(c_uint, @truncate((@as(usize, @bitCast(@as(c_ulong, @as(c_uint, 1812433253) *% (prev ^ (prev >> @intCast(30)))))) +% i) & @as(usize, @bitCast(@as(c_ulong, @as(c_uint, 4294967295))))))));
            }
        }
    }
    mt.*.index = @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 624))));
}
pub inline fn _mNext(mt: [*c]MersenneTwister) u32 {
    _ = &mt;
    if (__builtin_expect(@as(c_long, @intFromBool(!!(mt.*.index >= @as(uint_fast16_t, @bitCast(@as(c_long, @as(c_int, 624))))))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 0))))) != 0) {
        _mTwist(mt);
    }
    var y: u32 = mt.*.array[blk: {
            const ref = &mt.*.index;
            const tmp = ref.*;
            ref.* +%= 1;
            break :blk tmp;
        }];
    _ = &y;
    y ^= y >> @intCast(11);
    y ^= @as(u32, @bitCast((y << @intCast(7)) & @as(c_uint, 2636928640)));
    y ^= @as(u32, @bitCast((y << @intCast(15)) & @as(c_uint, 4022730752)));
    return y ^ (y >> @intCast(18));
}
pub inline fn mNextInt(mt: [*c]MersenneTwister, n: c_int) c_int {
    _ = &mt;
    _ = &n;
    if (__builtin_expect(@as(c_long, @intFromBool(!!((n & (n - @as(c_int, 1))) == @as(c_int, 0)))), @as(c_long, @bitCast(@as(c_long, @as(c_int, 1))))) != 0) {
        return @as(c_int, @bitCast(_mNext(mt) & @as(u32, @bitCast(n - @as(c_int, 1)))));
    }
    return @as(c_int, @bitCast(_mNext(mt) % @as(u32, @bitCast(n))));
}
pub inline fn mNextIntUnbound(mt: [*c]MersenneTwister) c_int {
    _ = &mt;
    return @as(c_int, @bitCast(_mNext(mt) >> @intCast(1)));
}
pub inline fn mNextFloat(mt: [*c]MersenneTwister) f32 {
    _ = &mt;
    return @as(f32, @floatFromInt(_mNext(mt))) * (1.0 / 4294967296.0);
}
pub const REGION_SALT_X: u64 = 341873128712;
pub const REGION_SALT_Z: u64 = 132897987541;
pub const CHUNK_OFFSET: c_int = 8;
pub fn mix_seed(seed: u64, regX: c_int, regZ: c_int, salt: u64) u64 {
    _ = &seed;
    _ = &regX;
    _ = &regZ;
    _ = &salt;
    return (((@as(u64, @bitCast(@as(c_long, regX))) *% REGION_SALT_X) +% (@as(u64, @bitCast(@as(c_long, regZ))) *% REGION_SALT_Z)) +% seed) +% salt;
}
pub fn getBedrockFeatureChunkInRegion(config: [*c]const StructureConfig, seed: u64, regX: c_int, regZ: c_int) Pos {
    _ = &config;
    _ = &seed;
    _ = &regX;
    _ = &regZ;
    var mt: MersenneTwister align(64) = undefined;
    _ = &mt;
    const mixedSeed: u64 = mix_seed(seed, regX, regZ, @as(u64, @bitCast(@as(c_long, config.*.salt))));
    _ = &mixedSeed;
    mSetSeed(&mt, mixedSeed, @as(c_int, 2));
    const range: c_int = @as(c_int, @bitCast(@as(c_int, config.*.chunkRange)));
    _ = &range;
    var pos: Pos = Pos{
        .x = mNextInt(&mt, range),
        .z = mNextInt(&mt, range),
    };
    _ = &pos;
    return pos;
}
pub fn getBedrockFeaturePos(config: [*c]const StructureConfig, seed: u64, regX: c_int, regZ: c_int) Pos {
    _ = &config;
    _ = &seed;
    _ = &regX;
    _ = &regZ;
    var pos: Pos = getBedrockFeatureChunkInRegion(config, seed, regX, regZ);
    _ = &pos;
    const regionSize: u64 = @as(u64, @bitCast(@as(c_long, config.*.regionSize)));
    _ = &regionSize;
    const xBase: u64 = @as(u64, @bitCast(@as(c_long, regX))) *% regionSize;
    _ = &xBase;
    const zBase: u64 = @as(u64, @bitCast(@as(c_long, regZ))) *% regionSize;
    _ = &zBase;
    pos.x = @as(c_int, @bitCast(@as(c_uint, @truncate(((xBase +% @as(u64, @bitCast(@as(c_long, pos.x)))) << @intCast(4)) +% @as(u64, @bitCast(@as(c_long, CHUNK_OFFSET)))))));
    pos.z = @as(c_int, @bitCast(@as(c_uint, @truncate(((zBase +% @as(u64, @bitCast(@as(c_long, pos.z)))) << @intCast(4)) +% @as(u64, @bitCast(@as(c_long, CHUNK_OFFSET)))))));
    return pos;
}
pub fn getBedrockLargeStructureChunkInRegion(config: [*c]const StructureConfig, seed: u64, regX: c_int, regZ: c_int) Pos {
    _ = &config;
    _ = &seed;
    _ = &regX;
    _ = &regZ;
    var mt: MersenneTwister align(64) = undefined;
    _ = &mt;
    const mixedSeed: u64 = mix_seed(seed, regX, regZ, @as(u64, @bitCast(@as(c_long, config.*.salt))));
    _ = &mixedSeed;
    mSetSeed(&mt, mixedSeed, @as(c_int, 4));
    const range: c_int = @as(c_int, @bitCast(@as(c_int, config.*.chunkRange)));
    _ = &range;
    const x1: c_int = mNextInt(&mt, range);
    _ = &x1;
    const x2: c_int = mNextInt(&mt, range);
    _ = &x2;
    const z1: c_int = mNextInt(&mt, range);
    _ = &z1;
    const z2: c_int = mNextInt(&mt, range);
    _ = &z2;
    var pos: Pos = Pos{
        .x = (x1 + x2) >> @intCast(1),
        .z = (z1 + z2) >> @intCast(1),
    };
    _ = &pos;
    return pos;
}
pub fn getBedrockLargeStructurePos(config: [*c]const StructureConfig, seed: u64, regX: c_int, regZ: c_int) Pos {
    _ = &config;
    _ = &seed;
    _ = &regX;
    _ = &regZ;
    var pos: Pos = getBedrockLargeStructureChunkInRegion(config, seed, regX, regZ);
    _ = &pos;
    const regionSize: u64 = @as(u64, @bitCast(@as(c_long, config.*.regionSize)));
    _ = &regionSize;
    const xBase: u64 = @as(u64, @bitCast(@as(c_long, regX))) *% regionSize;
    _ = &xBase;
    const zBase: u64 = @as(u64, @bitCast(@as(c_long, regZ))) *% regionSize;
    _ = &zBase;
    pos.x = @as(c_int, @bitCast(@as(c_uint, @truncate(((xBase +% @as(u64, @bitCast(@as(c_long, pos.x)))) << @intCast(4)) +% @as(u64, @bitCast(@as(c_long, CHUNK_OFFSET)))))));
    pos.z = @as(c_int, @bitCast(@as(c_uint, @truncate(((zBase +% @as(u64, @bitCast(@as(c_long, pos.z)))) << @intCast(4)) +% @as(u64, @bitCast(@as(c_long, CHUNK_OFFSET)))))));
    return pos;
}
pub fn bedrockChunkGenerateRnd(worldseed: u64, chunkX: c_int, chunkZ: c_int, n: c_int, mt: [*c]MersenneTwister) void {
    _ = &worldseed;
    _ = &chunkX;
    _ = &chunkZ;
    _ = &n;
    _ = &mt;
    mSetSeed(mt, worldseed, @as(c_int, 2));
    const r1: u64 = @as(u64, @bitCast(@as(c_long, mNextIntUnbound(mt))));
    _ = &r1;
    const r2: u64 = @as(u64, @bitCast(@as(c_long, mNextIntUnbound(mt))));
    _ = &r2;
    const mixedSeed: u64 = ((r1 *% @as(u64, @bitCast(@as(c_long, chunkX)))) ^ (r2 *% @as(u64, @bitCast(@as(c_long, chunkZ))))) ^ worldseed;
    _ = &mixedSeed;
    mSetSeed(mt, mixedSeed, n);
}
pub export fn getBedrockStructureConfig(arg_structureType: c_int, arg_mc: c_int, arg_sconf: [*c]StructureConfig) bool {
    var structureType = arg_structureType;
    _ = &structureType;
    var mc = arg_mc;
    _ = &mc;
    var sconf = arg_sconf;
    _ = &sconf;
    const s_ancient_city = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 20083232),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 16))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ancient_City)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ancient_city;
    const s_desert_pyramid = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Desert_Pyramid)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_desert_pyramid;
    const s_igloo = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Igloo)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_igloo;
    const s_jungle_pyramid = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Jungle_Pyramid)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_jungle_pyramid;
    const s_mansion = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387319),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 80))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 60))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Mansion)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_mansion;
    const s_mineshaft = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 0),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 1))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Mineshaft)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_mineshaft;
    const s_monument = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387313),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 27))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Monument)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_monument;
    const s_ocean_ruin_17 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357621),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 12))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 5))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ocean_Ruin)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ocean_ruin_17;
    const s_ocean_ruin = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357621),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 20))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 12))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ocean_Ruin)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ocean_ruin;
    const s_outpost = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 165745296),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 80))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 56))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Outpost)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_outpost;
    const s_ruined_portal = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 40552231),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 40))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 25))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ruined_Portal)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ruined_portal;
    const s_shipwreck_117 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 165745295),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 10))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 5))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Shipwreck)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_shipwreck_117;
    const s_shipwreck = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 165745295),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 20))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Shipwreck)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_shipwreck;
    const s_swamp_hut = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 14357617),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 32))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 24))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Swamp_Hut)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_swamp_hut;
    const s_trail_ruins = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 83469867),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 34))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 26))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Trail_Ruins)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_trail_ruins;
    const s_treasure = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 16842397),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 4))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 2))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Treasure)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_treasure;
    const s_trial_chambers = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 94251327),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 34))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 22))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Trial_Chambers)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_trial_chambers;
    const s_village_117 = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387312),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 27))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 17))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Village)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_village_117;
    const s_village = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387312),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 34))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 26))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Village)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_OVERWORLD)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_village;
    const s_bastion = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 30084232),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 30))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 26))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Bastion)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_bastion;
    const s_fortress = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 30084232),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 30))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 26))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Fortress)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_fortress;
    const s_ruined_portal_n = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 40552231),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 25))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 15))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(Ruined_Portal_N)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_NETHER)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_ruined_portal_n;
    const s_end_city = struct {
        const static: StructureConfig = StructureConfig{
            .salt = @as(c_int, 10387313),
            .regionSize = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 20))))),
            .chunkRange = @as(i8, @bitCast(@as(i8, @truncate(@as(c_int, 9))))),
            .structType = @as(u8, @bitCast(@as(i8, @truncate(End_City)))),
            .dim = @as(i8, @bitCast(@as(i8, @truncate(DIM_END)))),
            .rarity = @as(f32, @floatFromInt(@as(c_int, 0))),
        };
    };
    _ = &s_end_city;
    while (true) {
        switch (structureType) {
            @as(c_int, 13) => {
                sconf.* = s_ancient_city.static;
                return mc >= MC_1_19_2;
            },
            @as(c_int, 1) => {
                sconf.* = s_desert_pyramid.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 4) => {
                sconf.* = s_igloo.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 2) => {
                sconf.* = s_jungle_pyramid.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 9) => {
                sconf.* = s_mansion.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 15) => {
                sconf.* = s_mineshaft.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 8) => {
                sconf.* = s_monument.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 6) => {
                sconf.* = if (mc <= MC_1_17) s_ocean_ruin_17.static else s_ocean_ruin.static;
                return mc >= MC_1_16;
            },
            @as(c_int, 10) => {
                sconf.* = s_outpost.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 11) => {
                sconf.* = s_ruined_portal.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 7) => {
                sconf.* = if (mc <= MC_1_17) s_shipwreck_117.static else s_shipwreck.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 3) => {
                sconf.* = s_swamp_hut.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 23) => {
                sconf.* = s_trail_ruins.static;
                return mc >= MC_1_20;
            },
            @as(c_int, 14) => {
                sconf.* = s_treasure.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 24) => {
                sconf.* = s_trial_chambers.static;
                return mc >= MC_1_21_1;
            },
            @as(c_int, 5) => {
                sconf.* = if (mc <= MC_1_17) s_village_117.static else s_village.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 19) => {
                sconf.* = s_bastion.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 18) => {
                sconf.* = s_fortress.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 12) => {
                sconf.* = s_ruined_portal_n.static;
                return mc >= MC_1_14;
            },
            @as(c_int, 20) => {
                sconf.* = s_end_city.static;
                return mc >= MC_1_14;
            },
            else => {
                _ = memset(@as(?*anyopaque, @ptrCast(sconf)), @as(c_int, 0), @sizeOf(StructureConfig));
                return @as(c_int, 0) != 0;
            },
        }
        break;
    }
    return false;
}
pub export fn getBedrockStructurePos(arg_structureType: c_int, arg_mc: c_int, arg_seed: u64, arg_regX: c_int, arg_regZ: c_int, arg_pos: [*c]Pos) bool {
    var structureType = arg_structureType;
    _ = &structureType;
    var mc = arg_mc;
    _ = &mc;
    var seed = arg_seed;
    _ = &seed;
    var regX = arg_regX;
    _ = &regX;
    var regZ = arg_regZ;
    _ = &regZ;
    var pos = arg_pos;
    _ = &pos;
    var sconf: StructureConfig = undefined;
    _ = &sconf;
    if (!getBedrockStructureConfig(structureType, mc, &sconf)) return @as(c_int, 0) != 0;
    while (true) {
        switch (structureType) {
            @as(c_int, 1), @as(c_int, 4), @as(c_int, 2), @as(c_int, 11), @as(c_int, 3), @as(c_int, 19), @as(c_int, 18), @as(c_int, 12) => {
                pos.* = getBedrockFeaturePos(&sconf, seed, regX, regZ);
                return @as(c_int, 1) != 0;
            },
            @as(c_int, 13), @as(c_int, 9), @as(c_int, 8), @as(c_int, 10), @as(c_int, 14), @as(c_int, 5) => {
                pos.* = getBedrockLargeStructurePos(&sconf, seed, regX, regZ);
                return @as(c_int, 1) != 0;
            },
            @as(c_int, 6), @as(c_int, 7) => {
                pos.* = (if (mc <= MC_1_17) &getBedrockLargeStructurePos else &getBedrockFeaturePos)(&sconf, seed, regX, regZ);
                return @as(c_int, 1) != 0;
            },
            @as(c_int, 23), @as(c_int, 24) => return getStructurePos(structureType, mc, seed, regX, regZ, pos) != 0,
            @as(c_int, 20) => {
                pos.* = getBedrockLargeStructurePos(&sconf, seed, regX, regZ);
                return ((@as(i64, @bitCast(@as(c_long, pos.*.x))) * @as(i64, @bitCast(@as(c_long, pos.*.x)))) + (@as(i64, @bitCast(@as(c_long, pos.*.z))) * @as(i64, @bitCast(@as(c_long, pos.*.z))))) >= (@as(c_long, @bitCast(@as(c_long, @as(c_int, 1008)))) * @as(c_long, 1008));
            },
            @as(c_int, 15) => {
                pos.*.x = regX * @as(c_int, 16);
                pos.*.z = regZ * @as(c_int, 16);
                var mineshaftMt: MersenneTwister = undefined;
                _ = &mineshaftMt;
                bedrockChunkGenerateRnd(seed, regX, regZ, @as(c_int, 3), &mineshaftMt);
                _ = mNextIntUnbound(&mineshaftMt);
                return (@as(f64, @floatCast(mNextFloat(&mineshaftMt))) < 0.004) and (mNextInt(&mineshaftMt, @as(c_int, 80)) < (if (abs(regX) > abs(regZ)) abs(regX) else abs(regZ)));
            },
            else => {
                // _ = fprintf(stderr, "ERROR: getStructurePos: unsupported structure type %s\n", struct2str(structureType));
                exit(@as(c_int, 1));
            },
        }
        break;
    }
    return @as(c_int, 0) != 0;
}
// (no file):95:9
// (no file):101:9
// (no file):200:9
// (no file):222:9
// (no file):230:9
pub const linux = @as(c_int, 1);

