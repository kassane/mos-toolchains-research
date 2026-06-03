#include "std.h"
#include <stdlib.h>
#include <string.h>
uint16_t c_std(void){
    char *p = (char*)malloc(16); if(!p) return 0;
    memset(p, 'A', 15); p[15]=0;
    uint16_t n = (uint16_t)strlen(p);   /* 15 */
    free(p);
    return n;
}
