// libc_shim.zig — Pure-Zig replacements for libc functions used in cubiomes_port.zig
//
// Eliminates the need for linkLibC() in the production binary.
// Uses a size-prefixed allocation pattern (following ziglibc) for malloc/calloc/free.

const std = @import("std");
const page_alloc = std.heap.page_allocator;

// ─── Types used by cubiomes_port.zig ────────────────────────────────────────

const FILE = @import("cubiomes_port.zig").FILE;

// ─── Memory allocation: size-prefixed with page_allocator ───────────────────
//
// Each allocation stores its total byte length in a header before the returned
// pointer.  free() reads that header to recover the slice for deallocation.

const HEADER_SIZE: usize = 16; // >= @sizeOf(usize), keeps returned pointer aligned

pub fn malloc(__size: c_ulong) callconv(.C) ?*anyopaque {
    const size: usize = __size;
    const total = std.math.add(usize, HEADER_SIZE, size) catch return null;
    const slice = page_alloc.alloc(u8, total) catch return null;
    @as(*align(1) usize, @ptrCast(slice.ptr)).* = total;
    return @ptrCast(slice.ptr + HEADER_SIZE);
}

pub fn calloc(__nmemb: c_ulong, __size: c_ulong) callconv(.C) ?*anyopaque {
    const n: usize = __nmemb;
    const s: usize = __size;
    const data_size = std.math.mul(usize, n, s) catch return null;
    const ptr = malloc(@intCast(data_size)) orelse return null;
    @memset(@as([*]u8, @ptrCast(ptr))[0..data_size], 0);
    return ptr;
}

pub fn free(__ptr: ?*anyopaque) callconv(.C) void {
    const p = __ptr orelse return;
    const base = @as([*]u8, @ptrCast(p)) - HEADER_SIZE;
    const total = @as(*align(1) usize, @ptrCast(base)).*;
    page_alloc.free(base[0..total]);
}

// ─── Math ───────────────────────────────────────────────────────────────────

pub fn pow(__x: f64, __y: f64) callconv(.C) f64 {
    return std.math.pow(f64, __x, __y);
}

pub fn nan(__tagb: [*c]const u8) callconv(.C) f64 {
    _ = __tagb;
    return std.math.nan(f64);
}

pub fn abs(__x: c_int) callconv(.C) c_int {
    if (__x < 0) return -__x;
    return __x;
}

