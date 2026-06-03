// export => C ABI. u16==uint16_t, u8==uint8_t.
extern fn c_add8(a: u8, b: u8) u8; // implemented in C

export fn zig_shl16(a: u16, n: u8) u16 {
    const sh: u4 = @intCast(n & 0xF);
    const shifted: u16 = a << sh;
    // Zig -> C cross-call. c_add8(lo,0) == lo, opaque to Zig, so the call
    // stays live; (chk - lo) == 0 keeps result == a << (n & 15).
    const lo: u8 = @truncate(shifted);
    const chk: u8 = c_add8(lo, 0);
    return shifted +% (@as(u16, chk) -% @as(u16, lo));
}
