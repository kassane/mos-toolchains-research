#include <stdio.h>
#include "hal.h"
int main(void){
    /* each language drives the SAME MMIO console register -> "C+RDZ" */
    c_poke('C'); cpp_poke('+'); rs_poke('R'); d_poke('D'); zig_poke('Z');
    c_poke('\n');
    printf("[5 frontends drove the same MMIO register at $FFF9]\n");
    return 0;
}
