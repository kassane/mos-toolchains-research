const std = @import("std");
// Stdlib dimension: the SAME work, but pulled from Zig's standard library
// instead of hand-rolled. On bare-metal MOS only Zig can do this -- C/C++ (STL
// subset), Rust (`core`), D (`-betterC`) have no CRC/crypto/hash in their
// reachable stdlib (docs/13), so they must hand-roll (bench_*). These compile
// for `mos-freestanding` and run on mos-sim with zero porting.

// CRC-16/XMODEM from std.hash.crc -- table-based, so smaller *code* and far
// fewer cycles than the hand-rolled bit-serial zig_crc16 (it trades a 512-byte
// lookup table for speed). Same result (0x7E55).
export fn zig_crc16_std(buf: [*]const u8, len: u16) u16 {
    return std.hash.crc.Crc16Xmodem.hash(buf[0..len]);
}

// A real cryptographic hash (SHA-256, std.crypto) on a 6502. Writes the 32-byte
// digest to `out`; the driver checks it byte-for-byte against the known vector.
export fn zig_sha256(buf: [*]const u8, len: u16, out: [*]u8) void {
    var d: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(buf[0..len], &d, .{});
    var i: u8 = 0;
    while (i < 32) : (i += 1) out[i] = d[i];
}

// std.math integer square root.
export fn zig_isqrt(x: u16) u16 {
    return std.math.sqrt(x);
}
