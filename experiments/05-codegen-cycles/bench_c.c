#include "bench.h"
uint16_t c_lcg(uint16_t n){ uint16_t s=0; for(uint16_t i=0;i<n;i++) s=(uint16_t)(s*31+i); return s; }
