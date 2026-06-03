#include <stdio.h>
#include "ffi.h"

static int check(const char *name, uint16_t got, uint16_t want) {
    int ok = (got == want);
    printf("%-10s = %5u  expect %5u  [%s]\n", name, got, want, ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}

int main(void) {
    int fails = 0;
    fails += check("c_add8",    c_add8(0x12, 0x34),       0x46);   /* C            */
    fails += check("cpp_mul16", cpp_mul16(0x100, 3),      0x300);  /* C++          */
    fails += check("rs_sub16",  rs_sub16(1000, 1),        999);    /* Rust         */
    fails += check("d_xor16",   d_xor16(0xAAAA, 0x5555),  0xFFFF); /* D  -> Rust   */
    fails += check("zig_shl16", zig_shl16(1, 9),          512);    /* Zig -> C     */
    printf("== %d failure(s) ==\n", fails);
    return fails;
}
