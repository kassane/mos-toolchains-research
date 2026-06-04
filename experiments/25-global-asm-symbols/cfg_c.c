#include <stdint.h>
/* C — real-world MOS asm idioms, cross-frontend (exp 25).
 * (A) The llvm-mos-sdk NES iNES-config idiom (nes/include/ines.h): a *file-scope*
 *     asm() defines an ABSOLUTE linker symbol whose VALUE is a compile-time constant
 *     the linker reads (into the cartridge header). Namespaced per-language so all
 *     five objects can co-link into one binary. */
asm(".globl __cfg_c\n__cfg_c = 10");
/* (B) Real-world inline-asm MMIO: store a byte to the mos-sim stdout port (65529 =
 *     $FFF9). Decimal address keeps the template identical across frontends — in LDC's
 *     raw ldc.llvmasm a literal `$` is the operand sigil (needs `$$`); clang, Zig and
 *     Rust all take `$` literally. The A register and memory are clobbered — the store
 *     must not be reordered or elided ("memory" is what makes the MMIO asm sound). */
void c_hw(void) { __asm__ volatile("lda #67\nsta 65529" : : : "a", "memory"); } /* 'C' */
