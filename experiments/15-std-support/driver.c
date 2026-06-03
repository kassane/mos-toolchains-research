#include <stdio.h>
#include "std.h"
int main(void){
    printf("standard-library reach on bare MOS (each lang's own stdlib):\n");
    struct { const char *n, *what; uint16_t (*f)(void); uint16_t want; } t[] = {
        {"C",   "libc malloc+memset+strlen",      c_std,   15},
        {"C++", "STL <array>+min_element",        cpp_std, 1},
        {"Zig", "std.mem.sort + std.fmt",         zig_std, 101},
        {"Rust","alloc::Vec (global allocator)",   rs_std,  15},
        {"D",   "core.stdc.string + ldc.intrinsics", d_std, 1515},
    };
    int bad=0;
    for(int i=0;i<5;i++){
        uint16_t v=t[i].f(); int ok=(v==t[i].want);
        printf("  %-5s %-34s = %-5u %s\n", t[i].n, t[i].what, v, ok?"OK":"FAIL");
        if(!ok) bad++;
    }
    printf("== %d std-demo failure(s) ==\n", bad);
    return bad;
}
