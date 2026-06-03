#include "pkt.h"
extern "C" uint32_t cpp_read(const struct Pkt *p){ return p->val; }
extern "C" uint8_t  cpp_size(void){ return (uint8_t)sizeof(struct Pkt); }
