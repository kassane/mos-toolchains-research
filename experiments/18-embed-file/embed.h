#ifndef EMBED_H
#define EMBED_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Each language embeds the SAME payload.bin at COMPILE TIME (no runtime file I/O)
 * and returns the byte-sum (mod 2^16). run.sh passes the actual sum as -DEXPECT,
 * so this stays correct if payload.bin changes; all six methods must agree. */
uint16_t c_sum(void);    /* C23  #embed              */
uint16_t cpp_sum(void);  /* C++  #embed (Clang ext)  */
uint16_t rs_sum(void);   /* Rust include_bytes!      */
uint16_t d_sum(void);    /* D    import("file") + -J */
uint16_t zig_sum(void);  /* Zig  @embedFile          */
uint16_t c_incbin_sum(void); /* asm-inline .incbin (the SDK's NES-mapper technique) */
#ifdef __cplusplus
}
#endif
#endif
