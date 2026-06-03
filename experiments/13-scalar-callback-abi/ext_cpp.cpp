#include "ext.h"
extern "C" uint64_t cpp_addq(uint64_t a, uint64_t b){ return a + b; }
extern "C" int16_t  cpp_neg(int16_t x){ return (int16_t)-x; }
extern "C" uint16_t cpp_apply(cb_t f, uint16_t x){ return (uint16_t)(f(x) + 1); }
