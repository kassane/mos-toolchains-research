#include "scope.h"
/* C scope guard via the clang/GCC cleanup attribute (LIFO at scope exit). */
static void cl(char *p){ trace(*p); }
void c_run(void){
    char a __attribute__((cleanup(cl))) = '1';
    char b __attribute__((cleanup(cl))) = '2';
    (void)a; (void)b;
}
