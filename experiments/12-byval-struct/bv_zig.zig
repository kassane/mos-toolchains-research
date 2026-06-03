const Small = extern struct { a: u8, b: u8 };
const Big   = extern struct { a: u16, b: u16, c: u16, d: u16 };
export fn zig_small(p: Small) u16 { return @as(u16, p.a) + p.b; }
export fn zig_mkbig(base: u16) Big { return .{ .a = base, .b = base +% 1, .c = base +% 2, .d = base +% 3 }; }
