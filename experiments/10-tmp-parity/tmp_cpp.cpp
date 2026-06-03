#include "tmp.h"
// constexpr: MAY run at compile time (and does in a const context / at -O>=1).
constexpr uint32_t fact(uint32_t n){ return n<2 ? 1u : n*fact(n-1); }
static_assert(fact(10)==3628800u, "CTFE");
extern "C" uint32_t cpp_fact10(void){ return fact(10); }

// consteval (C++20): immediate function -- MUST evaluate at compile time, the
// strictest form (analogous to Zig's comptime). It cannot be called at runtime.
consteval uint32_t cfact(uint32_t n){ return n<2 ? 1u : n*cfact(n-1); }
extern "C" uint32_t cpp_fact10_ce(void){ return cfact(10); }
