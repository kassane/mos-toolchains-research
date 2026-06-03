#include "hal.h"
extern "C" void cpp_poke(uint8_t c){ *reinterpret_cast<volatile uint8_t*>(0xFFF9) = c; }
