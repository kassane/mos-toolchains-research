// D kernels (-betterC). @system to allow raw-pointer indexing under
// -preview=safer (CLAUDE gotcha #10). ushort == u16, identical algorithm.
extern(C) ushort d_sieve(ubyte* flags) @system {
    ushort count = 0;
    for (ushort i = 0; i <= 8190; i++) flags[i] = 1;
    for (ushort i = 0; i <= 8190; i++) if (flags[i]) {
        ushort p = cast(ushort)(i + i + 3);
        for (ushort k = cast(ushort)(i + p); k <= 8190; k = cast(ushort)(k + p)) flags[k] = 0;
        count++;
    }
    return count;
}
extern(C) ushort d_fib(ushort n) {
    return n < 2 ? n : cast(ushort)(d_fib(cast(ushort)(n - 1)) + d_fib(cast(ushort)(n - 2)));
}
extern(C) ushort d_crc16(ubyte* buf, ushort len) @system {
    ushort crc = 0;
    for (ushort i = 0; i < len; i++) {
        crc = cast(ushort)(crc ^ cast(ushort)(cast(ushort)buf[i] << 8));
        for (ushort j = 0; j < 8; j++)
            crc = (crc & 0x8000) ? cast(ushort)(cast(ushort)(crc << 1) ^ 0x1021)
                                 : cast(ushort)(crc << 1);
    }
    return crc;
}
