#include "tmp.h"
/* C (pre-C23) has no constexpr functions: this is a RUNTIME loop -> the
 * contrast that shows the others folded at compile time. */
uint32_t c_fact10(void){ uint32_t f=1; for(uint32_t i=2;i<=10;i++) f*=i; return f; }
