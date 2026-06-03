const std = @import("std");
export fn zig_cint_bytes() u8  { return @sizeOf(c_int); }  // == 4 (FOOTGUN: Zig c_int is 32-bit, != C int)
export fn zig_usize_bytes() u8 { return @sizeOf(usize); }  // == 2 (matches pointer)
export fn zig_i32_bytes() u8   { return @sizeOf(i32); }    // == 4
