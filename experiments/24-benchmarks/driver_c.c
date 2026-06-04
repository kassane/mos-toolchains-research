#include <stdio.h>
#include <stdint.h>
#include "bench.h"
// C-only driver, reused for the mos6502-vs-mos65c02 bonus run (same sources,
// different -mcpu + mos-sim --cmos). Times the three C kernels via $FFF0 (CYC).
static uint8_t buf[8191];
int main(void) {
    uint32_t t0, s, f, c; uint16_t rs, rf, rc;
    t0 = *CYC; rs = c_sieve(buf);     s = *CYC - t0;
    t0 = *CYC; rf = c_fib(24);        f = *CYC - t0;
    for (uint16_t i = 0; i < 256; i++) buf[i] = (uint8_t)i;
    t0 = *CYC; rc = c_crc16(buf, 256); c = *CYC - t0;
    printf("sieve=%lu fib=%lu crc16=%lu\n", (unsigned long)s, (unsigned long)f, (unsigned long)c);
    return (rs == 1899 && rf == 46368 && rc == 0x7E55) ? 0 : 1;
}
