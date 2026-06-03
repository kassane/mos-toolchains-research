#![no_std]
// exactly the mos-hardware poke! macro: core::ptr::write_volatile(addr, val)
#[unsafe(no_mangle)] pub extern "C" fn rs_poke(c: u8) {
    unsafe { core::ptr::write_volatile(0xFFF9 as *mut u8, c); }
}
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
