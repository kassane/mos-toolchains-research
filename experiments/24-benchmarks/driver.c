#include <stdio.h>
#include <stdint.h>
#include "bench.h"
// Time each kernel for each frontend with the $FFF0 cycle counter (CYC, from
// bench.h), bracketing ONLY the kernel call (excludes crt0/startup). Gate on the
// canonical result.
static uint8_t buf[8191];
static int bad = 0;

#define RUN(kern, name, call, expect, fmt)                                   \
    do {                                                                     \
        uint32_t t0 = *CYC; uint16_t r = (call); uint32_t cy = *CYC - t0;    \
        printf("%-6s %-4s " fmt " %lu\n", kern, name, r, (unsigned long)cy); \
        if (r != (expect)) bad++;                                            \
    } while (0)

int main(void) {
    printf("kernel lang result cycles\n");
    /* sieve: caller buffer; the kernel re-initialises it, so prior state is ok */
    RUN("sieve", "C",   c_sieve(buf),   1899, "%5u");
    RUN("sieve", "C++", cpp_sieve(buf), 1899, "%5u");
    RUN("sieve", "Rust",rs_sieve(buf),  1899, "%5u");
    RUN("sieve", "D",   d_sieve(buf),   1899, "%5u");
    RUN("sieve", "Zig", zig_sieve(buf), 1899, "%5u");
    /* fib(24) = 46368 (recursive; 150049 calls) */
    RUN("fib24", "C",   c_fib(24),   46368, "%5u");
    RUN("fib24", "C++", cpp_fib(24), 46368, "%5u");
    RUN("fib24", "Rust",rs_fib(24),  46368, "%5u");
    RUN("fib24", "D",   d_fib(24),   46368, "%5u");
    RUN("fib24", "Zig", zig_fib(24), 46368, "%5u");
    /* crc16/XMODEM over buf[i]=i, len 256 -> 0x7E55 (refill, sieve trashed buf) */
    for (uint16_t i = 0; i < 256; i++) buf[i] = (uint8_t)i;
    RUN("crc16", "C",   c_crc16(buf, 256),   0x7E55, "%04x");
    RUN("crc16", "C++", cpp_crc16(buf, 256), 0x7E55, "%04x");
    RUN("crc16", "Rust",rs_crc16(buf, 256),  0x7E55, "%04x");
    RUN("crc16", "D",   d_crc16(buf, 256),   0x7E55, "%04x");
    RUN("crc16", "Zig", zig_crc16(buf, 256), 0x7E55, "%04x");
    printf("== %d wrong result(s) (0 = every frontend computed the canonical value) ==\n", bad);
    return bad;
}
