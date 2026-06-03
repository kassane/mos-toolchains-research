#include <stdio.h>
#include <stddef.h>
#include "sizes.h"

int main(void) {
    printf("type        C   D   Zig Rust\n");
    printf("int/i32 kw  %d   %d   -   -   <- C 'int' vs D 'int' DIFFER\n",
           (int)sizeof(int), d_int_bytes());
    printf("long        %d   %d   -   -   <- C 'long' vs D 'long' DIFFER\n",
           (int)sizeof(long), d_long_bytes());
    printf("size_t      %d   %d   %d   %d   <- D size_t WIDER than pointer (ldc#1)\n",
           (int)sizeof(size_t), d_sizet_bytes(), zig_usize_bytes(), rs_usize_bytes());
    printf("pointer     %d   %d   %d   %d\n",
           (int)sizeof(void*), d_ptr_bytes(), zig_usize_bytes(), rs_usize_bytes());
    printf("c_int       %d   -   %d   %d   <- agree (all 16-bit)\n",
           (int)sizeof(int), zig_cint_bytes(), rs_cint_bytes());
    printf("i32 fixed   %d   %d   %d   %d   <- agree (all 32-bit)\n",
           (int)sizeof(int32_t), d_int_bytes(), zig_i32_bytes(), rs_i32_bytes());

    /* The actionable check: the keyword 'int' is NOT abi-compatible C<->D. */
    int fails = 0;
    /* Characterization: exit 0 iff every divergence is exactly as documented.
     * These are FACTS about this toolchain set, asserted so the experiment is a
     * regression test, not a one-off print. */
    #define EXPECT(cond) do { if(!(cond)){ printf("UNEXPECTED: " #cond "\n"); fails++; } } while(0)
    EXPECT(sizeof(int)    == 2);              /* C int  = i16 (mos ABI)           */
    EXPECT(sizeof(long)   == 4);              /* C long = i32                     */
    EXPECT(sizeof(void*)  == 2);              /* pointer = 16-bit                 */
    EXPECT(d_int_bytes()  == 4);              /* D int  = 32-bit (D spec)         */
    EXPECT(d_long_bytes() == 8);              /* D long = 64-bit (D spec)         */
    EXPECT(d_sizet_bytes()== 2);              /* D size_t FIXED to ptr (LDC 1.42) */
    EXPECT(zig_cint_bytes()== 4);             /* Zig c_int = 32-bit FOOTGUN != C  */
    EXPECT(zig_usize_bytes()== 2);            /* Zig usize = 16-bit, matches ptr  */
    EXPECT(rs_cint_bytes()== 2);              /* Rust c_int = 16-bit, matches C   */
    EXPECT(rs_usize_bytes()== 2);             /* Rust usize = 16-bit, matches ptr */
    EXPECT(rs_i32_bytes()==4 && zig_i32_bytes()==4 && d_int_bytes()==4); /* fixed-width agrees */
    printf("== %d unexpected mismatch(es) (0 = all divergences as documented) ==\n", fails);
    return fails;
}