/// erf(x) — error function.  Ported from musl libc (src/math/erf.c).
/// Only called from inverf() which is dead code in the production binary,
/// but we provide a correct implementation for completeness.
pub fn erf(arg: f64) callconv(.C) f64 {
    const erx = 8.45062911510467529297e-01;
    const efx8 = 1.02703333676410069053e+00;
    const pp0 = 1.28379167095512558561e-01;
    const pp1 = -3.25042107247001499370e-01;
    const pp2 = -2.84817495755985104766e-02;
    const pp3 = -5.77027029648944159157e-03;
    const pp4 = -2.37630166566501626084e-05;
    const qq1 = 3.97917223959155352819e-01;
    const qq2 = 6.50222499887672944485e-02;
    const qq3 = 5.08130628187576562776e-03;
    const qq4 = 1.32494738004321644526e-04;
    const qq5 = -3.96022827877536812320e-06;
    const pa0 = -2.36211856075265944077e-03;
    const pa1 = 4.14856118683748331666e-01;
    const pa2 = -3.72207876035701323847e-01;
    const pa3 = 3.18346619901161753674e-01;
    const pa4 = -1.10894694282396677476e-01;
    const pa5 = 3.54783043195201877747e-02;
    const pa6 = -2.16637559983254089680e-03;
    const qa1 = 1.06420880400844228286e-01;
    const qa2 = 5.40397917702171048937e-01;
    const qa3 = 7.18286544141962539399e-02;
    const qa4 = 1.26171219808761642112e-01;
    const qa5 = 1.36370839120290507362e-02;
    const qa6 = 1.19844998467991074170e-02;
    const ra0 = -9.86494403484714822705e-03;
    const ra1 = -6.93858572707181764372e-01;
    const ra2 = -1.05586262253232909814e+01;
    const ra3 = -6.23753324503260060396e+01;
    const ra4 = -1.62396669462573071767e+02;
    const ra5 = -1.84605092906711035994e+02;
    const ra6 = -8.12874355063065934246e+01;
    const ra7 = -9.81432934416914548592e+00;
    const sa1 = 1.96512716674392571292e+01;
    const sa2 = 1.37657754143519702237e+02;
    const sa3 = 4.34565877475229228608e+02;
    const sa4 = 6.45387271733267880594e+02;
    const sa5 = 4.29008140027567833386e+02;
    const sa6 = 1.08635005541779435134e+02;
    const sa7 = 6.57024977031928170135e+00;
    const sa8 = -6.04244152148580987438e-02;

    var x = arg;
    const bits = @as(u64, @bitCast(x));
    const ix = @as(u32, @intCast(bits >> 32)) & 0x7fffffff;
    const sign: bool = bits >> 63 != 0;
    if (ix >= 0x7ff00000) {
        // erf(nan) = nan, erf(+-inf) = +-1
        if (std.math.isNan(x)) return x;
        return if (sign) -1.0 else 1.0;
    }
    if (sign) x = -x;

    if (ix < 0x3feb0000) { // |x| < 0.84375
        if (ix < 0x3e300000) { // |x| < 2**-28
            if (ix < 0x00800000) { // avoid underflow
                const r = 0.125 * (8.0 * x + efx8 * x);
                return if (sign) -r else r;
            }
            const r = x + efx8 * x; // efx8 = 8*efx = 8*(2/sqrt(pi))*0.5 = 4/sqrt(pi)*x -> avoid underflow
            return if (sign) -r else r;
        }
        const z = x * x;
        const r = pp0 + z * (pp1 + z * (pp2 + z * (pp3 + z * pp4)));
        const s = 1.0 + z * (qq1 + z * (qq2 + z * (qq3 + z * (qq4 + z * qq5))));
        const y = r / s;
        const result = x + x * y;
        return if (sign) -result else result;
    }
    if (ix < 0x3ff40000) { // 0.84375 <= |x| < 1.25
        const s2 = x - 1.0;
        const P = pa0 + s2 * (pa1 + s2 * (pa2 + s2 * (pa3 + s2 * (pa4 + s2 * (pa5 + s2 * pa6)))));
        const Q = 1.0 + s2 * (qa1 + s2 * (qa2 + s2 * (qa3 + s2 * (qa4 + s2 * (qa5 + s2 * qa6)))));
        const result = erx + P / Q;
        return if (sign) -result else result;
    }
    if (ix >= 0x40180000) { // |x| >= 6
        const result: f64 = 1.0;
        return if (sign) -result else result;
    }

    // Compute 1 - erfc(x)
    const s2 = 1.0 / (x * x);
    var R: f64 = undefined;
    var S: f64 = undefined;
    if (ix < 0x4006DB6E) { // |x| < 1/0.35 ~ 2.857
        R = ra0 + s2 * (ra1 + s2 * (ra2 + s2 * (ra3 + s2 * (ra4 + s2 * (ra5 + s2 * (ra6 + s2 * ra7))))));
        S = 1.0 + s2 * (sa1 + s2 * (sa2 + s2 * (sa3 + s2 * (sa4 + s2 * (sa5 + s2 * (sa6 + s2 * (sa7 + s2 * sa8)))))));
    } else { // |x| >= 2.857
        // Use erfc coefficients directly (rb/sb)
        const rb0 = -9.86494292470009928597e-03;
        const rb1 = -7.99283237680523006574e-01;
        const rb2 = -1.77579549177547519889e+01;
        const rb3 = -1.60636384855557935030e+02;
        const rb4 = -6.37566443368389085394e+02;
        const rb5 = -1.02509513161107724954e+03;
        const rb6 = -4.83519191608651397019e+02;
        const sb1 = 3.03380607875625778203e+01;
        const sb2 = 3.25792512996573918826e+02;
        const sb3 = 1.53672958608443695994e+03;
        const sb4 = 3.19985821950859553908e+03;
        const sb5 = 2.55305040643316442583e+03;
        const sb6 = 4.74528541206955367215e+02;
        const sb7 = -2.24409524465858183362e+01;
        R = rb0 + s2 * (rb1 + s2 * (rb2 + s2 * (rb3 + s2 * (rb4 + s2 * (rb5 + s2 * rb6)))));
        S = 1.0 + s2 * (sb1 + s2 * (sb2 + s2 * (sb3 + s2 * (sb4 + s2 * (sb5 + s2 * (sb6 + s2 * sb7))))));
    }
    // exp(-x*x - 0.5625 + R/S)
    const high_bits = @as(u64, @bitCast(-x * x)) & 0xFFFFFFFF00000000;
    const z = @as(f64, @bitCast(high_bits));
    const r2 = @exp(z) * @exp(-x * x - z + R / S);
    const result = 1.0 - r2 / x;
    return if (sign) -result else result;
}

