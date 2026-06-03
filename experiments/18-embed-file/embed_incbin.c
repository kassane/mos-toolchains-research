#include "embed.h"
/* The classic pre-#embed method: embed a file via the assembler's .incbin
 * directive in a global inline-asm block. Works in any frontend with inline
 * asm (C/C++/D/Zig) -- NOT Rust (no inline asm on MOS, rust-mos#13). */
__asm__(
  ".globl _ib\n"
  "_ib:\n"
  ".incbin \"payload.bin\"\n"
  "_ib_end:\n"
  ".set _ib_sz, _ib_end - _ib\n"
);
extern const uint8_t _ib[];
extern const uint8_t _ib_sz[];   /* its ADDRESS encodes the byte count */
uint16_t c_incbin_sum(void){
  uint16_t n = (uint16_t)(uintptr_t)_ib_sz, s = 0;
  for (uint16_t i = 0; i < n; i++) s += _ib[i];
  return s;
}
