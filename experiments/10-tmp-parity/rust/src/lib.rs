#![no_std]
const fn fact(n: u32) -> u32 { if n < 2 { 1 } else { n * fact(n - 1) } }
const F10: u32 = fact(10);
const _: () = assert!(F10 == 3628800);     // compile-time proof
#[unsafe(no_mangle)] pub extern "C" fn rs_fact10() -> u32 { F10 }
#[panic_handler] fn p(_: &core::panic::PanicInfo) -> ! { loop {} }
