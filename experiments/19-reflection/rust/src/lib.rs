#![no_std]
#[repr(C)] struct S { a: u8, b: u32, c: u16 }
// Rust has NO in-language reflection: size_of only (field enumeration is proc-macro/build-time).
#[unsafe(no_mangle)] pub extern "C" fn rs_sizeof() -> u16 { core::mem::size_of::<S>() as u16 }
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
