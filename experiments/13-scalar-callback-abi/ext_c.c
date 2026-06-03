#include "ext.h"
uint64_t c_addq(uint64_t a, uint64_t b){ return a + b; }
int16_t  c_neg(int16_t x){ return (int16_t)-x; }
uint16_t c_apply(cb_t f, uint16_t x){ return (uint16_t)(f(x) + 1); }
