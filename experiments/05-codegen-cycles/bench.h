#ifndef BENCH_H
#define BENCH_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* s=0; for i in 0..n: s = s*31 + i; return s;  (same algorithm, 5 languages) */
uint16_t c_lcg(uint16_t n);
uint16_t cpp_lcg(uint16_t n);
uint16_t rs_lcg(uint16_t n);
uint16_t d_lcg(uint16_t n);
uint16_t zig_lcg(uint16_t n);
#ifdef __cplusplus
}
#endif
#endif
