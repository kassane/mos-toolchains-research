#include "hal.h"
#define REG ((volatile uint8_t *)0xFFF9)   /* like c64 VIC-II border_color @ $D020 */
void c_poke(uint8_t c){ *REG = c; }
