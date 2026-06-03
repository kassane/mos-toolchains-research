#![no_std]

// C ABI. u16 == uint16_t (fixed width, ABI-safe across the FFI boundary).
#[unsafe(no_mangle)]
pub extern "C" fn rs_sub16(a: u16, b: u16) -> u16 {
    a.wrapping_sub(b)
}

#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! {
    loop {}
}
