const std = @import("std");
const S = extern struct { a: u8, b: u32, c: u16 };
// Compile-time reflection. NB: zig-mos's `@typeInfo` Struct API changed in the
// 0.17-dev line — the old `.fields` array of Field{name,type,…} is now three
// parallel arrays `field_names` / `field_types` / `field_attrs` (Type moved to
// std.lang). Same information, different shape.
const ST = @typeInfo(S).@"struct";
const names = ST.field_names;                      // []const [:0]const u8
const types = ST.field_types;                      // []const type (same length)
comptime { std.debug.assert(names.len == 3); }     // compile-time reflection check
export fn zig_fields() u16 { return names.len; }   // 3
export fn zig_sizesum() u16 { var t: u16 = 0; inline for (types) |T| t += @sizeOf(T); return t; }  // 1+4+2 = 7
export fn zig_namesum() u16 { var s: u16 = 0; inline for (names) |n| s += n[0]; return s; }        // 'a'+'b'+'c' = 294
