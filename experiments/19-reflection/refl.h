#ifndef REFL_H
#define REFL_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* The SAME struct S { u8 a; u32 b; u16 c; } in every language.
 * D & Zig have COMPILE-TIME REFLECTION: enumerate fields, sum sizes, read names.
 * C/C++/Rust can only query whole-struct sizeof (no field enumeration in-language). */
uint16_t d_fields(void);   uint16_t d_sizesum(void);   uint16_t d_namesum(void);
uint16_t zig_fields(void); uint16_t zig_sizesum(void); uint16_t zig_namesum(void);
uint16_t c_sizeof(void);   uint16_t cpp_sizeof(void);  uint16_t rs_sizeof(void);
#ifdef __cplusplus
}
#endif
#endif
