#include "std.h"
#include <array>
#include <algorithm>
extern "C" uint16_t cpp_std(void){
    std::array<uint16_t,5> a{}; a[0]=9;a[1]=3;a[2]=7;a[3]=1;a[4]=5;
    return *std::min_element(a.begin(), a.end());  /* 1 ; <algorithm> subset */
}
