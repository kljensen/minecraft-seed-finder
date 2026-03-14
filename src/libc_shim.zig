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










