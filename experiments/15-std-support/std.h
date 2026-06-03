#ifndef STD_H
#define STD_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Each function exercises its language's STANDARD-LIBRARY reach on bare MOS and
 * returns a checkable value. The C driver links them all and runs on mos-sim. */
uint16_t c_std(void);    /* C    libc: malloc + memset + strlen          */
uint16_t cpp_std(void);  /* C++  STL subset: std::array + min_element     */
uint16_t zig_std(void);  /* Zig  std.mem.sort + std.fmt (rich subset)     */
uint16_t rs_std(void);   /* Rust alloc::Vec via global allocator          */
uint16_t d_std(void);    /* D    core.stdc.string + ldc.intrinsics        */
#ifdef __cplusplus
}
#endif
#endif
