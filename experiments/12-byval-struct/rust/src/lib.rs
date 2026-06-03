#![no_std]
#[repr(C)] pub struct Small { a: u8, b: u8 }
#[repr(C)] pub struct Big { a: u16, b: u16, c: u16, d: u16 }
#[unsafe(no_mangle)] pub extern "C" fn rs_small(p: Small) -> u16 { p.a as u16 + p.b as u16 }
#[unsafe(no_mangle)] pub extern "C" fn rs_mkbig(base: u16) -> Big {
    Big{ a: base, b: base.wrapping_add(1), c: base.wrapping_add(2), d: base.wrapping_add(3) }
}
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
