#ifndef BENCH_H
#define BENCH_H
#include <stdint.h>
/* Shared mos-sim cycle counter (4-byte MMIO at $FFF0); the drivers bracket each
 * kernel call with it. Single definition so the address lives in one place. */
#define CYC ((volatile uint32_t *)0xFFF0)
#ifdef __cplusplus
extern "C" {
#endif
/* Three integer-only kernels from the classic 6502 / 8-bit benchmark canon,
 * each implemented identically in C / C++ / Rust / D / Zig over the shared
 * llvm-mos backend. Same algorithm + u16 types everywhere, so the result is
 * identical and only the per-frontend codegen differs.
 *
 *  sieve : BYTE/Gilbreath Sieve of Eratosthenes, 8190 odd flags -> 1899 primes
 *          (memory + tight-loop bound; caller passes an 8191-byte buffer)
 *  fib   : naive recursive Fibonacci, fib(24) = 46368  (call/recursion bound;
 *          150049 calls -> stresses the soft-stack call path)
 *  crc16 : CRC-16/XMODEM (poly 0x1021) over buf[i]=i, len 256 -> 0x7E55
 *          (bit-twiddling: shift/xor inner loop)
 */
uint16_t c_sieve(uint8_t *flags);
uint16_t cpp_sieve(uint8_t *flags);
uint16_t rs_sieve(uint8_t *flags);
uint16_t d_sieve(uint8_t *flags);
uint16_t zig_sieve(uint8_t *flags);

uint16_t c_fib(uint16_t n);
uint16_t cpp_fib(uint16_t n);
uint16_t rs_fib(uint16_t n);
uint16_t d_fib(uint16_t n);
uint16_t zig_fib(uint16_t n);

uint16_t c_crc16(uint8_t *buf, uint16_t len);
uint16_t cpp_crc16(uint8_t *buf, uint16_t len);
uint16_t rs_crc16(uint8_t *buf, uint16_t len);
uint16_t d_crc16(uint8_t *buf, uint16_t len);
uint16_t zig_crc16(uint8_t *buf, uint16_t len);

/* Stdlib dimension (bench_zig_std.zig): only Zig has a usable stdlib for these
 * on bare-metal MOS -- C/C++/Rust(core)/D(-betterC) must hand-roll (docs/13). */
uint16_t zig_crc16_std(uint8_t *buf, uint16_t len);        /* std.hash.crc */
void     zig_sha256(uint8_t *buf, uint16_t len, uint8_t *out32); /* std.crypto */
uint16_t zig_isqrt(uint16_t x);                            /* std.math */
#ifdef __cplusplus
}
#endif
#endif
