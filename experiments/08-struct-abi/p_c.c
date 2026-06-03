#include "pkt.h"
#include <stddef.h>
uint32_t c_read(const struct Pkt *p){ return p->val; }
uint8_t  c_size(void){ return (uint8_t)sizeof(struct Pkt); }
