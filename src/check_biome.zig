const std = @import("std");
const c = @import("cubiomes_port.zig");
const search_eval = @import("search_eval.zig");
const types = @import("search_types.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var g: c.Generator = undefined;
    c.setupGenerator(&g, c.MC_1_21_1, 0);
    c.applySeed(&g, c.DIM_OVERWORLD, 18);

    const bounds = search_eval.precomputeBiomeClimateBounds(c.MC_1_21_1, c.cherry_grove).?;

    // The point in question: (-64, 196) at seed 18
    // Direct getBiomeAt says cherry_grove, fastBiomeIdWithFeasibility says none
    // Climate values: C=308 E=-2889 W=4961 D=6760 T=-874 H=-1017
    const np_vals = [6]i64{ -874, -1017, 308, -2889, 6760, 4961 };

    try stdout.print("leaf_count={d}, overflow={any}\n", .{ bounds.leaf_count, bounds.leaf_overflow });

    // Check each leaf
    var any_match = false;
    for (0..bounds.leaf_count) |li| {
        const leaf = bounds.leaves[li];
        var matches = true;
        var mismatch_dim: ?usize = null;
        for (0..6) |dim| {
            const v = np_vals[dim];
            const lo = @as(i64, leaf[dim].lo);
            const hi = @as(i64, leaf[dim].hi);
            if (v < lo or v > hi) {
                matches = false;
                mismatch_dim = dim;
                break;
            }
        }
        if (matches) {
            try stdout.print("  Leaf {d} MATCHES!\n", .{li});
            any_match = true;
        }
        // Print first few leaves that fail on depth (dim 4)
        if (!matches and mismatch_dim == 4) {
            try stdout.print("  Leaf {d} fails on depth: val={d}, range=[{d},{d}]\n", .{ li, np_vals[4], leaf[4].lo, leaf[4].hi });
        }
    }
    if (!any_match) {
        try stdout.print("  NO leaf matches! But climateToBiome returns cherry_grove.\n", .{});
    }

    // Count total cherry_grove nodes in the tree
    const tree = search_eval.selectBiomeTree(c.MC_1_21_1);
    var total_nodes: usize = 0;
    var matching_nodes: usize = 0;
    const biome_u8: u8 = @truncate(@as(u32, @intCast(c.cherry_grove)));
    for (tree.nodes) |node| {
        const node_biome: u8 = @truncate((node >> 48) & 0xff);
        if (node_biome == biome_u8) {
            total_nodes += 1;

            // Check if this node matches our point
            var node_matches = true;
            for (0..6) |dim| {
                const shift: u6 = @intCast(dim * 8);
                const param_idx: usize = @intCast((node >> shift) & 0xff);
                const p = tree.params[param_idx];
                const lo = @as(i64, p[0]);
                const hi = @as(i64, p[1]);
                if (np_vals[dim] < lo or np_vals[dim] > hi) {
                    node_matches = false;
                    break;
                }
            }
            if (node_matches) matching_nodes += 1;
        }
    }
    try stdout.print("\nTotal cherry_grove tree nodes: {d}\n", .{total_nodes});
    try stdout.print("Nodes matching our point: {d}\n", .{matching_nodes});
}
