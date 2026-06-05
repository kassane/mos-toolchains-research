const std = @import("std");
export fn zig_sqrt_x100(n: u16) i32 {
    return @intFromFloat(std.math.sqrt(@as(f32, @floatFromInt(n))) * 100.0);
}
// Float ARITHMETIC needs no libm symbol — soft-float libcalls ship in the SDK. 22/7*1000=3142.
export fn zig_fdiv_x1000(num: u16, den: u16) i32 {
    return @intFromFloat(@as(f32, @floatFromInt(num)) / @as(f32, @floatFromInt(den)) * 1000.0);
}
