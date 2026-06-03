const std = @import("std");
export fn zig_std() u16 {
    var a = [_]u16{ 9, 3, 7, 1, 5 };
    std.mem.sort(u16, &a, {}, std.sort.asc(u16));   // std.sort
    var buf: [8]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}", .{a[0]}) catch return 0; // std.fmt
    return s.len * 100 + a[0];   // "1" -> len 1 -> 100 + 1 = 101
}
