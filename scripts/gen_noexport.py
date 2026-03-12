#!/usr/bin/env python3
"""Generate cubiomes_port_noexport.zig by removing `export` linkage.

Replaces `pub export fn foo(...) RetType {` with
`pub fn foo(...) callconv(.C) RetType {` to preserve C calling convention
(needed for mapfunc_t function pointers) without emitting global C symbols.

Functions that already have callconv(.C) just get `export` stripped.
"""
import re

s = open('src/cubiomes_port.zig').read()

def fix_fn(m):
    line = m.group(0)
    # Already has callconv(.C) — just remove 'export'
    if 'callconv(.C)' in line:
        return 'pub ' + line[len('pub export '):]
    # Add callconv(.C) before the return type
    lp = line.rfind(')')
    br = line.rfind('{')
    ret_type = line[lp+1:br].strip()
    before = line[len('pub export '):lp+1]
    return 'pub ' + before + ' callconv(.C) ' + ret_type + ' {'

s = re.sub(r'^pub export fn .+ \{', fix_fn, s, flags=re.M)
s = s.replace('pub export const ', 'pub const ')
s = s.replace('pub export var ', 'pub var ')
open('src/cubiomes_port_noexport.zig', 'w').write(s)
