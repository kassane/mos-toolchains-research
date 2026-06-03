#ifndef TMP_H
#define TMP_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Each returns factorial(10)=3628800 computed AT COMPILE TIME (CTFE/constexpr/
 * const fn). A correct build collapses the body to a constant load (no loop/
 * recursion in the 6502 disassembly) -- that collapse IS the TMP evidence. */
uint32_t c_fact10(void);    /* C: no constexpr pre-C23 -> runtime baseline */
uint32_t cpp_fact10(void);  /* C++ constexpr */
uint32_t cpp_fact10_ce(void); /* C++ consteval (immediate fn, like comptime) */
uint32_t rs_fact10(void);   /* Rust const fn */
uint32_t d_fact10(void);    /* D CTFE (enum) */
#ifdef __cplusplus
}
#endif
#endif
