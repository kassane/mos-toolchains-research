#![no_std]
type CbT = extern "C" fn(u16) -> u16;
#[unsafe(no_mangle)] pub extern "C" fn rs_addq(a:u64,b:u64)->u64{ a.wrapping_add(b) }
#[unsafe(no_mangle)] pub extern "C" fn rs_neg(x:i16)->i16{ x.wrapping_neg() }
#[unsafe(no_mangle)] pub extern "C" fn rs_apply(f:CbT,x:u16)->u16{ f(x).wrapping_add(1) }
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
