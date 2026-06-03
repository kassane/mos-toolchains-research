#include "zc.h"
template<class T> static T sum(const T *a, uint16_t n){ T s=0; for(uint16_t i=0;i<n;i++) s+=a[i]; return s; }
template<class F> static uint16_t apply2(F f, uint16_t x){ return f(f(x)); }
extern "C" uint16_t cpp_sum16(const uint16_t *a, uint16_t n){ return sum<uint16_t>(a,n); }
extern "C" uint16_t cpp_apply(uint16_t x){ return apply2([](uint16_t v){return (uint16_t)(v*2);}, x); }
