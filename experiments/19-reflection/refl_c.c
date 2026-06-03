#include "refl.h"
struct S { uint8_t a; uint32_t b; uint16_t c; };
/* C has NO field reflection (only sizeof on the whole struct). */
uint16_t c_sizeof(void){ return (uint16_t)sizeof(struct S); }
