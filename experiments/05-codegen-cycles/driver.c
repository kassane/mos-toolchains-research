#include <stdio.h>
#include <stdint.h>
#include "bench.h"
static volatile uint32_t *const CYC = (volatile uint32_t *)0xFFF0;
static uint32_t timed(uint16_t (*f)(uint16_t), uint16_t n, uint16_t *out) {
    uint32_t t0 = *CYC; *out = f(n); return *CYC - t0;
}
int main(void) {
    uint16_t rc,rcpp,rrs,rd,rz;
    uint32_t cc=timed(c_lcg,1000,&rc),  ccpp=timed(cpp_lcg,1000,&rcpp),
             crs=timed(rs_lcg,1000,&rrs),cd=timed(d_lcg,1000,&rd),
             cz=timed(zig_lcg,1000,&rz);
    printf("lang  result  cycles\n");
    printf("C     %5u   %lu\n", rc,  (unsigned long)cc);
    printf("C++   %5u   %lu\n", rcpp,(unsigned long)ccpp);
    printf("Rust  %5u   %lu\n", rrs, (unsigned long)crs);
    printf("D     %5u   %lu\n", rd,  (unsigned long)cd);
    printf("Zig   %5u   %lu\n", rz,  (unsigned long)cz);
    int bad = !(rc==rcpp && rc==rrs && rc==rd && rc==rz);
    printf("== results %s ==\n", bad ? "DIVERGE" : "IDENTICAL");
    return bad;
}
