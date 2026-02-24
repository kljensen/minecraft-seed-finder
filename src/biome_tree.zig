// Clean idiomatic Zig rewrite of get_np_dist and get_resulting_node
// from cubiomes_port.zig. Must produce identical results.

fn asU64FromI32(value: i32) u64 {
    return @as(u64, @bitCast(@as(i64, value)));
}

pub fn getNpDist(np: [*c]const u64, param: [*c]const i32, nodes: [*c]const u64, idx: i32) u64 {
    const np_ptr: [*]const u64 = @ptrCast(np);
    const param_ptr: [*]const i32 = @ptrCast(param);
    const nodes_ptr: [*]const u64 = @ptrCast(nodes);

    const node = nodes_ptr[@intCast(idx)];
    var ds: u64 = 0;

    for (0..6) |i| {
        const shift: u6 = @intCast(i * 8);
        const component_idx: usize = @intCast((node >> shift) & 0xff);
        const lo = asU64FromI32(param_ptr[(component_idx * 2) + 0]);
        const hi = asU64FromI32(param_ptr[(component_idx * 2) + 1]);

        const a = np_ptr[i] -% hi;
        const b = lo -% np_ptr[i];
        const d = if (@as(i64, @bitCast(a)) > 0)
            a
        else if (@as(i64, @bitCast(b)) > 0)
            b
        else
            0;

        ds +%= d *% d;
    }

    return ds;
}

pub fn getResultingNode(
    np: [*c]const u64,
    steps: [*c]const u32,
    param: [*c]const i32,
    nodes: [*c]const u64,
    len: u32,
    order: u32,
    idx_in: i32,
    alt_in: i32,
    ds_in: u64,
    depth_in: i32,
) i32 {
    const steps_ptr: [*]const u32 = @ptrCast(steps);
    const nodes_ptr: [*]const u64 = @ptrCast(nodes);

    const idx = idx_in;
    var ds = ds_in;
    var depth = depth_in;

    if (steps_ptr[@intCast(depth)] == 0) return idx;

    var step: u32 = 0;
    while (true) {
        step = steps_ptr[@intCast(depth)];
        depth += 1;
        if ((@as(u32, @bitCast(idx)) +% step) < len) break;
    }

    const node = nodes_ptr[@intCast(idx)];
    var inner: u16 = @truncate(node >> 48);
    var leaf = alt_in;

    var i: u32 = 0;
    while (i < order) : (i += 1) {
        const inner_idx: i32 = @intCast(@as(u32, inner));
        const ds_inner = getNpDist(np, param, nodes, inner_idx);

        if (ds_inner < ds) {
            const leaf2 = getResultingNode(np, steps, param, nodes, len, order, inner_idx, leaf, ds, depth);
            const ds_leaf2 = if (inner_idx == leaf2) ds_inner else getNpDist(np, param, nodes, leaf2);
            if (ds_leaf2 < ds) {
                ds = ds_leaf2;
                leaf = leaf2;
            }
        }

        inner +%= @truncate(step);
        if (@as(u32, inner) >= len) break;
    }

    return leaf;
}
