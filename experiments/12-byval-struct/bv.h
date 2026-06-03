#ifndef BV_H
#define BV_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* By-VALUE struct ABI: <=4 bytes are decomposed into registers, >4 bytes go via
 * a hidden pointer (sret/byref). Small(2B) & Big(8B) are homogeneous so every
 * frontend agrees; the C driver passes them BY VALUE and also receives Big BY
 * VALUE (return), exercising both directions of the aggregate ABI. */
struct Small { uint8_t a, b; };              /* 2 bytes  -> register-passed     */
struct Big   { uint16_t a, b, c, d; };       /* 8 bytes  -> by hidden pointer   */
uint16_t c_small(struct Small p);   struct Big c_mkbig(uint16_t base);
uint16_t cpp_small(struct Small p); struct Big cpp_mkbig(uint16_t base);
uint16_t rs_small(struct Small p);  struct Big rs_mkbig(uint16_t base);
uint16_t d_small(struct Small p);   struct Big d_mkbig(uint16_t base);
uint16_t zig_small(struct Small p); struct Big zig_mkbig(uint16_t base);
#ifdef __cplusplus
}
#endif
#endif
