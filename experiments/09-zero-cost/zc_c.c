#include "zc.h"
/* hand-written baseline */
uint16_t c_sum16(const uint16_t *a, uint16_t n){ uint16_t s=0; for(uint16_t i=0;i<n;i++) s+=a[i]; return s; }
static uint16_t dbl(uint16_t v){ return (uint16_t)(v*2); }
uint16_t c_apply(uint16_t x){ return dbl(dbl(x)); }
