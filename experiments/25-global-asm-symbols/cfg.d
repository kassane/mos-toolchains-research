module cfg;
import ldc.llvmasm;
// D (LDC) — real-world MOS asm idioms (exp 25).
// (A) D has NO module-scope asm, so the iNES config directives are emitted from a
//     never-called @trusted function via ldc.llvmasm.__asm_trusted. `.globl x` / `x = N`
//     are pure assembler directives, so they define the ABSOLUTE symbol regardless of
//     whether the host function is ever called (verified: `A __cfg_d` in llvm-nm).
extern(C) void __cfg_d_def() @trusted {
    __asm_trusted(".globl __cfg_d\n__cfg_d = 50", "");
}
// (B) Real-world inline-asm MMIO putchar; A + memory clobbered (raw LLVM constraints).
extern(C) void d_hw() @trusted {
    __asm_trusted("lda #68\nsta 65529", "~{a},~{memory}"); // 'D'  (65529 = $FFF9)
}
