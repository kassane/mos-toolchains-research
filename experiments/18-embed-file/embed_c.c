#include "embed.h"
static const uint8_t D[] = {
#embed "payload.bin"
};
uint16_t c_sum(void){ uint16_t s=0; for(unsigned i=0;i<sizeof(D);i++) s+=D[i]; return s; }
