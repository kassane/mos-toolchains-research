#![no_std]
#[unsafe(no_mangle)] pub extern "C" fn rs_sub16(a:u16,b:u16)->u16{ a.wrapping_sub(b) }
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
