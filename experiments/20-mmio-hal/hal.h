#ifndef HAL_H
#define HAL_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* MMIO hardware-register access (the mos-hardware / mega65-libc pattern):
 * a volatile poke to a fixed address. Here the "register" is the mos-sim console
 * output at $FFF9, so each language's poke is observable. All must lower to the
 * SAME 6502 store (sta $fff9). */
void c_poke(uint8_t c);   void cpp_poke(uint8_t c);  void rs_poke(uint8_t c);
void d_poke(uint8_t c);   void zig_poke(uint8_t c);
#ifdef __cplusplus
}
#endif
#endif
