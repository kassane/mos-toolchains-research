#![no_std]
#[unsafe(no_mangle)]
pub extern "C" fn rs_lcg(n: u16) -> u16 {
    let mut s: u16 = 0; let mut i: u16 = 0;
    while i < n { s = s.wrapping_mul(31).wrapping_add(i); i = i.wrapping_add(1); }
    s
}
#[panic_handler] fn p(_: &core::panic::PanicInfo)->!{loop{}}
