#include "bv.h"
uint16_t c_small(struct Small p){ return (uint16_t)(p.a + p.b); }
struct Big c_mkbig(uint16_t base){ struct Big b={base,(uint16_t)(base+1),(uint16_t)(base+2),(uint16_t)(base+3)}; return b; }
