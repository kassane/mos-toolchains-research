#include <stdio.h>
#include "pkt.h"
int main(void){
    struct Pkt p = { 0x11, 0xDEADBEEF, 0x22 };
    uint8_t ref = c_size();
    printf("C sizeof(Pkt) = %u (byte-packed expect 6)\n", ref);
    printf("lang        size  read_val    status\n");
    /* The co-ABI group: must all match C's byte-packed layout exactly. */
    struct { const char*n; uint32_t (*r)(const struct Pkt*); uint8_t (*s)(void);} grp[] = {
        {"C",c_read,c_size},{"C++",cpp_read,cpp_size},{"Rust",rs_read,rs_size},
        {"D",d_read,d_size},{"Zig(align1)",zig_read_fixed,zig_size_fixed},
    };
    int bad = 0;
    for(int i=0;i<5;i++){
        uint32_t v=grp[i].r(&p); uint8_t s=grp[i].s();
        int ok=(v==0xDEADBEEF && s==ref);
        printf("%-11s %3u   0x%08lX  %s\n", grp[i].n, s, (unsigned long)v, ok?"PASS":"FAIL");
        if(!ok) bad++;
    }
    /* Zig diagnostics. packed: value-correct but @sizeOf=8 (u48 backing rounds
     * up) -> read-compatible, NOT size-compatible. plain: over-aligns, garbage. */
    uint32_t pv=zig_read_packed(&p); uint8_t ps=zig_size_packed();
    printf("%-11s %3u   0x%08lX  %s\n", "Zig(packed)", ps, (unsigned long)pv,
           (pv==0xDEADBEEF) ? "val OK, size!=6 (caveat)" : "FAIL");
    if(pv!=0xDEADBEEF) bad++;
    uint32_t zv=zig_read(&p); uint8_t zs=zig_size();
    int diverges=(zs!=ref);
    printf("%-11s %3u   0x%08lX  %s\n", "Zig(plain)", zs, (unsigned long)zv,
           diverges ? "DIVERGES (documented hole)" : "unexpectedly-matches");
    if(!diverges) bad++;
    printf("== %d unexpected result(s) (0 = co-ABI group exact, Zig hole as documented) ==\n", bad);
    return bad;
}
