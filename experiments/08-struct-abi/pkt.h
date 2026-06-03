#ifndef PKT_H
#define PKT_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Alignment-sensitive struct: u32 after a u8. On MOS the datalayout is
 * byte-packed (i32:8 => offset 1, sizeof 6). A frontend using NATURAL
 * alignment would put val at offset 4 (sizeof 12) and MISREAD it over FFI. */
struct Pkt { uint8_t tag; uint32_t val; uint8_t flag; };
uint32_t c_read  (const struct Pkt *p); uint8_t c_size(void);
uint32_t cpp_read(const struct Pkt *p); uint8_t cpp_size(void);
uint32_t rs_read (const struct Pkt *p); uint8_t rs_size(void);
uint32_t d_read  (const struct Pkt *p); uint8_t d_size(void);
uint32_t zig_read(const struct Pkt *p); uint8_t zig_size(void);
uint32_t zig_read_fixed(const struct Pkt *p); uint8_t zig_size_fixed(void);
uint32_t zig_read_packed(const struct Pkt *p); uint8_t zig_size_packed(void);
#ifdef __cplusplus
}
#endif
#endif
