#![no_std]
#![feature(asm_experimental_arch)] // MOS asm! is experimental-arch-gated (like avr/msp430)
use core::arch::asm;
// rust-mos#13 FIXED (rebuilt toolchain): inline asm! works on MOS.
// Reg classes: GPR `a`/`x`/`y`; Imag8 scratch `rc2`..`rc29`. Reserved (rejected as
// operands, with custom diagnostics): rc0/rc1 (rs0, soft-stack ptr), rc30/rc31 (rs15,
// frame ptr), s (HW SP). Flags are clobbered by default (no per-flag token).

// (1) Fine-grained explicit clobbers: clc; adc #3 => A = A+3, trashing X/Y/rc2.
#[unsafe(no_mangle)]
pub extern "C" fn rs_asm_add3(mut v: u8) -> u8 {
    unsafe {
        asm!(
            "ldx #0", "ldy #0",     // trash X / Y
            "clc", "adc #3",        // A = A + 3
            inout("a") v => v,      // A register operand
            out("x") _,             // X clobber
            out("y") _,             // Y clobber
            out("rc2") _,           // Imag8 zero-page register clobber
            options(nomem, nostack),
        );
    }
    v
}

// (2) Same effect via clobber_abi("C") — declares the asm clobbers the whole C-ABI
// caller-saved set without enumerating it. On MOS this expands to ={x},={y},
// ={rc2}..={rc19},~{cc} (verified in the IR). Supported on the rebuilt rust-mos.
#[unsafe(no_mangle)]
pub extern "C" fn rs_asm_add3_abi(mut v: u8) -> u8 {
    unsafe {
        asm!(
            "ldx #0", "ldy #0", "clc", "adc #3",
            inout("a") v => v,      // A is the explicit operand
            clobber_abi("C"),       // X, Y, rc2..rc19, cc clobbered as a C call would
            options(nomem, nostack),
        );
    }
    v
}

#[panic_handler] fn p(_: &core::panic::PanicInfo) -> ! { loop {} }
