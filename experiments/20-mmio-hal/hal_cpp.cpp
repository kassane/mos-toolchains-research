#include "hal.h"
extern "C" void cpp_poke(uint8_t c){
    // reinterpret_cast<int->ptr> is not constexpr, so name it as a local const
    // (same $FFF9 console register as hal_c.c's REG; lowers to the same sta $fff9).
    volatile uint8_t *const REG = reinterpret_cast<volatile uint8_t*>(0xFFF9);
    *REG = c;
}
