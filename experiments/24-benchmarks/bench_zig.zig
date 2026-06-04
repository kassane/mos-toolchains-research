// Zig kernels (freestanding). Wrapping ops (+%) avoid overflow-check traps;
// `[*]u8` many-item pointers match the C buffer. Identical algorithm.
export fn zig_sieve(flags: [*]u8) u16 {
    var count: u16 = 0;
    var i: u16 = 0;
    while (i <= 8190) : (i += 1) flags[i] = 1;
    i = 0;
    while (i <= 8190) : (i += 1) if (flags[i] != 0) {
        const p: u16 = i +% i +% 3;
        var k: u16 = i +% p;
        while (k <= 8190) : (k +%= p) flags[k] = 0;
        count += 1;
    };
    return count;
}
export fn zig_fib(n: u16) u16 {
    return if (n < 2) n else zig_fib(n - 1) +% zig_fib(n - 2);
}
export fn zig_crc16(buf: [*]const u8, len: u16) u16 {
    var crc: u16 = 0;
    var i: u16 = 0;
    while (i < len) : (i += 1) {
        crc ^= @as(u16, buf[i]) << 8;
        var j: u8 = 0;
        while (j < 8) : (j += 1)
            crc = if ((crc & 0x8000) != 0) (crc << 1) ^ 0x1021 else (crc << 1);
    }
    return crc;
}
