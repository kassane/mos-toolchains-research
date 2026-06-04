// Zig — real-world MOS asm idioms (exp 25).
// (A) Zig's container-level global asm = the iNES config-symbol idiom. It MUST live in
//     a top-level `comptime` block; NO `volatile` and NO clobber colons are allowed at
//     container scope. Emits the same ABSOLUTE symbol as C's file-scope asm().
comptime {
    asm (".globl __cfg_zig\n__cfg_zig = 30");
}
// (B) Real-world inline-asm MMIO putchar; A + memory clobbered (Zig ships the whole
//     register file as clobber tokens — see docs/12).
export fn zig_hw() void {
    asm volatile ("lda #90\nsta 65529" ::: .{ .a = true, .memory = true }); // 'Z' (=$FFF9)
}
