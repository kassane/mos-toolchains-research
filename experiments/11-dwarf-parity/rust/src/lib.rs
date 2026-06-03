#![no_std]
#[unsafe(no_mangle)] pub extern "C" fn dbg_add(a:i32,b:i32)->i32{ let s=a.wrapping_add(b); s }
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
