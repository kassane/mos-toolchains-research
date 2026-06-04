#include <stdio.h>
#include "bv.h"
/* By-value struct ABI on MOS for aggregates <=4 bytes: the MOS C ABI decomposes them
 * into scalar registers (>4 bytes go via an sret pointer). All five frontends now
 * AGREE -> every row prints "now-matches(!)"/"decompose OK". D and Rust were the
 * holdouts (both passed indirectly by hidden pointer, feeding a C caller garbage);
 * each was fixed in its callconv rebuild -- Rust first, then D (LDC, now a first-class
 * aggregate, no `byval`). A small-struct divergence here would now be a REGRESSION.
 * Conservative/version-proof fix: pass aggregates by pointer or keep them >4 bytes
 * (no ABI-stability promise). */
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
    /* the two formerly-indirect holdouts (Rust, then D) — both fixed; must now match */
    struct { const char *n; uint16_t(*sm)(struct Small); struct Big(*mk)(uint16_t); } ind[] = {
        {"Rust",rs_small,rs_mkbig},{"D",d_small,d_mkbig},
    };
    for(int i=0;i<2;i++){
        uint16_t sm=ind[i].sm(s); struct Big b=ind[i].mk(10);
        uint16_t bs=(uint16_t)(b.a+b.b+b.c+b.d);
        int small_div=(sm!=42), big_ok=(bs==46);
        printf("%-5s %4u   %5u    %s\n", ind[i].n, sm, bs,
               small_div ? "DIVERGES (REGRESSION!)" : "now-matches(!)");
        if(!big_ok || small_div) bad++;  /* hole closed: small AND big must now agree */
    }
    printf("== %d unexpected failure(s) (0 = all five decompose + all big agree) ==\n", bad);
    return bad;
}
