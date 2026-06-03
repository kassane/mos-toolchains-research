#include "bv.h"
extern "C" uint16_t cpp_small(struct Small p){ return (uint16_t)(p.a + p.b); }
extern "C" struct Big cpp_mkbig(uint16_t base){ return {base,(uint16_t)(base+1),(uint16_t)(base+2),(uint16_t)(base+3)}; }
