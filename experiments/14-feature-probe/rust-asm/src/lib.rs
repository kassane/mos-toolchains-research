#![no_std]
use core::arch::asm;
#[unsafe(no_mangle)] pub extern "C" fn f() { unsafe { asm!("nop"); } }
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
