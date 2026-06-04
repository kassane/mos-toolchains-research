#include <stdio.h>
#include <stdint.h>
#include "bench.h"
// Zig-stdlib kernels in their OWN binary. std.crypto + std.hash pull a large
// (~50 KB) transitive closure that build-obj does not dead-code-eliminate (the
// three functions themselves are ~1.7 KB), so they can't co-reside with the
// cross-language bench's 8 KB sieve buffer in 64 KB. Standalone they fit/run.
// Point of the experiment: on bare-metal MOS, only Zig can pull CRC / a real
// crypto hash / sqrt straight from its stdlib (docs/13). CYC ($FFF0) from bench.h.
static uint8_t buf[256];

int main(void) {
    int bad = 0; uint16_t i;
    for (i = 0; i < 256; i++) buf[i] = (uint8_t)i;
    printf("module        kernel  result  cycles\n");

    /* std.hash.crc -- table-based CRC-16/XMODEM, same 0x7E55 as the hand-rolled */
    uint32_t t0 = *CYC; uint16_t c = zig_crc16_std(buf, 256); uint32_t cy = *CYC - t0;
    printf("std.hash.crc  crc16   %04x    %lu\n", c, (unsigned long)cy);
    if (c != 0x7E55) bad++;

    /* std.crypto -- a real SHA-256 on a 6502; check the digest byte-for-byte */
    {
        static const uint8_t exp[32] = {
            0x40,0xaf,0xf2,0xe9,0xd2,0xd8,0x92,0x2e,0x47,0xaf,0xd4,0x64,0x8e,0x69,0x67,0x49,
            0x71,0x58,0x78,0x5f,0xbd,0x1d,0xa8,0x70,0xe7,0x11,0x02,0x66,0xbf,0x94,0x48,0x80};
        uint8_t dig[32]; int ok = 1;
        t0 = *CYC; zig_sha256(buf, 256, dig); cy = *CYC - t0;
        for (i = 0; i < 32; i++) if (dig[i] != exp[i]) ok = 0;
        printf("std.crypto    sha256  %-5s   %lu\n", ok ? "OK" : "BAD", (unsigned long)cy);
        if (!ok) bad++;
    }

    /* std.math -- integer sqrt(64000) = 252 */
    t0 = *CYC; uint16_t q = zig_isqrt(64000); cy = *CYC - t0;
    printf("std.math      isqrt   %5u   %lu\n", q, (unsigned long)cy);
    if (q != 252) bad++;

    printf("== %d stdlib failure(s) (Zig std.{hash.crc, crypto, math} run on a 6502) ==\n", bad);
    return bad;
}
