const D = @embedFile("payload.bin");
export fn zig_sum() u16 { var s: u16 = 0; for (D) |b| s +%= b; return s; }
