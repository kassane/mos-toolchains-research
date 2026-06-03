#include <stdio.h>
#include "embed.h"
#ifndef EXPECT
#define EXPECT 9231   /* byte-sum of payload.bin; run.sh passes -DEXPECT=<actual> */
#endif
int main(void){
    printf("compile-time file embed (real payload.bin, byte-sum=%u)\n", (unsigned)EXPECT);
    struct { const char *n, *how; uint16_t (*f)(void); } t[] = {
        {"C",   "#embed",        c_sum},   {"C++", "#embed",        cpp_sum},
        {"Rust","include_bytes!",rs_sum},  {"D",   "import(\"file\")", d_sum},
        {"Zig", "@embedFile",    zig_sum}, {"asm", ".incbin",       c_incbin_sum},
    };
    int bad=0; uint16_t first=t[0].f();
    for(int i=0;i<6;i++){
        uint16_t v=t[i].f(); int ok=(v==(uint16_t)EXPECT && v==first);
        printf("  %-5s %-15s sum=%u %s\n", t[i].n, t[i].how, v, ok?"OK":"FAIL");
        if(!ok) bad++;
    }
    printf("== %d embed mismatch(es) (0 = all 6 methods embedded identical bytes) ==\n", bad);
    return bad;
}
