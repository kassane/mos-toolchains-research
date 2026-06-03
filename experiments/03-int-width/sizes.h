#ifndef SIZES_H
#define SIZES_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Each language reports byte-sizes of its OWN native types (via the language's
 * own sizeof/.sizeof/@sizeOf). A C driver prints them side by side to expose
 * where the languages DISAGREE on a same-named type over the LLVM-MOS ABI. */
uint8_t d_int_bytes(void);    uint8_t d_long_bytes(void);
uint8_t d_sizet_bytes(void);  uint8_t d_ptr_bytes(void);
uint8_t zig_cint_bytes(void); uint8_t zig_usize_bytes(void); uint8_t zig_i32_bytes(void);
uint8_t rs_cint_bytes(void);  uint8_t rs_usize_bytes(void);  uint8_t rs_i32_bytes(void);
#ifdef __cplusplus
}
#endif
#endif
