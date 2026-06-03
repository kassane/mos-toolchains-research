#include <stdint.h>
/* C contrast: NO bounds check -> reads out of bounds (UB), no trap. */
uint8_t c_idx(uint8_t i){ uint8_t a[3]={10,20,30}; return a[i]; }
