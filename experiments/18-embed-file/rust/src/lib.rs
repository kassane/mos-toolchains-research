#![no_std]
// path is relative to THIS source file (rust/src/lib.rs -> 18-embed-file/payload.bin)
static D: &[u8] = include_bytes!("../../payload.bin");
#[unsafe(no_mangle)] pub extern "C" fn rs_sum() -> u16 {
    let mut s: u16 = 0; for &b in D { s = s.wrapping_add(b as u16); } s
}
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
