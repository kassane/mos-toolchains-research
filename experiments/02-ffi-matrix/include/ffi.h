/* Shared C-ABI contract for the cross-language FFI matrix.
 * Fixed-width types only: avoids the C-int(16) vs D/Rust/Zig-int(32) footgun
 * (documented separately in experiments/03-int-width). Every symbol below is
 * implemented in a DIFFERENT language and linked into one 6502 binary. */
#ifndef FFI_H
#define FFI_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint8_t  c_add8   (uint8_t  a, uint8_t  b);  /* C    (SDK clang, LLVM 23) */
uint16_t cpp_mul16(uint16_t a, uint16_t b);  /* C++  (SDK clang++,LLVM 23)*/
uint16_t rs_sub16 (uint16_t a, uint16_t b);  /* Rust (rust-mos,  LLVM 23) */
uint16_t d_xor16  (uint16_t a, uint16_t b);  /* D    (LDC 1.42,  LLVM 23) */
uint16_t zig_shl16(uint16_t a, uint8_t  n);  /* Zig  (0.17-mos,  LLVM 22) */

/* Transitive cross-language calls (prove non-C languages call each other):
 *   zig_shl16 internally calls c_add8   (Zig -> C)
 *   d_xor16   internally calls rs_sub16 (D   -> Rust) */

#ifdef __cplusplus
}
#endif
#endif
