#include <stdio.h>
/* exp 26 — float-sqrt PARITY across all frontends on a 6502, via the Rust `libm` crate
 * as the shared soft-math provider (it exports the C `sqrtf` the SDK libm lacks). C, D
 * and Zig link that symbol; Rust uses libm directly. All four compute sqrt(2)*100 = 141.
 * Bonus: float arithmetic runs everywhere with no libm symbol (Zig 22/7*1000). */
extern int c_sqrt_x100(unsigned short);
extern int zig_sqrt_x100(unsigned short);
extern int d_sqrt_x100(unsigned short);
extern int rs_sqrt_x100(unsigned short);
extern int zig_fdiv_x1000(unsigned short, unsigned short);

int main(void) {
    int c = c_sqrt_x100(2), z = zig_sqrt_x100(2), d = d_sqrt_x100(2), r = rs_sqrt_x100(2);
    int fd = zig_fdiv_x1000(22, 7);                    /* soft-float divide -> ~3142 */
    printf("sqrt(2)*100  C=%d Zig=%d D=%d Rust=%d  | soft-float 22/7*1000=%d\n",
           c, z, d, r, fd);
    int ok = (c == 141 && z == 141 && d == 141 && r == 141) && (fd >= 3140 && fd <= 3145);
    printf("%s\n", ok ? "PASS (all four run sqrt via the Rust libm provider; arithmetic runs)"
                      : "FAIL");
    return ok ? 0 : 1;
}
