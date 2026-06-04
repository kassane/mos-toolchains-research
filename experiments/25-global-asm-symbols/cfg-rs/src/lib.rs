#![no_std]
#![feature(asm_experimental_arch)]
use core::arch::{asm, global_asm};
// Rust — real-world MOS asm idioms (exp 25).
// (A) global_asm! is the direct equivalent of C's file-scope asm() — the iNES
//     config-symbol idiom. Emits the ABSOLUTE symbol __cfg_rs = 40.
global_asm!(".globl __cfg_rs", "__cfg_rs = 40");
// (B) Real-world inline-asm MMIO putchar; A clobbered, memory left clobberable
//     (no `nomem`, so the compiler treats the MMIO store as touching memory).
#[unsafe(no_mangle)]
pub extern "C" fn rs_hw() {
    unsafe { asm!("lda #82", "sta 65529", out("a") _, options(nostack)); } // 'R' (=$FFF9)
}
#[panic_handler] fn p(_: &core::panic::PanicInfo) -> ! { loop {} }
