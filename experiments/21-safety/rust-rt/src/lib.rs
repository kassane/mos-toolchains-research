#![no_std]
// Rust inserts a RUNTIME bounds check; OOB index -> panic=abort. The handler
// signals the sim ($FFF8 = exit code) so the trap is observable as exit 77.
#[unsafe(no_mangle)] pub extern "C" fn rs_idx(i: u8) -> u8 {
    let a = [10u8, 20, 30];
    a[i as usize]
}
#[panic_handler] fn ph(_: &core::panic::PanicInfo) -> ! {
    unsafe { core::ptr::write_volatile(0xFFF8 as *mut u8, 77); }
    loop {}
}
