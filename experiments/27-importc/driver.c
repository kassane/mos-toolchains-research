#include <stdio.h>
#include "imc.h"
int main(void){
    unsigned s = isz();                       /* 2 = 16-bit int (the fix)             */
    int a = add(40, 2);                        /* 42                                    */
    struct P p = { 20, 22 };
    int q = psum(p);                           /* 42 — C caller -> ImportC by-value cb  */
    printf("ImportC: sizeof(int)=%u  add(40,2)=%d  psum{20,22}=%d\n", s, a, q);
    int ok = (s == 2 && a == 42 && q == 42);
    printf("%s\n", ok ? "PASS (16-bit int + C<->ImportC FFI incl. by-value struct)" : "FAIL");
    return ok ? 0 : 1;
}
