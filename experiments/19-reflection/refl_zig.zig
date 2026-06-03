const std = @import("std");
const S = extern struct { a: u8, b: u32, c: u16 };
const F = @typeInfo(S).@"struct".fields;          // comptime field list
comptime { std.debug.assert(F.len == 3); }        // compile-time reflection check
export fn zig_fields() u16 { return F.len; }       // 3
export fn zig_sizesum() u16 { var t: u16 = 0; inline for (F) |f| t += @sizeOf(f.type); return t; } // 7
export fn zig_namesum() u16 { var s: u16 = 0; inline for (F) |f| s += f.name[0]; return s; }       // 'a'+'b'+'c'
