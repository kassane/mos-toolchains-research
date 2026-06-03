#include "refl.h"
struct S { uint8_t a; uint32_t b; uint16_t c; };
/* C++ (clang 23): <type_traits> predicates only; field enumeration needs C++26 P2996. */
extern "C" uint16_t cpp_sizeof(){ return (uint16_t)sizeof(S); }
