#include <stdio.h>
#include <stdint.h>
uint16_t c_step(uint16_t);    /* C    */
uint16_t rs_step(uint16_t);   /* Rust */
uint16_t d_step(uint16_t);    /* D    */
uint16_t zig_step(uint16_t);  /* Zig  */
int main(void) {
    uint16_t x = 7;
    uint16_t r = zig_step(d_step(rs_step(c_step(x))));  /* 4 languages, 1 expr */
    /* 7 ->c +1=8 ->rs <<1=16 ->d ^0xFF=239 ->zig +0x10=255 */
    printf("pipeline(7) = %u (expect 255)\n", r);
    int ok = (r == 255);
    printf("== %s ==\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
