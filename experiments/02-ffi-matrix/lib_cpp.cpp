#include "ffi.h"
// extern "C" => no C++ mangling, matches the contract symbol.
extern "C" uint16_t cpp_mul16(uint16_t a, uint16_t b) {
    return (uint16_t)(a * b);
}
