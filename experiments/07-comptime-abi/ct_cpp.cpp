#include <cstdint>
#include <cstddef>
static_assert(sizeof(int)   == 2, "mos C++ int is 16-bit");
static_assert(sizeof(long)  == 4, "mos C++ long is 32-bit");
static_assert(sizeof(void*) == 2, "mos pointer is 16-bit");
static_assert(alignof(std::int32_t) == 1, "mos: byte-aligned");
extern "C" int ct_cpp_ok(){ return 0; }
