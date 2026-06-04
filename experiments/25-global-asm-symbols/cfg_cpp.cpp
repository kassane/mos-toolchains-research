#include <cstdint>
// C++ — same two idioms as the C source (exp 25). File-scope asm() needs no linkage
// specifier; the MMIO helper is extern "C" so the driver can call it unmangled.
asm(".globl __cfg_cpp\n__cfg_cpp = 20");                       // (A) absolute symbol
extern "C" void cpp_hw(void) {                                  // (B) inline-asm MMIO
    __asm__ volatile("lda #43\nsta 65529" : : : "a", "memory"); // '+'  (65529 = $FFF9)
}
