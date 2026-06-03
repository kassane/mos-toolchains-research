#include <stdint.h>
uint8_t zig_ov(uint8_t, uint8_t);
int main(void){ return zig_ov(200, 100); }   /* 300 > 255 -> u8 overflow */
