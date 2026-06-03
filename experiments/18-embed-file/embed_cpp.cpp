#include "embed.h"
static const uint8_t D[] = {
#embed "payload.bin"
};
extern "C" uint16_t cpp_sum(){ uint16_t s=0; for(unsigned i=0;i<sizeof(D);i++) s+=D[i]; return s; }
