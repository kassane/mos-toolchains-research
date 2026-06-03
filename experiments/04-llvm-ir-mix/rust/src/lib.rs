#![no_std]
#[unsafe(no_mangle)]
pub extern "C" fn rs_step(x: u16) -> u16 { x << 1 }
#[panic_handler] fn p(_: &core::panic::PanicInfo) -> ! { loop {} }
