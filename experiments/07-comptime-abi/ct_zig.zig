const std = @import("std");
comptime {
    std.debug.assert(@sizeOf(c_int) == 4); // Zig c_int=32-bit FOOTGUN (C int=2)
    std.debug.assert(@sizeOf(usize) == 2); // usize matches 16-bit pointer
    std.debug.assert(@sizeOf(i32) == 4);
    std.debug.assert(@sizeOf(*u8) == 2); // normal pointer 16-bit
    // Zig uses NATURAL scalar alignment, NOT the LLVM-MOS datalayout's byte
    // packing (i32:8 => 1). C/D/Rust all assert @alignOf(i32)==1; Zig==4.
    std.debug.assert(@alignOf(i32) == 4); // DIVERGES from C/D/Rust (see exp 08)
    // zero-page address space: an AS .zp pointer is 8-bit (datalayout p1:8:8).
    std.debug.assert(@sizeOf(*addrspace(.zp) u8) == 1);
}
export fn ct_zig_ok() c_int { return 0; }
