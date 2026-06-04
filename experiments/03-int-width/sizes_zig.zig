const std = @import("std");
export fn zig_cint_bytes() u8  { return @sizeOf(c_int); }  // == 2 (matches C int now; was 32-bit on older 0.17-dev builds)
export fn zig_usize_bytes() u8 { return @sizeOf(usize); }  // == 2 (matches pointer)
export fn zig_i32_bytes() u8   { return @sizeOf(i32); }    // == 4
