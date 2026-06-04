#include <stdio.h>
#include <stdint.h>
/* exp 25 — real-world MOS asm idioms across all five frontends, in one binary.
 *
 * (A) Each language defined an ABSOLUTE config symbol via its global-asm mechanism
 *     (the llvm-mos-sdk iNES mapper-config idiom). For an absolute symbol, &sym IS the
 *     symbol's value, so the driver reads the compile-time constant each frontend baked
 *     into the link — exactly how the NES linker script reads __mirroring/__prg_rom_size.
 * (B) Each language exposes a real-world inline-asm MMIO putchar (store to $FFF9). */
extern char __cfg_c, __cfg_cpp, __cfg_zig, __cfg_rs, __cfg_d;
#define V(s) ((uint16_t)(uintptr_t)&(s))
void c_hw(void); void cpp_hw(void); void zig_hw(void); void rs_hw(void); void d_hw(void);

int main(void) {
    uint16_t c = V(__cfg_c), cp = V(__cfg_cpp), z = V(__cfg_zig), r = V(__cfg_rs), d = V(__cfg_d);
    printf("A) global-asm absolute config symbols (iNES mapper idiom), per frontend:\n");
    printf("   C=%u C++=%u Zig=%u Rust=%u D=%u  sum=%u\n",
           c, cp, z, r, d, (uint16_t)(c + cp + z + r + d));
    int a_ok = (c == 10 && cp == 20 && z == 30 && r == 40 && d == 50);

    printf("B) inline-asm MMIO putchar ($FFF9), per frontend -> ");
    c_hw(); cpp_hw(); zig_hw(); rs_hw(); d_hw();   /* emits: C + Z R D */
    printf("\n%s\n", a_ok ? "PASS (all five define a linker-readable absolute symbol = its value)"
                          : "FAIL (a config symbol did not resolve to its constant)");
    return a_ok ? 0 : 1;
}
