#ifndef EXT_H
#define EXT_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef uint16_t (*cb_t)(uint16_t);   /* C callback type (16-bit code pointer) */
/* 64-bit scalar round-trip, signed negate, and calling a C function pointer. */
uint64_t c_addq(uint64_t a, uint64_t b);   int16_t c_neg(int16_t x);   uint16_t c_apply(cb_t f, uint16_t x);
uint64_t cpp_addq(uint64_t a, uint64_t b); int16_t cpp_neg(int16_t x); uint16_t cpp_apply(cb_t f, uint16_t x);
uint64_t rs_addq(uint64_t a, uint64_t b);  int16_t rs_neg(int16_t x);  uint16_t rs_apply(cb_t f, uint16_t x);
uint64_t d_addq(uint64_t a, uint64_t b);   int16_t d_neg(int16_t x);   uint16_t d_apply(cb_t f, uint16_t x);
uint64_t zig_addq(uint64_t a, uint64_t b); int16_t zig_neg(int16_t x); uint16_t zig_apply(cb_t f, uint16_t x);
#ifdef __cplusplus
}
#endif
#endif
