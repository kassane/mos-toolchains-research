/* C compile-time ABI assertions. Compiles ONLY if every fact holds. */
#include <stdint.h>
#include <stddef.h>
_Static_assert(sizeof(int)    == 2, "mos C int is 16-bit");
_Static_assert(sizeof(long)   == 4, "mos C long is 32-bit");
_Static_assert(sizeof(void*)  == 2, "mos pointer is 16-bit");
_Static_assert(sizeof(size_t) == 2, "mos size_t matches pointer");
_Static_assert(_Alignof(int32_t) == 1, "mos: everything byte-aligned (datalayout a:8/n8)");
int ct_c_ok(void){ return 0; }
