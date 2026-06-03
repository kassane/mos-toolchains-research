#include <stdio.h>
#include "tmp.h"
int main(void){
    printf("factorial(10) = 3628800 (compile-time except C)\n");
    printf("lang  value     ok\n");
    int bad=0;
    struct{const char*n;uint32_t(*f)(void);} t[]={
        {"C(rt)",c_fact10},{"C++",cpp_fact10},{"Rust",rs_fact10},{"D",d_fact10},
    };
    for(int i=0;i<4;i++){
        uint32_t v=t[i].f();
        int ok=(v==3628800u);
        printf("%-6s %lu   %s\n", t[i].n, (unsigned long)v, ok?"PASS":"FAIL");
        if(!ok) bad++;
    }
    printf("== %d failure(s) ==\n", bad);
    return bad;
}
