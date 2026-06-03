const REG: *volatile u8 = @ptrFromInt(0xFFF9);
export fn zig_poke(c: u8) void { REG.* = c; }
