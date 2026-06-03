#include <stdint.h>
uint8_t rs_idx(uint8_t);
int main(void){ return rs_idx(5); }   /* index 5 into len-3 array -> OOB */
