#ifndef ZC_H
#define ZC_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Two zero-cost forms, same semantics, one per language vs the C baseline:
 *  *_sum16  : monomorphized generic accumulate over a u16 array
 *  *_apply  : higher-order — apply a non-capturing doubling callable to x */
uint16_t c_sum16  (const uint16_t *a, uint16_t n); uint16_t c_apply  (uint16_t x);
uint16_t cpp_sum16(const uint16_t *a, uint16_t n); uint16_t cpp_apply(uint16_t x);
uint16_t rs_sum16 (const uint16_t *a, uint16_t n); uint16_t rs_apply (uint16_t x);
uint16_t d_sum16  (const uint16_t *a, uint16_t n); uint16_t d_apply  (uint16_t x);
#ifdef __cplusplus
}
#endif
#endif
