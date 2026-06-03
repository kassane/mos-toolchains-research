#include <stdio.h>
#include "ext.h"
static uint16_t triple(uint16_t v){ return (uint16_t)(v*3); }   /* C callback */
int main(void){
    uint64_t A=0x0000000100000002ULL, Bv=0x0000000200000003ULL; /* sum 0x300000005 */
    uint64_t want=A+Bv;
    printf("addq(hi:lo) expect %08lx%08lx ; neg(-1234)=1234 ; apply(triple,10)=31\n",
           (unsigned long)(want>>32),(unsigned long)(want&0xffffffff));
    printf("lang  addq_ok  neg  apply  ok\n");
    int bad=0;
    struct{const char*n;uint64_t(*aq)(uint64_t,uint64_t);int16_t(*ng)(int16_t);uint16_t(*ap)(cb_t,uint16_t);} t[]={
        {"C",c_addq,c_neg,c_apply},{"C++",cpp_addq,cpp_neg,cpp_apply},
        {"Rust",rs_addq,rs_neg,rs_apply},{"D",d_addq,d_neg,d_apply},{"Zig",zig_addq,zig_neg,zig_apply},
    };
    for(int i=0;i<5;i++){
        uint64_t q=t[i].aq(A,Bv); int16_t ng=t[i].ng(-1234); uint16_t ap=t[i].ap(triple,10);
        int qok=(q==want), ngok=(ng==1234), apok=(ap==31);
        int ok=qok&&ngok&&apok;
        printf("%-5s %-7s %4d %5u   %s\n", t[i].n, qok?"yes":"NO", ng, ap, ok?"PASS":"FAIL");
        if(!ok) bad++;
    }
    printf("== %d extended-ABI failure(s) ==\n", bad);
    return bad;
}
