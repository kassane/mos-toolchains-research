#include <stdio.h>
#include "zc.h"
int main(void){
    uint16_t arr[8] = {1,2,3,4,5,6,7,8};   /* sum=36 */
    printf("sum16  apply(5)->20\n");
    printf("lang  sum  apply  ok\n");
    int bad=0;
    struct{const char*n;uint16_t(*s)(const uint16_t*,uint16_t);uint16_t(*a)(uint16_t);} t[]={
        {"C",c_sum16,c_apply},{"C++",cpp_sum16,cpp_apply},
        {"Rust",rs_sum16,rs_apply},{"D",d_sum16,d_apply},
    };
    for(int i=0;i<4;i++){
        uint16_t s=t[i].s(arr,8), a=t[i].a(5);
        int ok=(s==36 && a==20);
        printf("%-5s %3u  %4u   %s\n", t[i].n, s, a, ok?"PASS":"FAIL");
        if(!ok) bad++;
    }
    printf("== %d failure(s) ==\n", bad);
    return bad;
}
