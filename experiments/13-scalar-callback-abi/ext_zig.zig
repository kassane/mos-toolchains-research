const cb_t = *const fn (u16) callconv(.c) u16;
export fn zig_addq(a: u64, b: u64) u64 { return a +% b; }
export fn zig_neg(x: i16) i16 { return 0 -% x; }
export fn zig_apply(f: cb_t, x: u16) u16 { return f(x) +% 1; }
