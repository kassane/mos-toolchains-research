pub const panic = std.debug.FullPanic(struct {
    pub fn panic(_: []const u8, _: ?usize) noreturn {
        @as(*volatile u8, @ptrFromInt(0xFFF8)).* = 88;   // overflow trap -> exit 88
        while (true) {}
    }
}.panic);
const std = @import("std");
export fn zig_ov(a: u8, b: u8) u8 { return a + b; }       // ReleaseSafe: overflow-checked
