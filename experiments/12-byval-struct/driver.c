#include <stdio.h>
#include "bv.h"
/* By-value struct ABI on MOS splits into two camps for aggregates <=4 bytes:
 *   {C, C++, Zig}  decompose into scalar registers  (the official MOS C ABI)
 *   {Rust, LDC}    pass indirectly by hidden pointer (non-conformant)
 * so a C caller (which decomposes) feeds Rust/D garbage. The >4-byte path
 * (Big via sret pointer) is agreed by everyone. Portable fix: pass by pointer
 * (see exp 02/08) or keep aggregates >4 bytes. */
int main(void){
    struct Small s = { 40, 2 };  /* sum 42 */
    printf("by-value struct ABI (small<=4B register-decomposed; big>4B sret)\n");
    printf("lang  small  big_sum  small-ABI\n");
    int bad = 0;
    /* camp that MUST match C (frontends that register-decompose small structs) */
    struct { const char *n; uint16_t(*sm)(struct Small); struct Big(*mk)(uint16_t); } dec[] = {
        {"C",c_small,c_mkbig},{"C++",cpp_small,cpp_mkbig},{"Zig",zig_small,zig_mkbig},
    };
    for(int i=0;i<3;i++){
        uint16_t sm=dec[i].sm(s); struct Big b=dec[i].mk(10);
        uint16_t bs=(uint16_t)(b.a+b.b+b.c+b.d);
        int ok=(sm==42 && bs==46);
        printf("%-5s %4u   %5u    %s\n", dec[i].n, sm, bs, ok?"decompose OK":"BROKEN");
        if(!ok) bad++;
    }
    /* camp expected to diverge on SMALL (indirect), but agree on BIG (sret) */
    struct { const char *n; uint16_t(*sm)(struct Small); struct Big(*mk)(uint16_t); } ind[] = {
        {"Rust",rs_small,rs_mkbig},{"D",d_small,d_mkbig},
    };
    for(int i=0;i<2;i++){
        uint16_t sm=ind[i].sm(s); struct Big b=ind[i].mk(10);
        uint16_t bs=(uint16_t)(b.a+b.b+b.c+b.d);
        int small_div=(sm!=42), big_ok=(bs==46);
        printf("%-5s %4u   %5u    %s\n", ind[i].n, sm, bs,
               small_div ? "DIVERGES (indirect, documented)" : "now-matches(!)");
        if(!big_ok) bad++;            /* big (sret) must still agree everywhere */
    }
    printf("== %d unexpected failure(s) (0 = decompose camp + all big agree) ==\n", bad);
    return bad;
}