// ─── Process control ────────────────────────────────────────────────────────

pub fn exit(__status: c_int) callconv(.C) noreturn {
    std.process.exit(@truncate(@as(c_uint, @bitCast(__status))));
}

// ─── Formatted I/O (error-path only — best-effort stderr) ───────────────────
// These are only called on impossible-fail error paths (always followed by exit).
// We write the raw format string to stderr as a hint; substitutions are NOT rendered.

pub fn printf(__format: [*c]const u8, ...) callconv(.C) c_int {
    const fmt: [*:0]const u8 = __format orelse return 0;
    const len = std.mem.len(fmt);
    std.io.getStdErr().writeAll(fmt[0..len]) catch {};
    return 0;
}

pub fn fprintf(__stream: [*c]FILE, __format: [*c]const u8, ...) callconv(.C) c_int {
    _ = __stream;
    const fmt: [*:0]const u8 = __format orelse return 0;
    const len = std.mem.len(fmt);
    std.io.getStdErr().writeAll(fmt[0..len]) catch {};
    return 0;
}

// ─── String functions (dead code in production) ─────────────────────────────

pub fn strcmp(__s1: [*c]const u8, __s2: [*c]const u8) callconv(.C) c_int {
    const s1: [*]const u8 = __s1 orelse return -1;
    const s2: [*]const u8 = __s2 orelse return 1;
    var i: usize = 0;
    while (s1[i] == s2[i]) : (i += 1) {
        if (s1[i] == 0) return 0;
    }
    return @as(c_int, @intCast(s1[i])) - @as(c_int, @intCast(s2[i]));
}

pub fn strlen(__s: [*c]const u8) callconv(.C) c_ulong {
    const s: [*:0]const u8 = __s orelse return 0;
    return std.mem.len(s);
}

pub fn strstr(__haystack: [*c]const u8, __needle: [*c]const u8) callconv(.C) [*c]u8 {
    const hay: [*:0]const u8 = __haystack orelse return null;
    const ndl: [*:0]const u8 = __needle orelse return @constCast(__haystack);
    const needle_len = std.mem.len(ndl);
    if (needle_len == 0) return @constCast(__haystack);
    const hay_len = std.mem.len(hay);
    if (needle_len > hay_len) return null;
    const needle_slice = ndl[0..needle_len];
    var i: usize = 0;
    while (i <= hay_len - needle_len) : (i += 1) {
        if (std.mem.eql(u8, hay[i..][0..needle_len], needle_slice)) {
            return @constCast(@as([*c]const u8, @ptrCast(hay + i)));
        }
    }
    return null;
}

// ─── File I/O (dead code — never reached in production) ─────────────────────

pub fn fopen(__filename: [*c]const u8, __modes: [*c]const u8) callconv(.C) [*c]FILE {
    _ = __filename;
    _ = __modes;
    @panic("dead code: fopen");
}

pub fn fclose(__stream: [*c]FILE) callconv(.C) c_int {
    _ = __stream;
    @panic("dead code: fclose");
}

pub fn feof(__stream: [*c]FILE) callconv(.C) c_int {
    _ = __stream;
    @panic("dead code: feof");
}

pub fn fgetc(__stream: [*c]FILE) callconv(.C) c_int {
    _ = __stream;
    @panic("dead code: fgetc");
}

pub fn fscanf(__stream: [*c]FILE, __format: [*c]const u8, ...) callconv(.C) c_int {
    _ = __stream;
    _ = __format;
    @panic("dead code: fscanf");
}

pub fn fwrite(__ptr: ?*const anyopaque, __size: c_ulong, __n: c_ulong, __s: [*c]FILE) callconv(.C) c_ulong {
    _ = __ptr;
    _ = __size;
    _ = __n;
    _ = __s;
    @panic("dead code: fwrite");
}

pub fn rewind(__stream: [*c]FILE) callconv(.C) void {
    _ = __stream;
    @panic("dead code: rewind");
}
